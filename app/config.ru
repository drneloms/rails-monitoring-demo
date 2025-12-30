# config.ru
require_relative "config/environment"

# Prometheus middleware
require "prometheus/middleware/collector"
require "prometheus/middleware/exporter"

# Collect HTTP request metrics
use Prometheus::Middleware::Collector

# Expose /metrics endpoint
use Prometheus::Middleware::Exporter

# Rails app
run Rails.application

