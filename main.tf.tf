provider "aws" {
  region                  = "us-east-1"             # N.V
  access_key              = "AKIAUAS6GJM6VULF5XF3"
  secret_key              = "OKu4aDwxNyb71iuNYMjrMMmj9azHSVkiccZ0q60j"
  # session_token          = "your-session-token" # Only if required
}

resource "aws_vpc" "project_1_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "project-1 vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.project_1_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.project_1_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "Private Subnet"
  }
}

resource "aws_security_group" "rocketchat_sg" {
  name        = "rocketchat-sg"
  description = "RocketChat Security Group"
  vpc_id      = aws_vpc.project_1_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # You might also want to open SSH port for instance management:
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RocketChat Security Group"
  }
}


#Created Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.project_1_vpc.id

  tags = {
    Name = "igw"
  }
}

#Creating Route Table for public subnet
resource "aws_route_table" "public_routeTable" {
  vpc_id = aws_vpc.project_1_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "terraform_public_routeTable"
  }
}

#Associating Public Route Table with public subnet
resource "aws_route_table_association" "PublicRTassociation" {

  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_routeTable.id
}

#Creating Key Pair
resource "aws_key_pair" "InfraKey" {
    key_name= "InfraKey"
    public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
    algorithm = "RSA"
    rsa_bits= 4096
}
resource "local_file" "InfraKey" {
    content= tls_private_key.rsa.private_key_pem
    filename= "InfraKey"
}

resource "aws_instance" "rocket_chat_instance" {
  ami                    = "ami-053b0d53c279acc90"  # Ubuntu 20.04 LTS
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.InfraKey.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.rocketchat_sg.id]

  user_data = <<-EOT
    #!/bin/bash
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

    apt-get update && apt-get install -y docker.io

    docker run -d --name=db -v /my/own/datadir:/data/db mongo:4.4
    docker run -d --name=rocketchat --link=db -p 3000:3000 -e MONGO_URL=mongodb://db:27017/rocketchat -e ROOT_URL=http://localhost:3000 rocketchat/rocket.chat
  EOT

  timeouts {
    create = "30m"
  }

  tags = {
    Name = "RocketChat Instance"
  }
}

