#!/bin/bash

set -xe

yum update -y

sudo su - root

yum install -q -y jq
yum install -y amazon-efs-utils

mkdir -p ${EfsDir}
efs_id="${EfsId}"
mount -t efs -o tls $efs_id:/ ${EfsDir}
echo $efs_id:/ /efs efs defaults,_netdev 0 0 >>/etc/fstab

yum clean all
amazon-linux-extras enable php8.1 nginx1
yum clean metadata
yum install -q -y php-cli php-fpm php-opcache php-common php-mysqli nginx gcc make php php-pear php-devel libmemcached libmemcached-devel zlib-devel memcached

if [ ! -f /usr/lib64/php/modules/amazon-elasticache-cluster-client.so ]; then
  wget -P /tmp/ https://elasticache-downloads.s3.amazonaws.com/ClusterClient/PHP-8.1/latest-64bit-X86-openssl1.1
  tar -xf /tmp/latest-64bit-X86-openssl1.1 -C /tmp
  cp /tmp/amazon-elasticache-cluster-client.so /usr/lib64/php/modules/amazon-elasticache-cluster-client.so
  pecl install igbinary
fi

if [ ! -f /etc/php.d/50-memcached.ini ]; then
  touch /etc/php.d/50-memcached.ini
  echo 'extension=igbinary.so;' >>/etc/php.d/50-memcached.ini
  echo 'extension=amazon-elasticache-cluster-client.so;' >>/etc/php.d/50-memcached.ini
fi

SECRETARN="${DatabaseSecretArn}"
PASSWORD=$(aws secretsmanager get-secret-value --secret-id $SECRETARN --region ${Region} --query 'SecretString' --output text | jq -r '.password')
USERNAME=$(aws secretsmanager get-secret-value --secret-id $SECRETARN --region ${Region} --query 'SecretString' --output text | jq -r '.username')

if [ ! -f /bin/wp/wp-cli.phar ]; then
  curl -o /bin/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x /bin/wp-cli.phar
  /bin/wp-cli.phar --version --allow-root
fi

if [ ! -d ${EfsDir}/${WPSubDirectory} ]; then
  mkdir -p ${EfsDir}/${WPSubDirectory}

  if ! $(wp core is-installed --path=${EfsDir}/${WPSubDirectory} --allow-root); then
    php -d memory_limit=-1 /bin/wp-cli.phar core download --path=${EfsDir}/${WPSubDirectory} --version='${WPVersion}' --locale='${WPLocale}' --allow-root
    /bin/wp-cli.phar core config --path=${EfsDir}/${WPSubDirectory} --dbname='${DatabaseName}' --dbuser="$USERNAME" --dbpass="$PASSWORD" --dbhost='${DatabaseClusterEndpointAddress}' --dbprefix=wp_ --allow-root
    /bin/wp-cli.phar core install --path=${EfsDir}/${WPSubDirectory} --url='${WPDomainName}' --title='${WPTitle}' --admin_user='${WPAdminUsername}' --admin_password='${WPAdminPassword}' --admin_email='${WPAdminEmail}' --skip-email --allow-root
    /bin/wp-cli.phar plugin install --path=${EfsDir}/${WPSubDirectory} w3-total-cache --allow-root
    /bin/wp-cli.phar theme install --path=${EfsDir}/${WPSubDirectory} twentytwenty --activate --force --allow-root

    cp /var/www/wordpress/wp/wp-content/plugins/w3-total-cache/wp-content/advanced-cache.php /var/www/wordpress/wp/wp-content/anced-cache.php
    cp /var/www/wordpress/wp/wp-content/plugins/w3-total-cache/wp-content/db.php /var/www/wordpress/wp/wp-content/db.php
    mkdir /var/www/wordpress/wp/wp-content/cache
    chmod 777 /var/www/wordpress/wp/wp-content/cache
    mkdir /var/www/wordpress/wp/wp-content/w3tc-config
    chmod 777 /var/www/wordpress/wp/wp-content/w3tc-config

    sed -i "/\$table_prefix = 'wp_';/ a \$_SERVER['HTTPS'] = 'on';" ${EfsDir}/${WPSubDirectory}/wp-config.php
    sed -i "/\$table_prefix = 'wp_';/ a \\define('WP_CACHE', true);" ${EfsDir}/${WPSubDirectory}/wp-config.php

    /bin/wp-cli.phar plugin activate --path=${EfsDir}/${WPSubDirectory} w3-total-cache --allow-root

    /bin/wp-cli.phar w3-total-cache option set dbcache.enabled true --type=boolean --path=${EfsDir}/${WPSubDirectory} --allow-root
    /bin/wp-cli.phar w3-total-cache option set dbcache.engine memcached --type=string --path=${EfsDir}/${WPSubDirectory} --allow-root
    /bin/wp-cli.phar w3-total-cache option set dbcache.memcached.servers ${ElasticCacheEndpoint} --type=array --path=${EfsDir}/${WPSubDirectory} --allow-root
    /bin/wp-cli.phar w3-total-cache option set dbcache.memcached.servers ${ElasticCacheEndpoint} --type=array --path=${EfsDir}/${WPSubDirectory} --allow-root
    /bin/wp-cli.phar w3-total-cache option set browsercache.enabled false --type=boolean --path=${EfsDir}/${WPSubDirectory} --allow-root

    chown -R apache:apache ${EfsDir}/${WPSubDirectory}
    chmod u+wrx ${EfsDir}/${WPSubDirectory}/wp-content/*

    if [ ! -f ${EfsDir}/${WPSubDirectory}/opcache-instanceid.php ]; then
      wget -P ${EfsDir}/${WPSubDirectory}/ https://s3.amazonaws.com/aws-refarch/wordpress/latest/bits/opcache-instanceid.php
    fi
  fi
fi

mkdir -p /etc/nginx

if [ ! -f /var/www/wordpress/wp/nginx.conf ]; then
  cat <<'EOF' >/var/www/wordpress/wp/nginx.conf
events {}

http
{
	include mime.types;

    server
    {
        listen 80;
        server_name mamaurai.42.fr;

        index index.php;
        root ${EfsDir}/${WPSubDirectory};

        location / {
                try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ \.php$ {
            root    ${EfsDir}/${WPSubDirectory};
            index  index.html index.htm index.php;

            try_files $uri =404;
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:/var/run/php-fpm/www.sock;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param PATH_INFO $fastcgi_path_info;
        } 
    }
}
EOF
fi

ln -sf /var/www/wordpress/wp/nginx.conf /etc/nginx/nginx.conf

systemctl start nginx.service
