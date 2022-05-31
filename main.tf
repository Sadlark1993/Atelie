
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  cloud {
    organization = "Sadlark"

    workspaces {
      name = "Atelie"
    }
  }
}

provider "aws" {
  region = "us-east-2"
  access_key = "AKIA3MQQ574ZHXPWY6NS"
  secret_key = "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"
}

resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Production"
  }
} 

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod_vpc.id
  
}

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod-route"
  }
}

resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.prod_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "Prod-subnet"
  }

}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "allows http, https and ssh"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "web-server-nick" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nick.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_instance" "web-server-instance" {
  ami = "ami-0fa49cc9dc8d62c84"
  instance_type = "t2.micro"
  availability_zone = "us-east-2a"
  key_name = "ChavePutty"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nick.id
  }

  user_data = <<-EOF
    #! /bin/bash
    sudo su
    yum update -y
    yum install -y httpd
    apt install unzip
    echo "Hello World" > /var/www/html/index.html
    cd /var/www/html
    rm -rf index.html
    wget https://github.com/Sadlark1993/Atelie/archive/refs/heads/master.zip
    unzip master.zip
    cp -r Atelie-master/* /var/www/html/
    systemctl enable httpd
    systemctl start httpd
  EOF

  tags = {
    Name = "web-server"
  }
}