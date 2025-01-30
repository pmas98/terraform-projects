provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "ec2-key-pair"
  public_key = file("./key.pub")
}

resource "aws_security_group" "bootstrap_sg" {
  name        = "bootstrap-sg"
  description = "Allow P2P, SSH, and necessary ports for bootstrap server"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bootstrap_server" {
  ami           = "ami-09115b7bffbe3c5e4"  # Replace with a dynamic AMI lookup if necessary
  instance_type = "t2.micro"
  count         = 1
  key_name      = aws_key_pair.ssh_key.key_name
  tags = {
    Name = "BootstrapServer"
  }
  user_data = <<-EOF
                #!/bin/bash
                set -e
                LOG_FILE="/home/ec2-user/bootstrap_server_setup.log"
                exec > >(tee -a $LOG_FILE) 2>&1
                echo "Starting setup at $(date)"

                yum update -y
                yum install -y git

                curl -LO https://golang.org/dl/go1.23.5.linux-amd64.tar.gz
                tar -C /usr/local -xzf go1.23.5.linux-amd64.tar.gz

                echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile.d/go.sh
                echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/ec2-user/.bash_profile

                /usr/local/go/bin/go version

                git clone https://github.com/pmas98/mobius /home/ec2-user/mobius || { echo "Git clone failed"; exit 1; }

                cd /home/ec2-user/mobius/custom_peer/
                /usr/local/go/bin/go mod tidy

                /usr/local/go/bin/go build -o mobius_server bootstrap_peer.go

                nohup /home/ec2-user/mobius/custom_peer/mobius_server > /home/ec2-user/mobius/bootstrap_server.log 2>&1 &

                echo "Setup completed and Bootstrap server started."
                echo "Setup log can be found at $LOG_FILE"
              EOF
  vpc_security_group_ids = [aws_security_group.bootstrap_sg.id]
}

output "bootstrap_instance_info" {
  value = {
    public_ip  = aws_instance.bootstrap_server[*].public_ip
    public_dns = aws_instance.bootstrap_server[*].public_dns
    ssh_command = "ssh -i ./key ec2-user@${aws_instance.bootstrap_server[0].public_ip}"
  }
  description = "Information about the Bootstrap server instances"
}
