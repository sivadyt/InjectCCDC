# ===== HARD LOCK TO 80/443 ONLY (PS 5.1) =====
$ErrorActionPreference = 'SilentlyContinue'

# 0) Backup current firewall config
$bk = "C:\fw-backup-{0}.wfw" -f (Get-Date -Format "yyyyMMdd_HHmmss")
try { netsh advfirewall export "$bk" | Out-Null; Write-Host "Backup: $bk" -ForegroundColor Yellow } catch {}

# 1) Turn firewall ON and set default inbound BLOCK
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow

# 2) Create explicit ALLOWs for 80/443 (TCP, all profiles)
$allowNames = @("ALLOW_HTTP_80","ALLOW_HTTPS_443")
foreach ($n in $allowNames) { if (Get-NetFirewallRule -DisplayName $n -ErrorAction SilentlyContinue) { Remove-NetFirewallRule -DisplayName $n } }
New-NetFirewallRule -DisplayName "ALLOW_HTTP_80"   -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80  -Profile Any
New-NetFirewallRule -DisplayName "ALLOW_HTTPS_443" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 443 -Profile Any

# 3) Create explicit BLOCKs for everything else
# TCP except 80/443 -> split into ranges so we don't block 80/443
$blockTcp = @(
  @{Name="BLOCK_TCP_1_79";      Ports="1-79"},
  @{Name="BLOCK_TCP_81_442";    Ports="81-442"},
  @{Name="BLOCK_TCP_444_65535"; Ports="444-65535"}
)
foreach ($r in $blockTcp) {
  if (Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue) { Remove-NetFirewallRule -DisplayName $r.Name }
  New-NetFirewallRule -DisplayName $($r.Name) -Direction Inbound -Action Block -Protocol TCP -LocalPort $($r.Ports) -Profile Any | Out-Null
}

# UDP: block all inbound UDP
if (Get-NetFirewallRule -DisplayName "BLOCK_UDP_ALL" -ErrorAction SilentlyContinue) { Remove-NetFirewallRule -DisplayName "BLOCK_UDP_ALL" }
New-NetFirewallRule -DisplayName "BLOCK_UDP_ALL" -Direction Inbound -Action Block -Protocol UDP -LocalPort Any -Profile Any | Out-Null

# 4) Disable any other inbound ALLOW rules that might still be enabled
Get-NetFirewallRule -Direction Inbound -Action Allow -Enabled True |
  Where-Object { $_.DisplayName -notin @("ALLOW_HTTP_80","ALLOW_HTTPS_443") } |
  Disable-NetFirewallRule | Out-Null

# 5) Show effective posture
Write-Host "`n=== EFFECTIVE INBOUND RULES (ENABLED) ===" -ForegroundColor Cyan
Get-NetFirewallRule -Direction Inbound -Enabled True |
  Select DisplayName, Action, @{n='Proto';e={($_|Get-NetFirewallPortFilter).Protocol}},
         @{n='Ports';e={($_|Get-NetFirewallPortFilter).LocalPort}} |
  Sort DisplayName | Format-Table -Auto

Write-Host "`nProfiles:" -ForegroundColor Cyan
Get-NetFirewallProfile | Select Name, Enabled, DefaultInboundAction | Format-Table -Auto
Write-Host "`nLockdown complete. Only TCP 80/443 should be reachable from the network."
