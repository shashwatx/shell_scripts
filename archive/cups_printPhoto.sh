#!/bin/bash

# 20 Nov, 2015 by Shashwat Mishra

# Description
# -----------
# This script instructs the specified printer to print the specified photo. 
# -----------


jobName="Photo-Print"

printerName="Canon_MP280_series"
PageSize="Custom.170x115mm"
MediaType="glossypaper"
CNQuality="2"

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
echo -e "\t PageSize: $PageSize"
echo -e "\t MediaType: $MediaType"
echo -e "\t CNQuality: $CNQuality"
echo -e "\t File: $1"
echo "##########"

lpr -P $printerName $1 -o fit-to-page -o PageSize=$PageSize -o MediaType=$MediaType -o CNQuality=$CNQuality

echo
echo "Custom-Job $jobName finished."
echo


# to print A4 size pages
# adjust  parameters CNQuality and number-up
# lpr -P Canon_MP280_series $1 -o fit-to-page -o media=A4 -o CNQuality=2 -o number-up=1

