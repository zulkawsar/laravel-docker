# Use the official PHP image as the base image
FROM php:8.1-fpm

# Set the working directory inside the container
WORKDIR /var/www/html

# Add docker php ext repo
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# Install php extensions
RUN chmod +x /usr/local/bin/install-php-extensions && sync &&     install-php-extensions mbstring pdo_mysql zip exif pcntl gd

# Install dependencies
RUN apt-get update && apt-get install -y build-essential libpng-dev libjpeg62-turbo-dev libfreetype6-dev locales zip jpegoptim optipng pngquant gifsicle unzip curl lua-zlib-dev libmemcached-dev nano nginx &&     rm -rf /var/lib/apt/lists/*

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Copy custom Nginx configuration
COPY /docker/nginx/laraveltest.local.conf /etc/nginx/sites-available/laraveltest.local.conf

# Copy Laravel application files
COPY . /var/www/html/

# Install Laravel dependencies
RUN composer install --no-dev --optimize-autoloader

# Set permissions
#RUN chown -R www-data:www-data /var/www/html

# Expose port 9000 (PHP-FPM listens on this port)
EXPOSE 9000

# Expose port 80
EXPOSE 80

# Copy the entrypoint script
COPY ./docker/env/local.env /usr/local/bin/

COPY ./docker/bash/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Start PHP-FPM and Nginx when the container is run
CMD ["entrypoint.sh"]
