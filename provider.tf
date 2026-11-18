provider "aws" {
  region  = var.aws_region
  profile = "depi-team-5"

  default_tags {
    tags = {
      Project   = "depi-team-5"
      ManagedBy = "terraform"
      Stack     = "project"
    }
  }
}