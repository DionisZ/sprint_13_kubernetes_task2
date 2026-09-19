# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.3.1
FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libpq5 libsqlite3-0 libyaml-0-2 && \
    rm -rf /var/lib/apt/lists/*

RUN gem install bundler -v 2.4.20 --no-document

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential git pkg-config libpq-dev libyaml-dev libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle _2.4.20_ install --jobs 4 --retry 3 && \
    rm -rf /usr/local/bundle/ruby/*/cache

COPY . .
RUN chmod +x bin/* && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile && \
    rm -f tmp/local_secret.txt

FROM base AS final

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

RUN useradd --create-home --shell /bin/bash rails && \
    mkdir -p db log storage tmp/pids && \
    chown -R rails:rails db log storage tmp

USER rails:rails

EXPOSE 3000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
