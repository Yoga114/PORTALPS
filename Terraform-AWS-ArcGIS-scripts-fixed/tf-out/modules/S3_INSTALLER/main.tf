# ─── S3 Bucket untuk ArcGIS Installer ────────────────────────────────────────
resource "aws_s3_bucket" "arcgis_installer" {
  bucket = var.bucket_name

  tags = {
    Name    = var.bucket_name
    Purpose = "ArcGIS Installer Storage"
  }
}

resource "aws_s3_bucket_versioning" "arcgis_installer" {
  bucket = aws_s3_bucket.arcgis_installer.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "arcgis_installer" {
  bucket = aws_s3_bucket.arcgis_installer.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "arcgis_installer" {
  bucket                  = aws_s3_bucket.arcgis_installer.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── IAM Role untuk EC2 PSAGE ─────────────────────────────────────────────────
resource "aws_iam_role" "psage_role" {
  name = "psage-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "psage-ec2-role" }
}

# Policy: akses S3 bucket installer (read-only)
resource "aws_iam_role_policy" "psage_s3_policy" {
  name = "psage-s3-read-installer"
  role = aws_iam_role.psage_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.arcgis_installer.arn,
        "${aws_s3_bucket.arcgis_installer.arn}/*"
      ]
    }]
  })
}

# Policy: ec2:DescribeInstances (dibutuhkan oleh script bootstrap PSAGE/PSGEOV/PSSPATIO
# untuk resolve private IP instance lain demi penulisan /etc/hosts).
# Action ini tidak bisa di-scope ke resource tertentu, jadi Resource wajib "*".
resource "aws_iam_role_policy" "psage_ec2_describe_policy" {
  name = "psage-ec2-describe-instances"
  role = aws_iam_role.psage_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:DescribeInstances"]
      Resource = "*"
    }]
  })
}

# Policy: SSM Session Manager (akses tanpa RDP/SSH terbuka)
resource "aws_iam_role_policy_attachment" "psage_ssm_policy" {
  role       = aws_iam_role.psage_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "psage_profile" {
  name = "psage-instance-profile"
  role = aws_iam_role.psage_role.name
}
