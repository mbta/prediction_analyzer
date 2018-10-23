FROM elixir:1.6 as builder

ENV MIX_ENV=prod
ENV NODE_ENV=production

ARG ERL_COOKIE
ENV ERL_COOKIE=${ERL_COOKIE}
RUN if test -z $ERL_COOKIE; then (>&2 echo "No ERL_COOKIE"); exit 1; fi

ARG SECRET_KEY_BASE
ENV SECRET_KEY_BASE=${SECRET_KEY_BASE}
RUN if test -z $SECRET_KEY_BASE; then (>&2 echo "No SECRET_KEY_BASE"); exit 1; fi

WORKDIR /root
ADD . .

# Configure Git to use HTTPS in order to avoid issues with the internal MBTA network
RUN git config --global url.https://github.com/.insteadOf git://github.com/

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix do deps.get --only prod, compile --force

WORKDIR /root/assets/
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest  && \
    npm install -g brunch

RUN npm install
RUN brunch build --production

WORKDIR /root
RUN mix phx.digest
RUN mix release --verbose

# the one the elixir image was built with
FROM debian:stretch

RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl1.1 libsctp1 curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /root
EXPOSE 4000
ENV MIX_ENV=prod TERM=xterm LANG="C.UTF-8" PORT=4000

COPY --from=builder /root/_build/prod/rel/prediction_analyzer/releases/current/prediction_analyzer.tar.gz .
RUN tar -xzf prediction_analyzer.tar.gz
CMD ["bin/prediction_analyzer", "foreground"]
