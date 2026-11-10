provider "aws" {
  region  = "us-east-1"
  profile = "depi-team-5"

  default_tags {
    tags = {
      Project   = "depi-team-5"
      ManagedBy = "terraform"
      Stack     = "project"
    }
  }
}