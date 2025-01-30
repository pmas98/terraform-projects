provider "aws" {
  region = "us-east-2"
}

terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket = "abc"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "us-west-2"

    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}


resource "aws_db_instance" "example" {
  identifier_prefix   = "terraform-up-and-running"
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.t3.micro"
  skip_final_snapshot = true
  db_name             = "example_database"
  username            = var.db_username
  password            = var.db_password
}
