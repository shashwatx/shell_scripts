#!/bin/bash

# 20 Nov, 2015 by Shashwat Mishra

# Description
# -----------
# This script reports some stats for a given domain.
# -----------


if [ "$#" -ne 1 ]; then
    printf "\nUsage: details <domain-name>\n"
    printf "\tExample: details www.nytimes.com\n\n"
    exit 1
fi

dig +short $1 | tail -1 | xargs -I {} sh -c 'whois {}' | grep -i "^orgname\|^address\|^name\|.*postal.*\|.*city.*\|.*country.*\|.*state.*\|.*phone.*\|.*person.*"
