
param(
    [Parameter(Mandatory = $true)]$iperfTestServer,
    $port = 6900,
    [int32]$test_length = 30,
    [parameter(Mandatory = $true)]$toaddresses,
    [parameter(Mandatory = $true)]$smtpserver,
    [int32]$smtpport = 25,
    [parameter(Mandatory = $true)]$smtpuser,
    [parameter(Mandatory = $true)]$smtppw,
    [parameter(Mandatory = $true)]$fromaddress
)

$smtppw = ConvertTo-SecureString $smtppw -AsPlainText -Force
$smtpcredentials = new-object System.Management.Automation.PSCredential ($smtpuser, $smtppw)
$timestamp = get-date -Format yyyy-MM-dd_HH-mm

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#check to see if folder exist.
if (!(get-item "c:\allegbin" -ErrorAction SilentlyContinue)) { new-item -name allegbin -Path "C:\" -ItemType Directory }
$filestodownload = @"
{
    "files":[
        {"file":"iperf3.exe","hash":"39BD5AE4D92DF883E7FC6BAEBAC1C4345D8BB6BABDB3AAE89EC09D155A769DA4"},
        {"file":"cygcrypto-3.dll","hash":"3F5EC2C1A18439A10B360971411CE7F6E86562664D583EBD15566C4C14D8808C"},
        {"file":"cygwin1.dll","hash":"AB77212A71C2E2E8B870452D2C32BC72A6708D6E963DD3EBE2AC1A946CFFC242"},
        {"file":"cygz.dll","hash":"6B8C8A8F27692D167694C8B22E997DADFC20ABA1182BCC1410F335533CA301F3"}
    ]
}
"@ | convertfrom-json
#check to see if files exist.
foreach ($file in $filestodownload.files) {
    write-host "----"
    write-host "Working on $($file.file)"
    if (!(get-item "c:\allegbin\$($file.file)" -ErrorAction SilentlyContinue)) {
        write-host "Downloading $($file.file)"
        $source = "https://sftp.allegiantnetworks.com/$($file.file)"
        $destination = "C:\allegbin\$($file.file)"
        Invoke-WebRequest -uri $source -outfile $destination
    }
    write-host "Checking hash $($file.file)"
    if (!((get-filehash -Path "c:\allegbin\$($file.file)" -Algorithm SHA256).hash -eq $file.hash)) {
        remove-item $destination
        write-host "Hash did not match for $($file.file) with $($file.hash)"
        throw "$($file.file) hash did not match"
    }
    else {
        write-host "Success: Hash Matched!"
    }
}

$computername = cmd /c "hostname"

$emailBody = @"
<html><p style="font-family:Consolas">
<br>
Test Results:

"@
#getting my IP address
$ExternalIP = (Invoke-WebRequest -uri "http://ifconfig.me/ip" -UseBasicParsing).Content

$emailBody += @"
<br>
<br>External IP Address: $($ExternalIP)
<br>Workstation Name: $($computername)

"@

#running iperftests
$tests = @()
$filelist = @()
foreach ($ip in $iperfTestServer) {
    $downloadTCPSpeedJson = cmd /c "C:\allegbin\iperf3.exe -c $ip -p $port -P 10 -t $test_length -J"
    $uploadTCPSpeedJson = cmd /c "C:\allegbin\iperf3.exe -c $ip -p $port -P 10 -t $test_length -R -J"
    $downloadUDPSpeedJson = cmd /c "C:\allegbin\iperf3.exe -c $ip -p $port -t $test_length -u -b 10M -J"
    $uploadUDPSpeedJson = cmd /c "C:\allegbin\iperf3.exe -c $ip -p $port -t $test_length -R -u -b 10M -J"
    $downloadTCPSpeedJson | out-file "C:\allegbin\$($timestamp)_$($ip)_DownloadSpeed-tcp.json" -Force
    $uploadTCPSpeedJson | out-file "C:\allegbin\$($timestamp)_$($ip)_UploadSpeed-tcp.json" -Force
    $downloadUDPSpeedJson | out-file "C:\allegbin\$($timestamp)_$($ip)_DownloadSpeed-udp.json" -Force
    $uploadUDPSpeedJson | out-file "C:\allegbin\$($timestamp)_$($ip)_UploadSpeed-udp.json" -Force
    $filelist += get-item -Path "C:\allegbin\$($timestamp)_$($ip)_DownloadSpeed-tcp.json"
    $filelist += get-item -Path "C:\allegbin\$($timestamp)_$($ip)_UploadSpeed-tcp.json"
    $filelist += get-item -Path "C:\allegbin\$($timestamp)_$($ip)_DownloadSpeed-udp.json"
    $filelist += get-item -Path "C:\allegbin\$($timestamp)_$($ip)_UploadSpeed-udp.json"

    $myObject = [PSCustomObject]@{
        TestingServerIP             = $ip
        TCPDownload_mbps            = ($downloadTCPSpeedJson | convertfrom-json).end.sum_received.bits_per_second / 1024 / 1024
        TCPUpload_mbps              = ($uploadTCPSpeedJson | convertfrom-json).end.sum_received.bits_per_second / 1024 / 1024
        download_Jitter_ms          = ($downloadUDPSpeedJson | convertfrom-json).end.sum_received.jitter_ms
        download_packetloss_percent = ($downloadUDPSpeedJson | convertfrom-json).end.sum_received.lost_packets / ($downloadUDPSpeedJson | convertfrom-json).end.sum_received.packets * 100
        upload_Jitter_ms            = ($uploadUDPSpeedJson | convertfrom-json).end.sum_received.jitter_ms
        upload_packetloss_percent   = ($uploadUDPSpeedJson | convertfrom-json).end.sum_received.lost_packets / ($uploadUDPSpeedJson | convertfrom-json).end.sum_received.packets * 100
    }
    $tests += $myObject
}

$emailBody += @"

<br>-----------------------------------------
<br>
"@

foreach ($test in $tests) {
    $emailBody += @"
<br>
<br>Server&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;:&nbsp;$($Test.TestingServerIP)
<br>Download&nbsp;mbps&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;:&nbsp;$([math]::round($Test.TCPDownload_mbps,2))
<br>Upload&nbsp;mbps&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;:&nbsp;$([math]::round($Test.TCPUpload_mbps,2))
<br>Download&nbsp;jitter&nbsp;MS&nbsp;&nbsp;&nbsp;:&nbsp;$([math]::round($Test.download_Jitter_ms,2))
<br>Download&nbsp;packet&nbsp;loss&nbsp;:&nbsp;$([math]::round($Test.download_packetloss_percent,2))%
<br>Uplaod&nbsp;jitter&nbsp;MS&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;:&nbsp;$([math]::round($Test.upload_Jitter_ms,2))
<br>upload&nbsp;packet&nbsp;loss&nbsp;&nbsp;&nbsp;:&nbsp;$([math]::round($Test.upload_packetloss_percent,2))%
<br>
<br>
<br>------------------------------------------
<br>
"@
}

$emailboxy += @"
</p>
</html>
"@

Send-MailMessage -Attachments $filelist -To $toaddresses -Body $emailBody -SmtpServer $smtpserver -port $smtpport -Credential $smtpcredentials -from $fromaddress -Subject "Speedtest for $computername at $($timestamp)" -BodyAsHtml

$filelist | remove-item -Force