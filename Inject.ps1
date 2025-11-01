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
New-NetFirewallRule -DisplayName "ALLOW_LDAP_389_TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 389 -Profile Any"
New-NetFirewallRule -DisplayName "ALLOW_LDAP_389_UDP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 389 -Profile Any"
New-NetFirewallRule -DisplayName "ALLOW_LDAPS_636_TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 636 -Profile Any"
New-NetFirewallRule -DisplayName "ALLOW_DNS_53_TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 53 -Profile Any"
New-NetFirewallRule -DisplayName "ALLOW_DNS_53_UDP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 53 -Profile Any"
New-NetFirewallRule -DisplayName "ALLOW_NTP_123_UDP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 123 -Profile Any"

# 3) Create explicit ALLOW rules for required services (Inbound)
$allowRules = @(
  @{ Name = "ALLOW_HTTP_80_TCP";    Proto="TCP"; Ports="80"   },
  @{ Name = "ALLOW_HTTPS_443_TCP";  Proto="TCP"; Ports="443"  },
  @{ Name = "ALLOW_LDAP_389_TCP";   Proto="TCP"; Ports="389"  },
  @{ Name = "ALLOW_LDAP_389_UDP";   Proto="UDP"; Ports="389"  },
  @{ Name = "ALLOW_LDAPS_636_TCP";  Proto="TCP"; Ports="636"  },
  @{ Name = "ALLOW_DNS_53_TCP";     Proto="TCP"; Ports="53"   },
  @{ Name = "ALLOW_DNS_53_UDP";     Proto="UDP"; Ports="53"   },
  @{ Name = "ALLOW_NTP_123_UDP";    Proto="UDP"; Ports="123"  }
)

foreach ($r in $allowRules) {
  if (Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue) {
    Remove-NetFirewallRule -DisplayName $r.Name | Out-Null
  }
  New-NetFirewallRule -DisplayName $r.Name `
    -Direction Inbound -Action Allow -Protocol $r.Proto -LocalPort $r.Ports -Profile Any | Out-Null
}

# ICMP (allow both IPv4 and IPv6 so ping/PMTUD work)
foreach ($icmp in @("ALLOW_ICMPv4","ALLOW_ICMPv6")) {
  if (Get-NetFirewallRule -DisplayName $icmp -ErrorAction SilentlyContinue) {
    Remove-NetFirewallRule -DisplayName $icmp | Out-Null
  }
}
New-NetFirewallRule -DisplayName "ALLOW_ICMPv4" -Direction Inbound -Action Allow -Protocol ICMPv4 -IcmpType Any -Profile Any | Out-Null
New-NetFirewallRule -DisplayName "ALLOW_ICMPv6" -Direction Inbound -Action Allow -Protocol ICMPv6 -IcmpType Any -Profile Any | Out-Null

# 4) Disable any other inbound ALLOW rules so only the above are open
$keep = $allowRules.Name + @("ALLOW_ICMPv4","ALLOW_ICMPv6")
Get-NetFirewallRule -Direction Inbound -Action Allow -Enabled True |
  Where-Object { $_.DisplayName -notin $keep } |
  Disable-NetFirewallRule | Out-Null

# 5) Show effective posture
Write-Host "`n=== EFFECTIVE INBOUND RULES (ENABLED) ===" -ForegroundColor Cyan
Get-NetFirewallRule -Direction Inbound -Enabled True |
  Select DisplayName, Action, @{n='Proto';e={($_|Get-NetFirewallPortFilter).Protocol}},
         @{n='Ports';e={($_|Get-NetFirewallPortFilter).LocalPort}} |
  Sort DisplayName | Format-Table -Auto

Write-Host "`nProfiles:" -ForegroundColor Cyan
Get-NetFirewallProfile | Select Name, Enabled, DefaultInboundAction | Format-Table -Auto
Write-Host "`nLockdown complete. Only HTTP/HTTPS/LDAP/LDAPS/DNS/NTP/ICMP are allowed inbound; all else is blocked by default."
