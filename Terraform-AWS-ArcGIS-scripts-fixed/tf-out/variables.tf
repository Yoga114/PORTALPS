# ─── AWS Credentials ──────────────────────────────────────────────────────────
# Catatan: access key / secret key tidak dibutuhkan di sini.
# Autentikasi AWS CLI di dalam EC2 (PSAGE/PSSPATIO/PSGEOV) ditangani oleh
# IAM Instance Profile (module.S3_INSTALLER.instance_profile_name).
variable "aws_default_region" {
  description = "AWS Default Region"
  type        = string
  default     = "ap-southeast-3"
}
