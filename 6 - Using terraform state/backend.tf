#Run this first
terraform {
  backend "s3" {
    bucket         = "abc"  # Use the same bucket name you defined above
    key            = "workspaces-example/terraform.tfstate"
    region         = "us-west-2"                  # Use the same region
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}