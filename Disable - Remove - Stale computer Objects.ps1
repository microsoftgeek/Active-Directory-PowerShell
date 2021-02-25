#Script:	Stale_AD_Objects.vbs
#Purpose:  To check AD for stale computer objects based on date logon criteria and disable / delete
#Author:   Paperclips	
#Email:	pwd9000@hotmail.co.uk
#Date:     Oct 2013
#Comments: Can be scheduled to run e.g. weekly to eleviate manual checks
#Notes:  

$1year = (Get-Date).AddDays(-365) # The 365 is the number of days from today since the last logon.
$1y1m = (Get-Date).AddDays(-395)

# Disable computer objects and move to disabled OU (Older than 1 year):
Get-ADComputer -Property Name,lastLogonDate -Filter {lastLogonDate -lt $1year} | Set-ADComputer -Enabled $false
Get-ADComputer -Property Name,Enabled -Filter {Enabled -eq $False} | Move-ADObject -TargetPath "OU=Disabled Computers,DC=my,DC=domain,DC=local"

# Delete Older Disabled computer objects:
Get-ADComputer -Property Name,lastLogonDate -Filter {lastLogonDate -lt $1y1m} | Remove-ADComputer
