# First, get the elixir dependencies within an elixir container
FROM hexpm/elixir:1.11.4-erlang-24.3.4-alpine-3.14.5 AS elixir-builder

ENV LANG="C.UTF-8" MIX_ENV=prod

WORKDIR /root
# Install hex, rebar, and deps
RUN mix local.hex --force && \
  mix local.rebar --force

ADD mix.lock mix.lock
ADD mix.exs mix.exs
ADD config config

RUN mix do deps.get --only prod

# Next, build the frontend assets within a node.js container
FROM node:16.15.0-alpine3.14 as assets-builder

WORKDIR /root
# Copy in elixir deps required to build node modules for phoenix
COPY --from=elixir-builder /root/deps ./deps

ADD assets assets
RUN npm --prefix assets ci
RUN npm --prefix assets run deploy

# Now, build the application back in the elixir container
FROM elixir-builder as app-builder

ARG ERL_COOKIE
ENV ERL_COOKIE=${ERL_COOKIE}
RUN if test -z $ERL_COOKIE; then (>&2 echo "No ERL_COOKIE"); exit 1; fi

# Add Elixir code
ADD lib lib
ADD priv priv
ADD rel rel

RUN mix compile

# Add frontend assets compiled in node container, required by phx.digest
COPY --from=assets-builder /root/priv/static ./priv/static

RUN mix do phx.digest, release

# Finally, use an Alpine container for the runtime environment
FROM alpine:3.14.5

RUN apk add --update libssl1.1 ncurses-libs bash curl dumb-init \
  && rm -rf /var/cache/apk

# Create non-root user
RUN addgroup -S prediction_analyzer && adduser -S -G prediction_analyzer prediction_analyzer
USER prediction_analyzer
WORKDIR /home/prediction_analyzer

# Set environment
ENV MIX_ENV=prod TERM=xterm LANG="C.UTF-8" PORT=4000 REPLACE_OS_VARS=true

# Add frontend assets with manifests from app-builder container
COPY --from=app-builder --chown=prediction_analyzer:prediction_analyzer /root/priv/static ./priv/static

# Add application artifact compiled in app-builder container
COPY --from=app-builder --chown=prediction_analyzer:prediction_analyzer /root/_build/prod/rel/prediction_analyzer .

EXPOSE 4000

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Health Check
HEALTHCHECK CMD ["bin/prediction_analyzer", "rpc", "1 + 1"]
# Run the application
CMD ["bin/prediction_analyzer", "start"]
