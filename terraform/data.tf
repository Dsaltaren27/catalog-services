data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_route_tables" "vpc" {
  vpc_id = var.vpc_id
}

data "aws_iam_policy_document" "catalog_lambda" {
  statement {
    sid    = "AllowCatalogBucketReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${var.catalog_bucket_name}/${var.catalog_object_key}",
      "arn:aws:s3:::${var.catalog_bucket_name}/${dirname(var.catalog_object_key)}/*"
    ]
  }

  statement {
    sid    = "AllowCatalogBucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.catalog_bucket_name}"
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${dirname(var.catalog_object_key)}/*"]
    }
  }

  statement {
    sid    = "AllowElasticNetworkInterfaces"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses"
    ]
    resources = ["*"]
  }
}
