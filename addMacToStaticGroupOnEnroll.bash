#!/bin/bash

# Variables from Policy Script
destinationJSSuser="$4"
destinationJSSpw="$5"

########################################################################
############################ README ####################################
########################################################################
# This script is designed to be uploaded to a new JSS and run once per
# computer on enrollment.
#
# Static groups must be created first in JSS, this does not actually create the group
#
# Be sure to set custom parameters under Options for $4 and $5 when creating this 
# script in JSS, and then populating those values in your policy
#
# WARNING -- Strongly recommend to rename your static groups in the JSS
# to include no spaces.  
#
# You can use "_"   But special characters like quotes, spaces, colons, 
# dashes, etc. can be tricky.  
#
# Do NOT use commas in your static group name, or this will not work.
#
# See http://www.w3schools.com/tags/ref_urlencode.asp for more info
#
# Instructions :
#	1. Define variable "destinationJSS" - use example URL for reference 
#	2. Edit the list "fullList"
#		- Each line should contain one Mac serial number, a comma, and static group
#		- Use examples as guidance
#		- Recommend using script generateSaticGroupMembershipList.bash to
#			generate the list from the source JSS
#
########################################################################
########################################################################

# Set Variable
destinationJSS="https://pretendjss02.fakedomain.whatever:8443/"

# Edit this list below with one serial number, a comma, and one static group per line
fullList="
FAK3APLS3RL1,StaticGroup01
FAK3APLS3RL2,StaticGroup01
FAK3APLS3RL1,StaticGroup02
FAK3APLS3RL3,StaticGroup02
FAK3APLS3RL1,StaticGroup03
"

########################################################################
########################################################################
############# Edit below this section at your own risk ! ###############
########################################################################
########################################################################

mySerial=`/usr/sbin/system_profiler SPHardwareDataType | grep "Serial Number" | awk -F ": " '{print $2}'`
echo -e "My Serial is $mySerial\n\n"

if [[ `echo $fullList | grep $mySerial` ]]
	then
		for groupToJoin in $(echo "$fullList" | grep "$mySerial" | awk -F "," '{print $2}')
			do
				echo -e "\n----------\n"
				echo "This system -- $mySerial -- should be added to -- $groupToJoin"
				curl -k "$destinationJSS"JSSResource/computergroups/name/$groupToJoin --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: application/xml" -X PUT -d "<computer_group><computer_additions><computer><serial_number>$mySerial</serial_number></computer></computer_additions></computer_group>"
				echo -e "\n----------\n"
				
			done
	else
		echo "\n----------\nNo memberships\n----------\n"
fi





