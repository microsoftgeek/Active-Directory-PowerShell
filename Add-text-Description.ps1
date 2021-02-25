Import-Module ActiveDirectory
$Users = Import-csv c:\temp\sharedmbx.csv
foreach($User in $Users){
Set-ADUser $User.SamAccountName -Description $User.NewDescription
}