# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Filename	:	Remove_ComputerFromGroup.ps1
# Purpose	:	Removes a computer object from an Active Directory group. The 
# 			group and the computer must both already be present in Active 
#			Directory.
# Versions	:	2017.05.15 - Created.

Param(
    [Parameter(Mandatory=$True)][string]$Computer,
    [Parameter(Mandatory=$True)][String]$Group
)

# Set the ErrorActionPreference to SilentlyContinue, because the -ErrorAction 
# option doesn't work with Get-ADComputer or Get-ADGroup.
$ErrorActionPreference = "SilentlyContinue"

# Get the computer and group from AD to make sure they are valid.
$ComputerObject = Get-ADComputer $Computer
$GroupObject = Get-ADGroup $Group

if ($ComputerObject) {
    if ($GroupObject) {
        # If both the computer and the group exist, remove the computer from 
        # the group.
        Remove-ADGroupMember $Group `
            -Members (Get-ADComputer $Computer).DistinguishedName -Confirm:$False
        Write-Host " "
        Write-Host "The computer, ""$Computer"", has been removed from the group, ""$Group""." `
            -ForegroundColor Yellow
        Write-Host " "
    }
    else {
        Write-Host " "
        Write-Host "I could not find the group, ""$Group"", in Active Directory." `
            -ForegroundColor Red
        Write-Host " "
    }
}
else {
    Write-Host " "
    Write-Host "I could not find the computer, $Computer, in Active Directory." `
        -ForegroundColor Red
    Write-Host " "
}