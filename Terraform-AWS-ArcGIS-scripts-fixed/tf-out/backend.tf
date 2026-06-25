terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"   # Replace with your S3 bucket name
    key            = "terraform-aws/terraform.tfstate"
    region         = "ap-southeast-3"
    encrypt        = true
  }
}
