#!/bin/bash

serviceName=webserver
injecting=true
interactive=false
user=root

# parse options
while getopts "e:c:i:u:" opt; do
    case $opt in
    c)
        serviceName=${OPTARG}
        shift $((OPTIND - 1))
        ;;
    e)
        injecting=false
        shift $((OPTIND - 2))
        ;;
    i)
        interactive=true
        shift $((OPTIND - 2))
        ;;
    u)
        user=${OPTARG}
        shift $((OPTIND - 1))
        ;;
    esac
done

# set variables
currentDir=$(basename "$PWD")
container=$(docker ps -a | awk "/Up.*${currentDir}_${serviceName}_/{print \$2}")
service=$(docker ps -a | awk "/Up.*${currentDir}_${serviceName}_/{print \$NF}")

# act
if ${injecting}; then
    if [ -z "$service" ]; then
        echo "No ${serviceName} service running from current directory."
        exit 1
    fi
    echo "Injecting into ${service}..."
    if ${interactive}; then
      docker exec -u ${user} -i ${service} "$@"
    else
      docker exec -u ${user} ${service} "$@"
    fi
else
    if [ -z "$container" ]; then
        echo "No ${serviceName} container found in current directory."
        exit 1
    fi
    echo "Starting new ${serviceName}..."
    docker-compose run --rm ${serviceName} "$@"
fi
