FROM ruby:3.2-alpine

RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    postgresql-client \
    libc6-compat \
    nodejs \
    npm \
    tzdata \
    git \
    yaml-dev \
    bash

WORKDIR /app

RUN gem install bundler -v 2.7.2

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN chmod +x bin/docker-entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["bin/docker-entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb", "-b", "tcp://0.0.0.0:3000"]