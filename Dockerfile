FROM ruby:3.4.2-slim

WORKDIR /app

RUN apt-get update \
  && apt-get install --no-install-recommends -y build-essential busybox-static \
  && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle config set path /usr/local/bundle \
  && bundle install --jobs 4 --retry 3

COPY . .
RUN chmod +x scripts/rebuild-loop.sh

CMD ["./scripts/rebuild-loop.sh"]
