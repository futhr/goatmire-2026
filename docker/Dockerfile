# The Maude interpreter is GPL and is not redistributed by the ExMaude Hex
# package; it is fetched at image-build time by `mix maude.install`. If you
# publish an image built from this file, that licence travels with it.

ARG ELIXIR_VERSION=1.19.4
ARG OTP_VERSION=28.5
ARG DEBIAN_VERSION=bookworm-20260610-slim

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION} AS build

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends build-essential git ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
# Single-mapped JIT memory is required by OTP 28 when this x86_64 image runs
# through Apple Silicon emulation (OTP issue #10355). It is also supported on
# native x86_64 and keeps the image identical across rehearsal and CI.
ENV MIX_ENV=prod ERL_AFLAGS="+JMsingle true"

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod && mix deps.compile
RUN mix maude.install --version 3.5.1

COPY config config
COPY assets assets
COPY priv priv
COPY lib lib

RUN mix assets.setup && mix assets.deploy
RUN mix compile && mix phx.digest && mix release

FROM debian:${DEBIAN_VERSION} AS engine

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 MIX_ENV=prod ERL_AFLAGS="+JMsingle true"
WORKDIR /app

COPY --from=build /app/_build/prod/rel/goatmire ./
COPY docker/config/engine.exs /app/goatmire.runtime.exs

EXPOSE 4000 9568
CMD ["/app/bin/goatmire", "start"]

FROM debian:${DEBIAN_VERSION} AS simulator

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 MIX_ENV=prod ERL_AFLAGS="+JMsingle true"
WORKDIR /app

COPY --from=build /app/_build/prod/rel/goatmire ./
COPY docker/config/simulator.exs /app/goatmire.runtime.exs

RUN rm -rf /app/lib/ex_maude-*/priv

EXPOSE 9568
CMD ["/app/bin/goatmire", "start"]
