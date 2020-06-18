#!/bin/bash

currentDir=$(dirname $0)
cd ${currentDir}/../..
buildID=${PWD##*/}

copy_environment_configuration() {
    # copy existing environment configuration from parent directory if dir has no environment config yet
    [[ -e .env ]] || cp ../.env .env
}

generate_environment_configuration() {
    # generate new environment configuration if dir has no environment config yet
    [[ -e .env ]] || cp .env.example .env
}

generate_docker_compose_file() {
    export WORKSPACE=`pwd`; set -a; . .env; rm -f docker-compose.yml; envsubst < "docker-compose.yml.example" > "docker-compose.yml";
}

prepare_environment() {
    # build images
    docker-compose build

    # fix permissions #todo
    chmod -R 777 bootstrap/cache

    # set version tag
    echo -n "{\"name\":\"${buildID}\"}" >version.json

    # install dependencies
    echo 'Installing dependencies...'
    docker-compose run --entrypoint="" --no-deps --rm webserver composer install --no-scripts --no-interaction

    # generate laravel key
    docker-compose run --entrypoint="" --no-deps --rm webserver php artisan key:generate

    # check if dependency-directories exist
    if [[ -d ./vendor ]]; then return 0; else return 1; fi
}

copy_environment_configuration
generate_environment_configuration
generate_docker_compose_file
prepare_environment
