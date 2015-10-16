#!/bin/bash

# Setting IFS Env to only use new lines as field seperator 
IFS=$'\n' 

########################################################################
############################ README ####################################
########################################################################
# This script simply generates a comma separated list that can be pasted
# into addMacToStaticGroupOnEnroll.bash
#
# WARNING -- Strongly recommend to rename your static groups in the JSS
# to include no spaces.  
#
# You can use "_"   But special characters like quotes, spaces, colons, 
# dashes, etc. can be tricky.  
#
# See http://www.w3schools.com/tags/ref_urlencode.asp for more info
#
# Instructions :
#	1. Define variable "sourceJSS" - use example URL for reference 
#	2. Edit the "runLoopsOnGroups" function
#		- For each static group you need to pull - you need two lines of code
#			-- define the "staticGroup" variable"
#			-- run the "getStaticGroupMembers" function
#		- Use examples as guidance
#		
########################################################################
########################################################################

sourceJSS="https://pretendjss01.fakedomain.whatever:8443/"
outputFile=$HOME/Desktop/staticGroupMemberships

getStaticGroupMembers ()
{
for member in $(curl --silent -k --user "$sourceJSSuser:$sourceJSSpw" -H "Content-Type: application/xml" -X GET  "$sourceJSS"JSSResource/computergroups/name/$staticGroup  | xmllint --format - | grep serial | awk -F '<serial_number>|</serial_number>' '{print $2}')
	do
		echo "$member","$staticGroup" 
	done
}

runLoopOnGroups ()
{
staticGroup="staticGroupIneedToGet01"
getStaticGroupMembers
staticGroup="staticGroupIneedToGet02"
getStaticGroupMembers
staticGroup="staticGroupIneedToGet03"
getStaticGroupMembers
}

clear
echo -e "\n\n\n----------\n----------\n"
read -p "API User name for $sourceJSS ? " sourceJSSuser
read -p "API User password for $sourceJSS ? " -s sourceJSSpw
echo -e "\n\n\n----------\n----------\n"

echo "" > $outputFile
runLoopOnGroups | tee -a $outputFile









