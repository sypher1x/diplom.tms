compose := "docker compose"
compose_file := "docker-compose.yml"

# show available recipes
default:
    @just --list

# initialize environment
init: env build deps up

# copy .env.example to .env
env:
    cp .env.example .env

# build and start services
up:
    {{ compose }} -f {{ compose_file }} up -d --build

# build and start monitoring stack
up-monitoring:
    {{ compose }} -f docker-compose.monitoring.yml up -d

# stop and remove services
down:
    {{ compose }} -f {{ compose_file }} down

# stop and remove monitoring stack
down-monitoring:
    {{ compose }} -f docker-compose.monitoring.yml down

# build api image
build:
    {{ compose }} -f {{ compose_file }} build api

# restart services
restart:
    {{ compose }} -f {{ compose_file }} restart

# show containers
ps:
    {{ compose }} -f {{ compose_file }} ps

# follow all logs
logs:
    {{ compose }} -f {{ compose_file }} logs -f --tail=200

# shell inside api container
api-shell:
    {{ compose }} -f {{ compose_file }} exec api sh

# psql shell inside db container
db-shell:
    {{ compose }} -f {{ compose_file }} exec db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"

# follow api logs
api-logs:
    {{ compose }} -f {{ compose_file }} logs -f --tail=200 api

# follow db logs
db-logs:
    {{ compose }} -f {{ compose_file }} logs -f --tail=200 db

# curl /health
test-health:
    @curl -fsS http://localhost:8080/health > /dev/null
    @echo OK

# curl /db/ping
test-db:
    @curl -fsS http://localhost:8080/db/ping > /dev/null
    @echo OK

# composer install (local)
deps:
    docker run --rm -v "$(pwd)/api":/app -w /app composer:2 install --no-dev --optimize-autoloader
