#!/bin/bash

currentDir=$(dirname $0)
cd ${currentDir}/../..
buildID=${PWD##*/}

backup_live_environment() {
    echo 'Backing-up live environment...'

    cd ~/builds/live || return 1
    scripts/docker_inject.sh php artisan backup:run --quiet
    cd ../..

    return 0
}

create_backup_link_for_live_environment() {
    echo 'Creating backup link for live environment...'

    # link to current live environment
    backupBuildID=$(cat ~/builds/liveBuildId)
    rm ~/builds/backup
    ln -s ~/builds/${backupBuildID} ~/builds/backup
    echo ${backupBuildID} >~/builds/backupBuildId

    return 0
}

stop_live_environment() {
    echo 'Stopping service...'
    sudo systemctl stop engency

    # stop all images
    docker stop $(docker ps -a -q)

    return 0
}

migrate_new_environment() {
    # migrate data
    echo 'Migrating data...'
    cd ~/builds/${buildID}
    docker-compose up mariadb &
    sleep 5

    result=$(docker-compose run --entrypoint="" --rm webserver php artisan migrate --force --no-interaction)
    echo ${result}

    if [[ ${result} == *"Migrated:"* ]]; then
        echo -n '1' >./ranMigrations
        return 0
    else
        if [[ ${result} == *"Nothing to migrate"* ]]; then
            echo -n '0' >./ranMigrations
            return 0
        else return 1; fi
    fi
    cd ../..
}

install_new_environment() {
    echo 'Installing new environment...'
    # link to new environment
    rm ~/builds/live
    ln -s ~/builds/${buildID} ~/builds/live
    echo ${buildID} >~/builds/liveBuildId

    return 0
}

start_live_environment() {
    # first shutdown all running containers
    docker-compose down

    echo 'Starting service using new environment...'
    sudo systemctl start engency

    attempts=10
    services=(webserver mariadb)
    for service in "${services[@]}"; do
        while ! [[ $(docker ps --filter "name=${buildID}_${service}" | grep Up) ]]; do
            if [[ "$attempts" -eq "0" ]]; then
                echo "Service ${service} did NOT successfully start..."
                return 1 # error
            fi
            ((attempts--))
            sleep 1
        done
    done

    echo 'Service has started and is ready to be used!'
    return 0
}

trigger_upgrade_script() {
    echo 'Triggering upgrade script...'
    docker-compose run --entrypoint="" --rm webserver php artisan upgrade --quiet

    return 0
}

rollback_database() {
    echo 'Performing database rollback...'

    ranMigrations=$(cat ~/builds/live/ranMigrations)

    if [[ ranMigrations -eq '1' ]]; then
        docker-compose run --entrypoint="" --rm webserver php artisan migrate:rollback
    fi
}

rollback() {
    echo 'Performing rollback...'

    # force stop service
    stop_live_environment

    # unlink probable broken live environment
    rm ~/builds/live
    rm ~/builds/liveBuildId
    cp -P ~/builds/backup ~/builds/live
    cp ~/builds/backupBuildId ~/builds/liveBuildId

    # start service
    sudo systemctl start engency
}

echo 'Starting upgrade of service.'
df

if [[ -d ~/builds/live ]]; then
    backup_live_environment
    create_backup_link_for_live_environment
    stop_live_environment
else
    echo 'No live environment present to backup'
fi

# rollback is required in case of a failure starting here

if ! migrate_new_environment; then
    echo 'An exception occurred during migration of the database... Starting rollback procedure'
    rollback
    echo 'Rollback completed. Please make sure service is in a healthy condition.'
    exit 1
fi

if ! install_new_environment || ! start_live_environment; then
    echo 'An exception occurred after migrating the database... Starting rollback procedure'
    rollback_database
    rollback
    echo 'Rollback completed. Please make sure service is in a healthy condition.'
    exit 1
fi

# service was installed with success. Rollback won't be required anymore

trigger_upgrade_script
echo 'Completed upgrading service.'
