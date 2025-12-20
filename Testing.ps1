$WebRoot = "C:\inetpub\wwwroot"
$BaselineFile = "C:\SecOps\wwwroot_baseline.json"

New-Item -ItemType Directory -Path (Split-Path $BaselineFile) -Force | Out-Null

$baseline = Get-ChildItem -Path $WebRoot -Recurse -File |
  ForEach-Object {
    [PSCustomObject]@{
      Path = $_.FullName
      Hash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash
      LastWriteTime = $_.LastWriteTimeUtc
      Size = $_.Length
    }
  }

$baseline | ConvertTo-Json -Depth 3 | Set-Content -Path $BaselineFile -Encoding UTF8
Write-Host "Baseline saved to $BaselineFile"
