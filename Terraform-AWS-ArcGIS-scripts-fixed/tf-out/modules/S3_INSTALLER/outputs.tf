output "bucket_name" {
  value = aws_s3_bucket.arcgis_installer.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.arcgis_installer.arn
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.psage_profile.name
}
