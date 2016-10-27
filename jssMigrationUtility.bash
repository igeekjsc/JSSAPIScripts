#!/bin/bash

# JSS Migration Utility
# Version 1.23

########################################################################
########################################################################
######## Please edit information below to suit your migration ##########
########################################################################
########################################################################

# About JSS URL Variables
# You MUST include the "https://" prefix AND the ":port/" suffix (where applicable)

# For example, if your JSS address is "jss.mycompany.com"
# and it runs on port 8443, the URL should be
# "https://jss.mycompany.com:8443/"

# If the same JSS runs on port 443,
# the URL should be "https://jss.mycompany.com/"

# Edit variables below to suit your environment

sourceJSS="https://jss01.mycompany.com:8443/"
destinationJSS="https://jss02.mycompany.com:8443/"

# Output directory - please choose a directory that you have write access to
# Default is Desktop - "JSS_Migration" 

localOutputDirectory="$HOME/Desktop/JSS_Migration"

########################################################################
########################################################################
############# Edit below this section at your own risk ! ###############
########################################################################
########################################################################


# Setting IFS Env to only use new lines as field seperator 
IFS=$'\n' 

openingDialog ()
{
clear
echo -e "\n--------------------\n--------------------\n\nBeginning JSS Migration Utility\n\n--------------------\n--------------------\n"
echo "
It is critical that you have accounts on both JSS instances with the correct
API access levels.  On the source JSS, you need read access.  On the destination JSS,
you need full read and write access.

At any time during this script, you may abort with the standard Control - C keys."
echo -e "\n\n--------------------\n--------------------\n\n"
echo "Please enter your JSS API account name for"
read -p "$sourceJSS :	" sourceJSSuser
echo -e "\nPlease enter your JSS API password for"
read -p "$sourceJSS :	" -s sourceJSSpw
echo -e "\n\nAre your credentials the same for $destinationJSS ?"
read -p "(y or n) : " sameCredentialsChoice
	if [ "$sameCredentialsChoice" = y ]
		then 
			destinationJSSuser="$sourceJSSuser"
			destinationJSSpw="$sourceJSSpw"
		else
			echo -e "\n"
			echo -e "Please enter your JSS API account name for"
			read -p "$destinationJSS :	" destinationJSSuser
			echo -e "\nPlease enter your JSS API password for"
			read -p "$destinationJSS :	" -s destinationJSSpw
	fi	

clear
echo -e "\n--------------------\n--------------------\n"
echo "Checking System..."
echo -e "\nMaking sure we can write files to output directory..."
if [ -d $localOutputDirectory ]
	then
		echo "Output directory exists.  Making sure we can write files inside..."
			if [ -d "$localOutputDirectory"/authentication_check ]
				then 
					echo "Found previous authentication check directory.  Deleting..."
					rm -rf "$localOutputDirectory"/authentication_check 
					if (( $? == 0 ))
						then echo "Success."
						else 
							echo "Failure.  There is a problem with permissions in your output directory.  Aborting..."
							exit 1
					fi
			fi
	else
		echo "Creating top level output directory..."
		mkdir $localOutputDirectory
			if (( $? == 0 ))
				then echo "Success."
				else 
					echo "Failure.  There is a problem with permissions in your output directory.  Aborting..."
					exit 1
			fi
		chmod 775 $localOutputDirectory
fi
echo "Creating authentication check directory..."
mkdir "$localOutputDirectory"/authentication_check 
chmod 775 "$localOutputDirectory"/authentication_check 
		
echo -e "\n*****\nEverything looks good with your working directory\n*****\n"
echo "Would you like to run a quick authentication check?"
echo "This will entail creating a mock category in destination JSS"
read -p "( \"y\" or \"n\" ) " authCheckChoice
case $authCheckChoice in
	[yY] | [Yy][Ee][Ss])
		echo "Proceeding to test your credentials.  Downloading categories resource..."
		curl -k --user "$sourceJSSuser:$sourceJSSpw" -H "Accept: text/xml" -X GET "$sourceJSS"JSSResource/categories > "$localOutputDirectory"/authentication_check/raw.xml
		curlStatus=$?
		if (( $curlStatus == 0 ))
			then
				echo -e "\nAble to communicate with $sourceJSS"
			else
				echo -e "\n\nUnable to communicate with $sourceJSS"
				echo "Please check exit status $curlStatus in curl documentation for more details"
				echo "You may simply have a typo in your source JSS URL or there may be a network issue"
				echo -e "\n!!!!!!!!!!!!!!!!!!!!\nCURL ERROR - TERMINATING\n!!!!!!!!!!!!!!!!!!!!\n\n"
				exit 1
		fi

		#Authentication checks
		if [[ `cat "$localOutputDirectory"/authentication_check/raw.xml | grep "The request requires user authentication"` ]]
			then 
				echo -e "\nThere is a problem with your credentials for $sourceJSS\n"
				echo -e "\n!!!!!!!!!!!!!!!!!!!!\nAUTHENTICATION ERROR - TERMINATING\n!!!!!!!!!!!!!!!!!!!!\n\n"
				exit 1
			else echo "Credentials check out for $sourceJSS"
		fi

		echo -e "\nTo check your API write access to $destinationJSS \nwe will attempt to create a test category\n"
		echo "It will be named \"zzzz_Migration_Test_\", with a timestamp suffix"
		echo "Delete later if you wish"
		echo -e "\nAttempting post now...\n"
		curl -k "$destinationJSS"JSSResource/categories --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: text/xml" -X POST -d "<category><name>zzzz_Migration_Test_`date +%Y%m%d%H%M%S`</name><priority>20</priority></category>" > "$localOutputDirectory"/authentication_check/postCheck.xml
		curlStatus=$?
		if (( $curlStatus == 0 ))
			then
				echo -e "\nAble to communicate with $destinationJSS"
			else
				echo -e "\n\nUnable to communicate with $destinationJSS"
				echo "Please check exit status $curlStatus in curl documentation for more details"
				echo "You may simply have a typo in your destination JSS URL or there may be a network issue"
				echo -e "\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\nCURL ERROR - TERMINATING\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n"
				exit 1
		fi
		if [[ `cat "$localOutputDirectory"/authentication_check/postCheck.xml | grep "The request requires user authentication"` ]]
			then 
				echo -e "\nThere is a problem with your credentials for $destinationJSS\n"
				echo -e "\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\nAUTHENTICATION ERROR - TERMINATING\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n"
				exit 1
			else echo "Credentials check out for $destinationJSS"
		fi
		echo "Are you ready to proceed?"
		read -p "( \"y\" or \"n\" ) : " proceedChoice
		case $proceedChoice in
			[nN] | [Nn][Oo])
				echo "Aborting..."
				exit 1
				;;
			*)
				clear
				;;
		esac	
	;;	
esac
}

initializeDirectoriesPerResource ()
{
echo "Creating local directories for $jssResource ..."
if [ -d "$localOutputDirectory"/"$jssResource" ]
	then
		echo "Found existing directory for $jssResource -- Archiving..."
			if [ -d "$localOutputDirectory"/archives ]
				then 
					echo "Archive directory exists"
				else 
					echo "Archive directory does not exist.  Creating..."
					mkdir "$localOutputDirectory"/archives
			fi
		ditto -ck "$localOutputDirectory"/"$jssResource" "$localOutputDirectory"/archives/"$jssResource"-`date +%Y%m%d%H%M%S`.zip
		echo "Removing previous local directory structure for $jssResource"
		rm -rf "$localOutputDirectory"/"$jssResource"
	else
		echo "No previous directories found for $jssResource"
fi

mkdir -p "$localOutputDirectory"/"$jssResource"/id_list
mkdir -p "$localOutputDirectory"/"$jssResource"/fetched_xml
mkdir -p "$localOutputDirectory"/"$jssResource"/parsed_xml

echo -e "\nDirectories created\n"
}

setVariablesForResource ()
{
formattedList="$localOutputDirectory"/"$jssResource"/id_list/formattedList.xml
plainList="$localOutputDirectory"/"$jssResource"/id_list/plainList
plainListAccountsUsers="$localOutputDirectory"/"$jssResource"/id_list/plainListAccountsUsers
plainListAccountsGroups="$localOutputDirectory"/"$jssResource"/id_list/plainListAccountsGroups
resultInt=1
fetchedResult="$localOutputDirectory"/"$jssResource"/fetched_xml/result"$resultInt".xml
fetchedResultAccountsUsers="$localOutputDirectory"/"$jssResource"/fetched_xml/userResult"$resultInt".xml
fetchedResultAccountsGroups="$localOutputDirectory"/"$jssResource"/fetched_xml/groupResult"$resultInt".xml
}

createIDlist ()
{
echo -e "\nFetching XML data for $jssResource ID's"
curl -k --user "$sourceJSSuser:$sourceJSSpw" -H "Accept: text/xml" -X GET "$sourceJSS"JSSResource/$jssResource | xmllint --format - > $formattedList
if [ $jssResource = "accounts" ]
	then
		echo "For accounts resource - we need two separate lists"
		echo "Creating plain list of user ID's..."
		cat $formattedList | sed '/<site>/,/<\/site>/d' | sed '/<groups>/,/<\/groups>/d' | awk -F '<id>|</id>' '/<id>/ {print $2}' > $plainListAccountsUsers
		echo "Creating plain list of group ID's..."
		cat $formattedList | sed '/<site>/,/<\/site>/d'| sed '/<users>/,/<\/users>/d' | awk -F '<id>|</id>' '/<id>/ {print $2}' > $plainListAccountsGroups
	else
		echo -e "\n\nCreating a plain list of $jssResource ID's \n"
		cat $formattedList |awk -F'<id>|</id>' '/<id>/ {print $2}' > $plainList
fi
echo -e "\n\n\n"
sleep 3
}

fetchResourceID ()
{
if [ $jssResource = "accounts" ]
	then
		totalFetchedIDsUsers=`cat "$plainListAccountsUsers" | wc -l | sed -e 's/^[ \t]*//'`
		for userID in $(cat $plainListAccountsUsers)
			do
				echo "Downloading User ID number $userID ( $resultInt out of $totalFetchedIDsUsers )"
				curl --silent -k --user "$sourceJSSuser:$sourceJSSpw" -H "Accept: text/xml" -X GET  "$sourceJSS"JSSResource/accounts/userid/$userID  | xmllint --format - >> $fetchedResultAccountsUsers
				let "resultInt = $resultInt + 1"
				fetchedResultAccountsUsers="$localOutputDirectory"/"$jssResource"/fetched_xml/userResult"$resultInt".xml
			done
		resultInt=1
		totalFetchedIDsGroups=`cat "$plainListAccountsGroups" | wc -l | sed -e 's/^[ \t]*//'`
		for groupID in $(cat $plainListAccountsGroups)
			do
				echo "Downloading Group ID number $groupID ( $resultInt out of $totalFetchedIDsGroups )"
				curl --silent -k --user "$sourceJSSuser:$sourceJSSpw" -H "Accept: text/xml" -X GET  "$sourceJSS"JSSResource/accounts/groupid/$groupID  | xmllint --format - >> $fetchedResultAccountsGroups
				let "resultInt = $resultInt + 1"
				fetchedResultAccountsGroups="$localOutputDirectory"/"$jssResource"/fetched_xml/groupResult"$resultInt".xml
			done
	else
		totalFetchedIDs=`cat "$plainList" | wc -l | sed -e 's/^[ \t]*//'`
		for apiID in $(cat $plainList)
			do
				echo "Downloading ID number $apiID ( $resultInt out of $totalFetchedIDs )"
				curl --silent -k --user "$sourceJSSuser:$sourceJSSpw" -H "Accept: text/xml" -X GET  "$sourceJSS"JSSResource/$jssResource/id/$apiID  | xmllint --format - >> $fetchedResult
				let "resultInt = $resultInt + 1"
				fetchedResult="$localOutputDirectory"/"$jssResource"/fetched_xml/result"$resultInt".xml
			done
fi
}

parseResourceID ()
{ 
echo -e "\n\nProceeding to parse each downloaded XML file..."
if [ $jssResource = "accounts" ]
	then
		echo -e "\n**********\n\nVery Important Info regarding Accounts -- "
		echo -e "\n\n1. If you have LDAP-based JSS Admin accounts, you must migrate LDAP Servers first."
		echo -e "2. Passwords WILL NOT be included with standard accounts. Must enter manually in web app \n\n"
		read -p "Press RETURN key to acknowledge this message " returnChoice
		echo -e "\n\n"
		for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
			do
				echo "Parsing $resourceXML "
				cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" > "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_"$resourceXML"
			done	
elif [ $jssResource = "computergroups" ]
	then
		echo -e "\n**********\n\nVery Important Info regarding Computer Groups -- "
		echo -e "\n\n1. Smart Computer Groups will only contain logic.  Will not contain members"
		echo "2. Static Computer groups will only contain name and site membership."
		echo "3. Unfortunately, you will need to add computers back to Static groups after computers enroll in new jSS"
		read -p "Press RETURN key to acknowledge this message " returnChoice
		echo -e "\nParsing computer groups to EXCLUDE computers in both static and smart groups..."
		for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
			do
				echo "Parsing $resourceXML "				
				if [[ `cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep "<is_smart>false</is_smart>"` ]]
					then
						echo "$resourceXML is a STATIC computer group..."
						cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<computers>/,/<\/computers/d' > "$localOutputDirectory"/"$jssResource"/parsed_xml/static_group_parsed_"$resourceXML"
					else
						echo "$resourceXML is a SMART computer group..."
						cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<computers>/,/<\/computers/d' > "$localOutputDirectory"/"$jssResource"/parsed_xml/smart_group_parsed_"$resourceXML"
				fi					
			done							
elif [ $jssResource = "mobiledevicegroups" ]
	then
		echo -e "\n**********\n\nVery Important Info regarding Mobile Device Groups -- "
		echo -e "\n\n1. Smart Mobile Device Groups will only contain logic.  Will not contain members"
		echo "2. Static Mobile Device groups will only contain name and site membership."
		echo "3. Unfortunately, you will need to add Mobile Devices back to Static groups after Mobile Devices enroll in new jSS"
		read -p "Press RETURN key to acknowledge this message " returnChoice
		echo -e "\nParsing computer groups to EXCLUDE Mobile Devices in both static and smart groups..."
		for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
			do
				echo "Parsing $resourceXML "				
				if [[ `cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep "<is_smart>false</is_smart>"` ]]
					then
						echo "$resourceXML is a STATIC mobile device group..."
						cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<mobile_devices>/,/<\/mobile_devices/d' > "$localOutputDirectory"/"$jssResource"/parsed_xml/static_group_parsed_"$resourceXML"
					else
						echo "$resourceXML is a SMART mobile device group..."
						cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<mobile_devices>/,/<\/mobile_devices/d' > "$localOutputDirectory"/"$jssResource"/parsed_xml/smart_group_parsed_"$resourceXML"
				fi					
			done							
elif [ $jssResource = "advancedcomputersearches" ]
	then
		for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
			do
				echo "Parsing $resourceXML "				
				echo "$resourceXML is an Advanced Computer Search..."
				cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<computers>/,/<\/computers/d' > "$localOutputDirectory"/"$jssResource"/parsed_xml/advanced_computer_search_parsed_"$resourceXML"					
			done
elif [ $jssResource = "advancedmobiledevicesearches" ]
	then
		for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
			do
				echo "Parsing $resourceXML "				
				echo "$resourceXML is an Advanced Mobile Device Search..."
				cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<mobile_devices>/,/<\/mobile_devices/d' > "$localOutputDirectory"/"$jssResource"/parsed_xml/advanced_mobile_device_search_parsed_"$resourceXML"					
			done
elif [ $jssResource = "distributionpoints" ]
	then
		echo -e "\n**********\n\nVery Important Info regarding Distribution Points -- "
		echo -e "\n\n1. Failover settings will NOT be included in migration!"
		echo "2. Passwords for Casper Read and Casper Admin accounts will NOT be included in migration!"
		echo -e "\nThese must be set manually in web app\n\n**********\n\n"
		read -p "Press RETURN key to acknowledge this message " returnChoice
		for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
			do
				echo "Parsing $resourceXML "
				cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<failover_point>/,/<\/failover_point_url>/d' > "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_"$resourceXML"
			done
elif [ $jssResource = "ldapservers" ]
	then
		echo -e "\n**********\n\nVery Important Info regarding LDAP Servers -- "
		echo -e "\nPasswords for authenticating to LDAP will NOT be included!"
		echo -e "You must enter passwords for LDAP in web app\n\n**********\n\n"
		read -p "Press RETURN key to acknowledge this message " returnChoice
		for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
			do
				echo "Parsing $resourceXML "
				cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" > "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_"$resourceXML"
			done
elif [ $jssResource = "directorybindings" ]
	then
		echo -e "\n**********\n\nVery Important Info regarding Directory Bindings -- "
		echo -e "\nPasswords for directory binding account will NOT be included!"
		echo -e "You must set these passwords for LDAP in web app\n\n**********\n\n"
		read -p "Press RETURN key to acknowledge this message " returnChoice
		for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
			do
				echo "Parsing $resourceXML "
				cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" > "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_"$resourceXML"
			done
elif [ $jssResource = "packages" ]
	then
		echo -e "\n**********\n\nAbout Packages -- "
		echo -e "\nFor packages with no category assigned, we need to strip"
		echo -e "the category string from the xml, or it will fail to upload. \n\n**********\n\n"
		read -p "Press RETURN key to acknowledge this message " returnChoice
		for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
			do
				echo "Parsing $resourceXML "
				if [[ `cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep "No category assigned"` ]]
					then 
						echo "Stripping category string from $resourceXML"
						cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<category>/,/<\/category/d' > "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_"$resourceXML"
					else
						cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" > "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_"$resourceXML"
				fi
			done
elif [ $jssResource = "osxconfigurationprofiles" ]
	then
		echo -e "\n**********\n\nImportant note regarding OS X Configuration Profiles -- "
		echo -e "\nIt is critical that computer groups are migrated first!"
		echo "Data regarding which computers have profiles will be stripped."
		echo -e "This data will come back as computers enroll in destination JSS\n\n**********\n\n"
		read -p "Press RETURN key to acknowledge this message " returnChoice
		for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
			do
				echo "Parsing $resourceXML "
				cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<computers>/,/<\/computers/d' > "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_"$resourceXML"
			done
elif [ $jssResource = "mobiledeviceconfigurationprofiles" ]
	then
		echo -e "\n**********\n\nImportant note regarding Mobile Device Configuration Profiles -- "
		echo -e "\nIt is critical that mobile device groups are migrated first!"
		echo "Data regarding which mobile devices have profiles will be stripped."
		echo -e "This data will come back as mobile devices enroll in destination JSS\n\n**********\n\n"
		read -p "Press RETURN key to acknowledge this message " returnChoice
		for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
			do
				echo "Parsing $resourceXML "
				cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<mobile_devices>/,/<\/mobile_devices/d' > "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_"$resourceXML"
			done	
elif [ $jssResource = "mobiledeviceenrollmentprofiles" ]
	then
		echo -e "\n**********\n\nImportant note regarding Mobile Device Enrollment Profiles -- "
		echo -e "\nEnrollment Invitations will not be included"
		read -p "Press RETURN key to acknowledge this message " returnChoice
		echo -e "\nParsing Invitation IDs..."
		for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
			do
				echo "Parsing $resourceXML "
				cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | grep -v "<invitation>" | grep -v "<uuid>" > "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_"$resourceXML"
			done			
elif [ $jssResource = "restrictedsoftware" ]
	then
		echo -e "\n**********\n\nImportant note regarding Restricted Software -- "
		echo -e "\nIt is critical that the following items are migrated first!"
		echo "1. Computer Groups"
		echo "2. Buildings"
		echo "3. Departments"
		echo -e "\nIndividual computers that are excluded from restricted software items \nWILL NOT be included in migration!"
		echo "They will need to be added later after they re-enroll"
		read -p "Press RETURN key to acknowledge this message " returnChoice
		echo -e "\nParsing Restricted Software ID's to EXCLUDE computers..."
		for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
			do
				echo "Parsing $resourceXML "
				cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<computers>/,/<\/computers/d' > "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_"$resourceXML"
			done
elif [ $jssResource = "policies" ]
	then
		echo -e "\n**********\n\nVery Important Info regarding Policies -- "
		echo -e "\n1. Policies that are not assigned to a category will NOT be migrated"
		echo "	Reason: want to avoid migrating one-off policies generated by Casper Remote "
		echo "2. The following items will not be migrated "
		echo "	a. Individual computers as a scope, exclusion, etc."
		echo "	b. Self Service icons"
		echo -e "\nThese items must be added manually via web app\n\n**********\n\n"
		read -p "Press RETURN key to acknowledge this message " returnChoice
		echo -e "\n"
		echo "In some environments, posting policies with other limitations and exclusions"
		echo "(.e.g. LDAP Users and Groups) causes errors when posting."
		echo -e "\nWould you like to omit user and group limitations from your policies and add manually later?"
		read -p "( \"y\" or \"n\" ) " omitLimitationsChoice
		case $omitLimitationsChoice in
			[yY] | [Yy][Ee][Ss])
				for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
					do
						echo "Parsing $resourceXML "
						if [[ `cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep "<name>No category assigned</name>"` ]]
							then
								echo "Policy $resourceXML is not assigned to a category.  Ignoring..."
							else
								cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<computers>/,/<\/computers>/d' | sed '/<self_service_icon>/,/<\/self_service_icon>/d' | sed '/<limit_to_users>/,/<\/limit_to_users>/d' | sed '/<users>/,/<\/users>/d' | sed '/<user_groups>/,/<\/user_groups>/d' > "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_"$resourceXML"
						fi
					done
				;;
			*)
				for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
					do
						echo "Parsing $resourceXML "
						if [[ `cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep "<name>No category assigned</name>"` ]]
							then
								echo "Policy $resourceXML is not assigned to a category.  Ignoring..."
							else
								cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<computers>/,/<\/computers>/d' | sed '/<self_service_icon>/,/<\/self_service_icon>/d' > "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_"$resourceXML"
						fi
					done
				;;
		esac
else
	echo "For $jssResource - no need for extra special parsing.  Simply removing references to ID's"
	sleep 2
	for resourceXML in $(ls "$localOutputDirectory"/"$jssResource"/fetched_xml)
		do
			echo "Parsing $resourceXML "
			cat "$localOutputDirectory"/"$jssResource"/fetched_xml/$resourceXML | grep -v "<id>" > "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_"$resourceXML"
		done
fi
}

pauseForManualCheck ()
{
echo -e "\n----------------------------------------\nYou may wish to spot-check parsed XML \nin "$localOutputDirectory"/"$jssResource"/parsed_xml \n----------------------------------------"
echo -e "If you enter \"n\" - you will return to the main menu\nIt is safe to just leave the utility in this state while you spot-check parsed XML.\n"
read -p "Continue now ? (y or n) : " continueResponse

case $continueResponse in
	[nN] | [Nn][Oo])
		jssResource="null"
		;;
	*)
		echo -e "Continuing...\n\n"
		sleep 1
		;;
esac
}

postResource ()
{
if [ $jssResource = "null" ]
	then
		# We are not doing anything here.  
		# This is just a placeholder in case someone wants to return to main menu 
		# during pauseForManualCheck function
		# instead of proceeding with post
		echo "Nothing to see here" > /dev/null 
	else
		echo -e "\n\nTime to post $jssResource to destination JSS...\n\n"
		sleep 1
fi
if [ $jssResource = "accounts" ]
	then
		echo "For accounts, we need to post users first, then groups..."
		echo -e "\n\n----------\nPosting users...\n"
		sleep 1
		totalParsedResourceXML_user=$(ls "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_user* | wc -l | sed -e 's/^[ \t]*//')
		postInt_user=0	
		for parsedXML_user in $(ls "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_user*)
		do
			xmlPost_user=$parsedXML_user
			let "postInt_user = $postInt_user + 1"
			echo -e "\n----------\n----------"
			echo -e "\nPosting $parsedXML_user ( $postInt_user out of $totalParsedResourceXML_user ) \n"
	 		curl -k "$destinationJSS"JSSResource/accounts/userid/99999 --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: text/xml" -X POST -T "$xmlPost_user"
		done
		echo -e "\n\n----------\nPosting groups...\n"
		sleep 1
		totalParsedResourceXML_group=$(ls "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_group* | wc -l | sed -e 's/^[ \t]*//')
		postInt_group=0	
		for parsedXML_group in $(ls "$localOutputDirectory"/"$jssResource"/parsed_xml/parsed_group*)
		do
			xmlPost_group=$parsedXML_group
			let "postInt_group = $postInt_group + 1"
			echo -e "\n----------\n----------"
			echo -e "\nPosting $parsedXML_group ( $postInt_group out of $totalParsedResourceXML_group ) \n"
	 		curl -k "$destinationJSS"JSSResource/accounts/groupid/99999 --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: text/xml" -X POST -T "$xmlPost_group"
		done		
elif [ $jssResource = "computergroups" ]
	then 
		echo "For computers, we need to post static groups before smart groups,"
		echo "because smart groups can contain static groups"
		echo -e "\n\n----------\nPosting static computer groups...\n"
		totalParsedResourceXML_staticGroups=$(ls "$localOutputDirectory"/computergroups/parsed_xml/static_group_parsed* | wc -l | sed -e 's/^[ \t]*//')
		postInt_static=0	
		for parsedXML_static in $(ls "$localOutputDirectory"/computergroups/parsed_xml/static_group_parsed*)
		do
			xmlPost_static=$parsedXML_static
			let "postInt_static = $postInt_static + 1"
			echo -e "\n----------\n----------"
			echo -e "\nPosting $parsedXML_static ( $postInt_static out of $totalParsedResourceXML_staticGroups ) \n"
	 		curl -k "$destinationJSS"JSSResource/computergroups --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: text/xml" -X POST -T "$xmlPost_static"
		done
		echo -e "\n\n----------\nPosting smart computer groups...\n"
		sleep 1
		totalParsedResourceXML_smartGroups=$(ls "$localOutputDirectory"/computergroups/parsed_xml/smart_group_parsed* | wc -l | sed -e 's/^[ \t]*//')
		postInt_smart=0	
		for parsedXML_smart in $(ls "$localOutputDirectory"/computergroups/parsed_xml/smart_group_parsed*)
		do
			xmlPost_smart=$parsedXML_smart
			let "postInt_smart = $postInt_smart + 1"
			echo -e "\n----------\n----------"
			echo -e "\nPosting $parsedXML_smart ( $postInt_smart out of $totalParsedResourceXML_smartGroups ) \n"
	 		curl -k "$destinationJSS"JSSResource/computergroups --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: text/xml" -X POST -T "$xmlPost_smart"
		done
elif [ $jssResource = "mobiledevicegroups" ]
	then 
		echo "For mobile devices, we need to post static groups before smart groups,"
		echo "because smart groups can contain static groups"
		echo -e "\n\n----------\nPosting static mobile devices groups...\n"
		totalParsedResourceXML_staticGroups=$(ls "$localOutputDirectory"/mobiledevicegroups/parsed_xml/static_group_parsed* | wc -l | sed -e 's/^[ \t]*//')
		postInt_static=0	
		for parsedXML_static in $(ls "$localOutputDirectory"/mobiledevicegroups/parsed_xml/static_group_parsed*)
		do
			xmlPost_static=$parsedXML_static
			let "postInt_static = $postInt_static + 1"
			echo -e "\n----------\n----------"
			echo -e "\nPosting $parsedXML_static ( $postInt_static out of $totalParsedResourceXML_staticGroups ) \n"
	 		curl -k "$destinationJSS"JSSResource/mobiledevicegroups --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: text/xml" -X POST -T "$xmlPost_static"
		done
		echo -e "\n\n----------\nPosting smart mobile devices groups...\n"
		sleep 1
		totalParsedResourceXML_smartGroups=$(ls "$localOutputDirectory"/mobiledevicegroups/parsed_xml/smart_group_parsed* | wc -l | sed -e 's/^[ \t]*//')
		postInt_smart=0	
		for parsedXML_smart in $(ls "$localOutputDirectory"/mobiledevicegroups/parsed_xml/smart_group_parsed*)
		do
			xmlPost_smart=$parsedXML_smart
			let "postInt_smart = $postInt_smart + 1"
			echo -e "\n----------\n----------"
			echo -e "\nPosting $parsedXML_smart ( $postInt_smart out of $totalParsedResourceXML_smartGroups ) \n"
	 		curl -k "$destinationJSS"JSSResource/mobiledevicegroups --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: text/xml" -X POST -T "$xmlPost_smart"
		done		
elif [ $jssResource = "advancedcomputersearches" ]
	then 
		totalParsedResourceXML_advancedComputerSearches=$(ls "$localOutputDirectory"/advancedcomputersearches/parsed_xml/advanced_computer_search_parsed* | wc -l | sed -e 's/^[ \t]*//')
		postInt_smart=0	
		for parsedXML_smart in $(ls "$localOutputDirectory"/advancedcomputersearches/parsed_xml/advanced_computer_search_parsed*)
		do
			xmlPost_smart=$parsedXML_smart
			let "postInt_smart = $postInt_smart + 1"
			echo -e "\n----------\n----------"
			echo -e "\nPosting $parsedXML_smart ( $postInt_smart out of $totalParsedResourceXML_advancedComputerSearches ) \n"
	 		curl -k "$destinationJSS"JSSResource/advancedcomputersearches --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: text/xml" -X POST -T "$xmlPost_smart"
		done
elif [ $jssResource = "advancedmobiledevicesearches" ]
	then 
		totalParsedResourceXML_advancedMobileDeviceSearches=$(ls "$localOutputDirectory"/advancedmobiledevicesearches/parsed_xml/advanced_mobile_device_search_parsed* | wc -l | sed -e 's/^[ \t]*//')
		postInt_smart=0	
		for parsedXML_smart in $(ls "$localOutputDirectory"/advancedmobiledevicesearches/parsed_xml/advanced_mobile_device_search_parsed*)
		do
			xmlPost_smart=$parsedXML_smart
			let "postInt_smart = $postInt_smart + 1"
			echo -e "\n----------\n----------"
			echo -e "\nPosting $parsedXML_smart ( $postInt_smart out of $totalParsedResourceXML_advancedMobileDeviceSearches ) \n"
	 		curl -k "$destinationJSS"JSSResource/advancedmobiledevicesearches --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: text/xml" -X POST -T "$xmlPost_smart"
		done
else
	totalParsedResourceXML=$(ls "$localOutputDirectory"/"$jssResource"/parsed_xml | wc -l | sed -e 's/^[ \t]*//')
	postInt=0	
	for parsedXML in $(ls "$localOutputDirectory"/"$jssResource"/parsed_xml)
		do
			xmlPost="$localOutputDirectory"/"$jssResource"/parsed_xml/$parsedXML
			let "postInt = $postInt + 1"
			echo -e "\n----------\n----------"
			echo -e "\nPosting $parsedXML ( $postInt out of $totalParsedResourceXML ) \n"
	 		curl -k "$destinationJSS"JSSResource/$jssResource --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: text/xml" -X POST -T "$xmlPost"
		done
fi
if [ $jssResource != "null" ]
	then
		echo -e "\n\n**********\nPosting complete for $jssResource \n**********\n\n"
		read -p "Press RETURN to continue." returnKey
fi
}

manualUpload ()
{
clear
echo -e "\n\nYou have chosen to specify XML files to upload to a given resource."
echo -e "WARNING: No error control for this function."
echo -e "WARNING: Please only continue with this function if you know exactly what you are doing.\n\n"
read -p "API Resource (by name) : " jssResourceManualInput 
read -p "Source directory containing XML files : " resultOutputDirectory
echo -e "\nAre you creating new records (POST) or updating existing records (PUT)?"
read -p "Enter \"1\" for POST or \"2\" for PUT : " actionChoice
validChoice=999
until (( $validChoice == 1 ))
	do
		if (( $actionChoice == 1 ))
			then 
				echo "Proceeding to POST xml files..."
				curlAction="POST"
				validChoice=1
		elif (( $actionChoice == 2 ))
			then 
				echo "Proceeding to PUT xml files..."
				curlAction="PUT"
				validChoice=1
		else
			echo "Please enter a valid selection"
			read -p "Enter 1 for POST or 2 for PUT : " actionChoice
		fi
	done
echo -e "\n\n"

totalParsedResourceXML=$(ls "$resultOutputDirectory"/$manualPost | wc -l | sed -e 's/^[ \t]*//')
postInt=0			
		
for manualPost in $(ls "$resultOutputDirectory")  
	do 
		xmlPost="$resultOutputDirectory"/$manualPost
		let "postInt = $postInt + 1"
		echo -e "\n----------\n----------"
		echo -e "\nPosting $manualPost( $postInt out of $totalParsedResourceXML ) \n"
		curl -k "$destinationJSS"JSSResource/$jssResourceManualInput --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: text/xml" -X "$curlAction" -T "$xmlPost"
		
	done 
	
echo -e "\nExit or return to main menu?"
read -p "( \"x\" or \"m\" ) " exitChoice
case $exitChoice in
	[xX] | [Ee][Xx][Ii][Tt])
		echo -e "\nExiting..."
		exit 0
		;;
esac
}

exitDialog ()
{
echo -e "\n\n----------------------------------------\n\nThank you for using the JSS Migration Utility.  Goodbye.\n\n----------------------------------------\n"
exit 0
}

displayHelp ()
{
clear
echo "
README

The JSS Migration Utility uses the JAMF API to download resources from a source JSS and 
upload those resources to a destination JSS.  The utiltiy does NOT migrate computers.  
The primary goal and use-case for this utiltiy is to provide a mechanism where a JAMF 
admin can set up a barebones, clean JSS and import management resources (categories, 
scripts, extension attributes, computer groups, etc.) from another JSS instance.  This is 
perhaps most helpful when circumstances (e.g. a crufty database) prevent JSS migration via
the usual process - a database restore.

Basic Process:

1. XML files are downloaded from source JSS to local system 
2. XML files are parsed, depending on the current resource 
3. XML files are then uploaded to destination JSS

WARNINGS:

For this to work correctly, some data must be stripped from the downloaded XML before
uploading to new server.  This occurs during the parsing process.  Before each group of 
resource files are parsed, a warning will display explaining what data, if any, will be 
stripped.  For example, before the ldapservers resource files are parsed, you will see
this message -- 

Passwords for authenticating to LDAP will NOT be included!
You must enter passwords for LDAP in web app

Local File System:

By default, XML files are stored to ~/Desktop/JSS_Migration  Before work begins on each
resource, the utility looks for the presence of any previously downloaded resources and
archives to ~/Desktop/JSS_Migration/archives if necessary


"
read -p "Press RETURN key to return to main menu " returnChoice
}

displayMainMenu ()
{
clear
echo "

************ MAIN MENU ************

Which JSS resource would you like to migrate?

(WARNING - We strongly encourage you to proceed in order)

	 1 = Sites
	 2 = Categories
	 3 = LDAP Servers
	 4 = Accounts (JSS Admin Accounts and Groups)
	 5 = Buildings
	 6 = Departments
	 7 = Extension Attributes (for computers)
	 8 = Directory Bindings
	 9 = Dock Items
	10 = Removable MAC Addresses
	11 = Printers
	12 = Licensed Software
	13 = Scripts
	14 = Netboot Servers
	15 = Distribution Points
	16 = SUS Servers
	17 = Network Segments
	18 = Computer Groups
	19 = OS X Configuration Profiles
	20 = Restricted Software
	21 = Packages
	22 = Policies
	23 = Advanced Computer Searches
	24 = Advanced Mobile Device Searches
	25 = Mobile Device Groups
	26 = Mobile Device Configuration Profiles
	27 = Mobile Device Enrollment Profiles
	
	99 = Upload XML files from a specified directory to a specified resource
   		 (Useful if you have hand-edited XML files you need to upload)
   		 
	? = README
	
	 0 = EXIT
"
}

getMainMenuSelection ()
{
validChoice=9999
until (( $validChoice == 1 ))
	do
		displayMainMenu
		read -p "Enter the number which corresponds to the correct resource : " resourceNumber
		if [ "$resourceNumber" = "?" ]
			then validChoice=1
		elif (( $resourceNumber == 1 ))
			then 
				validChoice=1
				jssResource="sites"	
		elif (( $resourceNumber == 2 ))
			then
				validChoice=1 
				jssResource="categories"
		elif (( $resourceNumber == 3 ))
			then 
				validChoice=1
				jssResource="ldapservers"
		elif (( $resourceNumber == 4 ))
			then 
				validChoice=1
				jssResource="accounts"
		elif (( $resourceNumber == 5 ))
			then 
				validChoice=1
				jssResource="buildings"
		elif (( $resourceNumber == 6 ))
			then 
				validChoice=1
				jssResource="departments"
		elif (( $resourceNumber == 7 ))
			then 
				validChoice=1
				jssResource="computerextensionattributes"
		elif (( $resourceNumber == 8 ))
			then 
				validChoice=1
				jssResource="directorybindings"
		elif (( $resourceNumber == 9 ))
			then 
				validChoice=1
				jssResource="dockitems"
		elif (( $resourceNumber == 10 ))
			then 
				validChoice=1
				jssResource="removablemacaddresses"
		elif (( $resourceNumber == 11 ))
			then 
				validChoice=1
				jssResource="printers"
		elif (( $resourceNumber == 12 ))
			then 
				validChoice=1
				jssResource="licensedsoftware"
		elif (( $resourceNumber == 13 ))
			then 
				validChoice=1
				jssResource="scripts"
		elif (( $resourceNumber == 14 ))
			then 
				validChoice=1
				jssResource="netbootservers"
		elif (( $resourceNumber == 15 ))
			then 
				validChoice=1
				jssResource="distributionpoints"
		elif (( $resourceNumber == 16 ))
			then 
				validChoice=1
				jssResource="softwareupdateservers"
		elif (( $resourceNumber == 17 ))
			then 
				validChoice=1
				jssResource="networksegments"
		elif (( $resourceNumber == 18 ))
			then 
				validChoice=1
				jssResource="computergroups"
		elif (( $resourceNumber == 19 ))
			then 
				validChoice=1
				jssResource="osxconfigurationprofiles"
		elif (( $resourceNumber == 20 ))
			then 
				validChoice=1
				jssResource="restrictedsoftware"
		elif (( $resourceNumber == 21 ))
			then 
				validChoice=1
				jssResource="packages"
		elif (( $resourceNumber == 22 ))
			then 
				validChoice=1
				jssResource="policies"
		elif (( $resourceNumber == 23 ))
			then 
				validChoice=1
				jssResource="advancedcomputersearches"
		elif (( $resourceNumber == 24 ))
			then 
				validChoice=1
				jssResource="advancedmobiledevicesearches"
		elif (( $resourceNumber == 25 ))
			then 
				validChoice=1
				jssResource="mobiledevicegroups"
		elif (( $resourceNumber == 26 ))
			then 
				validChoice=1
				jssResource="mobiledeviceconfigurationprofiles"		
		elif (( $resourceNumber == 27 ))
			then 
				validChoice=1
				jssResource="mobiledeviceenrollmentprofiles"			
		elif (( $resourceNumber == 99 ))
			then
				validChoice=1
		elif (( $resourceNumber == 0 ))
			then
				validChoice=1
		else 
			echo -e "\n!!!!!!!!!!!!!!!!!!!!\nPlease select a valid number\n!!!!!!!!!!!!!!!!!!!!\n"
			sleep 3
		fi	
	done	
}

# MAIN

openingDialog
quitLoop=9999
until (( $quitLoop == 1 ))
	do
		getMainMenuSelection
		if [ "$resourceNumber" = "?" ]
			then displayHelp
		elif [ $resourceNumber = "99" ]
			then manualUpload
		elif [ $resourceNumber = "0" ]
			then
				quitLoop=1
				exitDialog
		else
			initializeDirectoriesPerResource
			setVariablesForResource
			createIDlist
			fetchResourceID
			parseResourceID
			pauseForManualCheck
			postResource
		fi
	done
	
exit 0
