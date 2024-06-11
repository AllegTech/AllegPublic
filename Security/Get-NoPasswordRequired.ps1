<#
.SYNOPSIS
    Returns a list of domain users with PasswordNotRequired set.
    Skips accounts used for domain trusts, as those are required to have PaswordNotRequired set.

.NOTES
    CREATE DATE:    2024-06-11
    CREATE AUTHOR:  Nick Noonan
    REV NOTES:
        v1.0: 2024-06-11 / Nick Noonan
        * Script created.
#>

# domain trust accounts need to have NoPasswordSet, so grab each trust
$trustedDomains = @()
$trusts = Get-AdTrust -filter * -properties FlatName
foreach ($trust in $trusts) {
    $trustedDomains += "$($trust.FlatName)"
}

# get all users with this set
$nonCompliantUsers = @()
$nonCompliantUsers += Get-Aduser -filter {PasswordNotRequired -eq $true} -properties whenChanged
# remove the accounts tied to domain trust from the list
foreach ($domain in $trustedDomains) {
    $nonCompliantUsers = $nonCompliantUsers | where-object {$_.name -ne "$($domain)$"}
}

return $nonCompliantUsers