# Rennan Tech – local infra toolkit
# Usage:  make <target>

.PHONY: help dev-up dev-down terraform-shell aws-shell gh-shell \
        terraform-init terraform-migrate terraform-plan terraform-apply \
        terraform-destroy terraform-fmt terraform-validate \
        aws-identity propagate-secrets clean prod-up prod-down prod-logs \
        doppler-setup doppler-secrets-sync doppler-run

## ---------------------------------------------------------------------
## default: list commands
## ---------------------------------------------------------------------
help:
	@echo ''
	@echo 'Available commands'
	@echo '──────────────────'
	@echo 'Dev environment:'
	@echo '  make dev-up            – start dev containers'
	@echo '  make dev-down          – stop  dev containers'
	@echo '  make terraform-shell   – bash inside terraform container'
	@echo '  make aws-shell         – bash inside aws-cli container'
	@echo '  make gh-shell          – bash inside gh-cli container'
	@echo ''
	@echo 'Terraform:'
	@echo '  make terraform-init    – terraform init'
	@echo '  make terraform-migrate – move local state → S3 backend'
	@echo '  make terraform-plan    – terraform plan'
	@echo '  make terraform-apply   – terraform apply'
	@echo '  make terraform-destroy – terraform destroy (prompt)'
	@echo '  make terraform-fmt     – terraform fmt -recursive'
	@echo '  make terraform-validate– terraform validate'
	@echo ''
	@echo 'Utilities:'
	@echo '  make aws-identity      – show current AWS identity'
	@echo '  make propagate-secrets – push terraform outputs as repo secrets'
	@echo '  make clean             – docker prune & volume cleanup'
	@echo ''
	@echo 'Doppler:'
	@echo '  make doppler-setup     – setup Doppler CLI and login'
	@echo '  make doppler-secrets-sync – sync secrets from Doppler'
	@echo '  make doppler-run       – run commands with Doppler secrets'
	@echo ''
	@echo 'Production docker-compose.yml:'
	@echo '  make prod-up / prod-down / prod-logs'
	@echo ''

## ---------------------------------------------------------------------
## dev containers
## ---------------------------------------------------------------------
dev-up:
	docker compose -f docker-compose.dev.yml up -d
	@echo 'Dev stack is running.'

dev-down:
	docker compose -f docker-compose.dev.yml down

terraform-shell: ; docker compose -f docker-compose.dev.yml exec terraform  sh
aws-shell:       ; docker compose -f docker-compose.dev.yml exec aws-cli    sh
gh-shell:        ; docker compose -f docker-compose.dev.yml exec gh-cli     sh

## ---------------------------------------------------------------------
## terraform helpers
## ---------------------------------------------------------------------
terraform-init:      ; docker compose -f docker-compose.dev.yml exec terraform terraform init
terraform-migrate:   ; docker compose -f docker-compose.dev.yml exec terraform terraform init -migrate-state -force-copy
terraform-plan:      ; docker compose -f docker-compose.dev.yml exec terraform terraform plan
terraform-apply:     ; docker compose -f docker-compose.dev.yml exec terraform terraform apply
terraform-destroy:
	@read -p 'Destroy ALL infra (y/N)? ' c && [ "$$c" = y ]
	docker compose -f docker-compose.dev.yml exec terraform terraform destroy
terraform-fmt:       ; docker compose -f docker-compose.dev.yml exec terraform terraform fmt -recursive
terraform-validate:  ; docker compose -f docker-compose.dev.yml exec terraform terraform validate

## ---------------------------------------------------------------------
## misc
## ---------------------------------------------------------------------
aws-identity: ; docker compose -f docker-compose.dev.yml exec aws-cli aws sts get-caller-identity

# push outputs (account-id, instance-id, ECR URIs) to child repos
propagate-secrets:
	@echo "============================================"
	@echo "🔍 COLLECTING VALUES FROM AWS & TERRAFORM"
	@echo "============================================"
	@ACCOUNT_ID=$$(aws sts get-caller-identity --profile personal --query Account --output text); \
	INSTANCE_ID=$$(docker compose -f docker-compose.dev.yml \
		exec -T terraform terraform output -raw instance_id); \
	RENNAN_REPO=$$(docker compose -f docker-compose.dev.yml \
		exec -T terraform terraform output -raw ecr_rennan_tech_repository_url); \
	LAB_REPO=$$(docker compose -f docker-compose.dev.yml \
		exec -T terraform terraform output -raw ecr_engineer_lab_repository_url); \
	echo "AWS_ACCOUNT_ID      = $$ACCOUNT_ID"; \
	echo "AWS_REGION          = us-east-1"; \
	echo "INSTANCE_ID         = $$INSTANCE_ID"; \
	echo "RENNAN_REPO (ECR)   = $$RENNAN_REPO"; \
	echo "LAB_REPO (ECR)      = $$LAB_REPO"; \
	echo ""; \
	echo "============================================"; \
	echo "📤 PROPAGATING SECRETS TO REPOSITORIES"; \
	echo "============================================"; \
	for R in rennan-tech-landing engineer-lab; do \
		echo "• Setting secrets for repo: $$R"; \
		echo "  - AWS_ACCOUNT_ID = $$ACCOUNT_ID"; \
		echo "  - AWS_REGION = us-east-1"; \
		echo "  - INSTANCE_ID = $$INSTANCE_ID"; \
		gh secret set AWS_ACCOUNT_ID --body "$$ACCOUNT_ID" --repo rennanribas/$$R; \
		gh secret set AWS_REGION     --body us-east-1       --repo rennanribas/$$R; \
		gh secret set INSTANCE_ID    --body "$$INSTANCE_ID" --repo rennanribas/$$R; \
		echo ""; \
	done; \
	echo "• Setting ECR_REPOSITORY_URI for rennan-tech-landing:"; \
	echo "  - ECR_REPOSITORY_URI = $$RENNAN_REPO"; \
	gh secret set ECR_REPOSITORY_URI --body "$$RENNAN_REPO" --repo rennanribas/rennan-tech-landing; \
	echo ""; \
	echo "• Setting ECR_REPOSITORY_URI for engineer-lab:"; \
	echo "  - ECR_REPOSITORY_URI = $$LAB_REPO"; \
	gh secret set ECR_REPOSITORY_URI --body "$$LAB_REPO"   --repo rennanribas/engineer-lab; \
	echo ""; \
	echo "✅ Secrets propagated successfully!"
	
clean:
	docker compose -f docker-compose.dev.yml down -v
	docker system prune -f

## ---------------------------------------------------------------------
## production (plain docker-compose.yml)
## ---------------------------------------------------------------------
prod-up:    ; docker compose up -d
prod-down:  ; docker compose down
prod-logs:  ; docker compose logs -f

## ---------------------------------------------------------------------
## doppler helpers
## ---------------------------------------------------------------------
doppler-setup:
	@echo "Setting up Doppler CLI..."
	@if ! command -v doppler >/dev/null 2>&1; then \
		echo "Installing Doppler CLI..."; \
		curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh | sh; \
	fi
	@echo "Doppler CLI installed. Please run 'doppler login' to authenticate."

doppler-secrets-sync:
	@echo "Syncing secrets from Doppler..."
	doppler secrets download --no-file --format env

doppler-run:
	@echo "Usage: make doppler-run CMD='your-command'"
	@echo "Example: make doppler-run CMD='terraform plan'"
	@if [ -z "$(CMD)" ]; then \
		echo "Error: CMD parameter is required"; \
		exit 1; \
	fi
	doppler run -- $(CMD)
