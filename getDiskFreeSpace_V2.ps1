$servers = Get-ADComputer -Filter * -SearchBase "OU=servers,OU=Reno,OU=Plants,OU=LPS,DC=lifetouch,DC=net" | Select-Object -ExpandProperty name
#$path = 'C:\PSscripts\rdrivespace.txt'
#$pathcsv = 'C:\PSscripts\export.csv'
$log = 'C:\PSscripts\rdrivespace.log'
#$recepients = @('Hbahnsen@lifetouch.com')
$recepients = @('Hbahnsen@lifetouch.com','dkrainess@lifetouch.com','jlyda@lifetouch.com')
$PSEmailServer = 'LTIVRS1.lifetouch.net'
$ErrorActionPreference = "Stop"

$Script:html =  '<body style ="font-family: Arial; font-size; 10pt;">'
$Script:html += '<style>'
$Script:html += '#acctTable { width: auto; margin: 10px auto; max-width: 800px; border-separate: separate;}'
$Script:html += '#acctTable tr { border:1px solid #777; margin: 1px 1px;}'
$Script:html += '#acctTable th { border:none; background: #dedede; padding: 1px 1px;}'
$Script:html += '#acctTable thead { border:1px solid #3333; background: #adadad; padding: 1px 1px;}'
$Script:html += '#acctTable tr td {  border: 1px solid #333; }'
$Script:html += '</style>'
$Script:html += '<table id="acctTable" style ="border : 1px solid black; border-collapse: collapse;">'


$Script:table = New-Object system.Data.DataTable "EmailBody"
$Script:col1 = New-Object system.Data.DataColumn Server,([string])
$Script:col2 = New-Object system.Data.DataColumn Drive,([string])
$Script:col3 = New-Object system.Data.DataColumn DiskSize,([string])
$Script:col4 = New-Object system.Data.DataColumn Fspace,([string])
$Script:col5 = New-Object system.Data.DataColumn Percentage,([string])
$Script:table.columns.add($col1)
$Script:table.columns.add($col2)
$Script:table.columns.add($col3)
$Script:table.columns.add($col4)
$Script:table.columns.add($col5)


function Drivespace{ param ([string] $server)
    #Write-Host working on $server
    Try
    {

    $locDisk = get-wmiobject win32_logicaldisk -ComputerName $server -Filter "DriveType = 3"
    }   
    Catch
    {
    $server |Out-file $log -Append
    $_ | Out-File $log -Append

    }
    # Calculate drive %
    foreach ($disk in $locDisk){
    if ($disk.size -gt 0){$percentfree = [math]::round((($disk.freespace /$disk.size)*100))}
    else {$percentfree = 0}
    $Drive = $disk.deviceID
    $disksize =[math]::Round($disk.size/1GB,2)
    $freeSpace = [math]::Round($disk.freespace/1GB,2)
    $date= Get-Date -format "yyyy-MM-dd hh:mm:ss"
    #insert results on sql server
    $InsertResults = "INSERT INTO [DiskMonitor].[dbo].[FreeSpace](Computer,Drive,DiskSize,FreeSpace,Percentage,Date) VALUES ('$server','$Drive',$disksize,$freeSpace,$percentfree,'$date')"
    Invoke-sqlcmd -Query $InsertResults -ServerInstance RPWSQL002 -Database DiskMonitor 
    
    #Save info of drives with low space to table
    if($percentfree -le 25){
    $Script:row = $Script:table.NewRow()
    $Script:row.Server = $server
    $Script:row.drive = $drive
    $Script:row.DiskSize = $disksize
    $Script:row.Fspace = $freeSpace
    $Script:row.Percentage = $percentfree
    $script:table.Rows.Add($script:row)
    
    }
    }
}

foreach ($server in $servers){
    if( Test-Connection $server -BufferSize 16 -Count 1 -quiet){
    Drivespace "$server"
    }
    else{
        Write-host unable to access $server -ForegroundColor red
    }
}

#add data into table 
$Script:html += '<tr> <th colspan="5">Servers with low Hard Drive Space</th> </tr>'
$Script:html += '<thead><th>Server</th><th>Drive Letter</th><th>Disk Size</th><th>Free Space</th><th>Percentage</th></thead>'
foreach ($Script:Rows in $Script:table.Rows)
    { 
      $Script:html += "<tr><td>" + $Script:Rows[0] + "</td><td>" + $Script:Rows[1] + "</td><td>" + $Script:Rows[2] + "</td><td>" + $Script:Rows[3] + "</td><td>" + $Script:Rows[4] + "</td></tr>"
}
    
$Script:html += "</table></body>"
$Script:html += "<br /> If you have any questions please let me know.<br /> Thank you,<br /> <br /> Harro Bahnsen <br />"
$Script:html

#$body = Get-Content -Path $path -Raw
if(Test-Path $log){
send-MailMessage -To $recepients -From rpwcontrol002@lifetouch.com -Subject "Servers Low on Free Space Reno" -body  $Script:html -Attachments $log -BodyAsHtml
Remove-Item $log
}
else{
Send-MailMessage -To $recepients -From rpwcontrol002@lifetouch.com -Subject "Servers Low on Free Space Reno" -body $Script:html -BodyAsHtml
#Remove-Item $path
}
