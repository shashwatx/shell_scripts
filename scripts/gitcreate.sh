#!/bin/bash

# Source: https://gist.github.com/robwierzbowski/5430952/
# Refined on 20 Nov, 2015 by Shashwat Mishra

# Description
# -----------
# This script allows command line based creation of github repositories.
# -----------


red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blue=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
end=$'\e[0m'

askIfPrivate() {
    echo -n "Is the repository private (y/n) ? "
    while read -r -n 1 -s answer; do
        if [[ $answer = [YyNn] ]]; then
            [[ $answer = [Yy] ]] && privateVal=1
            [[ $answer = [Nn] ]] && privateVal=0
            break
        fi
    done
}


CURRENTDIR=${PWD##*/}

# Gather constant vars
FETCHED_REPO_NAME=${PWD##*/}
FETCHED_GITHUB_USER=$(git config github.user)

# Get username
printf "\nFetching github username...${mag}%s${end}\n" $FETCHED_GITHUB_USER
if [[ -z "$FETCHED_GITHUB_USER" ]]; then
    read -p "${blue}I could not read gitconfig. What's your github username ? ${end}" GITHUB_USER
    printf "\n"
else
    read -p "${blue}Do you have a different github username. (Press enter to skip).${end}" GITHUB_USER
    printf "\n"
fi
GITHUB_USER="${GITHUB_USER:-$(echo $FETCHED_GITHUB_USER)}"
if [[ -z "$GITHUB_USER" ]]; then
    printf "\n${red}Error. Must specify valid github username.${end}\n"
    exit 1
fi

# Get repository name
printf "\nFetching current directory name...${mag}%s${end}\n" $FETCHED_REPO_NAME
read -p "${blue}Do you prefer a different repository name ? (Press enter to skip): ${end}" REPO_NAME 
printf "\n"

REPO_NAME="${REPO_NAME:-$(echo $FETCHED_REPO_NAME)}"
if [[ -z "$REPO_NAME" ]]; then
    printf "\n${red}Error. Must specify valid reponame.${end}\n"
    exit 1
fi

# Ask if repo private
# askIfPrivate
privateVal=0

# Lock and load
printf "\n\n=============================\n"
printf "Creating github repository...\n\n"
printf "\trepository: %s\n" $REPO_NAME
printf "\tuser: %s\n" $GITHUB_USER
printf "\tprivate: %s\n" $privateVal
printf "=============================\n"

curl -u ${GITHUB_USER} https://api.github.com/user/repos -d "{\"name\": \"${REPO_NAME}\", \"private\": false,\"has_issues\": true, \"has_downloads\": true, \"has_wiki\": false}"

echo "Now add a remote and start pushing. Happy coding !"
