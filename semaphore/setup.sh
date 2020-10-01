# Fail if any command fails
set -e

ELIXIR_VERSION=1.10.3
ERLANG_VERSION=22.3.4
NODEJS_VERSION=13.1

change-phantomjs-version 2.1.1
nvm install $NODEJS_VERSION --latest-npm

export ERL_HOME="${SEMAPHORE_CACHE_DIR}/.kerl/installs/${ERLANG_VERSION}"

if [ ! -d "${ERL_HOME}" ]; then
    mkdir -p "${ERL_HOME}"
    KERL_BUILD_BACKEND=git kerl build $ERLANG_VERSION $ERLANG_VERSION
    kerl install $ERLANG_VERSION $ERL_HOME
fi

. $ERL_HOME/activate

if ! kiex use $ELIXIR_VERSION; then
    kiex install $ELIXIR_VERSION
    kiex use $ELIXIR_VERSION
fi

AWS_ACCESS_KEY_ID=""
AWS_SECRET_ACCESS_KEY=""
SECRET_KEY_BASE=""

mix local.hex --force
mix local.rebar --force
mix deps.get --only test
env MIX_ENV=test mix compile --force --warnings-as-errors
npm --prefix assets ci
