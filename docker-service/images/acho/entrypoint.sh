#!/bin/sh
set -e

if [ -f "/docker-entrypoint-init.sh" ]; then
    f=/docker-entrypoint-init.sh
    if [ -x "$f" ]; then
        echo "$0: running $f"
        "$f"
    else
        echo "$0: sourcing $f"
        . "$f"
    fi
fi

# Run command
exec "$@"