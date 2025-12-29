FROM ruby:3.3

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y build-essential nodejs postgresql-client && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install bundle dependencies
COPY app/Gemfile app/Gemfile.lock* ./
RUN bundle install || true

# Copy the app code
COPY app/ /app

EXPOSE 3000

CMD ["bash", "-lc", "bundle install && bundle exec rails server -b 0.0.0.0 -p 3000"]

