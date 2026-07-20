resource "aws_s3_bucket" "state_bucket" {
  bucket = var.bucket_name
  tags = {
    Name = "tf-state-file"
  }
}

resource "aws_s3_bucket_versioning" "versioning_state_bucket" {
  bucket = aws_s3_bucket.state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
output "state_bucket_name" {
  value = aws_s3_bucket.state_bucket.bucket
}