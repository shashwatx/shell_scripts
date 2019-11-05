#!/usr/bin/env bash

helpMessage="

==================================================================================

getStats v0.1

==================================================================================

Description: A shell script utility for generating various stats from exeuction log of the indexing job.

    Date: June, 5th, 2017.

    Author: Shashwat Mishra

    Affiliation: GrupoICA/AEAT, Spain

==================================================================================

"

usageMessage="

==================================================================================

Usage:

    $0 [OPTIONS] <input>

where:

    <input> Path to execution log

    OPTIONS:

        -k Show top k most expensive files (Default: 10).

==================================================================================

"

set -e

errMsg() {

    echo -e "$usageMessage"

    echo -e "\n$errorMsg"

    echo -e "$1"

    echo

    exit 1

}

log(){

    #echo "[$(date)]: $*"

    printf ""

}

logInfo(){

    echo "[$(date)]: ${blue} $* ${end}"

    #printf ""

}

logWarn(){

    echo "[$(date)]: ${red} $* ${end}"

}

logImp(){

    echo "[$(date)]: ${mag} $* ${end}"

    #printf ""

}

checkParams() {

    if [ "$#" -lt 1 ]; then

        echo -e "$usageMessage"

        echo

        exit 1

    fi

}

helpMsg() {

    echo -e "${helpMessage}"

    echo -e "${usageMessage}"

    echo

    exit 0

}

init(){

    STARTTIME=$(date +%s)

    topK=10

    red=$'\e[1;31m'

    grn=$'\e[1;32m'

    yel=$'\e[1;33m'

    blue=$'\e[1;34m'

    mag=$'\e[1;35m'

    cyn=$'\e[1;36m'

end=$'\e[0m'

set +e

while [ $# -gt 0 ]

do # get parameters

    case "$1" in

        -h) # purge solr

            helpMsg

            ;;

        -k) # number

            shift # to get the next parameter

            errorMsg="--- INVALID NUMBER SPECIFICATION ---"

            topK=`expr "$1" : '\([0-9]*\)'`

            [ "$topK" = "" ] && errMsg "--- NUMBER=$1 MUST BE A POSITIVE INTEGER ---"

            ;;

        -*) # any other - argument

            errorMsg="--- UNKNOWN OPTION ---"

            errMsg "--- SUPPLIED OPTION ($1) IS NOT RECOGNIZED ---"

            ;;

        -) # STDIN and end of arguments

            break

            ;;

        *) # end of arguments

            break

            ;;

        esac

        shift # next option

    done

    set -e

    if [ "$#" -lt 1 ]; then

        echo -e "$usageMessage"

        echo -e "\nDid you forget to specify input ?\n"

        echo

        exit 1

    fi

    setMaster=1

    if [ "$#" -eq 2 ]; then

        setMaster=0

    fi

    logFile=$1

}

pause() {

    echo

    read -u 0 -p "Press any key to continue..."

}

askYesNo() {

    echo -n "$1 (y/n) "

    while read -r -n 1 -s answer; do

        if [[ $answer = [YyNn] ]]; then

            [[ $answer = [Yy] ]] && response=1

            [[ $answer = [Nn] ]] && response=0

            break

        fi

    done

    echo

    echo

}

end(){

    ENDTIME=$(date +%s)

    SPENTTIME=$(((ENDTIME-STARTTIME)/60));

    SPENTTIMESECS=$(((ENDTIME-STARTTIME)));

}

info(){

    tput setaf 3

    echo

    echo "Input: $logFile"

    echo "k: $topK"

    echo

    tput sgr 0

}

## Parameter check

checkParams $*

## init

init $*

## info

info

## Pause

#pause

#clear

　

logInfo "Start."

## Average Tesseract Calls

logInfo "Filtering tesseract calls..."

cat $logFile | grep "ejecutamos: tesseract" > dat.tesseractCalls

# Procesando pagina calls

logInfo "Filtering porcesando pagina calls..."

cat $logFile | grep "Procesando pagina" > dat.pageCalls

cat dat.pageCalls | grep -v "Es el reintento" > dat.pageCalls.unique

x=`wc -l dat.tesseractCalls`

numCallsTesseract=$(echo $x | cut -d' ' -f1)

x=`wc -l dat.pageCalls.unique`

numPaginas=$(echo $x | cut -d' ' -f1)

#averageCallsPerPage=$(( numCallsTesseract / numPaginas ))

averageCallsPerPage=$(bc -l <<< $numCallsTesseract/$numPaginas)

　

## Average Aspell Score

#logInfo "Calculating average aspell score..."

#averageAspellScore="$(cat "$logFile" | grep "Resultados Aspell" | sed -e 's/.*rotacion: \([0-9][0-9]*\), porcentaje: \([0-9][0-9]*\.[0-9][0-9]*\),.*/\1 \2/' | awk '

#BEGIN{

# rot=0;maxMatch=0;sum=0;counter=0;

#}

#

#{

# rot=$1;

# if(rot==0){

# sum=sum+maxMatch;maxMatch=$2;counter++;

# }

# else{

# if($2>maxMatch){

# maxMatch=$2;

# }

# }

#}

#

#END{

# sum=sum+maxMatch;avg=sum/counter;printf("%f",avg);

#}')"

　

## Average time per tesseract call

logInfo "Calculating time per tesseract call..."

cat ${logFile} | egrep "ejecutamos: tesseract| OK$|Error de timeout" | cut -d' ' -f1,2,6,7 | awk '

BEGIN{ startTime=0; startDoy=0; endTime=0; set=0; timeout=20; numCalls=0; totalTime=0; }

{

    if(index($3,"OK")!=0 || index($3,"ERROR")!=0){

        if(set==1){

            doyStart=gensub(/-/, " ", "g", startDoy);

            split(startTime, sz, ",");

            split(sz[1], stime, ":");

            ss=doyStart" "stime[1]" "stime[2]" "stime[3];

            st=mktime(ss);

            endTime=$2;

            doyEnd=gensub(/-/, " ", "g", $1);

            split(endTime, ez, ",");

            split(ez[1], etime, ":");

            ee=doyEnd" "etime[1]" "etime[2]" "etime[3];

            et=mktime(ee);

            printf("%s %s %d\n",startTime,endTime,(et-st));

            set=0;

            numCalls++;

            totalTime=totalTime+(et-st);

        }

    }

    if(index($4,"tesseract")!=0){

        startTime=$2;

        startDoy=$1;

        set=1;

    }

}

END{avg=totalTime/numCalls;printf("%f",avg);}' > dat.timePerTsrCall

averageTimePerTsr=$(tail -1 dat.timePerTsrCall)

if [ "${setMaster}" -eq 1 ]; then

    echo

    format="%s\t\t\t%s\n"

    formatD="%s\t\t\t%d\n"

    formatF="%s\t\t\t%.2f\n"

    divider="===================="

    divider=$divider$divider

    printf "%s\n" $divider

    printf "$format" Statistic Value

    printf "%s\n" $divider

    printf "$formatD" Pages-processed $numPaginas

    printf "$formatD" Tesseract-Calls $numCallsTesseract

    printf "$formatF" Calls-Per-Page $averageCallsPerPage

    printf "$formatF" Time-Per-Call $averageTimePerTsr

    #printf "$formatF" Aspell-Score $averageAspellScore

    echo

else

    logWarn "Average Time Per Tesseract Call: $averageTimePerTsr"

    #logWarn "Average Aspell Score: $averageAspellScore"

    logInfo "Num Tesseract Calls: $numCallsTesseract"

    logInfo "Num Pagina Calls: $numPaginas"

    logWarn "Average Calls Per Page: $averageCallsPerPage"

fi

　

## Average time per file type

logInfo "Calculating time per file type..."

cat $logFile | egrep "Black Box execution finished|Tipo documento:" | cut -d' ' -f1,2,6,7,8,9 | awk '

BEGIN{

set=0;

type="unknown";

startTime=0;

startDoy=0;

endTime=0;

    }

    {

        if(set==1 && index($6,"finished")!=0){

            doyStart=gensub(/-/, " ", "g", startDoy);

            split(startTime, sz, ",");

            split(sz[1], stime, ":");

            ss=doyStart" "stime[1]" "stime[2]" "stime[3];

            st=mktime(ss);

            endTime=$2;

            doyEnd=gensub(/-/, " ", "g", $1);

            split(endTime, ez, ",");

            split(ez[1], etime, ":");

            ee=doyEnd" "etime[1]" "etime[2]" "etime[3];

            et=mktime(ee);

            #printf("%s %s %d %s\n",startTime,endTime,(et-st),type);

            freq[type]++;

            totalTime[type]=totalTime[type]+(et-st);

            set=0;

            type="unknown";

        }

        if(set==0 && index($4,"Tipo")!=0){

            set=1;

            startTime=$2;

            startDoy=$1;

            type=$6;

        }

    }

END{

for(k in freq){

    average=totalTime[k]/freq[k];

    printf("%s %f\n",k,average);

}

}' > dat.timePerFileType

logInfo "Top 10 file types by average time:-"

cat dat.timePerFileType | sort -k2,2 -nr | head -10 | awk '{print $2" "$1}' > dat.tt.child

if [ "${setMaster}" -eq 1 ]; then

    echo

    format="%-15s\t\t\t\t%s\n"

    formatD="%-15s\t\t\t\t%.2f\n"

    divider="============================"

    divider=$divider$divider

    printf "%s\n" $divider

    printf "$format" Type "Avg-Time (secs)"

    printf "%s\n" $divider

    while read line; do

        tTime=$(echo $line | cut -d' ' -f1)

        tName=$(echo $line | cut -d' ' -f2)

        printf "$formatD" $tName $tTime

    done < dat.tt.child

    echo

else

    cat dat.tt.child

fi

if [ "${setMaster}" -eq 1 ]; then

    logInfo "Gathering execution times of all files"

    cat ${logFile} | egrep "Process finished for doc|FileName: " | cut -d' ' -f1,2,6,7,8,9 | awk '

    BEGIN{

    set=0;

    name="unknown";

    startTime=0;

    startDoy=0;

    endTime=0;

}

{

    if(set==1 && index($4,"finished")!=0){

        doyStart=gensub(/-/, " ", "g", startDoy);

        split(startTime, sz, ",");

        split(sz[1], stime, ":");

        ss=doyStart" "stime[1]" "stime[2]" "stime[3];

        st=mktime(ss);

        endTime=$2;

        doyEnd=gensub(/-/, " ", "g", $1);

        split(endTime, ez, ",");

        split(ez[1], etime, ":");

        ee=doyEnd" "etime[1]" "etime[2]" "etime[3];

        et=mktime(ee);

        times[name]=(et-st);

        set=0;

        name="unknown";

    }

    if(set==0 && index($3,"FileName")!=0){

        set=1;

        startTime=$2;

        startDoy=$1;

        name=$4;

    }

}

END{

for(f in times){

    printf("%d %s\n",times[f],f);

}

}' > dat.timePerFile

　

logInfo "Top ${topK} files by execution time:-"

cat dat.timePerFile | sort -k1,1 -nr | head -${topK} | tr ' ' '\t' > dat.tt

echo

formatHeader="%-3s\t%s\t%-115s\t\t%-20s\t%-15s\t%-9s\t%-10s\t%s\t\t%s\n"

formatData="%3d\t%d\t%-115s\t\t%-20s\t%-15s\t%.2f\t\t%-10s\t%.2f\t\t%.2f\n"

divider="======================================================================================================================"

dividerMini="----------------------------------------------------------------------------------------------------------------------"

dividerMini=${dividerMini}${dividerMini}

divider=$divider$divider

printf "%s\n" $divider

printf "$formatHeader" idx \t\i\m\e name \t\y\p\e \#pages tsr-pp \#tsrcalls avg-tsr \%tsr

printf "%s\n" $divider

index=0

while read line; do

    index=$((index+1))

    fName=$(echo $line | tr '\t' ' ' | cut -d' ' -f2)

    fTime=$(echo $line | tr '\t' ' ' | cut -d' ' -f1)

    log "Will log entries for ${fName}"

    ./showFile $logFile $fName > dump

    log "Fetched log entries for ${fName}"

    log "Will infer type for ${fName}"

    set +e

    ll1=$(cat temp | grep -m 1 "Tipo documento:")

    if [ "$?" -eq 1 ]; then

        fType="unknown"

    else

        fType=$(echo $ll1 | rev | cut -d' ' -f1 | rev)

    fi

    set -e

    log "Inferred type for ${fName}: ${fType}"

    set +e

    cat temp | grep "ejecutamos: tesseract" > dat.tesseractCalls

    x=`wc -l dat.tesseractCalls`

    numCallsTesseract=$(echo $x | cut -d' ' -f1)

    set -e

    log "Extracted tesseract calls for ${fName}"

    if [ "$numCallsTesseract" -gt 0 ]; then

        log "Calculating stats ${fName}"

        ./getStats temp popeye > ttt

        #ll1=$(cat ttt | grep -A1 "Top 10 file types" | grep -v "Top 10 file types")

        #fType=$(echo $ll1 | tr '\t' ' ' | cut -d' ' -f2)

        ll1=$(cat ttt | grep "Num Pagina Calls:")

        numPages=$(echo $ll1 | rev | cut -d' ' -f2 | rev)

        ll1=$(cat ttt | grep "Average Calls Per Page:")

        callsPerPage=$(echo $ll1 | rev | cut -d' ' -f2 | rev)

        ll1=$(cat ttt | grep "Num Tesseract Calls:")

        numCalls=$(echo $ll1 | rev | cut -d' ' -f2 | rev)

        ll1=$(cat ttt | grep "Average Time Per Tesseract Call:")

        avgTime=$(echo $ll1 | rev | cut -d' ' -f2 | rev)

        percentageTsr=$(bc -l <<< $avgTime*$numCalls/$fTime*100)

        printf "$formatData" $index $fTime $fName $fType $numPages $callsPerPage $numCalls $avgTime $percentageTsr

        printf "%s\n" ${dividerMini}

    else

        numPages=0

        callsPerPage=0

        numCalls=0

        avgTime=0

        percentageTsr=0

        printf "$formatData" $index $fTime $fName $fType $numPages $callsPerPage $numCalls $avgTime $percentageTsr

        printf "%s\n" ${dividerMini}

    fi

    　

done < dat.tt

echo

end

logImp "Execution time: $SPENTTIMESECS seconds."

rm -rf dat.*

rm -rf dump

rm -rf temp

rm -rf ttt

fi
