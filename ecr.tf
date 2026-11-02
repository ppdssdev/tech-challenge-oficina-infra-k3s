resource "aws_ecr_repository" "api" {
  name                 = "oficina-${var.environment}-api"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "oficina-${var.environment}-api"
  }
}
