#!/bin/bash

# Build and install Mosquitto-PHP extension
# Requires libmosquitto-dev to be pre-installed
cd /
git clone https://github.com/openenergymonitor/Mosquitto-PHP
cd Mosquitto-PHP/
phpize
./configure
make
make install
docker-php-ext-enable mosquitto

