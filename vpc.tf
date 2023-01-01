provider "aws" {
  region     = "us-east-1"
  access_key = "************************"
  secret_key = "**********************************"
}

# Creating VPC
resource "aws_vpc" "demovpc" {
  cidr_block       = "${var.vpc_cidr}"
  instance_tenancy = "default"

tags = {
  Name = "Demo VPC"
}
}

# Creating 1st web subnet

resource "aws_subnet" "public-subnet-1" {
  vpc_id                  = "${aws_vpc.demovpc.id}"
  cidr_block             = "${var.subnet_cidr}"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"

tags = {
  Name = "Web Subnet 1"
}
}

# Creating 2nd web subnet

resource "aws_subnet" "public-subnet-2" {
  vpc_id                  = "${aws_vpc.demovpc.id}"
  cidr_block             = "${var.subnet1_cidr}"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1b"

tags = {
  Name = "Web Subnet 2"
}
}

# Creating 1st application subnet

resource "aws_subnet" "application-subnet-1" {
  vpc_id                  = "${aws_vpc.demovpc.id}"
  cidr_block             = "${var.subnet2_cidr}"
  map_public_ip_on_launch = false
  availability_zone = "us-east-1a"

tags = {
  Name = "Application Subnet 1"
}
}

# Creating 2nd application subnet

resource "aws_subnet" "application-subnet-2" {
  vpc_id                  = "${aws_vpc.demovpc.id}"
  cidr_block             = "${var.subnet3_cidr}"
  map_public_ip_on_launch = false
  availability_zone = "us-east-1b"

tags = {
  Name = "Application Subnet 2"
}
}

# Create Database Private Subnet

resource "aws_subnet" "database-subnet-1" {
  vpc_id            = "${aws_vpc.demovpc.id}"
  cidr_block        = "${var.subnet4_cidr}"
  availability_zone = "us-east-1a"

tags = {
  Name = "Database Subnet 1"
}
}

# Create Database Private Subnet

resource "aws_subnet" "database-subnet-2" {
  vpc_id            = "${aws_vpc.demovpc.id}"
  cidr_block        = "${var.subnet5_cidr}"
  availability_zone = "us-east-1b"
tags = {
  Name = "Database Subnet 1"
}
}


# Creating Internet Gateway

resource "aws_internet_gateway" "demogateway" {
  vpc_id = "${aws_vpc.demovpc.id}"
}


# Creating Route Table

resource "aws_route_table" "route" {
  vpc_id = "${aws_vpc.demovpc.id}"

route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.demogateway.id}"
  }

tags = {
      Name = "Route to internet"
  }
}


# Associating Route Table

resource "aws_route_table_association" "rt1" {
  subnet_id = "${aws_subnet.public-subnet-1.id}"
  route_table_id = "${aws_route_table.route.id}"
}

# Associating Route Table

resource "aws_route_table_association" "rt2" {
  subnet_id = "${aws_subnet.public-subnet-2.id}"
  route_table_id = "${aws_route_table.route.id}"
}


# Creating 1st EC2 instance in Public Subnet

resource "aws_instance" "demoinstance" {
  ami                         = "ami-087c17d1fe0178315"
  instance_type               = "t2.micro"
  key_name                    = "VPC"
  vpc_security_group_ids      = ["${aws_security_group.demosg.id}"]
  subnet_id                   = "${aws_subnet.public-subnet-1.id}"
  associate_public_ip_address = true
  user_data                   = "${file("data.sh")}"

tags = {
  Name = "My Public Instance"
}
}


# Creating 2nd EC2 instance in Public Subnet

resource "aws_instance" "demoinstance1" {
  ami                         = "ami-087c17d1fe0178315"
  instance_type               = "t2.micro"
  key_name                    = "VPC"
  vpc_security_group_ids      = ["${aws_security_group.demosg.id}"]
  subnet_id                   = "${aws_subnet.public-subnet-2.id}"
  associate_public_ip_address = true
  user_data                   = "${file("data.sh")}"

tags = {
  Name = "My Public Instance 2"
}
}


# Creating Security Group

resource "aws_security_group" "demosg" {
  vpc_id = "${aws_vpc.demovpc.id}"

# Inbound Rules
# HTTP access from anywhere

ingress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# HTTPS access from anywhere
ingress {
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# SSH access from anywhere
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Outbound Rules
# Internet access to anywhere
egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

tags = {
  Name = "Web SG"
}
}

# Create Database Security Group

resource "aws_security_group" "database-sg" {
  name        = "Database SG"
  description = "Allow inbound traffic from application layer"
  vpc_id      = aws_vpc.demovpc.id

ingress {
  description     = "Allow traffic from application layer"
  from_port       = 3306
  to_port         = 3306
  protocol        = "tcp"
  security_groups = [aws_security_group.demosg.id]
}

egress {
  from_port   = 32768
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

tags = {
  Name = "Database SG"
}
}

# Creating External LoadBalancer

resource "aws_lb" "external-alb" {
  name               = "External-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.demosg.id]
  subnets            = [aws_subnet.public-subnet-1.id, aws_subnet.public-subnet-2.id]
}

resource "aws_lb_target_group" "target-elb" {
  name     = "ALB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demovpc.id
}

resource "aws_lb_target_group_attachment" "attachment" {
  target_group_arn = aws_lb_target_group.target-elb.arn
  target_id        = aws_instance.demoinstance.id
  port             = 80

depends_on = [
  aws_instance.demoinstance,
]
}

resource "aws_lb_target_group_attachment" "attachment1" {
  target_group_arn = aws_lb_target_group.target-elb.arn
  target_id        = aws_instance.demoinstance1.id
  port             = 80

depends_on = [
  aws_instance.demoinstance1,
]
}

resource "aws_lb_listener" "external-elb" {
  load_balancer_arn = aws_lb.external-alb.arn
  port              = "80"
  protocol          = "HTTP"
default_action {
  type             = "forward"
  target_group_arn = aws_lb_target_group.target-elb.arn
}
}

# Creating RDS Instance

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.database-subnet-1.id, aws_subnet.database-subnet-2.id]

tags = {
  Name = "My DB subnet group"
}
}

resource "aws_db_instance" "default" {
  allocated_storage      = 10
  db_subnet_group_name   = aws_db_subnet_group.default.id
  engine                 = "mysql"
  engine_version         = "8.0.20"
  instance_class         = "db.t2.micro"
  multi_az               = true
  db_name                   = "mydb"
  username               = "admin"
  password               = "admin123"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.database-sg.id]
}

# Getting the DNS of load balancer

output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = "${aws_lb.external-alb.dns_name}"
}

# Defining CIDR Block for VPC

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

# Defining CIDR Block for 1st Subnet

variable "subnet_cidr" {
  default = "10.0.1.0/24"
}

# Defining CIDR Block for 2nd Subnet

variable "subnet1_cidr" {
  default = "10.0.2.0/24"
}

# Defining CIDR Block for 3rd Subnet

variable "subnet2_cidr" {
  default = "10.0.3.0/24"
}

# Defining CIDR Block for 3rd Subnet
variable "subnet3_cidr" {
  default = "10.0.4.0/24"
}

# Defining CIDR Block for 3rd Subnet

variable "subnet4_cidr" {
  default = "10.0.5.0/24"
}

# Defining CIDR Block for 3rd Subnet

variable "subnet5_cidr" {
  default = "10.0.6.0/24"
}


