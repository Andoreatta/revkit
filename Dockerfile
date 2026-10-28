# syntax=docker/dockerfile:1

# Pinned to the Elixir/OTP versions used by this project.
ARG ELIXIR_IMAGE=hexpm/elixir:1.20.4-erlang-29.1.1-debian-bookworm-20261005-slim
ARG RUNTIME_IMAGE=debian:bookworm-slim

FROM ${ELIXIR_IMAGE} AS build

ENV MIX_ENV=prod \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    git \
  && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

COPY config config
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets
COPY rel rel

RUN mix assets.setup \
  && mix compile \
  && mix assets.deploy \
  && mix release

FROM ${RUNTIME_IMAGE} AS app

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    HOME=/app \
    MIX_ENV=prod \
    PHX_SERVER=true \
    PORT=4000 \
    DATABASE_PATH=/data/revkit.db

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libncurses6 \
    libsctp1 \
    libstdc++6 \
    openssl \
    tzdata \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --create-home --shell /usr/sbin/nologin --uid 1000 revkit \
  && mkdir -p /data \
  && chown revkit:revkit /data

WORKDIR /app

COPY --from=build --chown=revkit:revkit /app/_build/prod/rel/revkit ./
COPY --chown=revkit:revkit docker/entrypoint.sh /app/bin/docker-entrypoint

RUN chmod 0755 /app/bin/docker-entrypoint

USER revkit

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS "http://localhost:${PORT}/health" || exit 1

ENTRYPOINT ["/app/bin/docker-entrypoint"]
