# ===========================================================================
# Stage 1: Build
# ===========================================================================
FROM hexpm/elixir:1.17.3-erlang-27.2-debian-bookworm-20241016-slim AS build

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends git build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install dependencies first (better layer caching)
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config

# Copy compile-time config files
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

# Copy application source
COPY lib lib
COPY priv priv
COPY assets assets

# Build assets (esbuild JS + CSS, then digest)
RUN mix assets.deploy

# Compile the application
RUN mix compile

# Copy runtime config (needed in the release)
COPY config/runtime.exs config/

# Build the release
RUN mix release

# ===========================================================================
# Stage 2: Runtime
# ===========================================================================
FROM debian:bookworm-slim AS runtime

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      libstdc++6 \
      openssl \
      libncurses5 \
      locales \
      libvips42 \
      ca-certificates \
      curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set up locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

# Create a non-root user to run the app
RUN groupadd --system sunporch && \
    useradd --system --gid sunporch --home /app sunporch

# Copy the release from the build stage
COPY --from=build --chown=sunporch:sunporch /app/_build/prod/rel/sunporch ./

USER sunporch

ENV MIX_ENV=prod
ENV PHX_SERVER=true
ENV PORT=4000

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:4000/ || exit 1

CMD ["/app/bin/sunporch", "start"]
