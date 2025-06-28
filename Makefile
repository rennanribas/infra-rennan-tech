# Rennan Tech Infrastructure - Development Environment
# Usage: make <target>

.PHONY: help dev-up dev-down terraform-shell aws-shell terraform-init terraform-plan terraform-apply terraform-destroy terraform-fmt terraform-validate clean

# Default target
help:
	@echo "Rennan Tech Infrastructure - Available Commands:"
	@echo ""
	@echo "Development Environment:"
	@echo "  make dev-up          - Start development containers"
	@echo "  make dev-down        - Stop development containers"
	@echo "  make terraform-shell - Open interactive Terraform shell"
	@echo "  make aws-shell       - Open interactive AWS CLI shell"
	@echo ""
	@echo "Terraform Commands:"
	@echo "  make terraform-init     - Initialize Terraform"
	@echo "  make terraform-migrate  - Migrate state to S3 backend (automatic)"
	@echo "  make terraform-plan     - Create Terraform execution plan"
	@echo "  make terraform-apply    - Apply Terraform configuration"
	@echo "  make terraform-destroy  - Destroy Terraform infrastructure"
	@echo "  make terraform-fmt      - Format Terraform files"
	@echo "  make terraform-validate - Validate Terraform configuration"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean           - Clean up containers and volumes"
	@echo "  make aws-identity    - Show current AWS identity"

# Development environment
dev-up:
	@echo "Starting development environment..."
	docker compose -f docker-compose.dev.yml up -d
	@echo "Development environment ready!"
	@echo "Use 'make terraform-shell' or 'make aws-shell' to interact"

dev-down:
	@echo "Stopping development environment..."
	docker compose -f docker-compose.dev.yml down

terraform-shell:
	@echo "Opening Terraform interactive shell..."
	docker compose -f docker-compose.dev.yml exec terraform sh

aws-shell:
	@echo "Opening AWS CLI interactive shell..."
	docker compose -f docker-compose.dev.yml exec aws-cli sh

# Terraform commands
terraform-init:
	@echo "Initializing Terraform..."
	docker compose -f docker-compose.dev.yml exec terraform terraform init

terraform-migrate:
	@echo "Migrating Terraform state to S3 backend..."
	docker compose -f docker-compose.dev.yml exec terraform terraform init -migrate-state -force-copy

terraform-plan:
	@echo "Creating Terraform execution plan..."
	docker compose -f docker-compose.dev.yml exec terraform terraform plan

terraform-apply:
	@echo "Applying Terraform configuration..."
	docker compose -f docker-compose.dev.yml exec terraform terraform apply

terraform-destroy:
	@echo "Destroying Terraform infrastructure..."
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	docker compose -f docker-compose.dev.yml exec terraform terraform destroy

terraform-fmt:
	@echo "Formatting Terraform files..."
	docker compose -f docker-compose.dev.yml exec terraform terraform fmt -recursive

terraform-validate:
	@echo "Validating Terraform configuration..."
	docker compose -f docker-compose.dev.yml exec terraform terraform validate

# Utilities
aws-identity:
	@echo "Current AWS identity:"
	docker compose -f docker-compose.dev.yml exec aws-cli aws sts get-caller-identity

clean:
	@echo "Cleaning up development environment..."
	docker compose -f docker-compose.dev.yml down -v
	docker system prune -f
	@echo "Cleanup complete!"

# Production deployment (uses existing docker-compose.yml)
prod-up:
	@echo "Starting production environment..."
	docker compose up -d

prod-down:
	@echo "Stopping production environment..."
	docker compose down

prod-logs:
	@echo "Showing production logs..."
	docker compose logs -f