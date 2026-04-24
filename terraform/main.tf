locals {
  name_prefix         = "${var.project_name}-${var.environment}-${var.resource_suffix}"
  lambda_zip_path     = "${path.root}/../.artifacts/catalog-lambda.zip"
  catalog_seed_source = "${path.root}/../servicios.csv"
  catalog_bucket_name = lower("${var.project_name}-${var.environment}-${var.resource_suffix}-${data.aws_caller_identity.current.account_id}")
}

resource "aws_security_group" "lambda" {
  name        = "${local.name_prefix}-lambda-sg"
  description = "Security group for catalog lambdas"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-redis-sg"
  description = "Security group for Redis"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow Lambda access to Redis"
    from_port       = var.redis_port
    to_port         = var.redis_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name_prefix}-redis-subnets"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = replace("${local.name_prefix}-redis", "_", "-")
  description                = "Redis for the catalog cache"
  engine                     = "redis"
  engine_version             = var.redis_engine_version
  node_type                  = var.redis_node_type
  num_cache_clusters         = 1
  port                       = var.redis_port
  parameter_group_name       = "default.redis7"
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]
  automatic_failover_enabled = false
  multi_az_enabled           = false
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false
}

resource "aws_s3_bucket" "catalog" {
  bucket        = local.catalog_bucket_name
  force_destroy = true
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "catalog_lambda" {
  name   = "${local.name_prefix}-catalog-lambda"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.catalog_lambda.json
}

resource "aws_cloudwatch_log_group" "catalog_processor" {
  name              = "/aws/lambda/${local.name_prefix}-catalog-processor"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "catalog_reader" {
  name              = "/aws/lambda/${local.name_prefix}-catalog-reader"
  retention_in_days = 14
}

resource "aws_lambda_function" "catalog_processor" {
  function_name    = "${local.name_prefix}-catalog-processor"
  role             = aws_iam_role.lambda.arn
  runtime          = var.lambda_runtime
  handler          = "src/lambda/handlers/updateCatalog.handler"
  filename         = local.lambda_zip_path
  source_code_hash = filebase64sha256(local.lambda_zip_path)
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      CATALOG_BUCKET_NAME = aws_s3_bucket.catalog.bucket
      CATALOG_CACHE_KEY   = var.catalog_cache_key
      REDIS_HOST          = aws_elasticache_replication_group.redis.primary_endpoint_address
      REDIS_PORT          = tostring(var.redis_port)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.catalog_processor,
    aws_iam_role_policy_attachment.lambda_basic_logs,
    aws_iam_role_policy.catalog_lambda
  ]
}

resource "aws_lambda_function" "catalog_reader" {
  function_name    = "${local.name_prefix}-catalog-reader"
  role             = aws_iam_role.lambda.arn
  runtime          = var.lambda_runtime
  handler          = "src/lambda/handlers/getCatalog.handler"
  filename         = local.lambda_zip_path
  source_code_hash = filebase64sha256(local.lambda_zip_path)
  timeout          = 10
  memory_size      = 128

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      CATALOG_CACHE_KEY = var.catalog_cache_key
      REDIS_HOST        = aws_elasticache_replication_group.redis.primary_endpoint_address
      REDIS_PORT        = tostring(var.redis_port)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.catalog_reader,
    aws_iam_role_policy_attachment.lambda_basic_logs,
    aws_iam_role_policy.catalog_lambda
  ]
}

resource "aws_lambda_permission" "allow_s3_to_invoke_catalog_processor" {
  statement_id  = "AllowS3InvokeCatalogProcessor"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.catalog_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.catalog.arn
}

resource "aws_s3_bucket_notification" "catalog_upload" {
  bucket = aws_s3_bucket.catalog.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.catalog_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = dirname(var.catalog_object_key) == "." ? "" : "${dirname(var.catalog_object_key)}/"
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.allow_s3_to_invoke_catalog_processor]
}

resource "aws_s3_object" "catalog_seed" {
  bucket       = aws_s3_bucket.catalog.id
  key          = var.catalog_object_key
  source       = local.catalog_seed_source
  content_type = "text/csv"
  etag         = filemd5(local.catalog_seed_source)

  depends_on = [aws_s3_bucket_notification.catalog_upload]
}

resource "aws_api_gateway_rest_api" "catalog" {
  name        = "${local.name_prefix}-catalog-api"
  description = "Catalog API backed by Redis"
}

resource "aws_api_gateway_resource" "catalog" {
  rest_api_id = aws_api_gateway_rest_api.catalog.id
  parent_id   = aws_api_gateway_rest_api.catalog.root_resource_id
  path_part   = "catalog"
}

resource "aws_api_gateway_method" "catalog_get" {
  rest_api_id   = aws_api_gateway_rest_api.catalog.id
  resource_id   = aws_api_gateway_resource.catalog.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "catalog_get" {
  rest_api_id             = aws_api_gateway_rest_api.catalog.id
  resource_id             = aws_api_gateway_resource.catalog.id
  http_method             = aws_api_gateway_method.catalog_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.catalog_reader.invoke_arn
}

resource "aws_api_gateway_deployment" "catalog" {
  rest_api_id = aws_api_gateway_rest_api.catalog.id

  depends_on = [aws_api_gateway_integration.catalog_get]

  triggers = {
    redeployment = sha1(jsonencode({
      resource    = aws_api_gateway_resource.catalog.id
      method      = aws_api_gateway_method.catalog_get.id
      integration = aws_api_gateway_integration.catalog_get.id
    }))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "catalog" {
  rest_api_id   = aws_api_gateway_rest_api.catalog.id
  deployment_id = aws_api_gateway_deployment.catalog.id
  stage_name    = var.environment
}

resource "aws_lambda_permission" "allow_apigw_to_invoke_catalog_reader" {
  statement_id  = "AllowApiGatewayInvokeCatalogReader"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.catalog_reader.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.catalog.execution_arn}/*/GET/catalog"
}

output "catalog_api_url" {
  description = "Invoke URL for the catalog API stage."
  value       = aws_api_gateway_stage.catalog.invoke_url
}

output "catalog_get_url" {
  description = "GET endpoint URL for the catalog API."
  value       = "${aws_api_gateway_stage.catalog.invoke_url}/catalog"
}

output "redis_primary_endpoint" {
  description = "Primary Redis endpoint address."
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "catalog_bucket_name" {
  description = "Generated S3 bucket name for the catalog."
  value       = aws_s3_bucket.catalog.bucket
}
