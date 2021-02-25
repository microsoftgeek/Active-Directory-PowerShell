get-aduser -filter 'enabled -eq $true' -Properties lastlogondate | Where-object {$_.lastlogondate -lt (get-date).AddDays(-90)} | Export-csv C:\temp\users.csv -NoTypeInformation -Force -Delimiter ";"

#New PSscript below

get-aduser -filter 'enabled -eq $true' -Properties lastlogondate -SearchBase "ou=mfg,dc=noam,dc=corp,dc=contoso,dc=com" | Where-object {$_.lastlogondate -lt (get-date).AddDays(-90)} | Export-csv C:\temp\users.csv -NoTypeInformation -Force -Delimiter ";"

