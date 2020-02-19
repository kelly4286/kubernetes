#!/bin/sh
set -e

if [ -f "/docker-entrypoint-init.sh" ]; then
    . /docker-entrypoint-init.sh
fi

# Run command
exec "$@"