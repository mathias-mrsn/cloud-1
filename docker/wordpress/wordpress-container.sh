#!/bin/bash

set -euo pipefail

WP_ROOT="/var/www/wordpress"
WP_CONFIG_PATH="${WP_ROOT}/wp-config.php"
WP_INIT_FILE="${WP_ROOT}/wordpress.initialized"
WP_FAIL_FILE="${WP_ROOT}/wordpress.failed"
WP_LOCK_DIR="${WP_ROOT}/.bootstrap-lock"
WP_HEALTH_FILE="${WP_ROOT}/healthz.php"
WP_MU_PLUGIN_DIR="${WP_ROOT}/wp-content/mu-plugins"
WP_CLI_CACHE_DIR="${WP_ROOT}/.wp-cli/cache"

WORDPRESS_ADMIN_SECRET_ARN="${WORDPRESS_ADMIN_SECRET_ARN:-}"
PREFIX="${PREFIX:-}"
ENABLE_LOCAL_STACK="${ENABLE_LOCAL_STACK:-false}"

log() {
        printf '[wordpress-bootstrap] %s\n' "$1" >&2
}

parameter_value() {
        aws ssm get-parameter --with-decryption --name "$1" --query 'Parameter.Value' --output text
}

secret_value() {
        printf '%s' "$WORDPRESS_ADMIN_SECRET_JSON" | jq -er --arg key "$1" '.[$key] | select(type == "string" and length > 0)'
}

if [ ! -x /usr/local/bin/wp ]; then
        echo "wp-cli not found in image" >&2
        exit 1
fi

if [ "$ENABLE_LOCAL_STACK" = "false" ]; then
        WORDPRESS_ADMIN_SECRET_JSON="$(aws secretsmanager get-secret-value --secret-id "$WORDPRESS_ADMIN_SECRET_ARN" --query SecretString --output text)"

        WORDPRESS_DB_HOST="$(parameter_value "/${PREFIX}/aurora/endpoint")"
        WORDPRESS_DB_NAME="$(parameter_value "/${PREFIX}/aurora/name")"
        WORDPRESS_SITE_TITLE="$(parameter_value "/${PREFIX}/wordpress/title")"
        WORDPRESS_LOCALE="$(parameter_value "/${PREFIX}/wordpress/locale")"
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
fi

mkdir -p "$WP_ROOT" "$WP_MU_PLUGIN_DIR" "$WP_CLI_CACHE_DIR"
export WP_CLI_CACHE_DIR

MYSQLADMIN_ARGS=()
if [ "$ENABLE_LOCAL_STACK" = "true" ]; then
        MYSQLADMIN_ARGS+=(--protocol=tcp --skip-ssl)
fi

log "Waiting for MySQL at ${WORDPRESS_DB_HOST}"
until MYSQL_PWD="$WORDPRESS_DB_PASSWORD" mysqladmin ping "${MYSQLADMIN_ARGS[@]}" -h "$WORDPRESS_DB_HOST" -u "$WORDPRESS_DB_USER" --silent >/dev/null 2>&1; do
        sleep 5
done

if [ ! -f "$WP_INIT_FILE" ]; then
        while ! mkdir "$WP_LOCK_DIR" 2>/dev/null; do
                log "Bootstrap lock held by another task, waiting"
                sleep 5
                if [ -f "$WP_INIT_FILE" ]; then
                        break
                fi
        done

        if [ ! -f "$WP_INIT_FILE" ]; then
                trap 'rmdir "$WP_LOCK_DIR" 2>/dev/null || true' EXIT
                rm -f "$WP_FAIL_FILE"

                cd "$WP_ROOT"

                if [ ! -f "$WP_ROOT/wp-settings.php" ]; then
                        log "Syncing bundled WordPress into $WP_ROOT"
                        rsync -a /usr/src/wordpress/ "$WP_ROOT/"
                fi

                if [ ! -f "$WP_CONFIG_PATH" ]; then
                        log "Creating wp-config.php"
                        /usr/local/bin/wp core config --path="$WP_ROOT" --dbname="$WORDPRESS_DB_NAME" --dbuser="$WORDPRESS_DB_USER" --dbpass="$WORDPRESS_DB_PASSWORD" --dbhost="$WORDPRESS_DB_HOST" --dbprefix=wp_ --allow-root
                fi

                /usr/local/bin/wp config set WPLANG "$WORDPRESS_LOCALE" --type=constant --path="$WP_ROOT" --allow-root
                /usr/local/bin/wp config set WP_HOME "$WORDPRESS_SITE_URL" --type=constant --path="$WP_ROOT" --allow-root
                /usr/local/bin/wp config set WP_SITEURL "$WORDPRESS_SITE_URL" --type=constant --path="$WP_ROOT" --allow-root
                /usr/local/bin/wp config set AUTH_KEY "$WORDPRESS_AUTH_KEY" --type=constant --path="$WP_ROOT" --allow-root
                /usr/local/bin/wp config set SECURE_AUTH_KEY "$WORDPRESS_SECURE_AUTH_KEY" --type=constant --path="$WP_ROOT" --allow-root
                /usr/local/bin/wp config set LOGGED_IN_KEY "$WORDPRESS_LOGGED_IN_KEY" --type=constant --path="$WP_ROOT" --allow-root
                /usr/local/bin/wp config set NONCE_KEY "$WORDPRESS_NONCE_KEY" --type=constant --path="$WP_ROOT" --allow-root
                /usr/local/bin/wp config set AUTH_SALT "$WORDPRESS_AUTH_SALT" --type=constant --path="$WP_ROOT" --allow-root
                /usr/local/bin/wp config set SECURE_AUTH_SALT "$WORDPRESS_SECURE_AUTH_SALT" --type=constant --path="$WP_ROOT" --allow-root
                /usr/local/bin/wp config set LOGGED_IN_SALT "$WORDPRESS_LOGGED_IN_SALT" --type=constant --path="$WP_ROOT" --allow-root
                /usr/local/bin/wp config set NONCE_SALT "$WORDPRESS_NONCE_SALT" --type=constant --path="$WP_ROOT" --allow-root

                if [ "$ENABLE_LOCAL_STACK" = "true" ]; then
                        /usr/local/bin/wp config set FORCE_SSL_ADMIN false --raw --type=constant --path="$WP_ROOT" --allow-root
                else
                        /usr/local/bin/wp config set FORCE_SSL_ADMIN true --raw --type=constant --path="$WP_ROOT" --allow-root
                fi

                if [ "$ENABLE_LOCAL_STACK" != "true" ] && ! grep -Fq "\$_SERVER['HTTPS'] = 'on';" "$WP_CONFIG_PATH"; then
                        sed -i "/\$table_prefix = 'wp_';/ a \$_SERVER['HTTPS'] = 'on';" "$WP_CONFIG_PATH"
                fi

                if ! grep -Fq "define('WP_CACHE', true);" "$WP_CONFIG_PATH"; then
                        sed -i "/\$table_prefix = 'wp_';/ a \\define('WP_CACHE', true);" "$WP_CONFIG_PATH"
                fi

                if ! /usr/local/bin/wp core is-installed --path="$WP_ROOT" --allow-root >/dev/null 2>&1; then
                        log "Installing WordPress core"
                        /usr/local/bin/wp core install --path="$WP_ROOT" --url="$WORDPRESS_SITE_URL" --title="$WORDPRESS_SITE_TITLE" --admin_user="$WORDPRESS_ADMIN_USER" --admin_password="$WORDPRESS_ADMIN_PASSWORD" --admin_email="$WORDPRESS_ADMIN_EMAIL" --skip-email --allow-root
                        log "Installing TwentyTwenty theme"
                        /usr/local/bin/wp theme install --path="$WP_ROOT" twentytwenty --activate --allow-root
                fi

                cat >"$WP_HEALTH_FILE" <<'EOF'
<?php
http_response_code(200);
header('Content-Type: text/plain');
echo "ok\n";
EOF

                touch "$WP_INIT_FILE"
                rmdir "$WP_LOCK_DIR" 2>/dev/null || true
                trap - EXIT
        fi
fi

if [ "$ENABLE_LOCAL_STACK" = "true" ] && [ -f "$WP_CONFIG_PATH" ]; then
        sed -i "/\$_SERVER\['HTTPS'\] = 'on';/d" "$WP_CONFIG_PATH"
        /usr/local/bin/wp config set FORCE_SSL_ADMIN false --raw --type=constant --path="$WP_ROOT" --allow-root
fi

cp /opt/cloud1/wordpress-mu-plugins/cloud1-instance-ip.php "${WP_MU_PLUGIN_DIR}/cloud1-instance-ip.php"
chown -R www-data:www-data "$WP_ROOT"

log "Starting PHP-FPM"
exec "$@"
