resource "aws_vpc" "main" {
 cidr_block = var.vpc_cidr
 
 tags = {
   Name = "Project VPC"
 }
}

resource "aws_subnet" "public_subnets" {
 count             = length(var.public_subnet_cidrs)
 vpc_id            = aws_vpc.main.id
 cidr_block        = element(var.public_subnet_cidrs, count.index)
 availability_zone = element(var.availability_zones, count.index)
 
 tags = {
   Name = "Public Subnet ${count.index + 1}"
 }
}
 
resource "aws_subnet" "private_subnets" {
 count             = length(var.private_subnet_cidrs)
 vpc_id            = aws_vpc.main.id
 cidr_block        = element(var.private_subnet_cidrs, count.index)
 availability_zone = element(var.availability_zones, count.index)
 
 tags = {
   Name = "Private Subnet ${count.index + 1}"
 }
}

resource "aws_internet_gateway" "gw" {
 vpc_id = aws_vpc.main.id
 
 tags = {
   Name = "Project VPC IG"
 }
}

resource "aws_route_table" "public_rt" {
 vpc_id = aws_vpc.main.id
 
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.gw.id
 }
 
 tags = {
   Name = "Public Route Table"
 }
}

resource "aws_route_table_association" "public_subnet_asso" {
 count = length(var.public_subnet_cidrs)
 subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
 route_table_id = aws_route_table.public_rt.id
}

# ─── NAT Gateway untuk internet access dari private subnet ───────────────────
# EC2 di private subnet (PSAGE/PSSPATIO/PSGEOV) butuh akses internet untuk:
# download installer dari S3, AWS CLI, Cinc, cookbook GitHub, dan ArcGIS Online.
resource "aws_eip" "nat" {
 domain = "vpc"

 tags = {
   Name = "NAT Gateway EIP"
 }
}

resource "aws_nat_gateway" "nat" {
 allocation_id = aws_eip.nat.id
 subnet_id     = aws_subnet.public_subnets[0].id

 tags = {
   Name = "Project NAT Gateway"
 }

 depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "private_rt" {
 vpc_id = aws_vpc.main.id

 route {
   cidr_block     = "0.0.0.0/0"
   nat_gateway_id = aws_nat_gateway.nat.id
 }

 tags = {
   Name = "Private Route Table"
 }
}

resource "aws_route_table_association" "private_subnet_asso" {
 count          = length(var.private_subnet_cidrs)
 subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
 route_table_id = aws_route_table.private_rt.id
}