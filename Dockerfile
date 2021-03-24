FROM hexpm/elixir:1.10.3-erlang-22.3.4-debian-buster-20200224 as builder

ENV MIX_ENV=prod
ENV NODE_ENV=production

ARG ERL_COOKIE
ENV ERL_COOKIE=${ERL_COOKIE}
RUN if test -z $ERL_COOKIE; then (>&2 echo "No ERL_COOKIE"); exit 1; fi

WORKDIR /root
ADD . .

RUN apt-get update && apt-get install -y --no-install-recommends \
  curl git

# Configure Git to use HTTPS in order to avoid issues with the internal MBTA network
RUN git config --global url.https://github.com/.insteadOf git://github.com/

# Install hex and rebar
RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix do deps.get --only prod, compile --force

WORKDIR /root/assets/
RUN curl -sL https://deb.nodesource.com/setup_13.x | bash - && \
  apt-get install -y nodejs && \
  npm install -g npm@latest

RUN env NODE_ENV=development npm ci
RUN npm run deploy

WORKDIR /root
RUN mix phx.digest
RUN mix distillery.release --verbose

# the one the elixir image was built with
FROM debian:buster

RUN apt-get update && apt-get install -y --no-install-recommends \
  libssl1.1 libsctp1 curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /root
EXPOSE 4000
ENV MIX_ENV=prod TERM=xterm LANG="C.UTF-8" PORT=4000

COPY --from=builder /root/_build/prod/rel/prediction_analyzer/releases/current/prediction_analyzer.tar.gz .
RUN tar -xzf prediction_analyzer.tar.gz
CMD ["bin/prediction_analyzer", "foreground"]
