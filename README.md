JSSAPIScripts
==================

Utility scripts featuring the JAMF API by Jeffrey Compton

==================

###Index
[jssMigration_1.1.bash]
[getSelfServicePolicyicons.bash]

####**jssMigration_1.1.bash**<br>

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

####**getSelfServicePolicyicons.bash**<br>
