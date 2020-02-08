#!/usr/bin/env bash

jarName=${1}
mainClassName=${2}

memory=${3}
cores=${4}
failurePercent=${5}
mapTaskTimeout=${6} #this value should be specified in milliseconds


pathToLibFiles=${7} #this variable contains the absolute path to the folder which contains the files that need to be copied to the distributed cache.
LIBFILES=`echo ${pathToLibFiles}/* | sed 's/ /,/g'`

pathToLibJars=${8} #this variable contains the absolute path to the folder which contains the blackbox jar.
LIBJARS=`echo ${pathToLibJars}/* | sed 's/ /,/g'`

#tt=`pwd`
#PATH_LIBJARS_EXTRA="${tt}/../jars_extra"
#LIBJARS_EXTRA=`echo ${PATH_LIBJARS_EXTRA}/* | sed 's/ /,/g'`
#PATH_LIBJARS_SOLR="${tt}/../jars_solr"
#LIBJARS_SOLR=`echo ${PATH_LIBJARS_SOLR}/* | sed 's/ /,/g'`
#PATH_LIBJARS_BLACKBOX="${tt}/../jars_blackbox"
#LIBJARS_BLACKBOX=`echo ${PATH_LIBJARS_BLACKBOX}/* | sed 's/ /,/g'`
#
#LIBJARS=${LIBJARS_EXTRA}","${LIBJARS_SOLR}","${LIBJARS_BLACKBOX}
#
#
#export HADOOP_CLASSPATH=${HADOOP_CLASSPATH}:`echo ${PATH_LIBJARS_EXTRA}/*.jar | sed 's/ /:/g'`:`echo ${PATH_LIBJARS_SOLR}/*.jar | sed 's/ /:/g'`:`echo ${PATH_LIBJARS_BLACKBOX}/*.jar | sed 's/ /:/g'`

configMR="
-D mapreduce.task.timeout=${mapTaskTimeout}
-D mapreduce.job.split.metainfo.maxsize=-1
-D mapreduce.map.cpu.vcores=${cores}
-D mapreduce.map.memory.mb=${memory}
-D mapreduce.map.maxattempts=1
-D mapreduce.map.failures.maxpercent=${failurePercent}
-D yarn.scheduler.minimum-allocation-mb=${memory}
-D mapreduce.job.reduce.slowstart.completedmaps=1
"

configJVM="-D mapreduce.map.java.opts=\"-Djava.util.Arrays.useLegacyMergeSort=true -Djava.net.preferIPv4Stack=true -Dorg.apache.pdfbox.baseParser.pushBackSize=1000000 -Dfile.encoding=UTF-8 -Dpdfbox.fontcache=/tmp -Xmx${memory}000000\""

x="hadoop jar ${jarName} ${mainClassName} -files ${LIBFILES} -libjars ${LIBJARS} ${configMR} ${configJVM} ${@:9}"

eval $x
