COMPOSE = docker compose -f infra/compose.yaml --env-file infra/env/.env
ENV_FILE = infra/env/.env

.PHONY: up down logs reset migrate seed test-unit test-integration test-e2e test-security test-load

$(ENV_FILE):
	cp infra/env/.env.example $(ENV_FILE)

up: $(ENV_FILE)
	$(COMPOSE) up -d --wait
	$(COMPOSE) run --rm minio-init

down: $(ENV_FILE)
	$(COMPOSE) --profile init down

logs: $(ENV_FILE)
	$(COMPOSE) logs -f

reset: $(ENV_FILE)
	$(COMPOSE) --profile init down -v

# Filled in as the owning modules land (see the implementation plan, weeks 2-7).
migrate seed test-unit test-integration test-e2e test-security test-load:
	@echo "make $@: not set up yet"
