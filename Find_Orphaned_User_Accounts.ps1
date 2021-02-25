#Microsoft 365: Find Users Last Logon Time (Orphaned User Accounts)

Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber
Connect-ExchangeOnline -UserPrincipalName cesarduran@cdirad.onmicrosoft.com -ShowProgress $true


#List orphaned Users - To find all users that haven’t logged in for 10 days run the code below.
#Just replace -10 by any number of your choosing
Get-ExoMailbox -ResultSize Unlimited -Filter "Name -notlike '*discover*'" |
Get-ExoMailboxStatistics -PropertySets All |
Where-Object LastLogonTime -LE (Get-Date).AddDays(-10) |
Sort-Object LastLogonTime |
Select-Object DisplayName, LastLogonTime,TotalItemSize