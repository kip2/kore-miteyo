# ECR

resource "aws_ecr_repository" "backend_repository" {
  name = "image-manager-backend"
}

resource "aws_ecr_lifecycle_policy" "backend_repository_lifecycle" {
  repository = aws_ecr_repository.backend_repository.name
  policy     = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 14 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber":7 
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

# App Runner

resource "aws_apprunner_service" "backend_image_manager" {
  service_name = "image-manager-backend"

  source_configuration {
    authentication_configuration {
      access_role_arn = var.apprunner_ecr_access_role_arn
    }
    image_repository {
      image_configuration {
        port = "8080"
        runtime_environment_variables = {
          AUTH_TOKEN_TTL = 86400
          HOST           = "0.0.0.0"
          PORT           = 8080
        }
        runtime_environment_secrets = {
          DATABASE_HOST     = "${var._secrets_manager_arn}:DATABASE_HOST::"
          DATABASE_NAME     = "${var._secrets_manager_arn}:DATABASE_NAME::"
          DATABASE_PASSWORD = "${var._secrets_manager_arn}:DATABASE_PASSWORD::"
          DATABASE_PORT     = "${var._secrets_manager_arn}:DATABASE_PORT::"
          DATABASE_USERNAME = "${var._secrets_manager_arn}:DATABASE_USERNAME::"
          REDIS_HOST        = "${var._secrets_manager_arn}:REDIS_HOST::"
          REDIS_PORT        = "${var._secrets_manager_arn}:REDIS_PORT::"
        }
      }
      image_identifier      = "${aws_ecr_repository.backend_repository.repository_url}:latest"
      image_repository_type = "ECR"
    }
    auto_deployments_enabled = true
  }

  instance_configuration {
    cpu               = "1 vCPU"
    memory            = "2048"
    instance_role_arn = var.apprunner_instance_role_arn
  }

  network_configuration {
    ingress_configuration {
      is_publicly_accessible = true
    }

    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = aws_apprunner_vpc_connector.backend_image_manager.arn
    }
  }
}

resource "aws_apprunner_vpc_connector" "backend_image_manager" {
  vpc_connector_name = "backend-image-manager"
  subnets            = var._db_subnet_ids
  security_groups    = [var._vpc_connector_sg_id]
}
