FROM wordpress:6.8.3-php8.2-apache

RUN apt-get update \
        && apt-get install -y --no-install-recommends \
        autoconf \
        awscli \
        wget \
        bash \
        build-essential \
        ca-certificates \
        curl \
        default-mysql-client \
        jq \
        less \
        libmemcached-dev \
        libsasl2-dev \
        rsync \
        unzip \
        zlib1g-dev \
        && pecl install igbinary \
        && pecl install memcached \
        && docker-php-ext-enable igbinary memcached \
        && curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
        && chmod +x /usr/local/bin/wp \
        && mkdir -p /var/www/wordpress /var/www/wordpress/.health \
        && sed -ri 's!/var/www/html!/var/www/wordpress!g' /etc/apache2/sites-available/000-default.conf /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
        && rm -rf /var/lib/apt/lists/*

COPY docker/wordpress/apache-forwarded-proto.conf /etc/apache2/conf-enabled/forwarded-proto.conf
COPY docker/wordpress/wordpress-container.sh /usr/local/bin/wordpress-container.sh

RUN chmod +x /usr/local/bin/wordpress-container.sh

ENTRYPOINT ["/usr/local/bin/wordpress-container.sh"]
CMD ["apache2-foreground"]
