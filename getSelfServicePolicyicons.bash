#!/bin/bash

# Setting IFS Env to only use new lines as field seperator 
IFS=$'\n' 

########################################################################
############################ README ####################################
########################################################################
# This script downloads Self Service policy icons from your JSS
# Each icon is named as "FileName-XX" - where "XX" is the policy ID
# This ensures that each version of the same icon you have uploaded gets
# downloaded.  
#
# At the end - you will also have option to rename all the downloaded files with a 
# resolution tag appended to end of file name  e.g. (256X256)

########################################################################
########################################################################
######## Please edit information below to suit your migration ##########
########################################################################
########################################################################

#JSS URL - Must include https prefix, port, and trailing "/" just as example below.
jssSourceURL="https://pretendjss01.fakedomain.whatever:8443/"

# Scratch Files and Output directories
iconsDirectory=$HOME/Desktop/iconsFromJSS
rawXML=/private/tmp/raw.xml
formattedXML=/private/tmp/formatted.xml
plainList=/private/tmp/plainlist
resultOutputDirectory=/private/tmp/resultOutput

########################################################################
########################################################################
############# Edit below this section at your own risk ! ###############
########################################################################
########################################################################

getInitialXML ()
{
#Generate raw xml file
echo -e "\nGetting raw xml data from JSS for policies..."
curl -k "$jssSourceURL"JSSResource/policies -H "Accept: application/xml" --user "$jssSourceUser:$jssSourcePassword" > $rawXML

#Authentication check
if [[ `cat $rawXML | head -15 | grep "The request requires user authentication"` ]]
	then 
		echo -e "\n----------\n----------\nAUTHENTICATION ERROR - TERMINATING\n----------\n----------"
		exit 1
fi
#Clean up the xml file
echo -e "\nFormatting XML file..."
xmllint -format $rawXML > $formattedXML

#Create plain file of policy ID's
echo "Generating a plain file list of policy ID's..."
cat $formattedXML | grep "<id>" | awk -F'<id>|</id>' '{print $2}' > $plainList
policyCount=`cat $plainList | wc -l | sed -e 's/^[ \t]*//'`
echo -e "\nFound a total of $policyCount policies.  If that number seems high, please note"
echo "	that also includes one-off policies generated via casper remote."
}

initializeIconsDirectory ()
{
if [ -d "$iconsDirectory" ]
	then 
		echo -e "\nArchiving previous icon output directory..."
		ditto -ck $iconsDirectory $iconsDirectory/../iconsDirectoryArchive-`date +%Y%m%d%H%M%S`.zip
		rm -rf $iconsDirectory
		mkdir -p $iconsDirectory
		if (( $? == 0 ))
			then 
				echo "Successfully created $iconsDirectory"
			else
				echo -e "Could not create $iconsDirectory \nPlease be sure parent directory is writeable or redefine the \"iconsDirectory\" variable \nTerminating..."
				exit 1
		fi
	else
		echo -e "\nNo previous icon output directory found.  Creating..."
		mkdir -p $iconsDirectory
		if (( $? == 0 ))
			then 
				echo "Successfully created $iconsDirectory"
			else
				echo -e "Could not create $iconsDirectory \nPlease be sure parent directory is writeable or redefine the \"iconsDirectory\" variable \nTerminating..."
				exit 1
		fi
fi
}

initializeOutputs ()
{
echo -e "\nInitializing scratch output directory and files..."
if [ -d $resultOutputDirectory ]
	then 
		echo "Found previous scratch directory. Killing..."
		rm -rf $resultOutputDirectory
elif [ -f $resultOutputDirectory ]
	then 
		echo "Found a file with scratch directory name.  Killing..."
		rm -f $resultOutputDirectory
fi
echo "Creating scratch directory..."
mkdir $resultOutputDirectory
touch $resultOutputDirectory/uriList
outputInt=1
resultOutput=$resultOutputDirectory/output$outputInt
}
				
downloadIcons ()
{
ssPolicyName=`cat $resultOutput | sed -n '/<general>/,/<\/name>/p' | grep "<name>" | awk -F ">"  '{print $2}' | awk -F "<" '{print $1}'`
ssPolicyIconName=`cat $resultOutput | sed -n '/<self_service_icon>/,/<\/self_service_icon>/p' | grep "<filename>" | awk -F ">"  '{print $2}' | awk -F "<" '{print $1}'`
ssPolicyIconURI=`cat $resultOutput | sed -n '/<self_service_icon>/,/<\/self_service_icon>/p' | grep "<uri>" | awk -F ">"  '{print $2}' | awk -F "<" '{print $1}'`
ssPolicyIconID=`cat $resultOutput | sed -n '/<self_service_icon>/,/<\/self_service_icon>/p' | grep "<id>" | awk -F ">"  '{print $2}' | awk -F "<" '{print $1}'`
ssPolicyIconNameNoSuffix=`echo "$ssPolicyIconName" | awk -F ".png" '{print $1}'`
echo -e "\nPolicy ID $resultOutput is a Self Service policy"
echo "Examining -- $ssPolicyName"
echo "Icon for this policy is $ssPolicyIconName"
if [[ `cat $resultOutputDirectory/uriList | grep "$ssPolicyIconURI"` ]]
	then
		echo "$ssPolicyIconName - $ssPolicyIconID has already been downloaded"
	else
		echo -e "Downloading $ssPolicyIconName ...\n"
		curl -k  $ssPolicyIconURI -X GET > "$iconsDirectory"/"$ssPolicyIconNameNoSuffix"-"$ssPolicyIconID".png
		echo "$ssPolicyIconURI" >> $resultOutputDirectory/uriList
fi
}

getEachPolicyAsXML ()
{
for policyID in $(cat $plainList)
	do
		echo -e "\n********************\nFetching Policy ID number $policyID"
		curl --silent -k --user "$jssSourceUser:$jssSourcePassword" -H "Accept: application/xml" -X GET "$jssSourceURL"JSSResource/policies/id/$policyID | xmllint --format - >> $resultOutput
		if [[ `cat $resultOutput | grep "<use_for_self_service>false</use_for_self_service>"` ]]
			then 
 				echo -e "ID $policyID is not a Self Service policy.  Ignoring..."
 				rm -f $resultOutput
 			else
 				downloadIcons
 		fi
		let "outputInt = $outputInt + 1"
		resultOutput=$resultOutputDirectory/output$outputInt
	done
}

renameFilesBySize ()
{
/usr/bin/mdls $iconsDirectory/* > /dev/null
echo "Pausing to let Spotlight warm up..."
sleep 5
for iconFile in $(ls $iconsDirectory)
	do
		iconWidth=`/usr/bin/mdls -name kMDItemPixelWidth $iconsDirectory/$iconFile | awk -F "=" '{print $2}' | sed -e 's/^[ \t]*//'`
		iconHeight=`/usr/bin/mdls -name kMDItemPixelHeight $iconsDirectory/$iconFile | awk -F "=" '{print $2}' | sed -e 's/^[ \t]*//'`
		newIconFileName=`echo "$iconFile" | awk -F ".png" '{print $1}'`\("$iconWidth"X"$iconHeight"\).png
		echo "Renaming $iconFile..."
		mv $iconsDirectory/$iconFile $iconsDirectory/$newIconFileName
	done
}

#MAIN
clear
echo -e "\nCredentials -- \n"
read -p "Please enter your JSS API account name for $jssSourceURL :	" jssSourceUser
read -p "Please enter your JSS API password for $jssSourceURL :	" -s jssSourcePassword
echo -e "\n"
getInitialXML
sleep 2
initializeIconsDirectory
sleep 2
initializeOutputs
sleep 2
getEachPolicyAsXML

echo -e "\n========================================\n========================================\n"
echo "Download complete"
echo "$(ls $iconsDirectory | wc -l | sed -e 's/^[ \t]*//') icons downloaded"
echo -e "\n========================================\n========================================\n"

echo "Would you like to rename the icon files to include pixel size?"
echo -e "\nFor example, a file named \"My Icon.png\" would be renamed to \"My Icon(199X199).png\""
echo -e "Or whatever the pixel size is \(using mdls to determine pixel height and width\)\n"
read -p "Rename files? (y or n) : " renameResponse

if [ $renameResponse = "y" ]
	then 
		renameFilesBySize
		echo -e "\nFile renaming complete.\n"
	else	
		echo -e "\nOk.  Exiting now.\n"
fi

exit 0
