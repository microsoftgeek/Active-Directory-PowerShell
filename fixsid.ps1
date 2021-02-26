#------------------------------------------------------------------------------------------------------
 set-variable -name URI    -value "http://localhost:5725/resourcemanagementservice"    -option constant
 
 function GetSidAsBase64
{
    PARAM($AccountName, $Domain)
    END
    {
        $sidArray = [System.Convert]::FromBase64String("AQUAAAAAAAUVAAAA71I1JzEyxT2s9UYraQQAAA==") # This sid is a random value to allocate the byte array
        $args = (,$Domain)
        $args += $AccountName
        $ntaccount = New-Object System.Security.Principal.NTAccount $args
        $desiredSid = $ntaccount.Translate([System.Security.Principal.SecurityIdentifier])
		write-host " -Account SID : ($Domain\$AccountName) $desiredSid"
        $desiredSid.GetBinaryForm($sidArray,0)
        $desiredSidString = [System.Convert]::ToBase64String($sidArray)
        $desiredSidString
    }
}
#------------------------------------------------------------------------------------------------------
 write-host "`nFix Account ObjectSID"
 write-host "=========================="
#------------------------------------------------------------------------------------------------------
#Retrieve the Base64 encoded SID for the referenced user
 $accountSid = GetSidAsBase64 $AccountName $Domain
#------------------------------------------------------------------------------------------------------
#Export the account configuration from the service:
 write-host " -Reading Account information"
 if(@(get-pssnapin | where-object {$_.Name -eq "FIMAutomation"} ).count -eq 0) 
 {add-pssnapin FIMAutomation}
 
 $exportObject = export-fimconfig -uri $URI `
                                -onlyBaseResources `
                                -customconfig ("/Person[AccountName='$AccountName']")
 if($exportObject -eq $null) {throw "Cannot find an account by that name"} 
 $objectSID = $exportObject.ResourceManagementObject.ResourceManagementAttributes | `
                 Where-Object {$_.AttributeName -eq "ObjectSID"}

 Write-Host " -New Value = $accountSid"
 Write-Host " -Old Value =" $objectSID.Value
 
 if($accountSid -eq $objectSID.Value)
 	{
	Write-Host "Existing value is correct!"
	}
 else
 	{
	$importChange = New-Object Microsoft.ResourceManagement.Automation.ObjectModel.ImportChange
	$importChange.Operation = 1
	$importChange.AttributeName = "ObjectSID"
	$importChange.AttributeValue = $accountSid
	$importChange.FullyResolved = 1
	$importChange.Locale = "Invariant"
	$importObject = New-Object Microsoft.ResourceManagement.Automation.ObjectModel.ImportObject
	$importObject.ObjectType = $exportObject.ResourceManagementObject.ObjectType
	$importObject.TargetObjectIdentifier = $exportObject.ResourceManagementObject.ObjectIdentifier
	$importObject.SourceObjectIdentifier = $exportObject.ResourceManagementObject.ObjectIdentifier
	$importObject.State = 1 
	$importObject.Changes = (,$importChange)
	write-host " -Writing Account information ObjectSID = $accountSid"
	$importObject | Import-FIMConfig -uri $URI -ErrorVariable Err -ErrorAction SilentlyContinue
	if($Err){throw $Err}
	Write-Host "Success!"
	}
#------------------------------------------------------------------------------------------------------
 trap
 { 
    Write-Host "`nError: $($_.Exception.Message)`n" -foregroundcolor white -backgroundcolor darkred
    Exit
 }
#------------------------------------------------------------------------------------------------------
