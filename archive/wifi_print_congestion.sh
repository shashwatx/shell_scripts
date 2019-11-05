#!/bin/bash

# Written on 7 Jan, 2016 by Shashwat Mishra

# Description
# -----------
# Example script to print network congestion.
# -----------

sudo iwlist wlx0087309a0892 scan | grep Frequency | sort -nr | uniq -c | sort -nr
