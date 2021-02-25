$Path = "E:\AppTest"	## --- Put Folder-Path Here 
If (Test-Path $Path) {
	Write-Host
	Write-Host "Listing All Files Found In $Path" -ForegroundColor "Yellow"
	Write-Host "=========================================" -ForegroundColor "Yellow"

	Add-Type -assembly System.Windows.Forms

	## -- Create The Progress-Bar
	$ObjForm = New-Object System.Windows.Forms.Form
	$ObjForm.Text = "Demonstration of Progress-Bar In PowerShell"
	$ObjForm.Height = 100
	$ObjForm.Width = 500
	$ObjForm.BackColor = "White"

	$ObjForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
	$ObjForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

	## -- Create The Label
	$ObjLabel = New-Object System.Windows.Forms.Label
	$ObjLabel.Text = "Starting. Please wait ... "
	$ObjLabel.Left = 5
	$ObjLabel.Top = 10
	$ObjLabel.Width = 500 - 20
	$ObjLabel.Height = 15
	$ObjLabel.Font = "Tahoma"
	## -- Add the label to the Form
	$ObjForm.Controls.Add($ObjLabel)

	$PB = New-Object System.Windows.Forms.ProgressBar
	$PB.Name = "PowerShellProgressBar"
	$PB.Value = 0
	$PB.Style="Continuous"

	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = 500 - 40
	$System_Drawing_Size.Height = 20
	$PB.Size = $System_Drawing_Size
	$PB.Left = 5
	$PB.Top = 40
	$ObjForm.Controls.Add($PB)

	## -- Show the Progress-Bar and Start The PowerShell Script
	$ObjForm.Show() | Out-Null
	$ObjForm.Focus() | Out-NUll
	$ObjLabel.Text = "Starting. Please wait ... "
	$ObjForm.Refresh()

	Start-Sleep -Seconds 1

	## -- Execute The PowerShell Code and Update the Status of the Progress-Bar

	$Result = Get-ChildItem -Path $Path -File -Recurse -Force | Select Name, @{Name="Path";Expression={$_.FullName}}
	$Counter = 0
	ForEach ($Item In $Result) {
		## -- Calculate The Percentage Completed
		$Counter++
		[Int]$Percentage = ($Counter/$Result.Count)*100
		$PB.Value = $Percentage
		$ObjLabel.Text = "Recursive Search: Writing Names of All Files Found Inside $Path"
		$ObjForm.Refresh()
		Start-Sleep -Milliseconds 150
		# -- $Item.Name
		"`t" + $Item.Path

	}

	$ObjForm.Close()
	Write-Host "`n"
}
Else {
	Write-Host
	Write-Host "`t Cannot Execute The Script." -ForegroundColor "Yellow"
	Write-Host "`t $Path Does Not Exist in the System." -ForegroundColor "Yellow"
	Write-Host
}


