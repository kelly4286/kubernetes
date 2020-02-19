#!/bin/bash

if [ "${ENABLE_CROND}" == "yes" ]; then
   crontab /etc/acho-crontab
else
   echo "Ignore crontab!"
fi