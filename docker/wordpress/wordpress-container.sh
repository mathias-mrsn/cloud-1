#!/bin/bash

set -euo pipefail

log() {
        printf '[wordpress-bootstrap] %s\n' "$1" >&2
}

if [ ! -x /usr/local/bin/wp ]; then
        echo "wp-cli not found in image" >&2
        exit 1
fi

WORDPRESS_ADMIN_SECRET_ARN="${WORDPRESS_ADMIN_SECRET_ARN:-}"
PREFIX="${PREFIX:-}"
ENABLE_LOCAL_STACK="${ENABLE_LOCAL_STACK:-false}"

MYSQLADMIN_EXTRA_ARGS=()
if [ "$ENABLE_LOCAL_STACK" = "true" ]; then
        MYSQLADMIN_EXTRA_ARGS+=(--protocol=tcp --skip-ssl)
fi

parameter_value() {
        aws ssm get-parameter --with-decryption --name "$1" --query 'Parameter.Value' --output text
}

secret_value() {
        printf '%s' "$WORDPRESS_ADMIN_SECRET_JSON" | jq -er --arg key "$1" '.[$key] | select(type == "string" and length > 0)'
}

if [ "$ENABLE_LOCAL_STACK" = "false" ]; then
        WORDPRESS_ADMIN_SECRET_JSON="$(aws secretsmanager get-secret-value --secret-id "$WORDPRESS_ADMIN_SECRET_ARN" --query SecretString --output text)"

        WORDPRESS_DB_HOST="$(parameter_value "/${PREFIX}/aurora/endpoint")"
        WORDPRESS_DB_NAME="$(parameter_value "/${PREFIX}/aurora/name")"
        WORDPRESS_SITE_TITLE="$(parameter_value "/${PREFIX}/wordpress/title")"
        WORDPRESS_LOCALE="$(parameter_value "/${PREFIX}/wordpress/locale")"
        WORDPRESS_EFS_DIR="$(parameter_value "/${PREFIX}/wordpress/shared_root")"
        WORDPRESS_SITE_URL="$(parameter_value "/${PREFIX}/wordpress/url")"
        WORDPRESS_PERFORMANCE_URL="$(parameter_value "/${PREFIX}/wordpress/performance_url")"
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

WORDPRESS_PERFORMANCE_URL="${WORDPRESS_PERFORMANCE_URL:-${WORDPRESS_SITE_URL}}"
WORDPRESS_PERFORMANCE_HOST="${WORDPRESS_PERFORMANCE_URL#https://}"
WORDPRESS_PERFORMANCE_HOST="${WORDPRESS_PERFORMANCE_HOST#http://}"

WP_ROOT="$WORDPRESS_EFS_DIR"
WP_CLI_CACHE_DIR="${WP_ROOT}/.wp-cli/cache"
WP_CONFIG_PATH="${WP_ROOT}/wp-config.php"
WP_MU_PLUGIN_DIR="${WP_ROOT}/wp-content/mu-plugins"
BOOTSTRAP_LOCK_DIR="${WP_ROOT}/.bootstrap-lock"
WP_THEME_STYLESHEET="${WP_ROOT}/wp-content/themes/twentytwenty/style.css"

mkdir -p "${WP_ROOT}"
mkdir -p "$WP_CLI_CACHE_DIR"
mkdir -p "$WP_MU_PLUGIN_DIR"

export WP_CLI_CACHE_DIR

log "Waiting for MySQL at ${WORDPRESS_DB_HOST}"
until MYSQL_PWD="$WORDPRESS_DB_PASSWORD" mysqladmin ping "${MYSQLADMIN_EXTRA_ARGS[@]}" -h "$WORDPRESS_DB_HOST" -u "$WORDPRESS_DB_USER" --silent >/dev/null 2>&1; do
        log "MySQL not ready yet"
        sleep 5
done
log "MySQL is reachable"

while [ ! -f "${WP_ROOT}/wp-settings.php" ] || [ ! -f "$WP_CONFIG_PATH" ] || [ ! -f "${WP_ROOT}/healthz.php" ] || [ ! -f "$WP_THEME_STYLESHEET" ] || ! /usr/local/bin/wp core is-installed --path="${WP_ROOT}" --allow-root >/dev/null 2>&1; do
        if mkdir "$BOOTSTRAP_LOCK_DIR" 2>/dev/null; then
                log "Acquired bootstrap lock"
                trap 'rmdir "$BOOTSTRAP_LOCK_DIR"' EXIT

                log "Syncing bundled WordPress into ${WP_ROOT}"
                rsync -a /usr/src/wordpress/ "${WP_ROOT}/"

                if [ ! -f "$WP_CONFIG_PATH" ]; then
                        log "Creating wp-config.php"
                        /usr/local/bin/wp core config --path="${WP_ROOT}" --dbname="$WORDPRESS_DB_NAME" --dbuser="$WORDPRESS_DB_USER" --dbpass="$WORDPRESS_DB_PASSWORD" --dbhost="$WORDPRESS_DB_HOST" --dbprefix=wp_ --allow-root
                fi

                log "Writing WordPress constants"
                /usr/local/bin/wp config set WPLANG "$WORDPRESS_LOCALE" --type=constant --path="${WP_ROOT}" --allow-root
                /usr/local/bin/wp config set AUTH_KEY "$WORDPRESS_AUTH_KEY" --type=constant --path="${WP_ROOT}" --allow-root
                /usr/local/bin/wp config set SECURE_AUTH_KEY "$WORDPRESS_SECURE_AUTH_KEY" --type=constant --path="${WP_ROOT}" --allow-root
                /usr/local/bin/wp config set LOGGED_IN_KEY "$WORDPRESS_LOGGED_IN_KEY" --type=constant --path="${WP_ROOT}" --allow-root
                /usr/local/bin/wp config set NONCE_KEY "$WORDPRESS_NONCE_KEY" --type=constant --path="${WP_ROOT}" --allow-root
                /usr/local/bin/wp config set AUTH_SALT "$WORDPRESS_AUTH_SALT" --type=constant --path="${WP_ROOT}" --allow-root
                /usr/local/bin/wp config set SECURE_AUTH_SALT "$WORDPRESS_SECURE_AUTH_SALT" --type=constant --path="${WP_ROOT}" --allow-root
                /usr/local/bin/wp config set LOGGED_IN_SALT "$WORDPRESS_LOGGED_IN_SALT" --type=constant --path="${WP_ROOT}" --allow-root
                /usr/local/bin/wp config set NONCE_SALT "$WORDPRESS_NONCE_SALT" --type=constant --path="${WP_ROOT}" --allow-root
                if [ "$ENABLE_LOCAL_STACK" = "true" ]; then
                        /usr/local/bin/wp config set FORCE_SSL_ADMIN false --raw --type=constant --path="${WP_ROOT}" --allow-root
                else
                        /usr/local/bin/wp config set FORCE_SSL_ADMIN true --raw --type=constant --path="${WP_ROOT}" --allow-root
                fi

                if [ "$ENABLE_LOCAL_STACK" != "true" ] && ! grep -Fq "\$_SERVER['HTTPS'] = 'on';" "$WP_CONFIG_PATH"; then
                        log "Injecting HTTPS flag into wp-config.php"
                        sed -i "/\$table_prefix = 'wp_';/ a \$_SERVER['HTTPS'] = 'on';" "$WP_CONFIG_PATH"
                fi

                if ! grep -Fq "define('WP_CACHE', true);" "$WP_CONFIG_PATH"; then
                        log "Injecting WP_CACHE into wp-config.php"
                        sed -i "/\$table_prefix = 'wp_';/ a \\define('WP_CACHE', true);" "$WP_CONFIG_PATH"
                fi

                if ! /usr/local/bin/wp core is-installed --path="${WP_ROOT}" --allow-root >/dev/null 2>&1; then
                        log "Installing WordPress core"
                        /usr/local/bin/wp core install --path="${WP_ROOT}" --url="$WORDPRESS_SITE_URL" --title="$WORDPRESS_SITE_TITLE" --admin_user="$WORDPRESS_ADMIN_USER" --admin_password="$WORDPRESS_ADMIN_PASSWORD" --admin_email="$WORDPRESS_ADMIN_EMAIL" --skip-email --allow-root
                fi

                if [ ! -f "$WP_THEME_STYLESHEET" ]; then
                        log "Installing default theme"
                        /usr/local/bin/wp theme install --path="${WP_ROOT}" twentytwenty --activate --force --allow-root
                fi

                log "Creating healthz.php"
                cat >"${WP_ROOT}/healthz.php" <<'EOF'
<?php
http_response_code(200);
header('Content-Type: text/plain');
echo "ok\n";
EOF
                log "Bootstrap completed"
                rmdir "$BOOTSTRAP_LOCK_DIR"
                trap - EXIT
        else
                log "Bootstrap lock held by another task, waiting"
                sleep 5
        fi
done

if [ "$ENABLE_LOCAL_STACK" = "true" ] && [ -f "$WP_CONFIG_PATH" ]; then
        sed -i "/\$_SERVER\['HTTPS'\] = 'on';/d" "$WP_CONFIG_PATH"
        /usr/local/bin/wp config set FORCE_SSL_ADMIN false --raw --type=constant --path="${WP_ROOT}" --allow-root
fi

if [ "$ENABLE_LOCAL_STACK" = "false" ] && [ -f "$WP_CONFIG_PATH" ]; then
        cat > /tmp/cloud1-upsert-host-urls.php <<'PHP'
<?php
$path = $argv[1];
$main = $argv[2];
$host = $argv[3];
$perf = $argv[4];
$data = file_get_contents($path);
$data = preg_replace("/^define\('WP_HOME',.*$/m", "", $data);
$data = preg_replace("/^define\('WP_SITEURL',.*$/m", "", $data);
$marker = "/* CLOUD1_HOST_URLS_START */";
$end = "/* CLOUD1_HOST_URLS_END */";
$block = $marker . PHP_EOL
    . "if (isset(\$_SERVER[\"HTTP_HOST\"]) && \$_SERVER[\"HTTP_HOST\"] === \"{$host}\") {" . PHP_EOL
    . "    define('WP_HOME', '{$perf}');" . PHP_EOL
    . "    define('WP_SITEURL', '{$perf}');" . PHP_EOL
    . "} else {" . PHP_EOL
    . "    define('WP_HOME', '{$main}');" . PHP_EOL
    . "    define('WP_SITEURL', '{$main}');" . PHP_EOL
    . "}" . PHP_EOL
    . $end . PHP_EOL;

if (strpos($data, $marker) !== false && strpos($data, $end) !== false) {
    $data = preg_replace('/\/\* CLOUD1_HOST_URLS_START \*\/.*?\/\* CLOUD1_HOST_URLS_END \*\/\n?/s', $block, $data, 1);
} else {
    $needle = "/* That's all, stop editing! Happy publishing. */";
    if (strpos($data, $needle) === false) {
        fwrite(STDERR, "wp-config.php host url marker not found\n");
        exit(1);
    }
    $data = str_replace($needle, $block . $needle, $data);
}

file_put_contents($path, $data);
PHP
        php /tmp/cloud1-upsert-host-urls.php "$WP_CONFIG_PATH" "$WORDPRESS_SITE_URL" "$WORDPRESS_PERFORMANCE_HOST" "$WORDPRESS_PERFORMANCE_URL"
        rm -f /tmp/cloud1-upsert-host-urls.php
fi

cp /opt/cloud1/wordpress-mu-plugins/cloud1-instance-ip.php "${WP_MU_PLUGIN_DIR}/cloud1-instance-ip.php"
chown -R www-data:www-data "${WP_ROOT}"

log "Starting Apache"
exec "$@"
