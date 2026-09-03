output "assets_bucket_name" {
  description = "S3 assets bucket name."
  value       = aws_s3_bucket.assets.bucket
}

output "assets_bucket_arn" {
  description = "S3 assets bucket ARN."
  value       = aws_s3_bucket.assets.arn
}
