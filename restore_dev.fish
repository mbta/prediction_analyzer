#!/usr/bin/env fish

# Port for SSH tunnel (choose an unused port)
set LOCAL_PORT 5433

# Open an SSH tunnel in the background
ssh -NL $LOCAL_PORT:$DEV_PG_HOST:5432 $DEV_BASTION_HOST &

set PID $last_pid

sleep 5

function cleanup
    echo "Closing SSH tunnel..."
    kill $PID
    rm -rf predictionanalyzer.dump 2> /dev/null
end

trap cleanup EXIT
trap cleanup SIGINT

set -x PGPASSWORD $DEV_PG_PASSWORD

# Dump the remote database
pg_dump -v -Fd -f predictionanalyzer.dump --compress=6 -h localhost -p $LOCAL_PORT -U $DEV_PG_USER -d predictionanalyzer

# Restore to local database (assuming no authentication required)
PGPASSWORD="" pg_restore -v -c --no-owner -h localhost -p 5432 -U postgres -d prediction_analyzer_dev predictionanalyzer.dump

cleanup
