resource "aws_athena_database" "logs" {
  name   = "${replace(var.project_name, "-", "_")}_logs"
  bucket = aws_s3_bucket.central_logs.id
}

resource "aws_athena_workgroup" "security" {
  name = "${var.project_name}-security"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.central_logs.id}/athena-results/"
    }
  }

  depends_on = [
    aws_s3_bucket_public_access_block.central_logs
  ]
}
