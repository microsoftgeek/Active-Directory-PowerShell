$users = (Get-ADUser -Filter * -SearchBase "DC=cdirad,DC=net").samaccountname | Sort-Object
$formatenumerationlimit = -1

foreach ($user in $Users) {
    $groups = Get-ADPrincipalGroupMembership -Identity $user

    $obj = new-object psobject -Property @{
        Username        = $user
        GroupMembership = $groups.samaccountname
    }

    $obj | Format-Table Username, GroupMembership -auto
    
    }