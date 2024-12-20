provider "aws" {
    region = "us-east-1"
}

resource "aws_key_pair" "ssh_key" {
    key_name   = "ec2-key-pair" 
    public_key = file("./key.pub") 
}

resource "aws_security_group" "allow_ssh" {
    name        = "allow_ssh"
    description = "Security group to allow SSH access"

    ingress {
        description      = "Allow SSH"
        from_port        = 22
        to_port          = 22
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1" 
        cidr_blocks      = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "example" {
    ami           = "ami-01816d07b1128cd2d" #us-east-1 Amazon Linux 2 AMI, Instance Store Type
    instance_type = "t2.micro"
    key_name      = aws_key_pair.ssh_key.key_name
    security_groups = [aws_security_group.allow_ssh.name] 

    tags = {
        Name = "BasicEC2Instance"
    }
}

output "instance_public_ip" {
    value       = aws_instance.example.public_ip
    description = "Public IP of the EC2 instance"
    sensitive   = true
}
