# The Maude interpreter is GPL and is not redistributed by the ExMaude Hex
# package; it is fetched at image-build time by `mix maude.install`. If you
# publish an image built from this file, that licence travels with it.

ARG ELIXIR_VERSION=1.19.6
ARG OTP_VERSION=28.5.0.6
ARG DEBIAN_VERSION=bookworm-20260824-slim

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
COPY config config
RUN mix deps.get --only prod && mix deps.compile
RUN mix maude.install --version 3.5.1

COPY docs/talk/manuscript.md docs/talk/manuscript.md
COPY rel rel
COPY priv priv
COPY lib lib

RUN mix compile && mix phx.digest && mix release

FROM debian:${DEBIAN_VERSION} AS engine

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 libgmp10 locales curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 MIX_ENV=prod ERL_AFLAGS="+JMsingle true"
WORKDIR /app

COPY --from=build /app/_build/prod/rel/goatmire ./
COPY docker/config/engine.exs /app/goatmire.runtime.exs

EXPOSE 4000 9568
CMD ["/app/bin/goatmire", "start"]

FROM debian:${DEBIAN_VERSION} AS simulator

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 libgmp10 locales curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 MIX_ENV=prod ERL_AFLAGS="+JMsingle true"
WORKDIR /app

COPY --from=build /app/_build/prod/rel/goatmire ./
COPY docker/config/simulator.exs /app/goatmire.runtime.exs

RUN rm -rf /app/lib/ex_maude-*/priv/maude

EXPOSE 9568
CMD ["/app/bin/goatmire", "start"]

# Build Livebook on the patched runtime rather than inheriting the older OTP
# and Elixir bundled in its upstream image. Keep its source release pinned.
FROM build AS livebook
WORKDIR /opt/livebook
RUN git init && git remote add origin https://github.com/livebook-dev/livebook.git \
  && git fetch --depth 1 origin 782dc5ecfe103e953c8157df1b47613896aa2c1e \
  && git checkout --detach FETCH_HEAD
COPY docker/livebook-security.patch docker/livebook.mix.lock ./
RUN git apply livebook-security.patch && mv livebook.mix.lock mix.lock \
  && mix deps.get --only prod --check-locked && mix hex.audit
RUN mix assets.setup
RUN mix escript.build
ENV MAUDE_PATH=/app/deps/ex_maude/priv/maude/bin/maude
WORKDIR /data
EXPOSE 8080
CMD ["/opt/livebook/livebook", "server", "--ip", "0.0.0.0", "--port", "8080"]
