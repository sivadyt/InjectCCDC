$WebRoot = "C:\inetpub\wwwroot"
$BaselineFile = "C:\SecOps\wwwroot_baseline.json"
$LogFile = "C:\SecOps\web_integrity_alerts.log"

# Email settings (edit these)
$SmtpServer = "smtp.yourdomain.local"
$From = "webmonitor@yourdomain.local"
$To = "infrastructure-support@yourdomain.local"
$Subject = "ALERT: Website content change detected"

function Send-AlertEmail($Body) {
  try {
    Send-MailMessage -SmtpServer $SmtpServer -From $From -To $To -Subject $Subject -Body $Body
  } catch {
    Add-Content $LogFile "[$(Get-Date -Format o)] ERROR sending email: $($_.Exception.Message)"
  }
}

if (!(Test-Path $BaselineFile)) {
  Write-Error "Baseline file not found: $BaselineFile"
  exit 1
}

$baseline = Get-Content $BaselineFile -Raw | ConvertFrom-Json

# Build current snapshot
$current = Get-ChildItem -Path $WebRoot -Recurse -File | ForEach-Object {
  [PSCustomObject]@{
    Path = $_.FullName
    Hash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash
    LastWriteTime = $_.LastWriteTimeUtc
    Size = $_.Length
  }
}

# Convert to hashtables for quick lookup
$baseMap = @{}
foreach ($b in $baseline) { $baseMap[$b.Path] = $b.Hash }

$curMap = @{}
foreach ($c in $current) { $curMap[$c.Path] = $c.Hash }

$changes = New-Object System.Collections.Generic.List[string]

# Detect modified + new
foreach ($path in $curMap.Keys) {
  if (!$baseMap.ContainsKey($path)) {
    $changes.Add("NEW FILE: $path")
  } elseif ($baseMap[$path] -ne $curMap[$path]) {
    $changes.Add("MODIFIED: $path")
  }
}

# Detect deleted
foreach ($path in $baseMap.Keys) {
  if (!$curMap.ContainsKey($path)) {
    $changes.Add("DELETED: $path")
  }
}

if ($changes.Count -gt 0) {
  $time = Get-Date -Format o
  $body = @"
Website Integrity Alert

Time: $time
WebRoot: $WebRoot
Baseline: $BaselineFile

Detected changes:
$($changes -join "`n")

Recommended actions:
- Check IIS logs + Windows Security logs for suspicious activity
- Verify recent deployments/changes
- If unauthorized: isolate host, restore from backup, rotate credentials
"@

  Add-Content $LogFile "[$time] CHANGE DETECTED:`n$($changes -join "`n")`n"
  Send-AlertEmail -Body $body

  # Optional: also write a Windows Event Log entry
  if (-not [System.Diagnostics.EventLog]::SourceExists("WebIntegrityMonitor")) {
    New-EventLog -LogName Application -Source "WebIntegrityMonitor"
  }
  Write-EventLog -LogName Application -Source "WebIntegrityMonitor" -EventId 3001 -EntryType Warning -Message $body
}
