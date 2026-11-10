terraform {
  backend "s3" {
    bucket       = "depi-team-555-tfstate"
    key          = "project/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
