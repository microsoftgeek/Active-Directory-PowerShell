$Computers = Get-Content c:\temp\decomm2.txt

foreach ($Computer in $Computers) {
    $ADComputer = $null
    $ADComputer = Get-ADComputer $Computer -Properties Description

    if ($ADComputer) {
        Add-Content C:\temp\export\computers.log -Value "Found $Computer, disabling"
        Set-ADComputer $ADComputer -Description "Server Decommissioned - Computer Disabled on $(Get-Date)" -Enabled $false
    } else {
        Add-Content C:\temp\export\computers.log -Value "$Computer not in Active Directory"
    }
}