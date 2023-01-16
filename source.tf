
# Configure the AWS provider

provider "aws" {
  region = "us-east-1"
  access_key = ""
  secret_key = ""
}


# 1. Create VPC

resource "aws_vpc" "source_vpc" {
  cidr_block = "100.0.0.0/16"
  enable_dns_hostnames = "true"
  tags = {
    Name = "Source_VPC"
  }
}




# 2. Create IGW

resource "aws_internet_gateway" "source_IGW" {
  vpc_id = aws_vpc.source_vpc.id

  tags = {
    Name = "Source_IGW"
  }
}


# 3. Create Custom Route Table

    #source

resource "aws_route_table" "source_route_table" {
  vpc_id = aws_vpc.source_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.source_IGW.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.source_IGW.id
  }

  tags = {
    Name = "Source_RT"
  }
}

  


# 4. Create a Subnet

 #source
resource "aws_subnet" "source-subnet1" {
  vpc_id     = aws_vpc.source_vpc.id
  cidr_block = "100.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Source-Subnet1"
  }
}

resource "aws_subnet" "source-subnet2" {
  vpc_id     = aws_vpc.source_vpc.id
  cidr_block = "100.0.1.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Source-Subnet2"
  }
}






 
# 5. Associate subnet with Route Table

resource "aws_route_table_association" "a-S" {
  subnet_id      = aws_subnet.source-subnet1.id
  route_table_id = aws_route_table.source_route_table.id
}

resource "aws_route_table_association" "b-S" {
  subnet_id      = aws_subnet.source-subnet2.id
  route_table_id = aws_route_table.source_route_table.id
}




# 6. Create Security Group to allow port 22, 80, 443

resource "aws_security_group" "source_sg" {
  name        = "allow_web"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.source_vpc.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH"
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

  tags = {
    Name = "aws_SG_WEB"
  }
}





# 7. Create a network interface with an IP in the subnet that was created in step 4.

resource "aws_network_interface" "source_NIC" {
  subnet_id       = aws_subnet.source-subnet1.id
  private_ips     = ["100.0.0.99"]
  security_groups = [aws_security_group.source_sg.id]
}


# 8. Assign elastic IP to the network interface created in Step 7

resource "aws_eip" "source_EIP" {
  vpc                       = true
  network_interface         = aws_network_interface.source_NIC.id
  associate_with_private_ip = "100.0.0.99"
  depends_on = [aws_internet_gateway.source_IGW]
}

output "aws_Public_IP_for_Webserver_source" {
    value = aws_eip.source_EIP.public_ip
}

output "aws_Private_IP_for_Webserver_source" {
    value = aws_eip.source_EIP.private_ip
}



	


# Create Subnet_Group 

resource "aws_db_subnet_group" "source-db-subnet-group" {
  name = "source-db-subnet-group"
  subnet_ids = [aws_subnet.source-subnet1.id, aws_subnet.source-subnet2.id]

  tags = {
    Name = "Source_DB_subnet_group"
  }
}




# CREATE T3.MED RDS MYSQL DATABASE	

resource "aws_db_instance" "source_db" {
  identifier = "source-db"
  engine = "mysql"
  engine_version = "8.0.28"         # Optional
  instance_class = "db.t3.medium"
  port = "3306"                     # Optional
  db_name = "Source_DB"
  db_subnet_group_name = "source-db-subnet-group"
  availability_zone = "us-east-1a"
  username = "admin"
  password = "admin12345"
  storage_type = "gp2"
  allocated_storage = 20
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot = true
  publicly_accessible = true
  vpc_security_group_ids = [aws_security_group.source-mysqlsg.id]

  depends_on = [
     aws_db_subnet_group.source-db-subnet-group
  ]

  tags = {
    name = "Source_DB"
  }
}





# Create Source MYSQL Security Group

resource "aws_security_group" "source-mysqlsg" {
  name        = "source-mysqlsg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.source_vpc.id


  ingress {
    description = "mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [
    aws_vpc.source_vpc,
  ]


  tags = {
    Name = "Source_mysqlsg"
  }

}




