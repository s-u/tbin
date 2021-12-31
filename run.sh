#!/bin/bash

RVER="$1"

if [ -z "$RVER" ]; then
    RVER=devel
fi

echo "::group:: building R-$RVER"

echo '::endgroup::'

exit 0
