#!/bin/sh
SCRIPT=$(readlink -f "$0")
BASEDIR=$(dirname "$SCRIPT")

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Working directory: $BASEDIR"

cd $BASEDIR

/usr/local/bin/docker-compose "$@"

LAST=$?
echo $LAST
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Execution completed."
echo

exit $LAST
