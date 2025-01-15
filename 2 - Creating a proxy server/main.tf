provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "ssh_key" {
    key_name   = "ec2-key-pair" 
    public_key = file("./key.pub") 
}

resource "aws_instance" "proxy_server" {
  count         = 15
  ami           = "ami-09115b7bffbe3c5e4"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ssh_key.key_name

  tags = {
    Name = "ProxyServer-${count.index + 1}"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y squid
              # Backup the original Squid config
              cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

              # Set up basic authentication
              yum install -y httpd-tools
              htpasswd -bc /etc/squid/squid_passwd username${count.index + 1} password${count.index + 1}

              # Configure Squid
              cat <<EOT > /etc/squid/squid.conf
              auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid/squid_passwd
              auth_param basic children 5
              auth_param basic realm Proxy Server
              auth_param basic credentialsttl 2 hours
              auth_param basic casesensitive off
              acl authenticated proxy_auth REQUIRED
              http_access allow authenticated
              http_port ${3128 + count.index} # Assign unique ports for each server
              visible_hostname ProxyServer${count.index + 1}
              EOT

              systemctl enable squid
              systemctl restart squid
              EOF

  vpc_security_group_ids = [aws_security_group.proxy_sg.id]
}

resource "aws_security_group" "proxy_sg" {
  name        = "proxy-sg"
  description = "Allow proxy traffic"

  ingress {
    from_port   = 3128
    to_port     = 3143 
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

output "proxy_credentials" {
  value = [
    for idx, instance in aws_instance.proxy_server:
    {
      ip       = instance.public_ip,
      port     = 3128 + idx,
      username = "username${idx + 1}",
      password = "password${idx + 1}"
    }
  ]
  description = "List of proxy credentials (IP, port, username, and password)"
}