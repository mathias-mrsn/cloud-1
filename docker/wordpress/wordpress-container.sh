#!/bin/bash

set -euo pipefail

if [ ! -x /usr/local/bin/wp ]; then
        echo "wp-cli not found in image" >&2
        exit 1
fi

parameter_value() {
        aws ssm get-parameter --with-decryption --name "$1" --query 'Parameter.Value' --output text
}

secret_value() {
        printf '%s' "$WORDPRESS_ADMIN_SECRET_JSON" | jq -er --arg key "$1" '.[$key] | select(type == "string" and length > 0)'
}

WORDPRESS_ADMIN_SECRET_JSON="$(aws secretsmanager get-secret-value --secret-id "$WORDPRESS_ADMIN_SECRET_ARN" --query SecretString --output text)"

WORDPRESS_DB_HOST="$(parameter_value "/${PREFIX}/aurora/endpoint")"
WORDPRESS_DB_NAME="$(parameter_value "/${PREFIX}/aurora/name")"
WORDPRESS_SITE_TITLE="$(parameter_value "/${PREFIX}/wordpress/title")"
WORDPRESS_LOCALE="$(parameter_value "/${PREFIX}/wordpress/locale")"
WORDPRESS_EFS_DIR="$(parameter_value "/${PREFIX}/wordpress/shared_root")"
WORDPRESS_SITE_URL="$(parameter_value "/${PREFIX}/wordpress/url")"
WORDPRESS_AUTH_KEY="$(parameter_value "/${PREFIX}/wordpress/auth_key")"
WORDPRESS_SECURE_AUTH_KEY="$(parameter_value "/${PREFIX}/wordpress/secure_auth_key")"
WORDPRESS_LOGGED_IN_KEY="$(parameter_value "/${PREFIX}/wordpress/logged_in_key")"
WORDPRESS_NONCE_KEY="$(parameter_value "/${PREFIX}/wordpress/nonce_key")"
WORDPRESS_AUTH_SALT="$(parameter_value "/${PREFIX}/wordpress/auth_salt")"
WORDPRESS_SECURE_AUTH_SALT="$(parameter_value "/${PREFIX}/wordpress/secure_auth_salt")"
WORDPRESS_LOGGED_IN_SALT="$(parameter_value "/${PREFIX}/wordpress/logged_in_salt")"
WORDPRESS_NONCE_SALT="$(parameter_value "/${PREFIX}/wordpress/nonce_salt")"
WORDPRESS_ADMIN_USER="$(printf '%s' "$WORDPRESS_ADMIN_SECRET_JSON" | jq -er '.admin_user // .username | select(type == "string" and length > 0)')"
WORDPRESS_ADMIN_EMAIL="$(secret_value admin_email)"
WORDPRESS_ADMIN_PASSWORD="$(secret_value password)"

WP_ROOT="$WORDPRESS_EFS_DIR"
WP_CLI_CACHE_DIR="${WP_ROOT}/.wp-cli/cache"
WP_CONFIG_PATH="${WP_ROOT}/wp-config.php"
WP_MU_PLUGIN_DIR="${WP_ROOT}/wp-content/mu-plugins"

mkdir -p "${WP_ROOT}"
mkdir -p "$WP_CLI_CACHE_DIR"
mkdir -p "$WP_MU_PLUGIN_DIR"

export WP_CLI_CACHE_DIR

until MYSQL_PWD="$WORDPRESS_DB_PASSWORD" mysqladmin ping -h "$WORDPRESS_DB_HOST" -u "$WORDPRESS_DB_USER" --silent >/dev/null 2>&1; do
        sleep 5
done

if [ ! -f "${WP_ROOT}/wp-settings.php" ] || [ ! -f "$WP_CONFIG_PATH" ] || [ ! -f "${WP_ROOT}/healthz.php" ] || ! /usr/local/bin/wp core is-installed --path="${WP_ROOT}" --allow-root >/dev/null 2>&1; then
        rsync -a /usr/src/wordpress/ "${WP_ROOT}/"

        if [ ! -f "$WP_CONFIG_PATH" ]; then
                /usr/local/bin/wp core config --path="${WP_ROOT}" --dbname="$WORDPRESS_DB_NAME" --dbuser="$WORDPRESS_DB_USER" --dbpass="$WORDPRESS_DB_PASSWORD" --dbhost="$WORDPRESS_DB_HOST" --dbprefix=wp_ --allow-root
        fi

        /usr/local/bin/wp config set WP_HOME "$WORDPRESS_SITE_URL" --type=constant --path="${WP_ROOT}" --allow-root
        /usr/local/bin/wp config set WP_SITEURL "$WORDPRESS_SITE_URL" --type=constant --path="${WP_ROOT}" --allow-root
        /usr/local/bin/wp config set WPLANG "$WORDPRESS_LOCALE" --type=constant --path="${WP_ROOT}" --allow-root
        /usr/local/bin/wp config set AUTH_KEY "$WORDPRESS_AUTH_KEY" --type=constant --path="${WP_ROOT}" --allow-root
        /usr/local/bin/wp config set SECURE_AUTH_KEY "$WORDPRESS_SECURE_AUTH_KEY" --type=constant --path="${WP_ROOT}" --allow-root
        /usr/local/bin/wp config set LOGGED_IN_KEY "$WORDPRESS_LOGGED_IN_KEY" --type=constant --path="${WP_ROOT}" --allow-root
        /usr/local/bin/wp config set NONCE_KEY "$WORDPRESS_NONCE_KEY" --type=constant --path="${WP_ROOT}" --allow-root
        /usr/local/bin/wp config set AUTH_SALT "$WORDPRESS_AUTH_SALT" --type=constant --path="${WP_ROOT}" --allow-root
        /usr/local/bin/wp config set SECURE_AUTH_SALT "$WORDPRESS_SECURE_AUTH_SALT" --type=constant --path="${WP_ROOT}" --allow-root
        /usr/local/bin/wp config set LOGGED_IN_SALT "$WORDPRESS_LOGGED_IN_SALT" --type=constant --path="${WP_ROOT}" --allow-root
        /usr/local/bin/wp config set NONCE_SALT "$WORDPRESS_NONCE_SALT" --type=constant --path="${WP_ROOT}" --allow-root
        /usr/local/bin/wp config set FORCE_SSL_ADMIN true --raw --type=constant --path="${WP_ROOT}" --allow-root

        if ! grep -q "CLOUD1_FORCE_HTTPS" "$WP_CONFIG_PATH"; then
                php -r '$path = $argv[1]; $needle = "/* That'"'"'s all, stop editing! Happy publishing. */"; $insert = "/* CLOUD1_FORCE_HTTPS */\n\$_SERVER[\"HTTPS\"] = \"on\";\n\$_SERVER[\"SERVER_PORT\"] = 443;\n\$_SERVER[\"REQUEST_SCHEME\"] = \"https\";\n\n" . $needle; $data = file_get_contents($path); if (strpos($data, $needle) === false) { fwrite(STDERR, "wp-config.php marker not found\n"); exit(1); } file_put_contents($path, str_replace($needle, $insert, $data));' "$WP_CONFIG_PATH"
        fi

        /usr/local/bin/wp core install --path="${WP_ROOT}" --url="$WORDPRESS_SITE_URL" --title="$WORDPRESS_SITE_TITLE" --admin_user="$WORDPRESS_ADMIN_USER" --admin_password="$WORDPRESS_ADMIN_PASSWORD" --admin_email="$WORDPRESS_ADMIN_EMAIL" --skip-email --allow-root
        /usr/local/bin/wp theme install --path="${WP_ROOT}" twentytwenty --activate --force --allow-root

        cat >"${WP_ROOT}/healthz.php" <<'EOF'
<?php
http_response_code(200);
header('Content-Type: text/plain');
echo "ok\n";
EOF
fi

cp /opt/cloud1/wordpress-mu-plugins/cloud1-instance-ip.php "${WP_MU_PLUGIN_DIR}/cloud1-instance-ip.php"
chown -R www-data:www-data "${WP_ROOT}"

exec "$@"
