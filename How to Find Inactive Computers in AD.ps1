$DaysInactive = 90
$time = (Get-Date).Adddays(-($DaysInactive))
Get-ADComputer -Filter {LastLogonTimeStamp -lt $time} -ResultPageSize 2000 -resultSetSize $null -Properties Name, OperatingSystem, SamAccountName, DistinguishedName


#To export the output to a CSV file, add the Export-CSV PowerShell cmdlet, as shown below:

Get-ADComputer -Filter {LastLogonTimeStamp -lt $time} -ResultPageSize 2000 -resultSetSize $null -Properties Name, OperatingSystem, SamAccountName, DistinguishedName | Export-CSV “C:\Temp\StaleComps.CSV” –NoTypeInformation

