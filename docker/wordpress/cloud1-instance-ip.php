<?php
/**
 * Plugin Name: Cloud1 Instance IP
 * Description: Displays the EC2 instance IP serving the current request.
 */

if (!defined('ABSPATH')) {
    exit;
}

function cloud1_instance_ip_value(): string
{
    static $cached = null;

    if ($cached !== null) {
        return $cached;
    }

    $token_value = cloud1_instance_ip_metadata_request(
        'PUT',
        'http://169.254.169.254/latest/api/token',
        [
            'X-aws-ec2-metadata-token-ttl-seconds: 21600',
        ]
    );

    if ($token_value === '') {
        $cached = '';
        return $cached;
    }

    $cached = cloud1_instance_ip_metadata_request(
        'GET',
        'http://169.254.169.254/latest/meta-data/local-ipv4',
        [
            'X-aws-ec2-metadata-token: ' . $token_value,
        ]
    );

    return $cached;
}

function cloud1_instance_ip_metadata_request(string $method, string $url, array $headers): string
{
    if (!function_exists('curl_init')) {
        return '';
    }

    $curl = curl_init($url);
    if ($curl === false) {
        return '';
    }

    curl_setopt_array($curl, [
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT_MS => 500,
        CURLOPT_TIMEOUT_MS => 1000,
        CURLOPT_NOPROXY => '169.254.169.254',
    ]);

    $body = curl_exec($curl);
    $status = curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
    curl_close($curl);

    if (!is_string($body) || $status !== 200) {
        return '';
    }

    return trim($body);
}

function cloud1_instance_ip_markup(): string
{
    $ip = cloud1_instance_ip_value();
    if ($ip === '') {
        return '';
    }

    return sprintf(
        '<div style="position:fixed;right:16px;bottom:16px;z-index:9999;padding:8px 12px;background:#111827;color:#ffffff;border-radius:8px;font-size:14px;font-family:system-ui,sans-serif;box-shadow:0 10px 25px rgba(0,0,0,.2);">Instance IP: %s</div>',
        esc_html($ip)
    );
}

function cloud1_instance_ip_render(): void
{
    if (is_admin()) {
        return;
    }

    echo cloud1_instance_ip_markup();
}

add_action('wp_footer', 'cloud1_instance_ip_render');
add_shortcode('cloud1_instance_ip', static function (): string {
    return cloud1_instance_ip_markup();
});
