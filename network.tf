resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11:Flow Logs pagos adiados; risco e compensação em docs/security-report.md.
  cidr_block           = "10.30.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = local.name }
}
resource "aws_default_security_group" "closed" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-default-deny" }
}
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.30.0.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name}-public-a" }
}
resource "aws_subnet" "private" {
  for_each                = { a = "us-east-2a", b = "us-east-2b" }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.key == "a" ? "10.30.10.0/24" : "10.30.11.0/24"
  availability_zone       = each.value
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name}-private-${each.key}" }
}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = local.name }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-public" }
}
resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${local.name}-private-${each.key}" }
}
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
