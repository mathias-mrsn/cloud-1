#!/bin/bash

set -euo pipefail

EFS_DIR="${WORDPRESS_EFS_DIR}"
WP_SUBDIRECTORY="${WORDPRESS_SUBDIRECTORY}"
WP_ROOT="${EFS_DIR}${WP_SUBDIRECTORY:+/${WP_SUBDIRECTORY}}"
WP_VERSION="${WORDPRESS_VERSION}"
WP_LOCALE="${WORDPRESS_LOCALE}"
DATABASE_NAME="${WORDPRESS_DB_NAME}"
DATABASE_HOST="${WORDPRESS_DB_HOST}"
DATABASE_USER="${WORDPRESS_DB_USER}"
DATABASE_PASSWORD="${WORDPRESS_DB_PASSWORD}"
WP_DOMAIN_NAME="${WORDPRESS_SITE_URL}"
WP_TITLE="${WORDPRESS_SITE_TITLE}"
WP_ADMIN_USERNAME="${WORDPRESS_ADMIN_USER}"
WP_ADMIN_PASSWORD="${WORDPRESS_ADMIN_PASSWORD}"
WP_ADMIN_EMAIL="${WORDPRESS_ADMIN_EMAIL}"
ELASTICACHE_ENDPOINT="${WORDPRESS_MEMCACHED_SERVERS}"
READINESS_FILE="${WORDPRESS_READINESS_FILE:-${WP_ROOT}/.health/ready}"
HEALTHCHECK_SCRIPT="${WP_ROOT}/healthz.php"
WP_CLI_PHAR="/usr/local/bin/wp"
WP_TMP_DIR="${WORDPRESS_TMP_DIR:-${WP_ROOT}/.tmp}"
WP_CLI_CACHE_DIR_PATH="${WORDPRESS_WP_CLI_CACHE_DIR:-${WP_ROOT}/.wp-cli/cache}"
WP_CLI_RUN=(php -d memory_limit=-1 -d sys_temp_dir="${WP_TMP_DIR}" "$WP_CLI_PHAR")

append_config_once() {
        local marker="$1"
        local content="$2"

        if ! grep -q "$marker" "${WP_ROOT}/wp-config.php"; then
                php -r '$marker = $argv[1]; $content = $argv[2]; $path = $argv[3]; $data = file_get_contents($path); if (strpos($data, $marker) === false) { $needle = "/* That'"'"'s all, stop editing! Happy publishing. */"; $replacement = $content . PHP_EOL . PHP_EOL . $needle; if (strpos($data, $needle) !== false) { $data = preg_replace("/" . preg_quote($needle, "/") . "/", addcslashes($replacement, "\\$"), $data, 1); } else { $data .= PHP_EOL . $content . PHP_EOL; } file_put_contents($path, $data); }' "$marker" "$content" "${WP_ROOT}/wp-config.php"
        fi
}

rm -f "$READINESS_FILE"

if [ ! -x "$WP_CLI_PHAR" ]; then
        echo "wp-cli not found in image at $WP_CLI_PHAR" >&2
        exit 1
fi

mkdir -p "${WP_ROOT}"
mkdir -p "$(dirname "$READINESS_FILE")"
mkdir -p "$WP_TMP_DIR"
mkdir -p "$WP_CLI_CACHE_DIR_PATH"

export TMPDIR="$WP_TMP_DIR"
export WP_CLI_CACHE_DIR="$WP_CLI_CACHE_DIR_PATH"

until MYSQL_PWD="$DATABASE_PASSWORD" mysqladmin ping -h "$DATABASE_HOST" -u "$DATABASE_USER" --silent >/dev/null 2>&1; do
        sleep 5
done

if [ ! -f "${WP_ROOT}/wp-settings.php" ]; then
        "${WP_CLI_RUN[@]}" core download --path="${WP_ROOT}" --version="$WP_VERSION" --locale="$WP_LOCALE" --allow-root
fi

if [ ! -f "${WP_ROOT}/wp-config.php" ]; then
        "${WP_CLI_RUN[@]}" core config --path="${WP_ROOT}" --dbname="$DATABASE_NAME" --dbuser="$DATABASE_USER" --dbpass="$DATABASE_PASSWORD" --dbhost="$DATABASE_HOST" --dbprefix=wp_ --allow-root
fi

append_config_once "CLOUD1_WORDPRESS_BOOTSTRAP" "/* CLOUD1_WORDPRESS_BOOTSTRAP */
define('WP_HOME', '${WORDPRESS_SITE_URL}');
define('WP_SITEURL', '${WORDPRESS_SITE_URL}');
define('WP_CACHE', true);
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    \$_SERVER['HTTPS'] = 'on';
}
define('AUTH_KEY', '${WORDPRESS_AUTH_KEY}');
define('SECURE_AUTH_KEY', '${WORDPRESS_SECURE_AUTH_KEY}');
define('LOGGED_IN_KEY', '${WORDPRESS_LOGGED_IN_KEY}');
define('NONCE_KEY', '${WORDPRESS_NONCE_KEY}');
define('AUTH_SALT', '${WORDPRESS_AUTH_SALT}');
define('SECURE_AUTH_SALT', '${WORDPRESS_SECURE_AUTH_SALT}');
define('LOGGED_IN_SALT', '${WORDPRESS_LOGGED_IN_SALT}');
define('NONCE_SALT', '${WORDPRESS_NONCE_SALT}');"

append_config_once "CLOUD1_WORDPRESS_HTTPS_FIX" "/* CLOUD1_WORDPRESS_HTTPS_FIX */
\$_SERVER['HTTPS'] = 'on';
\$_SERVER['SERVER_PORT'] = 443;
\$_SERVER['REQUEST_SCHEME'] = 'https';
define('FORCE_SSL_ADMIN', true);"

if ! "${WP_CLI_RUN[@]}" core is-installed --path="${WP_ROOT}" --allow-root; then
        "${WP_CLI_RUN[@]}" core install --path="${WP_ROOT}" --url="$WP_DOMAIN_NAME" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USERNAME" --admin_password="$WP_ADMIN_PASSWORD" --admin_email="$WP_ADMIN_EMAIL" --skip-email --allow-root
        "${WP_CLI_RUN[@]}" theme install --path="${WP_ROOT}" twentytwenty --activate --force --allow-root
fi

if [ "${WORDPRESS_ENABLE_MEMCACHED}" = "true" ]; then
        "${WP_CLI_RUN[@]}" plugin is-installed w3-total-cache --path="${WP_ROOT}" --allow-root || "${WP_CLI_RUN[@]}" plugin install --path="${WP_ROOT}" w3-total-cache --allow-root
        "${WP_CLI_RUN[@]}" plugin is-active w3-total-cache --path="${WP_ROOT}" --allow-root || "${WP_CLI_RUN[@]}" plugin activate --path="${WP_ROOT}" w3-total-cache --allow-root

        if [ ! -f "${WP_ROOT}/wp-content/advanced-cache.php" ]; then
                cp "${WP_ROOT}/wp-content/plugins/w3-total-cache/wp-content/advanced-cache.php" "${WP_ROOT}/wp-content/advanced-cache.php"
        fi

        if [ ! -f "${WP_ROOT}/wp-content/db.php" ]; then
                cp "${WP_ROOT}/wp-content/plugins/w3-total-cache/wp-content/db.php" "${WP_ROOT}/wp-content/db.php"
        fi

        mkdir -p "${WP_ROOT}/wp-content/cache" "${WP_ROOT}/wp-content/w3tc-config"
        chmod 0777 "${WP_ROOT}/wp-content/cache" "${WP_ROOT}/wp-content/w3tc-config"

        "${WP_CLI_RUN[@]}" w3-total-cache option set dbcache.enabled true --type=boolean --path="${WP_ROOT}" --allow-root
        "${WP_CLI_RUN[@]}" w3-total-cache option set dbcache.engine memcached --type=string --path="${WP_ROOT}" --allow-root
        "${WP_CLI_RUN[@]}" w3-total-cache option set dbcache.memcached.servers "$ELASTICACHE_ENDPOINT" --type=array --path="${WP_ROOT}" --allow-root
        "${WP_CLI_RUN[@]}" w3-total-cache option set browsercache.enabled false --type=boolean --path="${WP_ROOT}" --allow-root
fi

cat > "$HEALTHCHECK_SCRIPT" <<'EOF'
<?php
http_response_code(200);
header('Content-Type: text/plain');
echo "ok\n";
EOF

touch "$READINESS_FILE"
chown -R www-data:www-data "${WP_ROOT}"

exec "$@"
