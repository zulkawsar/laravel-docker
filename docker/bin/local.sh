#!/bin/bash

# Get the full project path dynamically
PROJECT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Load variables from environment file
source "$PROJECT_PATH/../env/local.env"

# Check if the network already exists
if ! docker network inspect $NETWORK_NAME >/dev/null 2>&1; then
    # Create the network
    docker network create $NETWORK_NAME
fi

# Check if port 80 is already in use by another container
if docker ps --format '{{.Ports}}' | grep -q '0.0.0.0:80->80/tcp'; then
    # Get the container ID using port 80
    CONTAINER_ID=$(docker ps --format '{{.ID}}' --filter 'expose=80/tcp')

    # Stop and remove the container
    docker stop $CONTAINER_ID
    docker rm $CONTAINER_ID

    echo "Container using port 80 removed."
fi

# Check if the nginx-proxy service is running
if docker service ls --filter "name=${NGINX_SERVICE_NAME}" | grep -q "1/1"; then
    docker service rm $NGINX_SERVICE_NAME
fi

# Generate docker nginx proxy-server
cat << EOF > docker/nginx/docker-compose-proxy.yml
version: "3.9"

services:
  nginx-proxy:
    image: jwilder/nginx-proxy
    networks:
      - ${NETWORK_NAME}
    ports:
      - "80:80"

    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro

# Docker network
networks:
  ${NETWORK_NAME}:
    external: true

EOF


# Generate nginx doamin config
cat << EOF > docker/nginx/${VIRTUAL_HOST}.conf
server {
    listen 80;
    listen [::]:80;

    server_name $VIRTUAL_HOST;

    root /var/www/html/public;
    index index.php index.html;

    location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
    }
	location ~ \.php$ {
		try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass $NGINX_SERVICE_NAME:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
	}
}

EOF

# Generate Dockerfile
cat << EOF > Dockerfile
# Use the official PHP image as the base image
FROM $PHP_FPM

# Set the working directory inside the container
WORKDIR $WORK_DIR

# Add docker php ext repo
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# Install php extensions
RUN chmod +x /usr/local/bin/install-php-extensions && sync && \
    install-php-extensions $PHP_EXTENSIONS

# Install dependencies
RUN apt-get update && apt-get install -y $PHP_PACKAGES && \
    rm -rf /var/lib/apt/lists/*

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Copy custom Nginx configuration
COPY /docker/nginx/${VIRTUAL_HOST}.conf /etc/nginx/sites-available/${VIRTUAL_HOST}.conf

# Copy Laravel application files
COPY . $WORK_DIR/

# Install Laravel dependencies
RUN composer install --no-dev --optimize-autoloader

# Set permissions
#RUN chown -R www-data:www-data $WORK_DIR

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
EOF

# Generate docker-compose.yml
cat << EOF > docker-compose.yml
version: "3.9"

services:
    ${NGINX_SERVICE_NAME}:
        build:
            context: .
            dockerfile: Dockerfile
        container_name: ${NGINX_SERVICE_NAME}
        working_dir: /var/www//html
        volumes:
            - ./:$WORK_DIR
        ports:
            - 81:80
        environment:
            - VIRTUAL_HOST=$VIRTUAL_HOST
            # Add other environment variables for your Laravel app here if needed
        networks:
            - $NETWORK_NAME
# Docker network
networks:
    $NETWORK_NAME:
        external: true

#volumes
volumes:
    dbdata:
        driver: local

EOF


#nginx proxy up
docker compose --file docker/nginx/docker-compose-proxy.yml up -d

#run docker
docker compose up -d --build