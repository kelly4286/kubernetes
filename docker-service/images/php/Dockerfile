# docker build --no-cache . -t adhubtest.azurecr.io/php:5.6-stretch-fpm-custom
# docker push adhubtest.azurecr.io/php:5.6-stretch-fpm-custom
FROM php:5.6-fpm-stretch

ENV RUNTIME_DEPS git wget nginx cron rsyslog supervisor logrotate libgeoip1 imagemagick libmagickwand-6.q16-3 ffmpeg mailutils

RUN set -eux; \
    rm -rf /etc/localtime; \
    ln -s /usr/share/zoneinfo/Asia/Taipei /etc/localtime; \
    dpkg-reconfigure -f noninteractive tzdata; \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt update; \
    apt install -y --no-install-recommends lsb-release gnupg2; \
    echo "deb http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" | tee /etc/apt/sources.list.d/nginx.list; \
    echo "deb-src http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" | tee -a /etc/apt/sources.list.d/nginx.list; \
    curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -; \
    \
    apt update; \
    ln -s /usr/local/bin/php /usr/bin/php; \
    cp $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini; \
    apt install -y --no-install-recommends \
        libghc-zlib-dev libmcrypt-dev \
        libmagickwand-dev libgeoip-dev \
        libbz2-dev libxslt-dev libgd-dev \
        libfreetype6-dev libjpeg62-turbo-dev \
        build-essential libc6-dev \
        $RUNTIME_DEPS; \
    echo "cron.* /var/log/cron.log" > /etc/rsyslog.d/cron.conf; \
    ln -s /usr/lib/x86_64-linux-gnu/libsybdb.so /usr/lib/; \
    \
    # Build FreeTDS 1.1.6
    wget ftp://ftp.freetds.org/pub/freetds/stable/freetds-1.1.6.tar.gz -O /opt/freetds-1.1.6.tar.gz; \
    cd /opt; \
    tar zxvf freetds-1.1.6.tar.gz; \
    cd freetds-1.1.6; \
    ./configure; \
    make; \
    make install; \
    cd /usr/lib/; \
    rm libsybdb.so; \
    ln -s /usr/local/lib/libsybdb.so .; \
    ln -s libsybdb.so libsybdb.so.5; \
    ln -s /bin/tsql /usr/bin/tsql; \
    # Build FreeTDS 1.1.6
    \
    docker-php-ext-configure gd \
        --with-freetype-dir=/usr/include/ \
        --with-jpeg-dir=/usr/include/; \
    docker-php-ext-install gd; \
    docker-php-ext-install calendar gettext mcrypt exif soap sockets \
        mssql mysql mysqli pdo pdo_mysql xsl xmlrpc opcache zip bz2 pcntl; \
    pecl install propro-1.0.2 raphf-1.1.2 imagick-3.4.3 geoip-1.1.1 redis-4.3.0 json_post-1.0.1 apfd-1.0.1; \
    docker-php-ext-enable propro raphf imagick geoip redis json_post apfd; \
    pecl install pecl_http-2.6.0; \
    CFLAGS="-fgnu89-inline" pecl install memcache-3.0.8; \
    docker-php-ext-enable http memcache; \
    \
    pear install Archive_Tar Auth_SASL Console_Getopt \
        DB Log MDB2 Mail Mail_Mime Mail_mimeDecode \
        Net_SMTP Net_Socket PEAR PEAR_Manpages \
        Pager Structures_Graph XML_Util; \
    \
    docker-php-source delete; \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $RUNTIME_DEPS; \
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
    find /usr/local -type f -executable -exec ldd '{}' ';' \
     | awk '/=>/ { print $(NF-1) }' \
     | sort -u \
     | xargs -r dpkg-query --search \
     | cut -d: -f1 \
     | sort -u \
     | xargs -r apt-mark manual; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/* /tmp/pear /opt/freetds-1.1.6* /etc/logrotate.d; \
	{ \
        echo 'daily'; \
        echo 'rotate 7'; \
        echo 'dateext'; \
        echo 'create 666 root root'; \
        echo ''; \
        echo 'missingok'; \
        echo 'notifempty'; \
        echo 'compress'; \
        echo 'delaycompress'; \
        echo ''; \
        echo '/var/log/apps/*.log'; \
        echo '/var/log/nginx/*.log'; \
        echo '/var/log/php-fpm/*.log'; \
        echo '{'; \
        echo '}'; \
	} > /etc/logrotate.conf; \
    \
    php --version; \
    nginx -v; \
    supervisord -v; \
    \
    mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf_origin; \
    echo -e "<?php\nphpinfo();" > /usr/share/nginx/html/phpinfo.php; \
    mkdir -p /var/log/php-fpm; \
    chown www-data:www-data /var/log/php-fpm; \
    sed -i 's/user  nginx;/user  www-data;/g' /etc/nginx/nginx.conf; \
    sed -i 's/error_log = \/proc\/self\/fd\/2/error_log = \/var\/log\/php-fpm\/error.log/g' /usr/local/etc/php-fpm.d/docker.conf; \
    sed -i 's/access.log = \/proc\/self\/fd\/2/access.log = \/var\/log\/php-fpm\/access.log/g' /usr/local/etc/php-fpm.d/docker.conf;

WORKDIR /usr/share/nginx/html
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY nginx-default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["/usr/bin/supervisord", "-n"]