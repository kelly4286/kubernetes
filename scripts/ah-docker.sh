#!/bin/sh
BASEDIR=/ad-hub.net/docker-service

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Working directory: $BASEDIR"

cd $BASEDIR

if [ -z "${ENABLE_CROND}" ]; then
    ENABLE_CROND=$(test $(hostname) = "ah-t-ext02" -o $(hostname) = "ah-p-ext02" && echo "yes" || echo "no")
fi

ENABLE_CROND=${ENABLE_CROND} /usr/local/bin/docker-compose "$@"

LAST=$?

# Wait for graceful shutdown
if [ "$1" = "restart" ]; then
    echo "Wait 15 seconds for graceful shutdown..."
    sleep 15
fi

echo $LAST
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Execution completed."
echo

exit $LAST
