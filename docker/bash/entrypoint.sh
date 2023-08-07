#!/bin/bash

# symbolic link
ln -s /etc/nginx/sites-available/inkamapp.conf /etc/nginx/sites-enabled &

# Start PHP-FPM in the background
php-fpm &

# Start Nginx in the foreground
nginx -g "daemon off;"
