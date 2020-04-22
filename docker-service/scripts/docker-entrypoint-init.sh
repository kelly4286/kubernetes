#!/bin/bash

if [ "${ENABLE_CROND}" == "yes" ]; then
   crontab /etc/acho-scripts/acho-crontab
else
   echo "Ignore crontab!"
fi

# Setup service configs
rm -rf /usr/local/etc/freetds.conf
rm -rf /usr/local/etc/locales.conf
rm -rf /etc/nginx/nginxconfig.io/nginxconfig.io
rm -rf /etc/nginx/nginx.conf
rm -rf /etc/nginx/adhub/adhub
rm -rf /usr/local/etc/php-fpm.d/zz-adhub.conf
rm -rf /usr/local/etc/php/conf.d/adhub.ini
rm -rf /etc/td-agent/td-agent.conf
ln -s /etc/service-configs/freetds/freetds.conf    /usr/local/etc/freetds.conf
ln -s /etc/service-configs/freetds/locales.conf    /usr/local/etc/locales.conf
ln -s /etc/service-configs/nginx/nginxconfig.io    /etc/nginx/nginxconfig.io
ln -s /etc/service-configs/nginx/nginx.conf        /etc/nginx/nginx.conf
ln -s /etc/service-configs/nginx/adhub             /etc/nginx/adhub
ln -s /etc/service-configs/php-fpm/zz-adhub.conf   /usr/local/etc/php-fpm.d/zz-adhub.conf
ln -s /etc/service-configs/php-fpm/php.ini         /usr/local/etc/php/conf.d/adhub.ini
ln -s /etc/service-configs/td-agent/td-agent.conf  /etc/td-agent/td-agent.conf