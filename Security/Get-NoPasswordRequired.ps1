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

# only run on the PDC to avoid tickets for each DC
if (((Get-ADDomain | Select-Object PDCEmulator).PDCEmulator -replace "\..*$","") -eq $env:computername) {

    # grab each trust so they can be excluded later
    $trustedDomains = @()
    $trusts = Get-AdTrust -filter * -properties FlatName
    foreach ($trust in $trusts) {
        $trustedDomains += "$($trust.FlatName)"
    }

    # get all users with PasswordNotRequired set
    $nonCompliantUsers = @()
    $nonCompliantUsers += Get-Aduser -filter {PasswordNotRequired -eq $true} -properties whenChanged
    # remove the accounts tied to domain trust from the list
    foreach ($domain in $trustedDomains) {
        $nonCompliantUsers = $nonCompliantUsers | where-object {$_.name -ne "$($domain)$"}
    }

    # return the list
    if ($nonCompliantUsers) {
        return $nonCompliantUsers
    } else {
        return $null
    }
} else {
    return $null
}
