FROM wordpress:6.8.3-php8.2-fpm

RUN apt-get update \
        && apt-get install -y --no-install-recommends \
        awscli \
        wget \
        bash \
        ca-certificates \
        curl \
        default-mysql-client \
        jq \
        less \
        rsync \
        unzip \
        && curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
        && chmod +x /usr/local/bin/wp \
        && mkdir -p /var/www/wordpress /var/www/wordpress/.health \
        && rm -rf /var/lib/apt/lists/*

COPY docker/wordpress/wordpress-container.sh /usr/local/bin/wordpress-container.sh
COPY docker/wordpress/cloud1-instance-ip.php /opt/cloud1/wordpress-mu-plugins/cloud1-instance-ip.php

RUN chmod +x /usr/local/bin/wordpress-container.sh

ENTRYPOINT ["/usr/local/bin/wordpress-container.sh"]
CMD ["php-fpm", "-F"]
