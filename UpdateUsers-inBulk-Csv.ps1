# UpdateUsersCsv.ps1
# Script to update Active Directory users in bulk according to the information in a CSV file.
# Author: Richard L. Mueller
# Version 1.0 - January 28, 2017

##### Modify the values in this section to meet your needs #####
# Specify the CSV and log files.
$CsvFile = ".\Users.csv"
$LogFile = ".\UpdateUsersCsv.log"

# The first line of the CSV is a header line defining the fields. Users are identified by the
# field named UserID. The array $Fields defines other fields in the CSV to be used to update
# users. The other fields must be either the lDAPDisplayNames of AD attributes or the supported
# properties of Set-ADUser. The supported properties are AccountExpirationDate, Enabled,
# Manager, PasswordNeverExpires, and SmartcardLogonRequired.
$Fields = @("title", "Enabled", "manager", "AccountExpirationDate", "mobile", "otherMobile")

# Flag to indicate whether users will be updated.
# Change $Update to $True to have users updated.
$Update = $False

# Number of errors allowed before the script aborts.
$MaxErrorsAllowed = 6
##### End of section with values to be modified #####

# Script version and date.
$Version = "Version 1.0 - January 28, 2017"

# Function to pad with blanks and right justify formatted integer values.
Function RightJustify($IntValue, $Size)
{
    # Format integer value for readability and pad with 10 blanks on the left.
    $Padded = "          $('{0:n0}' -f $IntValue)"
    # Right justify as much as needed to accomodate the largest value.
    Return $Padded.SubString($Padded.Length - $Size, $Size)
}

# Write to the log file. Abort the script if the log file cannot be updated.
Add-Content -Path $LogFile -Value "================================================" `
    -ErrorAction Stop
Add-Content -Path $LogFile -Value "UpdateUsersCsv.ps1"
Add-Content -Path $LogFile -Value "$Version"
Add-Content -Path $LogFile -Value "Update Users from CSV file: $CsvFile"
Add-Content -Path $LogFile -Value "Started: $((Get-Date).ToString())"
Add-Content -Path $LogFile -Value "Update flag: $Update"
Add-Content -Path $LogFile -Value "Maximum errors allowed: $MaxErrorsAllowed"
Add-Content -Path $LogFile -Value "Log file: $LogFile"
Add-Content -Path $LogFile -Value "------------------------------------------------"

Try {Import-Module ActiveDirectory -ErrorAction Stop -WarningAction Stop}
Catch
{
    Add-Content -Path $LogFile -Value "## ActiveDirectory module (or DC with ADWS) not found."
    Add-Content -Path $LogFile -Value "Error Message: $_"
    Write-Host "ActiveDirectory module (or DC with ADWS) not found!!" `
        -ForegroundColor Red -BackgroundColor Black
    Write-Host "Script Aborted." -ForegroundColor Red -BackgroundColor Black
    # Abort the script.
    Write-Host "See log file $LogFile"
    Break
}

# Initialize counters.
$Total = 0
$Updated = 0
$NotChanged = 0
$NotFound = 0
$Errors = 0

# Import the CSV file.
Try {$Users = Import-Csv $CsvFile}
Catch
{
    Add-Content -Path $LogFile -Value "## Invalid CSV file $CsvFile."
    Add-Content -Path $LogFile -Value "Error Message: $_"
    Write-Host "Invalid CSV file $CsvFile!!" `
        -ForegroundColor Red -BackgroundColor Black
    Write-Host "Script Aborted." -ForegroundColor Red -BackgroundColor Black
    Write-Host "See log file $LogFile"
    # Abort the script.
    Break
}

# Retrieve field names in the CSV file.
$CsvFields = $Users | Get-Member -MemberType noteproperty | Select Name

$Abort = $False

# Check for leading or trailing spaces in the CSV field names.
ForEach ($CsvField In $CsvFields)
{
    $CsvName = $CsvField.Name
    If ($CsvName.Trim() -ne $CsvName)
    {
        Add-Content -Path $LogFile -Value "## Field $CsvName in the CSV has a trailing space."
        Write-Host "Field $CsvName in the CSV file has a trailing space" `
            -ForegroundColor Red -BackgroundColor Black
        # Abort the script after checking all fields in the CSV and in the array $Fields.
        $Abort = $True
    }
}

# Check for the array $Fields in the script.
If (-Not $Fields)
{
    Add-Content -Path $LogFile -Value "## Array `$Fields not defined in the script."
    Write-Host "Array `$Fields not defined in the script!!" `
        -ForegroundColor Red -BackgroundColor Black
    Write-Host "Script Aborted." -ForegroundColor Red -BackgroundColor Black
    Write-Host "See log file $LogFile"
    # Abort the script.
    Break
}

# Consider all fields in the array $Fields.
ForEach ($Field In $Fields)
{
    # Check for leading or trailing spaces in the field names.
    If ($Field.Trim() -ne $Field)
    {
        Add-Content -Path $LogFile `
            -Value "## Field $Field has leading or trailing spaces in array `$Fields."
        Write-Host "Field $Field has leading or trailing spaces in array `$Fields" `
            -ForegroundColor Red -BackgroundColor Black
        # Consider all fields in $Fields before aborting the script.
        $Abort = $True
    }
    # Check for field UserID.
    If ($Field -eq "UserID")
    {
        Add-Content -Path $LogFile `
            -Value "## Field $Field should be removed from the array `$Fields in the script."
        Write-Host "Field $Field should be removed from the array `$Fields in the script" `
            -ForegroundColor Red -BackgroundColor Black
        # Consider all fields in $Fields before aborting the script.
        $Abort = $True
    }

    # Consider each field in the CSV file.
    $OK = $False
    ForEach ($CsvField In $CsvFields)
    {
        $CsvName = $CsvField.Name
        # Find the field in the CSV that matches the field in the array $Fields.
        If ($CsvName -eq $Field)
        {
            $OK = $True
            # Break out of the inner ForEach.
            Break
        }
    }
    If ($OK -eq $False)
    {
        Add-Content -Path $LogFile -Value "## Field $Field is not in the CSV file."
        Write-Host "Field $Field is not in the CSV file" `
            -ForegroundColor Red -BackgroundColor Black
        # Consider all fields in $Fields before aborting the script.
        $Abort = $True
    }
}
If ($Abort)
{
    Add-Content -Path $LogFile -Value "Script aborted."
    Write-Host "Script Aborted." -ForegroundColor Red -BackgroundColor Black
    Write-Host "See log file $LogFile"
    # Abort the script.
    Break
}

# Enumerate the users in the CSV file, one line at a time.
ForEach ($User In $Users)
{
    # Retrieve the UserID from the CSV file for this user.
    $ID = $User.UserID.Trim()

    # Retrieve existing values in AD of the relevant attributes and properties for this user.
    # Trap error if DC with Web Services not found or an attribute name is invalid.
    $ADUser = $Null
    Try {$ADUser = Get-ADUser -Identity "$ID" -Properties $Fields}
    Catch
    {
        # Abort the script if the specfied error is raised.
        If ("$_".StartsWith("Unable to find a default server"))
        {
            Add-Content -Path $LogFile -Value "## DC with AD Web Services not found."
            Add-Content -Path $LogFile -Value "Error Message: $_"
            Write-Host "DC with AD Web Services not found!!" `
                -ForegroundColor Red -BackgroundColor Black
            Write-Host "Script Aborted." -ForegroundColor Red -BackgroundColor Black
            Write-Host "See log file $LogFile"
            # Break out of the ForEach that loops through each line of the CSV.
            $Abort = $True
            Break
        }
        ElseIf ("$_".StartsWith("One or more properties are invalid"))
        {
            Add-Content -Path $LogFile -Value "## Array `$Fields has invalid attribute."
            Add-Content -Path $LogFile -Value "Error Message: $_"
            Write-Host "Array `$Fields has invalid attribute name!!" `
                -ForegroundColor Red -BackgroundColor Black
            Write-Host "Script Aborted." -ForegroundColor Red -BackgroundColor Black
            Write-Host "See log file $LogFile"
            # Break out of the ForEach that loops through each line of the CSV.
            $Abort = $True
            Break
        }
        ElseIf ("$_".StartsWith("Cannot find an object with identity"))
        {
            # User not found, continue.
        }
        Else
        {
            Add-Content -Path $LogFile -Value "## Unexpected error with UserID $UserID."
            Add-Content -Path $LogFile -Value "Error Message: $_"
            Write-Host "Unexpected error with UserID $ID!!" `
                -ForegroundColor Red -BackgroundColor Black
            Write-Host "Script Aborted." -ForegroundColor Red -BackgroundColor Black
            Write-Host "See log file $LogFile"
            # Break out of the ForEach that loops through each line of the CSV.
            $Abort = $True
            Break
        }
    } # End of Catch.
    # Make sure the user is found in AD.
    If ($ADUser)
    {
        $Total = $Total + 1
        # Hash table of the attributes to replace for this user.
        $AttrReplace = @{}
        # Array of attributes to clear for this user.
        $AttrClear = @()
        # String of parameters of the Set-ADUser cmdlet to use to update this user.
        $Parameters = ""
        # List of parameters for the log file.
        $Params = "Parameters used:"

        # Construct the PowerShell command to update the user as a string.
        # Quote the UserID in case it includes any embedded spaces.
        $Cmd = "Set-ADUser -Identity ""$ID"""

        # Consider all fields in the array of CSV fields.
        ForEach ($Field In $Fields)
        {
            # Retrieve the value of this field for this user in the CSV file.
            # Remove any leading or trailing spaces from the value.
            $Value = $User.$Field.Trim()

            # Compare $True or $False in the CSV with True or False in AD.
            If (($Value -eq "`$True") -Or ($Value -eq "True"))
            {
                $CompareValue = "True"
            }
            ElseIf (($Value -eq "`$False") -Or ($Value -eq "False"))
            {
                $CompareValue = "False"
            }
            ElseIf (($Field -eq "AccountExpirationDate") -And ($Value))
            {
                # Do not convert the value "<delete>" into a datetime.
                If ($Value -eq "<delete>") {$CompareValue = $Value}
                Else
                {
                    # If the field is AccountExpirationDate, convert the value to a datetime.
                    $CompareValue = [datetime]$Value
                }
            }
            Else {$CompareValue = $Value}

            # Retrieve the value of this attribute for this user in AD.
            $ADValue = $ADUser.$Field

            # Only update each attribute or property if the value in the CSV is not missing
            # and differs from the existing value in AD.
            If (($Value) -And ($CompareValue -ne $ADValue))
            {
                # Look for supported PowerShell properties of the Set-ADUser cmdlet.
                Switch ($Field)
                {
                    "AccountExpirationDate"
                    {
                        # If the value is the string "<delete>", then clear the attribute.
                        If ($Value -eq "<delete>")
                        {
                            # Make sure the attribute has a value to be cleared.
                            If ($ADValue)
                            {
                                # The corresponding attribute is accountExpires.
                                # This attribute is cleared by assigning the value 2^63 - 1.
                                $AttrReplace.Add("accountExpires", 9223372036854775807)
                            }
                        }
                        Else
                        {
                            $Prop = [datetime]$Value
                            # Quote the value, since it can have spaces.
                            $Parameters = "$Parameters -AccountExpirationDate ""$Prop"""
                            $Params = "$Params AccountExpiratonDate"
                        }
                    }
                    "Enabled"
                    {
                        If ($Value -eq "True") {$Value = "`$True"}
                        ElseIf ($Value -eq "False") {$Value = "`$False"}
                        $Parameters = "$Parameters -Enabled $Value"
                        $Params = "$Params Enabled"
                    }
                    "Manager"
                    {
                        # If the value is the string "<delete>", then clear the attribute.
                        If ($Value -eq "<delete>")
                        {
                            # Make sure the attribute has a value to be cleared.
                            # The corresponding attribute is manager.
                            If ($ADValue) {$AttrClear = $AttrClear + "manager"}
                        }
                        Else
                        {
                            # Quote the value, since it can have spaces.
                            $Parameters = "$Parameters -Manager ""$Value"""
                            $Params = "$Params Manager"
                        }
                    }
                    "PasswordNeverExpires"
                    {
                        If ($Value -eq "True") {$Value = "`$True"}
                        ElseIf ($Value -eq "False") {$Value = "`$False"}
                        $Parameters = "$Parameters -PasswordNeverExpires $Value"
                        $Params = "$Params PasswordNeverExpires"
                    }
                    "SmartcardLogonRequired"
                    {
                        If ($Value -eq "True") {$Value = "`$True"}
                        ElseIf ($Value -eq "False") {$Value = "`$False"}
                        $Parameters = "$Parameters -SmartcardLogonRequired $Value"
                        $Params = "$Params SmartcardLogonRequired"
                    }
                    Default
                    {
                        # Field name assumed to be the lDAPDisplayName of an AD attribute.
                        # If the value is the string "<delete>", then clear the attribute.
                        If ($Value -eq "<delete>")
                        {
                            # Make sure the attribute has a value to be cleared.
                            If ($ADValue -ne $Null) {$AttrClear = $AttrClear + $Field}
                        }
                        Else
                        {
                            # Attribute value to be replaced in AD with value from the CSV file.
                            # Boolean attributes require that values be capitalized.
                            If (($Value -eq "`$True") -Or ($Value -eq "True"))
                            {$Value = "TRUE"}
                            ElseIf (($Value -eq "`$False") -Or ($Value -eq "False"))
                            {$Value = "FALSE"}
                            $AttrReplace.Add($Field, $Value)
                        }
                    } # End of Default in Switch.
                } # End of Switch.
            } # End of code to determine how and if this field should be modified.
        } # End of ForEach loop to handle all the fields in the array of CSV fields.

        $NumReplace = $AttrReplace.Count
        $NumClear = $AttrClear.Count

        # Only update the user if the $Update flag is set to $True.
        If ($Update -eq $True)
        {
            $UpdRepl = $False
            $UpdParam = $False
            # Only update the user when necessary.
            If (($NumReplace -eq 0) -And ($NumClear -eq 0) -And ($Parameters -eq ""))
            {
                Add-Content -Path $LogFile -Value "No change for user $ID"
                $NotChanged = $NotChanged + 1
            }
            Else
            {
                # The user should be updated.
                Add-Content -Path $LogFile -Value "Update User: $ID"
                If ($NumReplace -ge 1)
                {
                    # The -Replace parameter must be used separately, because the hash table
                    # cannot be converted from a String into a Hashtable in the script block.
                    Try
                    {
                        Set-ADUser -Identity "$ID" -Replace $AttrReplace
                        Add-Content -Path $LogFile -Value "    Attributes replaced: $NumReplace"
                        $UpdRepl = $True
                    } # End of Try.
                    Catch
                    {
                        Add-Content -Path $LogFile `
                            -Value "## Error replacing attributes for user $ID"
                        Add-Content -Path $LogFile -Value "    Error Message: $_"
                        $Errors = $Errors + 1
                        # Allow only the specified number of errors before aborting the script.
                        If ($Errors -gt $MaxErrorsAllowed)
                        {
                            Add-Content -Path $LogFile `
                                -Value "## More Than $MaxErrorsAllowed Errors"
                            Add-Content -Path $LogFile `
                                -Value "    Script Aborted."
                            Write-Host "More Than $MaxErrorsAllowed Errors Encountered!!" `
                                -ForegroundColor Red -BackgroundColor Black
                            Write-Host "Script Aborted." `
                                -ForegroundColor Red -BackgroundColor Black
                            # Break out of the ForEach that loops through each line of the CSV.
                            Break
                        }
                    } # End of Catch.
                } # End of code when there is at least one attribute value to replace.
                # Construct the PowerShell command to update the user
                # using the remaining parameters.
                If ($NumClear -ge 1)
                {
                    $Cmd = "$Cmd -Clear $AttrClear"
                    Add-Content -Path $LogFile -Value "    Attributes cleared:  $NumClear"
                }
                If ($Parameters -ne "")
                {
                    $Cmd = "$Cmd$Parameters"
                    Add-Content -Path $LogFile -Value "    $Params"
                }
                Try
                {
                    # Convert the string into a script block so it can be executed.
                    $Command = [scriptblock]::Create("$Cmd")
                    # Run the PowerShell command to update the user.
                    Invoke-Command -ScriptBlock $Command
                    $UpdParam = $True
                } # End of Try.
                Catch
                {
                    Add-Content -Path $LogFile -Value "## Error updating user $ID"
                    Add-Content -Path $LogFile -Value "    Error Message: $_"
                    $Errors = $Errors + 1
                    # Allow only the specified number of errors before aborting the script.
                    If ($Errors -gt $MaxErrorsAllowed)
                    {
                        Add-Content -Path $LogFile `
                            -Value "## More Than $MaxErrorsAllowed Errors"
                        Add-Content -Path $LogFile `
                            -Value "    Script Aborted."
                        Write-Host "More Than $MaxErrorsAllowed Errors Encountered!!" `
                            -ForegroundColor Red -BackgroundColor Black
                        Write-Host "Script Aborted." -ForegroundColor Red -BackgroundColor Black
                        # Break out of the ForEach that loops through each line of the CSV.
                        Break
                    }
                } # End of Catch.
                If (($UpdRepl) -Or ($UpdParam)) {$Updated = $Updated + 1}
            } # End of Else code to update the user only when necessary.
        } # End of code when $Update is $True.
        Else
        {
            # The flag $Update is $False.
            If (($NumReplace -ge 1) -Or ($NumClear -ge 1) -Or ($Parameters -ne ""))
            {
                # User could be updated, if $Update flag were $True.
                Add-Content -Path $LogFile -Value "User $ID could be updated"
                $Updated = $Updated + 1
            }
            Else
            {
                Add-Content -Path $LogFile -Value "No change for user $ID"
                $NotChanged = $NotChanged + 1
            }
            If ($NumReplace -ge 1)
            {
                Add-Content -Path $LogFile `
                    -Value "    Attributes could be replaced: $NumReplace"
            }
            If ($NumClear -ge 1)
            {
                Add-Content -Path $LogFile `
                    -Value "    Attributes could be cleared:  $NumClear"
            }
            If ($Parameters -ne "")
            {
                Add-Content -Path $LogFile -Value "    $Params"
            }
        } # End of code when $Update is $False.
    } # End of code to handle when the user is found in AD.
    Else
    {
        # The user is not found in AD.
        $NotFound = $NotFound + 1
        $Errors = $Errors + 1
        Add-Content -Path $LogFile -Value "User with ID $ID not found"
        # Allow only the specified number of errors before aborting the script.
        If ($Errors -gt $MaxErrorsAllowed)
        {
            Add-Content -Path $LogFile `
                -Value "## More Than $MaxErrorsAllowed Errors"
            Add-Content -Path $LogFile `
                -Value "    Script Aborted."
            Write-Host "More Than $MaxErrorsAllowed Errors Encountered!!" `
                -ForegroundColor Red -BackgroundColor Black
            Write-Host "Script Aborted." -ForegroundColor Red -BackgroundColor Black
            # Break out of the ForEach that loops through each line of the CSV.
            Break
        }
    } # End of code when the user is not found in AD.
} # End of the ForEach loop that reads lines of the CSV file.

Add-Content -Path $LogFile -Value "------------------------------------------------"
Add-Content -Path $LogFile -Value "Finished: $((Get-Date).ToString())"
If ($Abort -eq $True)
{
    # No need to output totals.
    Add-Content -Path $LogFile -Value "Script Aborted."
    Break
}

# Maximum integer length for right justifying the output.
$TotalSize = $('{0:n0}' -f ($Total + $NotFound)).Length

# Add totals to the log file.
Add-Content -Path $LogFile `
    -Value "Number of users processed:   $(RightJustify $Total $TotalSize)"
If ($Update -eq $True)
{
    Add-Content -Path $LogFile `
        -Value "Number of users updated:     $(RightJustify $Updated $TotalSize)"
}
Else
{
    Add-Content -Path $LogFile `
        -Value "Users that could be updated: $(RightJustify $Updated $TotalSize)"
}
Add-Content -Path $LogFile `
    -Value "Number of users not changed: $(RightJustify $NotChanged $TotalSize)"
Add-Content -Path $LogFile `
    -Value "Number of users not found:   $(RightJustify $NotFound $TotalSize)"
Add-Content -Path $LogFile `
    -Value "Number of errors:            $(RightJustify $Errors $TotalSize)"

Write-Host "Done. See log file $LogFile"
