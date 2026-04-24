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

data "aws_caller_identity" "current" {
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
      "${aws_s3_bucket.catalog.arn}/${var.catalog_object_key}",
      "${aws_s3_bucket.catalog.arn}/${dirname(var.catalog_object_key)}/*"
    ]
  }

  statement {
    sid    = "AllowCatalogBucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.catalog.arn
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
