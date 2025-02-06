provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-jte-terraform-bucket"
  acl    = "private"
}
