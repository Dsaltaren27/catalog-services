variable "region" {
  default = "us-east-1"
}

variable "bucket_name" {
  default = "bank-avatar-bucket-2026"
}

variable "redis_host" {
  default = "catalog-redis.i9vrbu.ng.0001.use1.cache.amazonaws.com"
}

variable "subnet_ids" {
  type = list(string)
  default = [
    "subnet-0869f50fd1fa1b1af",
    "subnet-0d55f91852e120713"
  ]
}

variable "security_group_ids" {
  type = list(string)
  default = [
    "sg-0cfb5e305ffdf3c9a"
  ]
}