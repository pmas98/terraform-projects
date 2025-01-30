provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "bootstrap_server" {
  ami           = "ami-09115b7bffbe3c5e4"  # Replace with a dynamic AMI lookup if necessary
  instance_type = "t2.micro"
}