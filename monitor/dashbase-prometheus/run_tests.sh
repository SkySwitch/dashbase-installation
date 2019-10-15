#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
docker run -ti --entrypoint="/bin/sh" --volume=${DIR}:/prom -w /prom prom/prometheus:v2.7.1 -c 'promtool check rules dashbase-recording/* && promtool check rules dashbase-alerts/* && promtool test rules tests/*'
