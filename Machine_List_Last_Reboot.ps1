# Powershell script to check Last Reboot Time on a list of machines included in a text file
# Author - Vikram Bedi 
# vikram.bedi.it@gmail.com 


$machines = Get-Content C:\Users\<User Alias>\Desktop\Machine_List.txt
$report = @()
$object = @()
foreach($machine in $machines)
{
$machine
$object = gwmi win32_operatingsystem -ComputerName $machine | select csname, @{LABEL='LastBootUpTime';EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}
$report += $object
}
$report | Export-csv C:\Users\<User Alias>\Desktop\Reboot.csv