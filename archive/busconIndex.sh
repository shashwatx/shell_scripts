#!/usr/bin/env bash

helpMessage="
============================================================================================
busconIndex v1.0
============================================================================================
Given the path to a directory containing binaries to index, this script attempts to
execute all required steps and send the generated info to a solr collection.
Date:           Oct, 21st, 2017
Author:         Shashwat Mishra
Affiliation:    GrupoICA, AEAT Spain
============================================================================================
"
usageMessage="
======================================================================================================
Usage:

    ./busconIndex [OPTIONS] <input>

where:

    <input> Absolute path to the directory containing the binaries to index.

    [OPTIONS]

        [MANDATORY]
            -c Full path to configuration file.
            -e Environment (one of DES, PRE, or PRO).
            -i Execution string (Ex. execution_00001).
            -m Full path to metadata file.
            -n Number of retries.
            -t1 Timeout for MR1 (in seconds).
            -t2 Timeout for MR2 (in seconds).

        [OPTIONAL]
            -q Run in silent mode.
            -o Order binaries within a tar in ascending order of size.
            -p Purge data uploaded to HDFS after execution terminates.
            -df Disable fail in PolicyManager.
======================================================================================================
"
exec 3>&1
set -o pipefail
set -e
getScreenWideSeparator(){
    separatorStages="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    separatorSteps="----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
    separatorSubSteps="......................................................................................................................................................................................................................................."
}
initColors(){
    # Bold colors
    red=$'\e[1;31m'
    grn=$'\e[1;32m'
    yel=$'\e[1;33m'
    blue=$'\e[1;34m'
    mag=$'\e[1;35m'
    cyn=$'\e[1;36m'
    end=$'\e[0m'

    # Dim colors
    grnDim=$'\e[5;32m'
    yelDim=$'\e[5;33m'
    bluDim=$'\e[5;34m'
    redDim=$'\e[5;31m'
    # Underlined colors
    grnUl=$'\e[5;32m'
}
getProperty(){
    val0=$(cat ${configFile} | grep -v "^#" | grep "${1}=" | cut -d'=' -f2- | cut -d'"' -f2)
    echo "${val0}"
}
log(){
    echo "${yelDim}[$(date)]:${end} $*"
    #printf ""
}
runStringAsStep(){
    log "Executing: ${grnDim}$*${end}"
    if [[ "${flagSilent}" -eq 1 ]]; then
        eval $* > /dev/null 2>&1
    else
        eval $*
    fi
}
runStringAsStep_2(){
    log "Executing (NoTrap): ${grnDim}$*${end}"
    unsetTrap
    if [[ "${flagSilent}" -eq 1 ]]; then
        eval $* > /dev/null 2>&1
    else
        eval $*
    fi
    setTrap
}
runStringAsStep_3(){
    log "Executing (Background): ${grnDim}$*${end}"
    unsetTrap
    eval $* > /dev/null 2>&1 &
    setTrap
}
runStringAsStep_2S(){
    unsetTrap
    if [[ "${flagSilent}" -eq 1 ]]; then
        eval $* > /dev/null 2>&1
    else
        eval $*
    fi
    setTrap
}
separateSteps(){
    echo "${grn}$*${end}"
}
separateSubSteps(){
    echo "${cyn}$*${end}"
}
separateStages(){
    echo "${mag}$*${end}"
    echo "${mag}$*${end}"
}
logInfo(){
    echo "${yelDim}[$(date)]:${end} ${bluDim}$@ ${end}"
    #printf ""
}
logWarn(){
    echo "${yelDim}[$(date)]:${end} ${red}$* ${end}"
}
logImp(){
    echo "${yelDim}[$(date)]:${end} ${redDim}$* ${end}"
    #printf ""
}
writeToReport2(){
    echo "$*" >> ${pathToSummarizedReport2}
}
checkParams() {
    if [[ "$#" -lt 1 ]]; then
        echo -e "${usageMessage}"
        echo
        exit 1
    fi
}
errMsg() {
    echo -e "${usageMessage}"
    echo "${red}${errorMsg}: ${1}${end}"
    echo
    exit 1
}
helpMsg() {
    echo -e "${helpMessage}"
    echo -e "${usageMessage}"
    echo
    exit 0
}


init(){
    STARTTIME=$(date +%s)

    flagDoNotDeleteSolrDocs=0
    didWeLaunchWrite1=0
    configSet=0
    envSet=0
    idSet=0
    timeoutMR1Set=0
    timeoutMR2Set=0
    flagSilent=0
    flagPurge=0
    flagOrder=0
    flagDisableFail=0
    numRetries=0
    numRetriesSet=0
    set +e
    while [ $# -gt 0 ]
    do         # get parameters
        case "$1" in
            -h) # help
                helpMsg
                ;;
            -q) # silent mode
                flagSilent=1
                ;;
            -o) # order binaries within tar
                flagOrder=1
                ;;
            -df) # disable fail
                flagDisableFail=1
                ;;
            -p) # purge hdfs after execution
                flagPurge=1
                ;;
            -c) # configuration file
                shift # to get the next parameter
                configFile="${1}"
                configSet=1
                ;;
            -m) # metadata file
                shift # to get the next parameter
                metadataFile="$1"
                metadataSet=1
                ;;
            -n) # number of retries
                shift # to get the next parameter
                errorMsg="ERROR"
                numRetries=`expr "${1}" : '\(0\|1\)'`
                [ "${numRetries}" = "" ] && errMsg "Number of retries (${1}) should be either 0 or 1."
                numRetriesSet=1
                ;;
            -e) # environment
                shift # to get the next parameter
                errorMsg="ERROR"
                ENV=`expr "${1}" : '\(DES\|PRE\|PRO\)'`
                [ "${ENV}" = "" ] && errMsg "Environment (${1}) is not known."
                envSet=1
                ;;
            -i) # execution string
                shift # to get the next parameter
                errorMsg="ERROR"
                executionString=`expr "${1}" : '\(execution_[0-9]*\)'`
                [ "${executionString}" = "" ] && errMsg "Execution string (${1}) is not properly formatted."
                idSet=1
                ;;
            -t1) # Timeout for MR1
                shift
                timeoutMR1=$(expr "${1}" : '\([0-9]*\)')
                errorMsg="ERROR"
                [ "${timeoutMR1}" = "" ] && errMsg "--- TIMEOUT MR1 (${1}) MUST BE A POSITIVE INTEGER ---"
                timeoutMR1Set=1
                ;;
            -t2) # Timeout for MR2
                shift
                timeoutMR2=$(expr "${1}" : '\([0-9]*\)')
                errorMsg="ERROR"
                [ "${timeoutMR2}" = "" ] && errMsg "--- TIMEOUT MR2 (${1}) MUST BE A POSITIVE INTEGER ---"
                timeoutMR2Set=1
                ;;
            -skipdelete) # does not delete generated solr docs
                flagDoNotDeleteSolrDocs=1
                ;;
            -*) # any other - argument
                errorMsg="ERROR"
                errMsg "Option (${1}) is not recognized."
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
    if [[ ${configSet} -ne 1 ]]; then
        errorMsg="ERROR"
        errMsg "You did not specify configuration file."
    fi

    if [[ ${envSet} -ne 1 ]]; then
        errorMsg="ERROR"
        errMsg "You did not specify environment."
    fi

    if [[ ${metadataSet} -ne 1 ]]; then
        errorMsg="ERROR"
        errMsg "You did not specify a metadata file."
    fi
    if [[ ${idSet} -ne 1 ]]; then
        errorMsg="ERROR"
        errMsg "You did not specify execution string."
    fi

    if [[ ${timeoutMR1Set} -ne 1 ]]; then
        errorMsg="ERROR"
        errMsg "You did not specify MR1 timeout."
    fi
    if [[ ${timeoutMR2Set} -ne 1 ]]; then
        errorMsg="ERROR"
        errMsg "You did not specify MR2 timeout."
    fi
    if [[ ${numRetriesSet} -ne 1 ]]; then
        errorMsg="ERROR"
        errMsg "You did not specify number of retries."
    fi

    if [[ "$#" -lt 1 ]]; then
        errorMsg="ERROR"
        errMsg "Did you forget to specify input?"
    fi

    data=${1}

    #####################################################################################################################################
    #####################################################################################################################################
    #####################################################################################################################################
    ############################################ PARSE PROPERTIES FILE TO GET PARAMETER VALUES ##########################################
    #####################################################################################################################################
    #####################################################################################################################################
    #####################################################################################################################################
    synchronizedLogs=$(getProperty 'bigbuscon.user.paths.synchronizedLogs.'${ENV})
    containerMemory=$(getProperty 'bigbuscon.mapreduce.memory.'${ENV})
    containerCores=$(getProperty 'bigbuscon.mapreduce.cores.'${ENV})
    containerFailure=$(getProperty 'bigbuscon.mapreduce.failure.'${ENV})
    containerIdleTimeout=$(getProperty 'bigbuscon.mapreduce.container.idletimeout.'${ENV})
    sqlDriver=$(getProperty 'bigbuscon.mysql.driver.'${ENV})
    sqlUser=$(getProperty 'bigbuscon.mysql.user.'${ENV})
    sqlPassword=$(getProperty 'bigbuscon.mysql.pwd.'${ENV})
    sqlURL=$(getProperty 'bigbuscon.mysql.url.'${ENV})
    sqlTable=$(getProperty 'bigbuscon.mysql.table.'${ENV})
    solrCollection=$(getProperty 'bigbuscon.solr.collection.'${ENV})
    solrBagSize=$(getProperty 'bigbuscon.solr.bag.size.'${ENV})
    solrAuthFile=$(getProperty 'bigbuscon.user.solr.jaasFile.'${ENV})

    solrShootBlanks=$(getProperty 'bigbuscon.solr.shootBlanks.'${ENV})
    solrShootBlanksString=""
    if [[ ${solrShootBlanks} == "true" ]]; then
        solrShootBlanksString="-s"
    fi
    solrWaitSearch=$(getProperty 'bigbuscon.solr.waitSearch.'${ENV})
    solrWaitSearchString=""
    if [[ ${solrWaitSearch} == "true" ]]; then
        solrWaitSearchString="-ws"
    fi

    solrSoftCommit=$(getProperty 'bigbuscon.solr.softCommit.'${ENV})
    solrSoftCommitString=""
    if [[ ${solrSoftCommit} == "true" ]]; then
        solrSoftCommitString="-sf"
    fi

    flagOrderString=""
    if [[ "${flagOrder}" -eq 1 ]]; then
        flagOrderString="-r"
    fi
    disableFailString=""
    if [[ "${flagDisableFail}" -eq 1 ]]; then
        disableFailString="-df"
    fi
    solrWriteDelay=$(getProperty 'bigbuscon.solr.writeDelay.'${ENV})

    numMappers=$(getProperty 'bigbuscon.mapreduce.numMappers.'${ENV})
    sizeFilter=$(getProperty 'bigbuscon.discard.size.'${ENV})
    timeoutTesseract=$(getProperty 'bigbuscon.tesseract.timeout.'${ENV})

    aspellV=$(getProperty 'bigbuscon.aspell.valido.'${ENV})
    aspellG=$(getProperty 'bigbuscon.aspell.global.'${ENV})
    pdfTrimParam=$(getProperty 'bigbuscon.pdf.trim.'${ENV})
    pdfDiscardLimit=$(getProperty 'bigbuscon.pdf.discard.'${ENV})
    rotationParam=$(getProperty 'bigbuscon.rotation.'${ENV})
    javaSeven=$(getProperty 'bigbuscon.java.javaPath.'${ENV})
    stateInProcess=$(getProperty 'bigbuscon.statecodes.inProcess.'${ENV})
    stateProcessed=$(getProperty 'bigbuscon.statecodes.processed.'${ENV})
    stateFailed=$(getProperty 'bigbuscon.statecodes.failed.'${ENV})
    statePartProcessed=$(getProperty 'bigbuscon.statecodes.partProcessed.'${ENV})
    stateDeleted=$(getProperty 'bigbuscon.statecodes.deleted.'${ENV})
    userName=$(getProperty 'bigbuscon.user.'${ENV})

    zookeeperHost=$(getProperty 'bigbuscon.solr.zkp.'${ENV})

    logConfig=$(getProperty 'bigbuscon.config.logConfig.'${ENV})
    bigbusconKey=$(getProperty 'bigbuscon.config.key.'${ENV})

    jarLight=$(getProperty 'bigbuscon.user.jars.jarLight.'${ENV})
    jarFat=$(getProperty 'bigbuscon.user.jars.jarFat.'${ENV})
    jarFatSQL=$(getProperty 'bigbuscon.user.jars.jarFatSQL.'${ENV})

    pathExecutions=$(getProperty 'bigbuscon.user.paths.pathExecutions.'${ENV})
    pathHelpers=$(getProperty 'bigbuscon.user.paths.helperScripts.'${ENV})
    pathFireScripts=$(getProperty 'bigbuscon.user.paths.fireScripts.'${ENV})


    libFiles=$(getProperty 'bigbuscon.user.paths.libFiles.'${ENV})
    libJars=$(getProperty 'bigbuscon.user.paths.libJars.'${ENV})
    globalTmp=$(getProperty 'bigbuscon.mapreduce.containers.tmp.'${ENV})
    #####################################################################################################################################
    #####################################################################################################################################
    #####################################################################################################################################
    #####################################################################################################################################
    #####################################################################################################################################
    #####################################################################################################################################

    #######################
    ### EXECUTION-INDEX ###
    #######################
    #set +e
    #lastExecutionIndexT=$(ls -1d ${pathExecutions}/execution_* | rev | cut -d'/' -f1 | rev | tr -dc '[0-9\n]' | sort -k 1,1n | tail -1)
    #set -e
    #lastExecutionIndex=$((10#${lastExecutionIndexT}+0))
    #currentExecutionIndex=$((lastExecutionIndex+1))
    #executionString=`printf "%s_%05d" "execution" ${currentExecutionIndex}`
    #log "Execution ${currentExecutionIndex}"
    ###################################
    ### EXECUTION-SPECIFIC-LFS-HOME ###
    ###################################
    lfsExecutionHome=${pathExecutions}/${executionString}
    log "Execution-home LFS: ${lfsExecutionHome}"
    mkdir -p ${lfsExecutionHome}
    ###################################
    ### EXECUTION-SPECIFIC-HDFS-HOME ##
    ###################################
    hdfsUserHome="/user/${userName}"
    hdfsBusconHome="${hdfsUserHome}/bigbuscon"
    hdfsExecutionsHome="${hdfsBusconHome}/executions"
    hdfsExecutionHome=${hdfsExecutionsHome}/${executionString}
    log "Execution-home HDFS: ${hdfsExecutionHome}"

    set +e
    hdfs dfs -test -d ${hdfsExecutionHome}
    if [[ $? -eq 0 ]]; then
        logImp "HDFS directory exists: ${hdfsExecutionHome}"
        logImp "Deleting HDFS directory."
        hadoop fs -rm -r ${hdfsExecutionHome} > /dev/null 2>&1
    fi

    set -e
    logInfo "Creating HDFS directory."
    hadoop fs -mkdir -p ${hdfsExecutionHome}
    logInfo "HDFS directory created."
    ############################################
    ### EXECUTION-SPECIFIC JOBNAMES PREFIX #####
    ############################################
    namePrefix="${bigbusconKey}_${executionString}"
    #########################################
    ## EXECUTION-SPECIFIC-PARTITION-OUTPUT ##
    #########################################
    pathToPDFGroups="${lfsExecutionHome}/pdf.groups"
    ######################################
    #### EXECUTION-SPECIFIC-MR-INPUTS ####
    ######################################
    pathToInputDataForUnpacker="${hdfsExecutionHome}/bigbuscon.docs.in.unpacker"
    pathToInputDataForExtractorLight1="${hdfsExecutionHome}/bigbuscon.docs.in.extractorLight1"
    pathToInputDataForSplitter="${hdfsExecutionHome}/bigbuscon.docs.in.splitter"
    pathToInputDataForExtractorLight2="${hdfsExecutionHome}/bigbuscon.docs.in.extractorLight2"
    ######################################
    #### EXECUTION-SPECIFIC-MR-OUTPUTS ###
    ######################################
    pathToOutputDataForUnpacker="${hdfsExecutionHome}/bigbuscon.docs.out.unpacker"
    pathToOutputDataForExtractorLight1="${hdfsExecutionHome}/bigbuscon.docs.out.extractorLight1"
    pathToOutputDataForSplitter="${hdfsExecutionHome}/bigbuscon.docs.out.splitter"
    pathToOutputDataForExtractorLight2="${hdfsExecutionHome}/bigbuscon.docs.out.extractorLight2"
    ######################################
    #### EXECUTION-SPECIFIC-LOCAL-FILES ##
    ######################################
    stateFileFailed="${lfsExecutionHome}/state.failed"
    stateFileFailedT="${lfsExecutionHome}/state.failed.t"
    stateFileProcessed="${lfsExecutionHome}/state.processed"
    stateFilePartProcessed="${lfsExecutionHome}/state.partProcessed"
    errorMessageMap="${lfsExecutionHome}/errorMessageMap"
    rm -rf ${errorMessageMap}
    touch ${stateFileFailed} ${stateFileProcessed} ${stateFilePartProcessed} ${stateFileFailedT} ${errorMessageMap}
    failedEL1="${lfsExecutionHome}/list.el1_failed"
    failedSplitter="${lfsExecutionHome}/list.splitter_failed"
    failedEL2="${lfsExecutionHome}/list.el2_failed"
    touch ${failedEL1} ${failedEL2} ${failedSplitter}
    fileContainingSolrDocsGeneratedByExtractorLight2="${lfsExecutionHome}/solrdocs.el2_processed"
    fileContainingSolrDocsGeneratedByExtractorLight2_T="${lfsExecutionHome}/solrdocs.el2_processed_T"
    fileContainingSolrDocsGeneratedByExtractorLight1="${lfsExecutionHome}/solrdocs.el1_processed"
    touch ${fileContainingSolrDocsGeneratedByExtractorLight1} ${fileContainingSolrDocsGeneratedByExtractorLight2} ${fileContainingSolrDocsGeneratedByExtractorLight2_T}

    fileContainingLargePDFsFoundByExtractorLight1="${lfsExecutionHome}/list.el1_skippedpdfs"
    touch ${fileContainingLargePDFsFoundByExtractorLight1}

    SplitDecodeFailFile="${lfsExecutionHome}/SplitDecodeFailFile"
    rm -rf ${SplitDecodeFailFile}
    touch ${SplitDecodeFailFile}
    UnzipDecodeFailFile="${lfsExecutionHome}/UnzipDecodeFailFile"
    rm -rf ${UnzipDecodeFailFile}
    touch ${UnzipDecodeFailFile}
    tmpFile="${lfsExecutionHome}/temp"
    rm -rf ${tmpFile}
    touch ${tmpFile}

    OAF="${lfsExecutionHome}/solrdocs.el2_atomic"
    rm -rf ${OAF}
    touch ${OAF}
    OCSAF="${lfsExecutionHome}/solrdocs.el2_ocsaf"
    rm -rf ${OCSAF}
    touch ${OCSAF}
    inputDocs="${lfsExecutionHome}/temp.input"
    rm -rf ${inputDocs}
    touch ${inputDocs}

    inputDocsMR1="${lfsExecutionHome}/temp.input.mr1"
    rm -rf ${inputDocsMR1}
    touch ${inputDocsMR1}
    OPSAF="${lfsExecutionHome}/solrdocs.el2_opsaf"
    rm -rf ${OPSAF}
    touch ${OPSAF}

    OPSAFL="${lfsExecutionHome}/list.el2_opsaf"
    rm -rf ${OPSAFL}
    touch ${OPSAFL}
    splittedPDFs="${lfsExecutionHome}/docs.splitter_processed"

    sWrite2OF="${lfsExecutionHome}/sWrite2OF"
    sWrite2OP="${lfsExecutionHome}/sWrite2OP"
    sWrite1OF="${lfsExecutionHome}/sWrite1OF"
    sWrite1OP="${lfsExecutionHome}/sWrite1OP"
    rm -rf ${sWrite2OF} ${sWrite2OP} ${sWrite1OF} ${sWrite1OP}
    touch ${sWrite2OF} ${sWrite2OP} ${sWrite1OF} ${sWrite1OP}
    synchronizedLogsHome=${synchronizedLogs}/${executionString}
    mkdir -p ${synchronizedLogsHome}
    pathToSummarizedReport2=${synchronizedLogsHome}/summarizedReport2.csv
    touch ${pathToSummarizedReport2}
    errorMessageLog=${synchronizedLogsHome}/errorMessage.log
    touch ${errorMessageLog}

    logInfo "Init call finished."
}
pause() {
    echo
    read -u 0 -p "Press Enter key to continue..."
}
askYesNo() {
    echo -n "${red}$1${end} (y/n) "
    while read -r -n 1 -s answer; do
        if [[ ${answer} = [YyNn] ]]; then
            [[ ${answer} = [Yy] ]] && response=1
            [[ ${answer} = [Nn] ]] && response=0
            break
        fi
    done
    echo
    echo
}
showStats(){
    logInfo "Generating stats."
    numD=$(wc -l ${filesToDelete} | cut -d' ' -f1)
    numP=$(wc -l ${filesToProcess} | cut -d' ' -f1)
    numT=$(bc -l <<< ${numD}+${numP})
    numPrd=$(wc -l ${stateFileProcessed} | cut -d' ' -f1)
    numPtPrd=$(wc -l ${stateFilePartProcessed} | cut -d' ' -f1)
    numFd=$(wc -l ${stateFileFailed} | cut -d' ' -f1)
    logImp "Total: ${numT}"
    logImp " - Deleted: ${numD}"
    logImp " - Attempted: ${numP}"
    logImp " * Failed: ${numFd}"
    logImp " * Part-Processed: ${numPtPrd}"
    logImp " * Processed: ${numPrd}"
}
updateMySQL(){
    runStringAsStep "${javaSeven} -cp ${jarFatSQL} es.aeat.taiif.midas.bigbuscon.sql.operations.UpdateFinalState -l ${logConfig} -s ${stateProcessed} -i ${stateFileProcessed} -t \"${sqlTable}\" -d \"${sqlDriver}\" -u ${sqlUser} -p \"${sqlPassword}\" -r \"${sqlURL}\"" # state code 2
    runStringAsStep "${javaSeven} -cp ${jarFatSQL} es.aeat.taiif.midas.bigbuscon.sql.operations.UpdateFinalState -l ${logConfig} -s ${stateFailed} -i ${stateFileFailed} -t \"${sqlTable}\" -d \"${sqlDriver}\" -u ${sqlUser} -p \"${sqlPassword}\" -r \"${sqlURL}\"" # state code 3
    runStringAsStep "${javaSeven} -cp ${jarFatSQL} es.aeat.taiif.midas.bigbuscon.sql.operations.UpdateFinalState -l ${logConfig} -s ${statePartProcessed} -i ${stateFilePartProcessed} -t \"${sqlTable}\" -d \"${sqlDriver}\" -u ${sqlUser} -p \"${sqlPassword}\" -r \"${sqlURL}\"" # state code 4
    runStringAsStep "${javaSeven} -cp ${jarFatSQL} es.aeat.taiif.midas.bigbuscon.sql.operations.UpdateFinalState -l ${logConfig} -s ${stateDeleted} -i ${filesToDelete} -t \"${sqlTable}\" -d \"${sqlDriver}\" -u ${sqlUser} -p \"${sqlPassword}\" -r \"${sqlURL}\"" # state code 5
    logInfo "Setting error messages."
    # For all failures (state code 3), add the error message (if any) to the corresponding record in mysql.
    runStringAsStep_2 "${javaSeven} -cp ${jarFatSQL} es.aeat.taiif.midas.bigbuscon.sql.operations.UpdateErrorMessage -l ${logConfig} -i ${stateFileFailed} -e ${errorMessageMap} -t \"${sqlTable}\" -d \"${sqlDriver}\" -u ${sqlUser} -p \"${sqlPassword}\" -r \"${sqlURL}\" > ${errorMessageLog}" # state code 3
}
cleanExecutionTMP(){
    # Change permissions to make everything writable.
    runStringAsStep_2S "hadoop org.apache.hadoop.yarn.applications.distributedshell.Client -jar ${jarLight} -shell_command \"find ${globalTmp}/${executionString} -maxdepth 1 -user ${userName} -exec chmod -R +rw {} \\; \" -num_containers 16"
    # Delete all files in tmp dir for the user
    runStringAsStep_2S "hadoop org.apache.hadoop.yarn.applications.distributedshell.Client -jar ${jarLight} -shell_command \"find ${globalTmp}/${executionString} -maxdepth 1 -user ${userName} -exec rm -rf {} \\; \" -num_containers 16"
}
end(){
    ENDTIME=$(date +%s)
    SPENTTIME=$(((ENDTIME-STARTTIME)));
}
deleteTempFiles(){
    logInfo "Deleting temporary files."
    runStringAsStep "rm -rf ${tmpFile} ${splittedPDFs} ${stateFileFailedT} ${inputDocs} ${inputDocsMR1}"
    runStringAsStep "rm -rf ${fileContainingSolrDocsGeneratedByExtractorLight1}"
    runStringAsStep "rm -rf ${fileContainingSolrDocsGeneratedByExtractorLight1}.*"
    runStringAsStep "rm -rf ${fileContainingSolrDocsGeneratedByExtractorLight2} ${fileContainingSolrDocsGeneratedByExtractorLight2_T} "
    runStringAsStep "rm -rf ${OAF} ${OCSAF} ${OPSAF}"
    if [[ "${flagPurge}" -eq 1 ]]; then
        runStringAsStep_2 "hadoop fs -rm -r ${pathToInputDataForUnpacker} ${pathToInputDataForExtractorLight1} ${pathToInputDataForSplitter} ${pathToInputDataForExtractorLight2}"
    fi
}
unsetTrap(){
    trap '' ERR TERM
    set +eE
}
setTrap(){
    trap 'cleanUP' ERR TERM
    set -eE
}
postProcessWrite1_part1(){
    runStringAsStep "cat ${sWrite1OP}.* > ${sWrite1OP}"
    runStringAsStep "cat ${sWrite1OF}.* > ${sWrite1OF}"
    numSolrDocsMDFailed=$(wc -l ${sWrite1OF} | cut -d' ' -f1)
    numSolrDocsMDProcessed=$(wc -l ${sWrite1OP} | cut -d' ' -f1)
    logInfo "#Solrdocs that I wrote to Solr: ${numSolrDocsMDProcessed}"
    logImp "#Solrdocs I could not write because there was no associated metadata: ${numSolrDocsMDFailed}"
}
postProcessWrite1_part2(){
    # Failure type 1: Binaries that were scheduled on containers that crashed
    logInfo "MR1 - Failure Type 1: Binaries that were scheduled on containers that crashed."
    fileContainingEmptyContentDocsByExtractorLight1="${lfsExecutionHome}/list.el1_emptyDocs"
    runStringAsStep "cat ${inputDocsMR1} | sort > ${tmpFile}"
    runStringAsStep "cat ${tmpFile} > ${inputDocsMR1}"
    runStringAsStep "cat ${fileContainingDocsEncounteredByExtractorLight1} | sort > ${tmpFile}"
    runStringAsStep "cat ${tmpFile} > ${fileContainingDocsEncounteredByExtractorLight1}"
    runStringAsStep "comm -23 ${inputDocsMR1} ${fileContainingDocsEncounteredByExtractorLight1} > ${failedEL1}"
    numFilesFailedEL1=$(wc -l ${failedEL1} | cut -d' ' -f1)
    logInfo "Number of Failures: ${numFilesFailedEL1}"
    runStringAsStep "cat ${failedEL1} | xargs -I {} echo {}\"#####Failed in MR1: Container Crash\" >> ${errorMessageMap}"

    separateSubSteps "${separatorSubSteps}"
    # Failure type 2: Binaries that resulted in an error in BlackBox or resulted in empty content.
    logInfo "MR1 - Failure Type 2: Binaries that resulted in an error in BlackBox or resulted in empty content."
    runStringAsStep_2 "hadoop fs -cat ${pathToOutputDataForExtractorLight1}/failed-m* > ${fileContainingEmptyContentDocsByExtractorLight1}"
    runStringAsStep "cat ${fileContainingEmptyContentDocsByExtractorLight1} >> ${failedEL1}"
    numFilesFailedEL1EC=$(wc -l ${fileContainingEmptyContentDocsByExtractorLight1} | cut -d' ' -f1)
    logInfo "Number of Failures: ${numFilesFailedEL1EC}"
    runStringAsStep_2 "hadoop fs -cat ${pathToOutputDataForExtractorLight1}/errorMessage-m* >> ${errorMessageMap}"
    separateSubSteps "${separatorSubSteps}"
    # Failure type 3: Binaries with no associated metadata.
    logInfo "MR1 - Failure Type 3: Binaries that failed while writing to Solr."
    runStringAsStep "cat ${sWrite1OF} >> ${failedEL1}"
    logInfo "Number of Failures: ${numSolrDocsMDFailed}"
    runStringAsStep "cat ${sWrite1OF} | xargs -I {} echo {}\"#####Failed in MR1: Could not write to Solr.\" >> ${errorMessageMap}"
    separateSubSteps "${separatorSubSteps}"
    # Failure type 4: Binaries that could not be manifested after Unzip.
    logInfo "MR1 - Failure Type 4: Binaries that could not be manifested after unzip."
    runStringAsStep "cat ${UnzipDecodeFailFile} >> ${failedEL1}"
    numUnzipDecodeFailed=$(wc -l ${UnzipDecodeFailFile} | cut -d' ' -f1)
    logInfo "Number of Failures: ${numUnzipDecodeFailed}"
    runStringAsStep "cat ${UnzipDecodeFailFile} | xargs -I {} echo {}\"#####Failed in Unzip: Could not materialize after Unzip.\" >> ${errorMessageMap}"
    separateSubSteps "${separatorSubSteps}"
    # And we are done!
    numFilesFailedEL1=$(wc -l ${failedEL1} | cut -d' ' -f1)
    logImp "Total Number of Failures in MR1: ${numFilesFailedEL1}"
    writeToReport2 "MR1: Number of binaries failed in MR1, ${numFilesFailedEL1}"
    numFilesActuallyProcessed=$(((numFilesEnteringMR1-numFilesFailedEL1-numSkippedEL1)))
    writeToReport2 "MR1: Number of binaries I actually processed in MR1, ${numFilesActuallyProcessed}"
}
cleanUP(){
    exec 1>&3

    separateStages "${separatorStages}"

    logWarn "Critical Failure. Cleaning up."

    set +e

    # delete data directory
    logInfo "Delete data directory: ${data}"
    runStringAsStep "rm -rf ${data}"

    if [[ ${didWeLaunchWrite1} -eq 0 ]]; then

        # In this case, no background processes are running because
        # no background processes were launched yet.
        #
        # Thus, all input ordens are failed ordens.
        logWarn "Early Failure: We hadn't launched any background processes."
        logInfo "All files to process are failed files."

        # delete temp files
        deleteTempFiles

        runStringAsStep "cat ${filesToProcess} > ${stateFileFailed}"
    else
        # In this case, some background processes may still be running.
        # We must wait for all background processes to finish.
        #
        # Failed ordens are
        # (a) All failures of MR1 and
        # (b) All skipped by MR1
        logWarn "Late Failure: We launched some background processes."
        logInfo "I will wait for background processes to finish."
        wait
        logInfo "All background processes have finished."
        logInfo "I will run postProcessWrite1_part1."
        postProcessWrite1_part1
        logInfo "I will run postProcessWrite1_part2."
        postProcessWrite1_part2

        logImp "I have finished all post processing steps for MR1."
        logInfo "Failed ordens are (a) All failures of MR1 (b) All skipped by MR1."
        runStringAsStep "cat ${failedEL1} > ${stateFileFailedT}"
        runStringAsStep "cat ${fileContainingLargePDFsFoundByExtractorLight1} | sed -e 's/\(.*\) [1-9][0-9]*/\1/' > ${tmpFile}"
        runStringAsStep "cat ${tmpFile} >> ${stateFileFailedT}"
        runStringAsStep "${javaSeven} -cp ${jarFat} es.aeat.taiif.midas.bigbuscon.operations.StateFileCalculator -l ${logConfig} -ifd ${stateFileFailedT} -ipr ${filesToProcess} -ipt ${OPSAFL} -ofd ${stateFileFailed} -opr ${stateFileProcessed} -opt ${stateFilePartProcessed}"

        # delete temp files
        deleteTempFiles

    fi

    # update state in MySQL
    logInfo "Update state in MySQL."
    updateMySQL


    #########################################################################################################################
    #########################################################################################################################
    separateStages "${separatorStages}"
    #########################################################################################################################
    #########################################################################################################################
    showStats

end
logWarn "Execution time: ${SPENTTIME} seconds."
logWarn "FAILURE."

exit 1
}

info(){
    formatConfig1="%-35s\t%-35s\n"
    formatConfig2="%-35s\t%-35d\n"
    sep="========================================================================================================================================================================================="
    sep2="----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
    echo
    echo ${sep}
    printf "${formatConfig1}" "Execution" ${executionString}
    printf "${formatConfig1}" "Input" ${data}
    echo ${sep2}
    printf "${formatConfig1}" "Flag: Order Tar" ${flagOrder}
    printf "${formatConfig1}" "Flag: Purge HDFS" ${flagPurge}
    printf "${formatConfig1}" "Flag: Disable Fail" ${flagDisableFail}
    echo ${sep2}
    printf "${formatConfig2}" "Timeout: MR1" ${timeoutMR1}
    printf "${formatConfig2}" "Timeout: MR2" ${timeoutMR2}
    printf "${formatConfig2}" "Timeout: Tesseract" ${timeoutTesseract}
    printf "${formatConfig2}" "Timeout: Idle Container" ${containerIdleTimeout}
    echo ${sep2}
    printf "${formatConfig2}" "Parameter: Num Retries" ${numRetries}
    printf "${formatConfig2}" "Parameter: PDF Trim" ${pdfTrimParam}
    printf "${formatConfig2}" "Parameter: Solr Bag" ${solrBagSize}
    printf "${formatConfig2}" "Parameter: Num Mappers" ${numMappers}
    printf "${formatConfig2}" "Threshold: Aspell Valido" ${aspellV}
    printf "${formatConfig2}" "Threshold: Aspell Global" ${aspellG}
    printf "${formatConfig2}" "Threshold: Skew Correction" ${rotationParam}
    printf "${formatConfig2}" "Threshold: PDF Discard" ${pdfDiscardLimit}
    echo ${sep2}
    printf "${formatConfig1}" "Solr: ZookeeperHosts" "${zookeeperHost}"
    printf "${formatConfig1}" "Solr: Collection" ${solrCollection}
    printf "${formatConfig1}" "Solr: SoftCommit" ${solrSoftCommit}
    printf "${formatConfig1}" "Solr: WaitSearch" ${solrWaitSearch}
    printf "${formatConfig1}" "Solr: ShootBlanks" ${solrShootBlanks}
    printf "${formatConfig1}" "Solr: KerberosCredentials" ${solrAuthFile}
    echo ${sep2}
    printf "${formatConfig1}" "Path HelperScripts" ${pathHelpers}
    printf "${formatConfig1}" "Path FireScripts" ${pathFireScripts}
    printf "${formatConfig1}" "Path Executions" ${pathExecutions}
    echo ${sep2}
    printf "${formatConfig1}" "Jar: Main" ${jarFat}
    printf "${formatConfig1}" "Jar: SQL" ${jarFatSQL}
    echo ${sep2}
    printf "${formatConfig1}" "SQL: User" ${sqlUser}
    #printf "${formatConfig1}" "SQL: PWD" "${sqlPassword}"
    printf "${formatConfig1}" "SQL: URL" "${sqlURL}"
    printf "${formatConfig1}" "SQL: Table" "${sqlTable}"
    printf "${formatConfig1}" "SQL: Driver" "${sqlDriver}"
    echo ${sep2}
    printf "${formatConfig1}" "Log4J conf" ${logConfig}
    echo ${sep}
    echo
}
getScreenWideSeparator
initColors
checkParams $*
init $*
info

response=1
#askYesNo "Do you want to launch the pipeline?"
trap 'cleanUP' ERR TERM
trap 'cleanExecutionTMP' EXIT
set -eE
logInfo "Trap set."
logInfo "Commencing execution."
if [[ ${response} -eq 1 ]]; then

    separateStages "${separatorStages}"

    logImp "Stage 0: Filter."
    # =================================================
    # Step 0.1: Generating list of files to be deleted.
    # =================================================
    filesToDelete="${lfsExecutionHome}/list.data_deleted"
    sizeFilterComplement=`echo ${sizeFilter} | tr '-' '+'`
    logInfo "Step 0.1: Generating list of all binaries larger than the specified size ${sizeFilterComplement}."
    runStringAsStep "find ${data} -maxdepth 1 -type f -size ${sizeFilterComplement} | rev | cut -d'/' -f1 | rev > ${filesToDelete}"
    numFilesFoundToDelete=$(wc -l ${filesToDelete} | cut -d' ' -f1)
    logImp "Number of binaries that will be deleted: ${numFilesFoundToDelete}"
    logInfo "Step 0.1: Done"
    runStringAsStep_2S "find ${data} -maxdepth 1 -type f > ${tmpFile}"
    numFilesEnteredProcess=$(wc -l ${tmpFile} | cut -d' ' -f1)

    separateSteps "${separatorSteps}"

    # ===========================================
    # Step 0.2: Discarding all files to be deleted.
    # ===========================================
    logInfo "Step 0.2: Discarding all binaries larger than the specified size."
    runStringAsStep "find ${data} -maxdepth 1 -type f -size ${sizeFilterComplement} -exec rm -rf {} \;"
    logInfo "Step 0.2: Done"
    separateSteps "${separatorSteps}"

    # =====================================================
    # Step 0.3: Generating list of all files to be indexed.
    # =====================================================
    logInfo "Step 0.3: Generating list of all binaries less than or equal to the specified size."
    filesToProcess="${lfsExecutionHome}/list.data_toProcess"
    runStringAsStep "find ${data} -maxdepth 1 -type f | rev | cut -d'/' -f1 | rev > ${filesToProcess}"
    numFilesFoundToProcess=`wc -l ${filesToProcess} | cut -d' ' -f1`
    logImp "Number of binaries that I will attempt to index: ${numFilesFoundToProcess}"
    logInfo "Step 0.3: Done"

    separateSteps "${separatorSteps}"

    # =====================================================
    # Step 0.4: Update state in MySQL to inProcess.
    # =====================================================
    logInfo "Step 0.4: Updating state to En_Proceso (${stateInProcess}) in MySQL for all ordens I will attempt to Index."
    runStringAsStep "${javaSeven} -cp ${jarFatSQL} es.aeat.taiif.midas.bigbuscon.sql.operations.UpdateFinalState -l ${logConfig} -s ${stateInProcess} -i ${filesToProcess} -t \"${sqlTable}\" -d \"${sqlDriver}\" -u ${sqlUser} -p \"${sqlPassword}\" -r \"${sqlURL}\""
    logInfo "Step 0.4: Done"

    separateSteps "${separatorSteps}"
    # =====================================================
    # Step 0.5: Update mapreduce_id in MySQL.
    # =====================================================
    logInfo "Step 0.5: Updating mapreduce_id to ${executionString} in MySQL."
    runStringAsStep "${javaSeven} -cp ${jarFatSQL} es.aeat.taiif.midas.bigbuscon.sql.operations.UpdateMapReduceId -l ${logConfig} -x ${executionString} -i ${filesToProcess} -t \"${sqlTable}\" -d \"${sqlDriver}\" -u ${sqlUser} -p \"${sqlPassword}\" -r \"${sqlURL}\""
    logInfo "Step 0.5: Done"
    writeToReport2 "Filter: Number of Index Ordens Received, ${numFilesEnteredProcess}"
    writeToReport2 "Filter: Number of Index Ordens Discarded, ${numFilesFoundToDelete}"
    writeToReport2 "Filter: Number of Index Ordens Attempted, ${numFilesFoundToProcess}"

    #########################################################################################################################
    #########################################################################################################################
    separateStages "${separatorStages}"
    #########################################################################################################################
    #########################################################################################################################


    logImp "Stage 1: Unpack."
    # =============================
    # Step 1.1: Send Docs to Cluster
    # =============================
    logInfo "Step 1.1: Uploading docs to cluster."
    runStringAsStep "${pathHelpers}/docs2cluster -s -n ${numMappers} ${data} ${pathToInputDataForUnpacker}"
    logInfo "Step 1.1: Done."
    separateSteps "${separatorSteps}"
    START_TIME_UNPACK=$(date +%s)
    # ==============================
    # Step 1.2: (MR) Unpack Archives
    # ==============================
    logInfo "Step 1.2: Executing Unpacker."
    runStringAsStep "${pathFireScripts}/run_mr_light.sh ${jarFat} es.aeat.taiif.midas.bigbuscon.mapreduce.operations.UnpackArchives ${containerMemory} ${containerCores} ${containerFailure} ${containerIdleTimeout} ${libFiles} ${libJars} -l ${logConfig} -o ${pathToOutputDataForUnpacker} -i ${pathToInputDataForUnpacker} -n ${namePrefix}_Unpacker -id ${executionString}"
    logInfo "Step 1.2: Done."
    END_TIME_UNPACK=$(date +%s)
    SPENT_TIME_UNPACK=$(((END_TIME_UNPACK-START_TIME_UNPACK)));
    separateSteps "${separatorSteps}"
    # =============================================
    # Step 1.3: Copy unpacked files to this machine
    # =============================================
    directoryContainingUnpackedFiles="${lfsExecutionHome}/docs.unpacker_processed"
    logInfo "Step 1.3: Copying unpacked files to this machine."
    runStringAsStep "rm -rf ${directoryContainingUnpackedFiles}"
    runStringAsStep "mkdir -p ${directoryContainingUnpackedFiles}"
    # gather unzipped docs
    runStringAsStep_2 "hadoop fs -cat ${pathToOutputDataForUnpacker}/unzip-* > ${tmpFile}"
    runStringAsStep "${javaSeven} -Xmx16384M -cp ${jarFat} es.aeat.taiif.midas.bigbuscon.operations.DecodeBinaries -i ${tmpFile} -l ${logConfig} -o ${directoryContainingUnpackedFiles} -f ${UnzipDecodeFailFile}"
    #runStringAsStep "hadoop fs -copyToLocal ${pathToOutputDataForUnpacker}/* ${directoryContainingUnpackedFiles}"
    #runStringAsStep "rm -rf ${directoryContainingUnpackedFiles}/part-*"
    #runStringAsStep "rm -rf ${directoryContainingUnpackedFiles}/_SUCCESS"
    logInfo "Step 1.3: Done."

    separateSteps "${separatorSteps}"
    # ============================================================
    # Step 1.4: Generate list of files that were unpacked
    # ============================================================
    listOfArchives="${lfsExecutionHome}/list.unpacker_archives"
    logInfo "Step 1.4: Generating list of all archive files that were unpacked."
    # generate list
    runStringAsStep "ls -l ${directoryContainingUnpackedFiles} | tail -n +2 | rev | cut -d' ' -f1 | cut -d'_' -f4- | rev | sort | uniq > ${listOfArchives}"
    numArchiveFiles=$(wc -l ${listOfArchives} | cut -d' ' -f1)
    logImp "Number of archive-type binaries that I unpacked: ${numArchiveFiles}"
    logInfo "Step 1.4: Done."

    separateSteps "${separatorSteps}"
    # ====================================
    # Step 1.5: Delete original zip files
    # ====================================
    directoryContainingArchivesBackup="${lfsExecutionHome}/docs.unpacker_archives"
    logInfo "Step 1.5: Delete original zip files."
    runStringAsStep "mkdir ${directoryContainingArchivesBackup}"
    runStringAsStep "${pathHelpers}/moveExtractedZips ${data} ${directoryContainingArchivesBackup} ${listOfArchives}"
    runStringAsStep "rm -rf ${directoryContainingArchivesBackup}"
    logInfo "Step 1.5: Done."
    separateSteps "${separatorSteps}"
    # ===============================================
    # Step 1.6: Move unpacked files to data directory
    # ===============================================
    listOfUnpacked="${lfsExecutionHome}/list.unpacker_processed"
    logInfo "Step 1.6: Moving unpacked binaries to original data directory."
    runStringAsStep "ls -l ${directoryContainingUnpackedFiles} | tail -n +2 | rev | cut -d' ' -f1 | rev > ${listOfUnpacked}"
    numUnpackedFiles=$(wc -l ${listOfUnpacked} | cut -d' ' -f1)
    logImp "Number of new binaries produced: ${numUnpackedFiles}"
    runStringAsStep "${pathHelpers}/moveExtractedZips ${directoryContainingUnpackedFiles} ${data} ${listOfUnpacked}"
    runStringAsStep "rm -rf ${directoryContainingUnpackedFiles}"
    runStringAsStep "ls -l ${data} | tail -n +2 | rev | cut -d' ' -f1 | rev > ${tmpFile}"
    numFilesAfterUnpack=$(wc -l ${tmpFile} | cut -d' ' -f1)
    logImp "Total number of binaries after Unpacking: ${numFilesAfterUnpack}"
    logInfo "Step 1.6: Done."

    writeToReport2 "Unpack: Number of binaries entering Unpack process, ${numFilesFoundToProcess}"
    writeToReport2 "Unpack: Number of ZIP binaries found among Index Ordens, ${numArchiveFiles}"
    writeToReport2 "Unpack: Number of binaries generated by extracting ZIPs, ${numUnpackedFiles}"
    writeToReport2 "Unpack: Total number of binaries after Unpacking, ${numFilesAfterUnpack}"
    writeToReport2 "Unpack: Time spent in Unpacking, ${SPENT_TIME_UNPACK}"

    #########################################################################################################################
    #########################################################################################################################
    separateStages "${separatorStages}"
    #########################################################################################################################
    #########################################################################################################################


    logImp "Stage 2: MR1."
    # =============================
    # Step 2.1: Send Docs to Cluster
    # =============================
    logInfo "Step 2.1: Uploading docs to cluster."
    runStringAsStep "${pathHelpers}/docs2cluster ${flagOrderString} -s -n ${numMappers} ${data} ${pathToInputDataForExtractorLight1}"
    runStringAsStep "find ${data} -type f -printf \"%f\\n\" > ${inputDocs}"
    runStringAsStep "find ${data} -type f -printf \"%f\\n\" > ${inputDocsMR1}"
    numFilesEnteringMR1=$(wc -l ${inputDocs} | cut -d' ' -f1)
    logInfo "Step 2.1: Done."
    # We cannot delete the entire directory but can surely delete the files that will be successfully processed in this Stage.
    separateSteps "${separatorSteps}"
    START_TIME_MR1=$(date +%s)
    # ===================================================
    # Step 2.2: (MR) Extractor Light #1
    # ===================================================
    logInfo "Step 2.2: Run MapReduce#1"
    runStringAsStep "${pathFireScripts}/run_mr_light.sh ${jarFat} es.aeat.taiif.midas.bigbuscon.mapreduce.operations.RunMetaDataExtractionOnTar ${containerMemory} ${containerCores} ${containerFailure} ${containerIdleTimeout} ${libFiles} ${libJars} -l ${logConfig} -o ${pathToOutputDataForExtractorLight1} -i ${pathToInputDataForExtractorLight1} -id ${executionString} -t ${timeoutTesseract} -av ${aspellV} -ag ${aspellG} -nr ${numRetries} -r ${rotationParam} -n ${namePrefix}_MR1 -tc ${timeoutMR1} ${disableFailString}"
    logInfo "Step 2.2: Done."
    END_TIME_MR1=$(date +%s)
    SPENT_TIME_MR1=$(((END_TIME_MR1-START_TIME_MR1)));
    separateSteps "${separatorSteps}"

    # ==================================
    # Step 2.3: Copy data handle to edge
    # ==================================
    logInfo "Step 2.3: Copy binaries encountered by MR1 to Edge."
    fileContainingDocsEncounteredByExtractorLight1="${lfsExecutionHome}/list.el1_data"
    runStringAsStep "hadoop fs -cat ${pathToOutputDataForExtractorLight1}/data-m* > ${fileContainingDocsEncounteredByExtractorLight1}"
    numDataEL1=$(wc -l ${fileContainingDocsEncounteredByExtractorLight1} | cut -d' ' -f1)
    logImp "Number of binaries encountered by MR1: ${numDataEL1}"
    logInfo "Step 2.3: Done."
    separateSteps "${separatorSteps}"
    # ==============================
    # Step 2.4: Copy results to edge
    # ==============================
    logInfo "Step 2.4: Copy binaries processed by MR1 to Edge."
    runStringAsStep_2 "hadoop fs -cat ${pathToOutputDataForExtractorLight1}/processed-m* > ${fileContainingSolrDocsGeneratedByExtractorLight1}"
    numSolrDocsEL1=$(wc -l ${fileContainingSolrDocsGeneratedByExtractorLight1} | cut -d' ' -f1)
    logInfo "#Solrdocs prepared by MR1: ${numSolrDocsEL1}"
    logInfo "Step 2.4: Done."
    separateSteps "${separatorSteps}"
    # ===========================
    # Step 2.5: Write To Solr
    # ===========================
    logInfo "Step 2.5: Write binaries processed by MR1 to Solr."
    numLines=$(wc -l ${fileContainingSolrDocsGeneratedByExtractorLight1} | cut -d' ' -f1)
    part1Limit=$((${numLines}/2))
    part2Offset=$((${part1Limit}+1))
    runStringAsStep "head -${part1Limit} ${fileContainingSolrDocsGeneratedByExtractorLight1} > ${fileContainingSolrDocsGeneratedByExtractorLight1}.part0"
    runStringAsStep "tail -n +${part2Offset} ${fileContainingSolrDocsGeneratedByExtractorLight1} > ${fileContainingSolrDocsGeneratedByExtractorLight1}.part1"
    runStringAsStep_3 "${javaSeven} -Xmx4096M -Dfile.encoding=UTF-8 -cp ${jarFat} es.aeat.taiif.midas.bigbuscon.operations.WriteToSolr -i ${fileContainingSolrDocsGeneratedByExtractorLight1}.part0 -l ${logConfig} -a ${solrAuthFile} -c ${solrCollection} -m ${metadataFile} -z \"${zookeeperHost}\" -op ${sWrite1OP}.part0 -of ${sWrite1OF}.part0 ${solrSoftCommitString} ${solrWaitSearchString} -b ${solrBagSize} ${solrShootBlanksString} -d ${solrWriteDelay}"
    runStringAsStep_3 "${javaSeven} -Xmx4096M -Dfile.encoding=UTF-8 -cp ${jarFat} es.aeat.taiif.midas.bigbuscon.operations.WriteToSolr -i ${fileContainingSolrDocsGeneratedByExtractorLight1}.part1 -l ${logConfig} -a ${solrAuthFile} -c ${solrCollection} -m ${metadataFile} -z \"${zookeeperHost}\" -op ${sWrite1OP}.part1 -of ${sWrite1OF}.part1 ${solrSoftCommitString} ${solrWaitSearchString} -b ${solrBagSize} ${solrShootBlanksString} -d ${solrWriteDelay}"
    didWeLaunchWrite1=1
    logInfo "Step 2.5: Done."

    # ============================================================
    # Extra Step: Gather list of binaries skipped by MR1
    # ============================================================
    fileContainingLargePDFsFoundByExtractorLight1="${lfsExecutionHome}/list.el1_skippedpdfs"
    runStringAsStep_2 "hadoop fs -cat ${pathToOutputDataForExtractorLight1}/skipped-m* > ${fileContainingLargePDFsFoundByExtractorLight1}"
    numSkippedEL1=$(wc -l ${fileContainingLargePDFsFoundByExtractorLight1} | cut -d' ' -f1)
    logImp "Number of binaries skipped by MR1: ${numSkippedEL1}"
    writeToReport2 "MR1: Time spent in MR1, ${SPENT_TIME_MR1}"
    writeToReport2 "MR1: Number of binaries entering MR1 process, ${numFilesEnteringMR1}"
    writeToReport2 "MR1: Number of binaries I skipped in MR1, ${numSkippedEL1}"


    #########################################################################################################################
    #########################################################################################################################
    separateStages "${separatorStages}"
    #########################################################################################################################
    #########################################################################################################################

    logImp "Stage 3: Split."

    if [[ ${numSkippedEL1} -gt 0 ]]; then
        # ============================================================
        # Step 3.1: Generate page-balanced groups
        # ============================================================
        logInfo "Step 3.1: Grouping skipped binaries into equi-sized groups."
        runStringAsStep "${javaSeven} -Xmx2048M -cp ${jarFat} es.aeat.taiif.midas.bigbuscon.operations.FairPartitioner -i ${fileContainingLargePDFsFoundByExtractorLight1} -o ${pathToPDFGroups} -l ${logConfig} -p ${numMappers} -d ${pdfDiscardLimit}"
        logInfo "Step 3.1 Done"
        separateSteps "${separatorSteps}"
        # ==============================================
        # Step 3.2: Generate new tars, upload to cluster
        # ==============================================
        logInfo "Step 3.2: Generating tars from equi-sized groups of skipped binaries and uploading to cluster."
        runStringAsStep "${pathHelpers}/partitions2cluster ${pathToPDFGroups} ${data} ${pathToInputDataForSplitter}"
        logInfo "I will delete original data directory."
        runStringAsStep "rm -rf ${data}"
        logInfo "Step 3.2: Done."
        separateSteps "${separatorSteps}"

        START_TIME_SPLIT=$(date +%s)
        # =============================================
        # Step 3.3: (MR) Split pdfs
        # =============================================
        logInfo "Step 3.3: Split large binaries (Optim.)"
        runStringAsStep "${pathFireScripts}/run_mr_light.sh ${jarFat} es.aeat.taiif.midas.bigbuscon.mapreduce.operations.SplitLargePDFs ${containerMemory} ${containerCores} ${containerFailure} ${containerIdleTimeout} ${libFiles} ${libJars} -i ${pathToInputDataForSplitter} -l ${logConfig} -o ${pathToOutputDataForSplitter} -n ${namePrefix}_Splitter -p ${pdfTrimParam} -id ${executionString}"
        logInfo "Step 3.3: Done."
        END_TIME_SPLIT=$(date +%s)
        SPENT_TIME_SPLIT=$(((END_TIME_SPLIT-START_TIME_SPLIT)));

        separateSteps "${separatorSteps}"

        # ==================================
        # Step 3.4: Copy data handle to edge
        # ==================================
        logInfo "Step 3.4: Generate list of binaries encountered by Splitter."
        fileContainingDocsEncounteredBySplitter="${lfsExecutionHome}/list.splitter_data"
        runStringAsStep "hadoop fs -cat ${pathToOutputDataForSplitter}/data-m* | sort > ${fileContainingDocsEncounteredBySplitter}"
        numDocsEncounteredSplitter=$(wc -l ${fileContainingDocsEncounteredBySplitter} | cut -d' ' -f1)
        logImp "Number of binaries encountered by Splitter: ${numDocsEncounteredSplitter}"
        logInfo "Step 3.4: Done."

        separateSteps "${separatorSteps}"
        # =============================================
        # Step 3.5: Collect Splitted PDFs
        # =============================================
        # gather splitted docs
        logInfo "Step 3.5: Copy binaries that have been successfully split to Edge."
        runStringAsStep "mkdir ${splittedPDFs}"
        runStringAsStep "hadoop fs -cat ${pathToOutputDataForSplitter}/split-* > ${tmpFile}"
        runStringAsStep "${javaSeven} -Xmx8192M -cp ${jarFat} es.aeat.taiif.midas.bigbuscon.operations.DecodeBinaries -i ${tmpFile} -l ${logConfig} -o ${splittedPDFs} -f ${SplitDecodeFailFile}"
        runStringAsStep "find ${splittedPDFs} -maxdepth 1 -type f | rev | cut -d'/' -f1 | rev > ${tmpFile}"
        numSplitPDFsFound=$(wc -l ${tmpFile} | cut -d' ' -f1)
        logImp "Number of binaries created by Splitter: ${numSplitPDFsFound}"
        logInfo "Step 3.5: Done."
        separateSteps "${separatorSteps}"

        # ============================================
        # Step 3.6: Find Failures
        # ============================================
        logInfo "Step 3.6: Find failures of Splitter."

        # Failure type 1: Binaries that were scheduled on containers that crashed
        logInfo "Failure Type 1: Binaries that were scheduled on containers that crashed."
        # We must find all files present in file ${pathToPDFGroups} that are not present in file ${fileContainingDocsEncounteredBySplitter}
        runStringAsStep "sed -e 's/ /\\n/g' ${pathToPDFGroups} | sort > ${tmpFile}"
        numFilesEnteringSplitter=$(wc -l ${tmpFile} | cut -d' ' -f1)
        runStringAsStep "comm -23 ${tmpFile} ${fileContainingDocsEncounteredBySplitter} > ${failedSplitter}"
        numFilesFailedSplitter=$(wc -l ${failedSplitter} | cut -d' ' -f1)
        logInfo "Number of failures of type 1: ${numFilesFailedSplitter}"
        runStringAsStep "cat ${failedSplitter} | xargs -I {} echo {}\"#####Failed in Split: Container Crash\" >> ${errorMessageMap}"
        separateSubSteps "${separatorSubSteps}"

        # Failure type 2: Binaries that could not be split because of time out.
        logInfo "Failure type 2: Binaries that could not be split because of time out."
        fileContainingDocsTEBySplitter="${lfsExecutionHome}/list.splitter_te"
        runStringAsStep_2 "hadoop fs -cat ${pathToOutputDataForSplitter}/te-m* | sort > ${fileContainingDocsTEBySplitter}"
        numDocsTESplitter=$(wc -l ${fileContainingDocsTEBySplitter} | cut -d' ' -f1)
        runStringAsStep "cat ${fileContainingDocsTEBySplitter} >> ${failedSplitter}"
        logInfo "Number of failures of type 2: ${numDocsTESplitter}"
        runStringAsStep "cat ${fileContainingDocsTEBySplitter} | xargs -I {} echo {}\"#####Failed in Split: Timeout\" >> ${errorMessageMap}"

        separateSubSteps "${separatorSubSteps}"
        # And we are done!
        numFilesFailedSplitterFinal=$(wc -l ${failedSplitter} | cut -d' ' -f1)
        logImp "Total number of binaries that failed in Split: ${numFilesFailedSplitterFinal}"
        logInfo "Step 3.6: Done."
        writeToReport2 "Split: Number of binaries entering the Split process, ${numFilesEnteringSplitter}"
        writeToReport2 "Split: Number of binaries failed in Split process, ${numFilesFailedSplitterFinal}"
        numFilesActuallySplit=$(((numFilesEnteringSplitter-numFilesFailedSplitterFinal)))
        writeToReport2 "Split: Number of binaries I actually split, ${numFilesActuallySplit}"
        writeToReport2 "Split: Number of binaries generated by splitting, ${numSplitPDFsFound}"
        writeToReport2 "Split: Time spent in Splitting, ${SPENT_TIME_SPLIT}"


        #########################################################################################################################
        #########################################################################################################################
        separateStages "${separatorStages}"
        #########################################################################################################################
        #########################################################################################################################
        logImp "Stage 4: MR2."
        if [[ ${numSplitPDFsFound} -gt 0 ]]; then
            logInfo "Skipped files were created by Splitter."
            # =============================================
            # Step 4.1: Send splitted pdfs to cluster
            # =============================================
            logInfo "Step 4.1: Upload split binaries to Cluster."
            runStringAsStep "${pathHelpers}/docs2cluster -s -n ${numMappers} ${splittedPDFs} ${pathToInputDataForExtractorLight2}"
            runStringAsStep "find ${splittedPDFs} -type f -printf \"%f\\n\" > ${inputDocs}"
            numFilesEnteringMR2=$(wc -l ${inputDocs} | cut -d' ' -f1)
            runStringAsStep "rm -rf ${splittedPDFs}"
            logInfo "Step 4.1: Done."
            separateSteps "${separatorSteps}"

            START_TIME_MR2=$(date +%s)
            # ===================================================
            # Step 4.2: (MR) Map Reduce #2
            # ===================================================
            logInfo "Step 4.2: Run MapReduce#2."
            runStringAsStep "${pathFireScripts}/run_mr_light.sh ${jarFat} es.aeat.taiif.midas.bigbuscon.mapreduce.operations.RunMetaDataExtractionOnTar ${containerMemory} ${containerCores} ${containerFailure} ${containerIdleTimeout} ${libFiles} ${libJars} -l ${logConfig} -o ${pathToOutputDataForExtractorLight2} -i ${pathToInputDataForExtractorLight2} -id ${executionString} -t ${timeoutTesseract} -av ${aspellV} -ag ${aspellG} -nr ${numRetries} -r ${rotationParam} -ds ${disableFailString} -n ${namePrefix}_MR2 -tc ${timeoutMR2}"
            logInfo "Step 4.2: Done."
            END_TIME_MR2=$(date +%s)
            SPENT_TIME_MR2=$(((END_TIME_MR2-START_TIME_MR2)));
            separateSteps "${separatorSteps}"

            # ==================================
            # Step 4.3: Copy data handle to edge
            # ==================================
            logInfo "Step 4.3: Copy binaries encountered by MR2 to Edge."
            fileContainingDocsEncounteredByExtractorLight2="${lfsExecutionHome}/list.el2_data"
            runStringAsStep "hadoop fs -cat ${pathToOutputDataForExtractorLight2}/data-m* > ${fileContainingDocsEncounteredByExtractorLight2}"
            numDataEL2=$(wc -l ${fileContainingDocsEncounteredByExtractorLight2} | cut -d' ' -f1)
            logImp "Number of binaries encountered by MR2: ${numDataEL2}"
            logInfo "Step 4.3: Done."
            separateSteps "${separatorSteps}"
            # =================================================
            # Step 4.4: Copy binaries processed by MR2 to Edge.
            # =================================================
            logInfo "Step 4.4: Copy binaries processed by MR2 to Edge."
            runStringAsStep_2 "hadoop fs -cat ${pathToOutputDataForExtractorLight2}/processed-m* > ${fileContainingSolrDocsGeneratedByExtractorLight2_T}"
            numSolrDocsEL2=$(wc -l ${fileContainingSolrDocsGeneratedByExtractorLight2_T} | cut -d' ' -f1)
            logInfo "Number of solrdocs prepared by MR2: ${numSolrDocsEL2}"

            logInfo "I will consolidate the solrdocs prepared by MR2."
            runStringAsStep "${javaSeven} -Xmx8192M -cp ${jarFat} es.aeat.taiif.midas.bigbuscon.operations.consolidations.SplitConsolidator -i ${fileContainingSolrDocsGeneratedByExtractorLight2_T} -l ${logConfig} -oaf ${OAF} -ocsaf ${OCSAF} -opsaf ${OPSAF} -opsafl ${OPSAFL}"
            runStringAsStep "cat ${OAF} > ${fileContainingSolrDocsGeneratedByExtractorLight2}"
            runStringAsStep "cat ${OCSAF} >> ${fileContainingSolrDocsGeneratedByExtractorLight2}"
            runStringAsStep "cat ${OPSAF} >> ${fileContainingSolrDocsGeneratedByExtractorLight2}"
            numSolrDocsEL2_C=$(wc -l ${fileContainingSolrDocsGeneratedByExtractorLight2} | cut -d' ' -f1)
            logInfo "Number of solrdocs after consolidation: ${numSolrDocsEL2_C}"
            logInfo "Step 4.4: Done."
            separateSteps "${separatorSteps}"
            # ===========================
            # Step 4.5: Write To Solr
            # ===========================
            logInfo "Step 4.5: Write (consolidated) solrdocs to Solr."
            # write to solr
            runStringAsStep_2 "${javaSeven} -Xmx8192M -Dfile.encoding=UTF-8 -cp ${jarFat} es.aeat.taiif.midas.bigbuscon.operations.WriteToSolr -i ${fileContainingSolrDocsGeneratedByExtractorLight2} -l ${logConfig} -a ${solrAuthFile} -c ${solrCollection} -m ${metadataFile} -z \"${zookeeperHost}\" -op ${sWrite2OP} -of ${sWrite2OF} ${solrSoftCommitString} ${solrWaitSearchString} -b ${solrBagSize} ${solrShootBlanksString} -d ${solrWriteDelay}"
            numSolrDocsMDFailed=$(wc -l ${sWrite2OF} | cut -d' ' -f1)
            numSolrDocsMDProcessed=$(wc -l ${sWrite2OP} | cut -d' ' -f1)
            logInfo "Number of solrdocs that I wrote to Solr: ${numSolrDocsMDProcessed}"
            logImp "Number of solrdocs that I could not write because there was no metadata: ${numSolrDocsMDFailed}"
            logInfo "Step 4.5: Done."
            separateSteps "${separatorSteps}"
            # ============================================
            # Step 4.6: Find Failures
            # ============================================
            logInfo "Step 4.6: Find failures."
            separateSubSteps "${separatorSubSteps}"
            # Failure type 1: Binaries that were scheduled on containers that crashed
            logInfo "Failure Type 1: Binaries that were scheduled on containers that crashed."
            failedEL2_flat="${lfsExecutionHome}/list.el2_failed_flat"
            fileContainingEmptyContentDocsByExtractorLight2="${lfsExecutionHome}/list.el2_emptyDocs"
            runStringAsStep "cat ${inputDocs} | sort > ${tmpFile}"
            runStringAsStep "cat ${tmpFile} > ${inputDocs}"
            runStringAsStep "cat ${fileContainingDocsEncounteredByExtractorLight2} | sort > ${tmpFile}"
            runStringAsStep "cat ${tmpFile} > ${fileContainingDocsEncounteredByExtractorLight2}"
            runStringAsStep "comm -23 ${inputDocs} ${fileContainingDocsEncounteredByExtractorLight2} > ${failedEL2_flat}"
            numFilesFailedEL2=$(wc -l ${failedEL2_flat} | cut -d' ' -f1)
            logInfo "Number of failures of type 1: ${numFilesFailedEL2}"
            runStringAsStep "cat ${failedEL2_flat} | xargs -I {} echo {}\"#####Failed in MR2: Container Crash\" >> ${errorMessageMap}"
            separateSubSteps "${separatorSubSteps}"
            # Failure type 2: Binaries that resulted in an error in BlackBox or resulted in empty content.
            logInfo "Failure type 2: Binaries that resulted in an error in BlackBox or resulted in empty content."
            runStringAsStep_2 "hadoop fs -cat ${pathToOutputDataForExtractorLight2}/failed-m* > ${fileContainingEmptyContentDocsByExtractorLight2}"
            runStringAsStep "cat ${fileContainingEmptyContentDocsByExtractorLight2} >> ${failedEL2_flat}"
            numFilesFailedEL2EC=$(wc -l ${fileContainingEmptyContentDocsByExtractorLight2} | cut -d' ' -f1)
            logInfo "Number of failures of type 2: ${numFilesFailedEL2EC}"
            runStringAsStep_2 "hadoop fs -cat ${pathToOutputDataForExtractorLight2}/errorMessage-m* >> ${errorMessageMap}"
            separateSubSteps "${separatorSubSteps}"
            # Failure type 3: Binaries with no associated metadata.
            logInfo "Failure type 3: Binaries with no associated metadata."
            runStringAsStep "cat ${sWrite2OF} >> ${failedEL2_flat}"
            logInfo "Number of failures of type 3: ${numSolrDocsMDFailed}"
            numFilesFailedEL2_Flat=$(wc -l ${failedEL2_flat} | cut -d' ' -f1)
            numFilesActuallyProcessed=$(((numFilesEnteringMR2-numFilesFailedEL2_Flat)))
            runStringAsStep "cat ${sWrite2OF} | xargs -I {} echo {}\"#####Failed in MR2: Could not write to Solr.\" >> ${errorMessageMap}"
            separateSubSteps "${separatorSubSteps}"
            # Failure type 4: Binaries that could not be manifested after split.
            logInfo "Failure type 4: Binaries that could not be manifested after split."
            runStringAsStep "cat ${SplitDecodeFailFile} >> ${failedEL2_flat}"
            numDecodeFailed=$(wc -l ${SplitDecodeFailFile} | cut -d' ' -f1)
            logInfo "Number of failures of type 4: ${numDecodeFailed}"
            runStringAsStep "cat ${SplitDecodeFailFile} | xargs -I {} echo {}\"#####Failed in Split: Could not be split properly.\" >> ${errorMessageMap}"
            separateSubSteps "${separatorSubSteps}"
            # And we are done! However, we need to aggregate the names
            logInfo "I will consolidate all the failures I have collected so far."
            runStringAsStep "${javaSeven} -Xmx8192M -cp ${jarFat} es.aeat.taiif.midas.bigbuscon.operations.consolidations.ConsolidateFailedEL2 -i ${failedEL2_flat} -l ${logConfig} -o ${failedEL2}"
            # And now we are really done!
            numFilesFailedEL2=$(wc -l ${failedEL2} | cut -d' ' -f1)
            logImp "Total number of failed binaries in MR2: ${numFilesFailedEL2}"
            logInfo "Step 4.6: Done."
            writeToReport2 "MR2: Number of binaries entering MR2 process, ${numFilesEnteringMR2}"
            writeToReport2 "MR2: Number of binaries failed in MR2, ${numFilesFailedEL2_Flat}"
            writeToReport2 "MR2: Number of binaries that were processed in MR2, ${numFilesActuallyProcessed}"
            writeToReport2 "MR2: Number of binaries generated after consolidation of processed binaries, ${numSolrDocsEL2_C}"
            writeToReport2 "MR2: Number of binaries actually processed in MR2, ${numSolrDocsMDProcessed}"
            writeToReport2 "MR2: Time spent in MR2, ${SPENT_TIME_MR2}"
            #########################################################################################################################
            #########################################################################################################################
            separateStages "${separatorStages}"
            #########################################################################################################################
            #########################################################################################################################

        else
            logImp "Splitter did not create any split binaries."
        fi
    else
        logImp "MR1 did not skip any binaries. Will skip to Stage 5."
        runStringAsStep "rm -rf ${data}"
        #########################################################################################################################
        #########################################################################################################################
        separateStages "${separatorStages}"
        #########################################################################################################################
        #########################################################################################################################
    fi

    logImp "Stage 5: Update Final States in MySQL."
    # ==========================================
    # Step 5.0: Wait for MR1 SolrWrite to finish
    # ==========================================
    logInfo "Step 5.0: I will wait for all background processes that are writing to Solr."
    wait
    logInfo "All background processes writing to Solr have finished."
    logInfo "I will check if some of the records failed while writing to Solr."
    postProcessWrite1_part1
    logInfo "Step 5.0: Done."
    separateSteps "${separatorSteps}"
    # ============================================
    # Step 5.1: Find Failures of MR1.
    # ============================================
    logInfo "Step 5.1: Find failures of MR1."
    postProcessWrite1_part2
    logInfo "Step 5.1: Done."

    separateSteps "${separatorSteps}"
    # ============================
    # Step 5.2: Init State Files
    # ============================
    logInfo "Step 5.2: Init failure, processed, and partially-processed state files."
    runStringAsStep_2 "rm -rf ${stateFileFailed} ${stateFileProcessed} ${stateFilePartProcessed} ${stateFileFailedT}"
    runStringAsStep "touch ${stateFileFailed} ${stateFileProcessed} ${stateFilePartProcessed} ${stateFileFailedT}"
    logInfo "Step 5.2: Done"
    separateSteps "${separatorSteps}"
    # ==============================
    # Step 5.3: Populate State Files
    # ==============================
    logInfo "Step 5.3: Populate state files."
    logInfo "SubStep 5.3.1: Gather all failures."
    runStringAsStep "cat ${failedEL1} >> ${stateFileFailedT}"
    runStringAsStep "cat ${failedSplitter} >> ${stateFileFailedT}"
    runStringAsStep "cat ${failedEL2} >> ${stateFileFailedT}"
    logInfo "SubStep 5.3.2: Generate all state files."
    runStringAsStep "${javaSeven} -Xmx8192M -cp ${jarFat} es.aeat.taiif.midas.bigbuscon.operations.StateFileCalculator -l ${logConfig} -ifd ${stateFileFailedT} -ipr ${filesToProcess} -ipt ${OPSAFL} -ofd ${stateFileFailed} -opr ${stateFileProcessed} -opt ${stateFilePartProcessed}"
    logInfo "Step 5.3: Done"

    separateSteps "${separatorSteps}"

    # ==================================
    # Step 5.4: Total number of failures
    # ==================================
    logInfo "Step 5.4: Find total number of failed files."
    numTotalFailedFiles=$(wc -l ${stateFileFailed} | cut -d' ' -f1)
    logImp "Total number of failed binaries: ${numTotalFailedFiles}"
    logInfo "Step 5.4: Done."
    separateSteps "${separatorSteps}"

    # =====================================================
    # Step 5.5: Update state in MySQL.
    # =====================================================
    logInfo "Step 5.5: Updating state in MySQL."
    updateMySQL
    logInfo "Step 5.5: Done"

    separateSteps "${separatorSteps}"
else
    logInfo "Should remove execution home directory in local file system: ${lfsExecutionHome}"
    logInfo "Removing execution home directory in hdfs: ${hdfsExecutionHome}"
fi
#########################################################################################################################
#########################################################################################################################
separateStages "${separatorStages}"
#########################################################################################################################
#########################################################################################################################
deleteTempFiles
#########################################################################################################################
#########################################################################################################################
separateStages "${separatorStages}"
#########################################################################################################################
#########################################################################################################################
showStats

end
logWarn "Execution time: ${SPENTTIME} seconds."
logWarn "SUCCESS."
exit 0
