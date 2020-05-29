#!/bin/bash

# switch to correct directory
currentDir=$(dirname $0)
cd ${currentDir}/..
dirName=${PWD##*/}

# create .env file
cp .env.example .env
cp docker-compose.yml.example docker-compose.yml

# set random mysql password
mysql_password=$(
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 26
    echo ''
)
sed -i "s/^.*MYSQL_PASSWORD\:.*$/      MYSQL_PASSWORD: ${mysql_password}/" docker-compose.yml
sed -i "s/^DB_PASSWORD=.*$/DB_PASSWORD=${mysql_password}/" .env

# build docker images
docker-compose pull

echo "Starting services..."

output=$(mktemp "${TMPDIR:-/tmp/}log_laravel_engency_installation.XXX")
docker-compose up &> $output &
server_pid=$!
until grep -q -i 'Server socket created on IP' $output
do
  if ! ps $server_pid > /dev/null
  then
    echo "The server died" >&2
    exit 1
  fi
  echo -n "."
  sleep 1
done
echo
echo "Server is running!"

# install dependencies
docker exec "${dirName}"_webserver_1 chown -R www-data: storage/app
docker exec "${dirName}"_webserver_1 chown -R www-data: storage/framework
docker exec "${dirName}"_webserver_1 chown -R www-data: storage/logs
docker exec "${dirName}"_webserver_1 chmod -R 740 storage/app
docker exec "${dirName}"_webserver_1 chmod -R 740 storage/framework
docker exec "${dirName}"_webserver_1 chmod -R 740 storage/logs
docker exec "${dirName}"_webserver_1 composer install

docker exec "${dirName}"_webserver_1 php artisan key:generate

docker exec -u www-data "${dirName}"_webserver_1 php artisan migrate

# start application
xdg-open http://localhost &
