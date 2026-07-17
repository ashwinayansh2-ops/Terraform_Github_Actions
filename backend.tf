terraform {
  backend "s3" {
    bucket       = "s3terraforbackup17072026"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}