COMPOSE = docker compose -f infra/compose.yaml --env-file infra/env/.env
ENV_FILE = infra/env/.env
PROFILE ?= $(shell grep -s '^PROFILE=' $(ENV_FILE) | cut -d= -f2 || echo dev)
PROFILE := $(or $(PROFILE),dev)
PYTHON_PACKAGES = security payments backend workers

.PHONY: up down logs ps watch tunnel monitoring reset migrate seed test-unit test-integration \
	test-e2e test-security test-resilience test-load resilience

$(ENV_FILE):
	cp infra/env/.env.example $(ENV_FILE)

## Start the stack for $(PROFILE) and wait until every service is healthy.
up: $(ENV_FILE)
	$(COMPOSE) --profile $(PROFILE) up -d --wait
	$(COMPOSE) run --rm minio-init

down: $(ENV_FILE)
	$(COMPOSE) --profile '*' down

logs: $(ENV_FILE)
	$(COMPOSE) --profile $(PROFILE) logs -f

ps: $(ENV_FILE)
	$(COMPOSE) --profile $(PROFILE) ps

## Sync source changes into the running api for hot reload (dev).
watch: $(ENV_FILE)
	$(COMPOSE) --profile dev watch --no-up

## Expose the api over HTTPS for Razorpay webhooks and print the public URL.
tunnel: $(ENV_FILE)
	$(COMPOSE) --profile $(PROFILE) --profile tunnel up -d tunnel
	@sleep 5; $(COMPOSE) --profile $(PROFILE) --profile tunnel logs tunnel | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | tail -n1

## Prometheus, Alertmanager, Grafana, Loki and the exporters next to $(PROFILE).
monitoring: $(ENV_FILE)
	$(COMPOSE) --profile $(PROFILE) --profile monitoring up -d --wait

## Stop everything and delete all volumes.
reset: $(ENV_FILE)
	$(COMPOSE) --profile '*' down -v

## Run every package's migrations as the schema owner.
migrate: $(ENV_FILE)
	$(COMPOSE) --profile $(PROFILE) exec -T api sh /src/infra/scripts/migrate.sh

seed: $(ENV_FILE)
	$(COMPOSE) --profile $(PROFILE) exec -T api python /src/infra/seed/seed.py

## Unit tests of each Python package, on the host (needs a venv with the packages).
test-unit:
	@for pkg in $(PYTHON_PACKAGES); do \
	  if [ -f $$pkg/pyproject.toml ]; then echo "== $$pkg"; (cd $$pkg && pytest -q) || exit 1; fi; \
	done
	cd frontend && flutter test

test-integration test-e2e test-security test-resilience: $(ENV_FILE)
	$(COMPOSE) --profile test --profile runner run --rm test-runner pytest -q $(subst test-,,$@)

test-load: $(ENV_FILE)
	$(COMPOSE) --profile test --profile runner run --rm test-runner \
	  locust -f performance/locustfile.py --headless -u 50 -r 10 -t 2m --host http://api:8000

## Stop Kafka, kill and pause the workers under traffic; see docs/runbooks/resilience.md.
resilience: $(ENV_FILE)
	python3 ci/scripts/resilience.py kafka workers delay
