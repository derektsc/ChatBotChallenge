COMPOSE = docker compose

.PHONY: setup up down logs api-logs frontend-logs seed rails-console frontend-shell restart clean

setup:
	$(COMPOSE) build

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

api-logs:
	$(COMPOSE) logs -f api

frontend-logs:
	$(COMPOSE) logs -f frontend

seed:
	$(COMPOSE) run --rm api bin/rails db:seed

rails-console:
	$(COMPOSE) run --rm api bin/rails console

frontend-shell:
	$(COMPOSE) exec frontend sh

restart:
	$(COMPOSE) down && $(COMPOSE) up -d

clean:
	$(COMPOSE) down -v