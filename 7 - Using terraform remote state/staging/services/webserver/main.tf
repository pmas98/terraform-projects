# Fetch the remote state for the DB
data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = "abc"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "us-west-2"
  }
}

# Define the security group (if not existing)
resource "aws_security_group" "instance" {
  name        = "example-security-group"
  description = "Allow inbound traffic on the necessary ports"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH traffic on port 22
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Be cautious: This allows access from any IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "example-security-group"
  }
}


# Define the EC2 instance
resource "aws_instance" "example" {
  ami             = "ami-09115b7bffbe3c5e4"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.name]  # Using the security group's name here

  # Render the User Data script as a template
  user_data = templatefile("./user-data.sh", {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  })

  tags = {
    Name = "example-instance"
  }
}
