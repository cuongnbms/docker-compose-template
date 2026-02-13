# syntax = docker/dockerfile:1

# ============================================================
# Errbit Dockerfile - standalone build from GitHub source
# ============================================================

FROM ruby:4.0.1-slim AS base

WORKDIR /rails

RUN set -eux ; \
    apt-get update -qq ; \
    apt-get dist-upgrade -qq ; \
    apt-get install --no-install-recommends -y curl libjemalloc2 shared-mime-info ; \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    BOOTSNAP_LOG="true" \
    BOOTSNAP_READONLY="true"

RUN set -eux ; \
    gem update --system "4.0.6" ; \
    gem install bundler --version "4.0.6" --force

# ---- Build stage ----
FROM base AS build

RUN set -eux ; \
    apt-get update -qq ; \
    apt-get dist-upgrade -qq ; \
    apt-get install --no-install-recommends -y build-essential git pkg-config libyaml-dev

ARG ERRBIT_BRANCH=main
RUN git clone --depth 1 --branch "${ERRBIT_BRANCH}" https://github.com/errbit/errbit.git /rails

WORKDIR /rails

# Disable force_ssl and assume_ssl so Errbit serves plain HTTP
RUN sed -i 's/config\.force_ssl\b.*/config.force_ssl = false/' config/environments/production.rb && \
    sed -i 's/config\.assume_ssl\b.*/config.assume_ssl = false/' config/environments/production.rb

RUN set -eux ; \
    bundle install ; \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git ; \
    bundle exec bootsnap precompile --gemfile

RUN bundle exec bootsnap precompile app/ lib/ config/ Rakefile

RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# ---- Final stage ----
FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Custom entrypoint that bootstraps the database on first run
COPY docker-entrypoint /rails/bin/docker-entrypoint
RUN chmod +x /rails/bin/docker-entrypoint

RUN set -eux ; \
    groupadd --system --gid 1000 rails ; \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash ; \
    chown -R rails:rails db log storage tmp

USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000/tcp

CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
