FROM    adhub.azurecr.io/php:5.6-stretch-fpm-custom

WORKDIR /ad-hub.net/apps

ARG  OPENJDK
ADD  $OPENJDK /usr/lib/jvm

RUN set -eux; \
    apt update; \
    curl -sL https://deb.nodesource.com/setup_8.x | bash -; \
    apt install -y sudo jq vim nodejs net-tools procps inetutils-ping; \
    curl -sL https://toolbelt.treasuredata.com/sh/install-debian-stretch-td-agent3.sh | sh; \
    sh -c 'for bin in /usr/lib/jvm/jdk-11.0.2/bin/*; do update-alternatives --install /usr/bin/$(basename $bin) $(basename $bin) $bin 100; done'; \
    sh -c 'for bin in /usr/lib/jvm/jdk-11.0.2/bin/*; do update-alternatives --set $(basename $bin) $bin; done'; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

ARG  BRANCH_NAME
COPY fff-og-0.3.9 /usr/local/lib/php/fff-og-0.3.9
COPY branchs/$BRANCH_NAME /ad-hub.net/apps/acho

RUN set -eux; \
    cd /ad-hub.net/apps/acho; \
    test -e Makefile && make; \
    test -e package.json && npm install; \
    mkdir -p /ad-hub.net/media /var/log/apps /var/log/apps-java /var/lib/php/upload_tmp_dir; \
    cd /ad-hub.net/media; \
    mkdir -p \
        acho_api_files \
        acho_beta_file_queue \
        acho_beta_locks \
        acho_file_queue \
        acho_job \
        acho_locks \
        line_carousel_images \
        line_channel_pictures \
        line_chat_images \
        line_coupon_images \
        line_crop_images \
        line_imagemap \
        line_images \
        line_message_image \
        line_rich_menu_images \
        line_survey_images \
        line_tools \
        line_videos \
        messageRequestChunks/pool \
        mission_image; \
    chown -R www-data:www-data /ad-hub.net/media /var/log/apps /var/log/apps-java /var/lib/php/upload_tmp_dir; \
    ln -sf /usr/local/lib/php/fff-og-0.3.9/fff.php /usr/local/lib/php/fff.php

COPY ./entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n"]