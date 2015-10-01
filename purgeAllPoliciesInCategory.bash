#!/bin/bash

#Authenticate
read -p "Please enter your JSS URL (e.g. https://myJSS.myCompany.com:8443/)   : " jssURL
#jssURL="https://jssapp01.kdc.capitalone.com:8443/"
echo -e "\nPlease enter the name of the category"
echo "containing all policies you wish to purge."
echo -e "\nYou MUST replace any spaces in your category name with \"%20\""
echo "For example, a policy named \"My Policy\" should"
echo -e "be entered as \"My%20Policy\"\n"
read -p "Category Name : " jssCategory
read -p "Please enter your JSS user account : " jssUser
read -p "Please enter your JSS user password : " -s jssPassword

echo ""



#Generate raw xml file
curl -k "$jssURL"JSSResource/policies/category/"$jssCategory" --user "$jssUser:$jssPassword" > /private/tmp/jssPolicyList.xml

#Clean up the xml file
/usr/bin/xmllint -format /private/tmp/jssPolicyList.xml > /private/tmp/jssPolicyListFormatted.xml

#Create plain file of policy ID's
cat /private/tmp/jssPolicyListFormatted.xml | grep "<id>" | awk -F'<id>|</id>' '{print $2}' > /private/tmp/policyList.txt

policyList=$(cat /private/tmp/policyList.txt)

for policy in $policyList
	do
		curl -k "$jssURL"JSSResource/policies/id/$policy --user "$jssUser:$jssPassword" -X DELETE
	done

