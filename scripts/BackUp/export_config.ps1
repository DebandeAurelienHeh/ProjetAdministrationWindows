. "C:\Scripts\config.ps1"

$ExportPath = "$NAS_SHARE\Exports_Configs\$(Get-Date -Format yyyy-MM-dd)"
New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null

# AD
ntdsutil "activate instance ntds" "ifm" "create full $ExportPath\AD" quit quit

# DNS
dnscmd localhost /ZoneExport contoso.local $ExportPath\dns_export.txt

# DHCP
Export-DhcpServer -ComputerName localhost -File "$ExportPath\dhcp.xml" -Leases -Force

