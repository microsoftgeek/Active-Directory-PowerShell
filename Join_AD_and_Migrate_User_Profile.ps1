$DNS1='9.9.9.9'
$DNS2='10.170.0.100'
$DomainName='contoso.com'

#######################################################################################################
# This script will join the computer to domain as defined $DomainName and migrate the existing user's #
# profile to new domain users. Don't worry. This script will prompt the user every time before system #
# changes occurs. A Domain user's username & password will be asked. Admin needs to define the DNS    #
# Servers and Domain Name in the header sections. You can change the profile back to old user by      #
# manually renaming the following registry from new domain user's SID to local user's SID.            #
# Computer\HKey_Local_Machine\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\<yourNewSID>   #
# The respective old and new SID values are backed up to file in C:\Users\<yourName>\UserSID.txt file.#
# Supported from Powershell v2.0. Run as Administrator if permission issue occurs. You can compile the#
# script to .exe and distribute to users for bulk deployment and to bypass powershell execution policy#
# Author: phyoepaing3.142@gmail.com                                                                   #
# Released Date: 10/15/2016                                                                           #
# version: 1.0                                                                                        #
# Country: Myanmar                                                                                    #
#######################################################################################################

############### function to test if TCP Port 53 is open in DNS Servers #####
function Test-DNS { param([string]$Destination,[string]$Port)
$Socket= New-Object Net.Sockets.TcpClient
$IAsyncResult= [IAsyncResult] $Socket.BeginConnect($Destination,$Port,$null,$null)
$success=$IAsyncResult.AsyncWaitHandle.WaitOne(500,$true)   ## Adjust the port test time-out in milli-seconds, here is 500ms
Return $Socket.Connected
$Socket.close()
}

################ function to get SID of user #####################
function Get-SID ([string]$User)
{
$objUser = New-Object System.Security.Principal.NTAccount($User)
$strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
$strSID.Value
}
################ Test TCP Port 53 of DNS Servers #################
if(Test-DNS $DNS1 '53')
{ 
Write-Host -Fore Green "Connection to DNS Server $DNS1 is OK."
$DNS1_OK=1;
}
else
{
Write-Host "Connection to DNS Server $DNS1 is NOT OK."
$DNS1_OK=0;
}
if(Test-DNS $DNS2 '53')
{ 
Write-Host -Fore Green "Connection to DNS Server $DNS2 is OK."
$DNS2_OK=1;
}
else
{
Write-Host "Connection to DNS Server $DNS2 is NOT OK."
$DNS2_OK=0;
}
If ((!$DNS1_OK) -AND (!$DNS2_OK))
{ Write-Host -Fore Red "Cannot connect to both DNS Server.`nPlease contact your network administrator. Now exists.";
Exit;
}
############# Swap the primary & secondary DNS Settings if the secondary DNS Server is connected where primary is not #######
If (!$DNS1_OK -AND $DNS2_OK)
{
$TempDNS=$DNS1
$DNS1=$DNS2
$DNS2=$TempDNS
}
############# Check DNS Settings for each Network Adapter and Prompt the user to correct if not correct ############
$Netinfo=Get-WmiObject Win32_NetworkAdapterConfiguration -filter "ipenabled=true"

$Netinfo | foreach {
If(!$_.DNSServerSearchOrder)
	{
	Write-Host -Fore Yellow "Client DNS Settings are empty for $($_.Description) Adapter."
	$Correct_DNS_Settings = Read-Host "Do you want to correct Client DNS Settings(y/n)?"
	while($Correct_DNS_Settings -ne 'y' -AND $Correct_DNS_Settings -ne 'n')
		{
		Write-Host "Please only type 'y' or 'n'."
		$Correct_DNS_Settings = Read-Host "Do you want to correct Client DNS Settings(y/n)?"
		}
	If ($Correct_DNS_Settings -eq 'y')
		{
		$DNS_Change_Result = $_.SetDNSServerSearchOrder($(If($DNS1 -AND $DNS2){$DNS1,$DNS2} elseif($DNS1){$DNS1} else{$DNS2}))
		If (!$DNS_Change_Result.ReturnValue)
		{
		Write-Host -Fore Cyan "DNS Setting of $($_.Description) has been changed to $DNS1 $(if($DNS2){"and $DNS2"})"
		}
		else
		{
		Write-Host -Fore Red "Cannot change DNS Setting for $($_.Description). Please make sure you have necessary permission or Run Powershell as Administrator. Now exit."
		Exit;
		}
		}
	}
elseif( $Dns1 -contains $_.DNSServerSearchOrder[0] -AND $DNS2 -contains $_.DNSServerSearchOrder[1]  )
	{
	Write-Host "Client DNS Settings of $($_.Description) is correct."
	}
else
	{
	Write-Host -Fore Red "Client DNS Settings of $($_.Description) is not correct."
	$Correct_DNS_Settings = Read-Host "Do you want to correct Client DNS Settings(y/n)?"
		while($Correct_DNS_Settings -ne 'y' -AND $Correct_DNS_Settings -ne 'n')
		{
		Write-Host "Please only type 'y' or 'n'."
		$Correct_DNS_Settings = Read-Host "Do you want to correct Client DNS Settings(y/n)?"
		}
	If ($Correct_DNS_Settings -eq 'y')
		{
		$DNS_Change_Result = $_.SetDNSServerSearchOrder($($DNS1,$DNS2))
		If (!$DNS_Change_Result.ReturnValue)
		{
		Write-Host -Fore Cyan "DNS Setting of $($_.Description) has been changed to $DNS1 $(if($DNS2){"and $DNS2"})"
		}
		else
		{
		Write-Host -Fore Red "Cannot change DNS Setting for $($_.Description). Please make sure you have necessary permission or Run Powershell as Administrator. Now exit."
		Exit;
		}
		}
	}
}
############## Prompt the user to join to domain or not #######################
$ComfirmDomainJoin=Read-Host "Do you want to continue joining to Domain?"
while($ComfirmDomainJoin -ne 'y' -AND $ComfirmDomainJoin -ne 'n')
{
Write-Host "Please only type 'y' or 'n'."
$ComfirmDomainJoin=Read-Host "Do you want to continue joining to Domain?"
}

############## If user choose to join domain, prompt for credentials and extract only domain user name from credential #####
If($ComfirmDomainJoin -eq 'y')
{
$username = Read-Host "Enter Domain User Name"
$password = Read-Host  -AsSecureString "Enter Password"
$Credential = New-Object System.Management.Automation.PSCredential($username,$password)

############## If the password is not blank, reconstruct the user name to the UPN format for domain join #############
If ($Credential.GetNetworkCredential().password)
{
$NewUser = $Credential.GetNetworkCredential().UserName
$NewSPN_Name=$NewUser+'@'+$DomainName			## Append @ for standard UPN
$Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $NewSPN_Name, $Credential.Password	## Create new Credential Object with UPN
Write-Host -Fore Cyan "Joining to domain. Please wait..."

############## Join the domain ########################################################
Try
	{
	$DomainJoinResult=Add-Computer -DomainName $DomainName -Credential $Cred -PassThru -EA Stop -WarningAction SilentlyContinue
	Start-Sleep 1;              ## Time wait before domain user SID is fetched.
	}
catch
	{
	Write-Host -Fore Red "Cannot join to domain. This may be due to:"
	Write-Host -Fore Red "1) Incorrect username & password."
	Write-Host -Fore Red "2) Windows Powershell Console is not Run as Administrator."
	}
}
else
{
Write-Host -Fore Red "User Password is empty. Please run the program again type a valid password."
}

############### If the domain join is succeed then continue profile migration state ##############
If ($DomainJoinResult.HasSucceeded)
{
Write-Host -Fore Green "The computer has been successfully joined to domain."
################ Get current user SID & new user SID ############
$CurrentUser = [Environment]::UserName
$CurrentUserSID= Get-SID $CurrentUser
$NewUserSID= Get-SID $NewSPN_Name

################# Prompt users for current profile migration to new domain user ##############
$Migrate_Profile = Read-Host "`nDo you want to migrate $CurrentUser`'s profile to new `'$NewSPN_Name`' user. This will also keep user preference settings such as Desktop Wallpaper,Internet explorer settings etc.(y/n)?"
while($Migrate_Profile -ne 'y' -AND $Migrate_Profile -ne 'n')
{
Write-Host "Please only type 'y' or 'n'."
$Migrate_Profile = Read-Host "Do you want to migrate $CurrentUser`'s profile to new $NewSPN_Name user. This will also keep user preference settings such as Desktop Wallpaper,Internet explorer settings etc.(y/n)?"
}

If ($Migrate_Profile -eq 'y')
{
##################### Assign full permission of Current User's home directory to new user ################
$Acl = (Get-Item $home).GetAccessControl('Access')
$Ar = New-Object system.security.accesscontrol.filesystemaccessrule($NewSPN_Name,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
$Acl.SetAccessRule($Ar)
$Acl | Set-Acl -Path $home

###################### Backup current user's SID to file in home directory(comment below 2 lines if not needed)#################
Write-Host "$CurrentUser`'s SID $CurrentUserSID is saved to file in $home\UserSID.txt."
Set-Content $home\UserSID.txt "SID of $CurrentUser `r`n$CurrentUserSID`r`n`r`nSID of $NewSPN_Name SID `r`n$NewUserSID"

####################### If AD Join is OK, then change registry of current user SID to new user SID ##############
Rename-Item "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\$CurrentUserSID" -NewName $NewUserSID

####################### Change Security Permission of Current User's SID Profile and Profile's SID_Classes key registry ###############
$Acl = Get-Acl "Registry::HKU\$CurrentUserSID"
$rule = New-Object System.Security.AccessControl.RegistryAccessRule ($NewSPN_Name,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
$Acl.SetAccessRule($rule)
$Acl |Set-Acl -Path "Registry::HKU\$CurrentUserSID"

$Acl = Get-Acl "Registry::HKU\$($CurrentUserSID)_Classes"
$rule = New-Object System.Security.AccessControl.RegistryAccessRule ($NewSPN_Name,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
$Acl.SetAccessRule($rule)
$Acl |Set-Acl -Path "Registry::HKU\$($CurrentUserSID)_Classes"
Write-Host -Fore Green "Current $CurrentUser`'s profile has been migrated successfully to new $NewSPN_Name."
}
####################### Prompt the user to restart the computer ############################
$Restart=Read-Host "`nDo you want to restart the computer now and login as new domain user($NewSPN_Name)? If you choose 'y', please close your programs and save your work?(y/n)"
If ($Restart -eq 'y')
{ Restart-Computer -Force }
}
}

