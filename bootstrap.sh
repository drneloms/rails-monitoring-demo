#!/usr/bin/env bash
set -euo pipefail

APP_NAME="hello_world_app"
APP_DIR="./app"

echo "[*] Checking for docker..."
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed or not in PATH."
  echo "Install Docker Desktop first, then re-run."
  exit 1
fi

# Basic check that Docker is running
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker engine does not seem to be running."
  echo "Start Docker Desktop and try again."
  exit 1
fi

# One-time Rails app creation (inside a temporary container)
if [ ! -d "$APP_DIR" ] || [ ! -f "$APP_DIR/Gemfile" ]; then
  echo "[*] Creating new Rails app in $APP_DIR ..."

  mkdir -p "$APP_DIR"

  docker run --rm \
    -v "$(pwd)/app":/app \
    -w /app \
    ruby:3.3 \
        bash -lc "gem install rails -v 7.1.0 && export PATH=\"/usr/local/bundle/bin:$PATH\" && rails new . -d postgresql --skip-test --skip-sprockets --skip-javascript"

  echo "[*] Rails app created."
fi

# Ensure prometheus_exporter gem is present
if ! grep -q "prometheus_exporter" "$APP_DIR/Gemfile"; then
  echo "[*] Adding prometheus_exporter gem..."
  echo 'gem "prometheus_exporter"' >> "$APP_DIR/Gemfile"
fi

# Simple HelloWorld controller + route
HELLO_CONTROLLER="$APP_DIR/app/controllers/hello_controller.rb"
if [ ! -f "$HELLO_CONTROLLER" ]; then
  cat > "$HELLO_CONTROLLER" <<'RUBY'
class HelloController < ApplicationController
  def index
    render plain: "Hello World from Rails + PostgreSQL + Redis!"
  end
end
RUBY

  # Add route
  if ! grep -q "root \"hello#index\"" "$APP_DIR/config/routes.rb"; then
    echo 'root "hello#index"' >> "$APP_DIR/config/routes.rb"
  fi
fi

# Configure database.yml for Docker Postgres
DB_YML="$APP_DIR/config/database.yml"
if grep -q "default: &default" "$DB_YML"; then
  cat > "$DB_YML" <<'YAML'
default: &default
  adapter: postgresql
  encoding: unicode
  host: db
  username: postgres
  password: password
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: app_development

YAML
fi

# Add Redis config (optional, just to exercise Redis)
REDIS_INITIALIZER="$APP_DIR/config/initializers/redis.rb"
if [ ! -f "$REDIS_INITIALIZER" ]; then
  cat > "$REDIS_INITIALIZER" <<'RUBY'
require "redis"

REDIS = Redis.new(url: ENV.fetch("REDIS_URL", "redis://redis:6379/0"))
RUBY
fi

# Add Prometheus middleware
PROM_INIT="$APP_DIR/config/initializers/prometheus_exporter.rb"
if [ ! -f "$PROM_INIT" ]; then
  cat > "$PROM_INIT" <<'RUBY'
require "prometheus_exporter/middleware"
require "prometheus_exporter/instrumentation"

Rails.application.middleware.use PrometheusExporter::Middleware
PrometheusExporter::Instrumentation::ActiveRecord.start
PrometheusExporter::Instrumentation::Process.start(type: "web")
RUBY
fi

echo "[*] Building and starting Docker stack (this may take several minutes the first time)..."
docker compose build
docker compose up -d

echo "[*] Running database migrations..."
docker compose exec app bundle exec rails db:prepare

echo
echo "====================================================="
echo "Environment is up!"
echo "Rails app:     http://localhost:3000"
echo "Prometheus:    http://localhost:9090"
echo "Grafana:       http://localhost:3001  (user: admin / pass: admin)"
echo "====================================================="
