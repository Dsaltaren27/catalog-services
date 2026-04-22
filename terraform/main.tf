provider "aws" {
  region = var.region
}

# ======================
# IAM ROLE
# ======================
resource "aws_iam_role" "lambda_role" {
  name = "catalog-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# ======================
# LOGS (CRÍTICO - LO QUE SERVERLESS TE DABA AUTOMÁTICO)
# ======================
resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ======================
# PERMISOS S3
# ======================
resource "aws_iam_role_policy" "s3_policy" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::${var.bucket_name}",
        "arn:aws:s3:::${var.bucket_name}/*"
      ]
    }]
  })
}

# ======================
# VPC PERMISSIONS
# ======================
resource "aws_iam_role_policy" "vpc_policy" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses"
      ]
      Resource = "*"
    }]
  })
}

# ======================
# LAMBDA updateCatalog
# ======================
resource "aws_lambda_function" "update_catalog" {
  function_name = "updateCatalog"

  handler = "src/handlers/updateCatalog.handler"
  runtime = "nodejs18.x"

  role = aws_iam_role.lambda_role.arn

  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")

  timeout = 15

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      REDIS_HOST  = var.redis_host
      BUCKET_NAME = var.bucket_name
    }
  }
}

# ======================
# LAMBDA getCatalog
# ======================
resource "aws_lambda_function" "get_catalog" {
  function_name = "getCatalog"

  handler = "src/handlers/getCatalog.handler"
  runtime = "nodejs18.x"

  role = aws_iam_role.lambda_role.arn

  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      REDIS_HOST = var.redis_host
    }
  }
}

# ======================
# API GATEWAY
# ======================
resource "aws_apigatewayv2_api" "api" {
  name          = "catalog-api"
  protocol_type = "HTTP"
}

# ======================
# INTEGRATIONS
# ======================
resource "aws_apigatewayv2_integration" "update_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.update_catalog.invoke_arn
}

resource "aws_apigatewayv2_integration" "get_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.get_catalog.invoke_arn
}

# ======================
# ROUTES
# ======================
resource "aws_apigatewayv2_route" "update_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /catalog/update"
  target    = "integrations/${aws_apigatewayv2_integration.update_integration.id}"
}

resource "aws_apigatewayv2_route" "get_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /catalog"
  target    = "integrations/${aws_apigatewayv2_integration.get_integration.id}"
}

# ======================
# STAGE
# ======================
resource "aws_apigatewayv2_stage" "dev" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

# ======================
# PERMISOS API GATEWAY → LAMBDA 
# ======================
resource "aws_lambda_permission" "apigw_get" {
  statement_id  = "AllowGetInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_catalog.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_update" {
  statement_id  = "AllowUpdateInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_catalog.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}