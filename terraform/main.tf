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
# LOGS LAMBDA
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
# VPC PERMISSIONS (Redis en VPC)
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
# LAMBDA: UPDATE CATALOG
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
# LAMBDA: GET CATALOG
# ======================
resource "aws_lambda_function" "get_catalog" {
  function_name = "getCatalog"

  handler = "src/handlers/getCatalog.handler"
  runtime = "nodejs18.x"

  role = aws_iam_role.lambda_role.arn

  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")

  timeout = 10

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
# API GATEWAY REST API (CORREGIDO)
# ======================
resource "aws_api_gateway_rest_api" "api" {
  name        = "catalog-api"
  description = "Catalog REST API"
}

# ======================
# RESOURCES
# ======================

# /catalog
resource "aws_api_gateway_resource" "catalog" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "catalog"
}

# /catalog/update
resource "aws_api_gateway_resource" "catalog_update" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.catalog.id
  path_part   = "update"
}

# ======================
# METHODS
# ======================

# GET /catalog
resource "aws_api_gateway_method" "get_catalog" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.catalog.id
  http_method   = "GET"
  authorization = "NONE"
}

# POST /catalog/update
resource "aws_api_gateway_method" "update_catalog" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.catalog_update.id
  http_method   = "POST"
  authorization = "NONE"
}

# ======================
# INTEGRATIONS (LAMBDA PROXY)
# ======================

resource "aws_api_gateway_integration" "get_catalog_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.catalog.id
  http_method = aws_api_gateway_method.get_catalog.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_catalog.invoke_arn
}

resource "aws_api_gateway_integration" "update_catalog_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.catalog_update.id
  http_method = aws_api_gateway_method.update_catalog.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.update_catalog.invoke_arn
}

# ======================
# DEPLOYMENT
# ======================
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [
    aws_api_gateway_integration.get_catalog_integration,
    aws_api_gateway_integration.update_catalog_integration
  ]
}

# ======================
# STAGE
# ======================
resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "dev"
}

# ======================
# LAMBDA PERMISSIONS
# ======================

resource "aws_lambda_permission" "apigw_get" {
  statement_id  = "AllowGetInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_catalog.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/GET/catalog"
}

resource "aws_lambda_permission" "apigw_update" {
  statement_id  = "AllowUpdateInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_catalog.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/POST/catalog/update"
}