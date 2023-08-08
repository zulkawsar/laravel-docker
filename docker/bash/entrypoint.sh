#!/bin/bash
PROJECT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Load variables from environment file
source "$PROJECT_PATH/local.env"
# symbolic link
ln -s /etc/nginx/sites-available/${VIRTUAL_HOST}.conf /etc/nginx/sites-enabled &

# Start PHP-FPM in the background
php-fpm &

# Start Nginx in the foreground
nginx -g "daemon off;"
