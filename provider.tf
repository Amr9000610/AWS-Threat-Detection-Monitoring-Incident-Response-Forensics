provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "depi-team-5"
      ManagedBy = "terraform"
      Stack     = "init"
    }
  }
}
