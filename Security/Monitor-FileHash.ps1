<#
.SYNOPSIS
    Monitors FileHash of files definded in c:\allegbin\FileMon.csv

.NOTES
    CREATE DATE:    2024-12-02
    CREATE AUTHOR:  Zackery Schwermer
    REV NOTES:
        v1.0: 2024-12-02 / Zackery Schwermer
        * Script created.
#>

# Exit script if FileMon.csv doesn't exist.
if (!(Get-item c:\allegbin\FileMon\FileMon.csv)) {
    Throw "c:\allegbin\FileMon\FileMon.csv Doesn't exist"
}

# Test files file for proper formatting.
if (!((Get-Content c:\allegbin\FileMon\FileMon.csv)[0] -match "^[Ff]ile$")) {
    Throw "First line of the file needs to be only 'File'"
}

$FilesToMonitor = Import-Csv c:\allegbin\FileMon\FileMon.csv
if (!(Get-item C:\allegbin\FileMon\FileInfo.csv -ErrorAction SilentlyContinue)) {
}
else {
    $PastFileInfo = Import-CSV -Path C:\allegbin\FileMon\FileInfo.csv
}

# Checking files in hashes.
foreach ($file in $FilesToMonitor) {
    if ((Get-item -Path $file.File).psiscontainer -eq $false) {
        $MD5Hash = (Get-FileHash -Path $file.File -Algorithm MD5).Hash
        $TimeStamp = (get-date).tostring("yyyyMMddTHHmmssffffZ")
        $FileInfo = Get-item -Path $file.file
        # SDDL is the string needed to restore permissions. with ConvertFrom-sddlstring.
        $SDDL = (Get-Acl -Path $file.File).sddl
        $info = [PSCustomObject]@{
            MD5Hash       = $MD5Hash
            DateRetrived  = $TimeStamp
            Path          = $fileInfo.FullName
            CreationTime  = $fileInfo.CreationTime.ToString("yyyyMMddTHHmmssffffZ")
            LastWriteTime = $FileInfo.LastWriteTime.ToString("yyyyMMddTHHmmssffffZ")
            SDDL          = $SDDL
        }
        if (!($PastFileInfo)) {
            $info | Export-Csv -Path C:\allegbin\FileMon\FileInfo.csv -NoTypeInformation -Append
        }
        else {
            if ($MD5HASH -ne ($PastFileInfo | Where-Object { $_.path -eq $file.File } | Sort-Object DateRetrived -Descending)[0].MD5Hash) {
                $info | Export-Csv -Path C:\allegbin\FileMon\FileInfo.csv -NoTypeInformation -Append
            }
        }

    }
    else {
        Write-Host $File.File " is not a file."
        continue
    }
}