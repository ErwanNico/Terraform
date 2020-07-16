terraform {
  backend "s3" {
    bucket = "buckettpepsi"
    key    = "epsi/terraform.tfstate"
    region = "us-east-1"
  }
}
