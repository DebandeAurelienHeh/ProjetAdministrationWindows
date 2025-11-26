. "C:\Scripts\config.ps1"

$DateFolder = Get-Date -Format "yyyy-MM-dd"
$ExportPath = "$NAS_SHARE\Exports_Configs\$DateFolder"

Log-Write "Démarrage Exports AD/DNS/DHCP vers $ExportPath"

if (-not (Connect-Nas)) {
    exit
}

Try {
    if (-not (Test-Path $ExportPath)) {
        New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
    }

    # Export AD 
    $ADPath = "$ExportPath\AD"
    Log-Write "Export AD"
    ntdsutil "activate instance ntds" "ifm" "create full `"$ADPath`"" quit quit

    # Export DNS
    $DNSPath = "$ExportPath\DNS"
    New-Item -ItemType Directory -Path $DNSPath -Force | Out-Null
    Log-Write "Export DNS"
    
    # Exporte toutes les zones DNS
    $zones = Get-DnsServerZone | Where-Object { -not $_.IsAutoCreated }
    
    foreach ($zone in $zones) {
        Try {
            dnscmd localhost /ZoneExport $zone.ZoneName "$($zone.ZoneName).txt" | Out-Null
            
            $SourceFile = "$env:SystemRoot\System32\dns\$($zone.ZoneName).txt"
            if (Test-Path $SourceFile) {
                Copy-Item $SourceFile "$DNSPath\" -Force
                Log-Write "Zone DNS exportée : $($zone.ZoneName)"
            }
        }
        Catch {
            Log-Write "ERREUR export zone $($zone.ZoneName) : $_"
        }
    }
    
    # Export config DNS complète
    Get-DnsServerZone | Export-Clixml "$DNSPath\dns_zones_config.xml"
    Get-DnsServerForwarder | Export-Clixml "$DNSPath\dns_forwarders.xml" -ErrorAction SilentlyContinue
    
    Log-Write "Export DNS terminé : $($zones.Count) zones"

    # Export DHCP
    Log-Write "Export DHCP"
    Export-DhcpServer -ComputerName localhost -File "$ExportPath\dhcp.xml" -Leases -Force

    Log-Write "SUCCÈS : Tous les exports sont terminés"
}
Catch {
    Log-Write "ERREUR lors des exports : $_"
}