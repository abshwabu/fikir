COMPOSE ?= docker compose -f docker-compose.yml -f docker-compose.dev.yml

.PHONY: help up down logs migrate-up migrate-down seed test lint build-apk

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

up: ## Start all infrastructure services in detached mode
	$(COMPOSE) up -d --build

down: ## Stop and remove all containers
	$(COMPOSE) down --remove-orphans

logs: ## Tail logs for all running services
	$(COMPOSE) logs -f

migrate-up: ## Run pending database migrations
	$(COMPOSE) run --rm migrate up

migrate-down: ## Roll back the last database migration
	$(COMPOSE) run --rm migrate down 1

seed: ## Run database seeder inside Docker
	$(COMPOSE) run --rm --entrypoint "go run ./cmd/seed" api

test: ## Run backend unit and integration tests inside Docker
	docker run --rm --net=host -e TESTCONTAINERS_RYUK_DISABLED=true -v $(CURDIR)/backend:/app -v $(HOME)/go/pkg/mod:/go/pkg/mod -v /var/run/docker.sock:/var/run/docker.sock -w /app golang:1.24-alpine sh -c "go test -v ./..."

lint: ## Run golangci-lint static analysis inside Docker
	docker run --rm -v $(CURDIR)/backend:/app -v $(HOME)/go/pkg/mod:/go/pkg/mod -w /app golangci/golangci-lint:v1.64.5 golangci-lint run --timeout 5m ./...

build-apk: ## Build Flutter Android APK using CirrusLabs Flutter Docker container
	docker run --rm -v $(CURDIR)/mobile:/app -w /app ghcr.io/cirruslabs/flutter:latest flutter build apk
