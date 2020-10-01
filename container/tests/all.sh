#!/bin/bash

# script that tests outputs. will exit 1 if any of the command fails
# simply just add testme command to be tested
# look at the examples below

function testme {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo
        echo "The command failed:  error with $1" >&2
        echo "Exiting"
        exit 1
    fi
}

testme curl -s localhost --connect-timeout 2 -m 2 1> /dev/null
testme ps aux | grep -iv nginx | grep -vi grep 1> /dev/null
