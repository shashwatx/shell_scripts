#!/bin/bash

# 20 Nov, 2015 by Shashwat Mishra

# Description
# -----------
# This script instructs the specified printer to print the specified file. 
# -----------

jobName="A4-Print"

printerName="DCPL2520DW"
numberup="1"
media="A4"
CNQuality="2"
sides="two-sided-long-edge"

echo
echo "Executing Custom-Job: $jobName..."
echo "To set dpi: lpoptions -p $printerName -o Resolution=2400dpi"
echo
if [ "$#" -lt 1 ]; then
echo "Error: Please give parameters \"file-name\""
echo "Usage: $0 <file-name-to-print>"
echo
exit 1
fi


echo "#### Sending job ####"
echo -e "\t Printer: $printerName"
echo -e "\t media: $media"
echo -e "\t CNQuality: $CNQuality"
echo -e "\t number-up: $numberup"
echo -e "\t sides: ${sides}"
echo -e "\t File: $1"
echo "##########"

lpr -P ${printerName} ${1} -o sides=${sides} -o fit-to-page -o media=${media} -o CNQuality=${CNQuality} -o number-up=${numberup}

echo
echo "Custom-Job $jobName finished."
echo
