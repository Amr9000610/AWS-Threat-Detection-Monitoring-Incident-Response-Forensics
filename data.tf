# 1. S3 Bucket لاستقبال سجلات المشروع الأساسية (Project Logs)
resource "aws_s3_bucket" "project_logs_bucket" {
  bucket        = "depi-team5-project-logs-450505040291"
  force_destroy = true

  tags = {
    Name        = "Project Logs Bucket"
    Environment = "Project-4"
    Owner       = "Abdallah Mohamed"
  }
}

# 2. حجب الوصول العام تماماً (Block Public Access) لضمان الأمان وعدم جعل السجلات عامة
resource "aws_s3_bucket_public_access_block" "logs_bucket_public_access" {
  bucket = aws_s3_bucket.project_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. S3 Bucket منفصلة ومخصصة لحفظ سجلات الوصول للـ S3 (Server Access Logging)
resource "aws_s3_bucket" "access_logs_bucket" {
  bucket        = "depi-team5-s3-access-logs-450505040291"
  force_destroy = true

  tags = {
    Name        = "S3 Server Access Logs"
    Environment = "Project-4"
    Owner       = "Abdallah Mohamed"
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs_public_access" {
  bucket = aws_s3_bucket.access_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# تفعيل خاصية تسجيل الوصول للـ Bucket الرئيسية وتوجيهها للـ Bucket المخصصة للسجلات
resource "aws_s3_bucket_logging" "project_logs_logging" {
  bucket        = aws_s3_bucket.project_logs_bucket.id
  target_bucket = aws_s3_bucket.access_logs_bucket.id
  target_prefix = "s3-access-logs/"
}

# 4. سياسة الاحتفاظ بالسجلات وتخزينها (Log Retention & Lifecycle Policy)
resource "aws_s3_bucket_lifecycle_configuration" "logs_retention" {
  bucket = aws_s3_bucket.project_logs_bucket.id

  rule {
    id     = "log-retention-policy"
    status = "Enabled"

    # نقل السجلات لطبقة تخزين أرخص (STANDARD_IA) بعد 30 يوم وحذفها بعد 90 يوم لتوفير التكلفة
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }
}

# 5. تجهيز قاعدة بيانات Amazon Athena لتحليل السجلات الأمنية
resource "aws_athena_database" "security_logs_db" {
  name   = "depi_team5_security_logs"
  bucket = aws_s3_bucket.project_logs_bucket.id
}