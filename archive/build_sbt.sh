#!/bin/bash

# Written on 7 Jan, 2016 by Shashwat Mishra

# Description
# -----------
# Example script to package and push jar to a cluster. 
# -----------

set -u

declare -a specs=("sample.sbt" "pom.xml")
declare -a tools=("sbt" "mvn")

log(){
    echo "[$(date)]: $*"
}
existsFile(){
    if [ -f $1 ]; then
        return 0
    fi
    return -1
}


init(){

    STARTTIME=$(date +%s)
    

    red=$'\e[1;31m'
    grn=$'\e[1;32m'
    yel=$'\e[1;33m'
    blue=$'\e[1;34m'
    mag=$'\e[1;35m'
    cyn=$'\e[1;36m'
    end=$'\e[0m'
}

end(){
    ENDTIME=$(date +%s)
    SPENTTIME=$((ENDTIME-STARTTIME));
}

checkParams() {
    if [ "$#" -lt 1 ]; then
        echo
        echo "Usage: $0 <cluster>" 
        echo 
        exit 1
    fi
}

findBuildTool() {

    index=0
    matchIndex=-1
    for i in "${specs[@]}"
    do
        if [ -f $i ]; then
            matchIndex=$index
        fi
        index=$((index+1))
    done 

    if [[ $matchIndex -eq -1 ]]; then
        log "${red}Error: unknown build tool${end}"
        exit 1
    fi
    
    bTool=${tools[$matchIndex]}
    log "build tool: ${mag} $bTool ${end}"
}

build(){
    if [[ "$bTool" == "mvn" ]]; then
        rm -rf target/*.jar
        mvn install
    fi
    if [[ "$bTool" == "sbt" ]]; then
        rm -rf target/scala-*/*.jar
        sbt package
    fi
}

checkRemoteLocationExists() {
    sshEntry="Host $1"
    #log "${mag}Looking up in ssh config: $sshEntry ${end}"
    cat ~/.ssh/config | grep -q "$sshEntry"
    if [[ $? -ne 0 ]]; then
        log "${red}Error: unknown remote location: $1 ${end}"
        exit 1
    fi
    log "${mag}remote location exists${end}"
}

push(){
    if [[ "$bTool" == "mvn" ]]; then
        pushFile=target/*.jar
        #log "push file $pushFile"
        scp $pushFile $1:
    fi
    if [[ "$bTool" == "sbt" ]]; then
        pushFile=target/scala-*/*.jar
        #log "push file $pushFile"
        scp $pushFile $1: 
    fi
}

checkParams $*
init
findBuildTool
build
checkRemoteLocationExists $1
push $1
end

log "Execution time: ${blue} $SPENTTIME ${end}seconds."
