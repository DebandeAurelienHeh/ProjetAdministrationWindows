<#
.SYNOPSIS
  Script PRO pour installer AD DS, promouvoir en DC, créer la forêt/domain "espagne.lan"
  et, après promotion (redémarrage), créer la zone reverse DNS (10.4.0.0/22 par défaut).

.NOTES
  - Exécuter en admin (PowerShell elevated).
  - Le serveur doit avoir une IP statique déjà configurée (le script vérifie la présence d'une IPv4).
  - Le script automatise la post-promotion via une tâche planifiée qui s'exécute au prochain démarrage.
  - DSRM password par défaut : "Azerty47" (conforme à ta demande). Si tu veux le changer, modifie $DSRMPlain.
#>

param(
    [string]$DomainName = "espagne.lan",
    [string]$ReverseNetwork = "10.4.0.0/22",
    [string]$InterfaceAlias = "Ethernet",
    [string]$DSRMPlain = "Azerty47",
    [switch]$ForceInstall = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Msg, [string]$Level = "INFO")
    $t = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$t] [$Level] $Msg"
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Log "Le script doit être exécuté en tant qu'administrateur. Relancez PowerShell en 'Run as Administrator'." "ERROR"
    exit 1
}

try {
    Write-Log "Début du script PRO d'installation ADDS pour le domaine '$DomainName'." "INFO"

    # Vérifier présence d'une IPv4 (autre que loopback)
    $localIps = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.IPAddress -ne $null })
    if (-not $localIps -or $localIps.Count -eq 0) {
        Write-Log "Aucune adresse IPv4 détectée sur ce serveur. Configure d'abord une IP statique." "ERROR"
        throw "NoIPv4"
    } else {
        $primaryIp = ($localIps | Select-Object -First 1).IPAddress
        Write-Log "Adresse IPv4 détectée : $primaryIp" "INFO"
    }

    # Vérifier si AD existe déjà
    $domainExists = $false
    try {
        $d = Get-ADDomain -ErrorAction Stop
        if ($d.DNSRoot) {
            $domainExists = $true
            Write-Log "Un domaine AD existe déjà sur ce serveur : $($d.DNSRoot). (Script en mode post-install/check)" "WARN"
        }
    } catch {
        # Pas de domaine présent (normal pour première exécution)
        Write-Log "Aucun domaine AD détecté sur ce serveur (execution initiale)." "INFO"
    }

    # Installer le rôle AD-Domain-Services si nécessaire (ou si force)
    $role = Get-WindowsFeature -Name 'AD-Domain-Services' -ErrorAction SilentlyContinue
    if ($null -eq $role -or -not $role.Installed -or $ForceInstall) {
        Write-Log "Installation du rôle AD-Domain-Services..." "INFO"
        Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | Out-Null
        Write-Log "Rôle AD-Domain-Services installé." "INFO"
    } else {
        Write-Log "Le rôle AD-Domain-Services est déjà installé." "INFO"
    }

    # Vérifier configuration DNS client pour l'interface donnée
    $dnsServers = $null
    try {
        $dnsServers = (Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction Stop).ServerAddresses
    } catch {
        Write-Log "Impossible de lire les serveurs DNS sur l'interface '$InterfaceAlias' : $_" "WARN"
    }

    if (-not $dnsServers -or $dnsServers.Count -eq 0) {
        Write-Log "Aucun serveur DNS client configuré pour l'interface '$InterfaceAlias'." "WARN"
        # Proposer de configurer DNS client sur l'IP locale (pas modifier l'IP)
        $choice = Read-Host "Souhaitez-vous configurer les serveurs DNS client pour pointer sur l'IP locale $primaryIp ? (O/N)"
        if ($choice -match '^[Oo]') {
            try {
                Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $primaryIp -ErrorAction Stop
                Write-Log "Serveur DNS client configuré sur $primaryIp pour l'interface $InterfaceAlias." "INFO"
                $dnsServers = @($primaryIp)
            } catch {
                Write-Log "Echec du Set-DnsClientServerAddress : $_" "ERROR"
                throw
            }
        } else {
            Write-Log "Tu as choisi de ne pas configurer de DNS client automatique. Si aucun DNS n'est accessible, la promotion échouera." "WARN"
        }
    } else {
        Write-Log "Serveurs DNS client détectés : $($dnsServers -join ', ')" "INFO"
    }

    # Si le domaine existe déjà, sauter la promotion et créer la zone reverse si besoin
    if ($domainExists) {
        Write-Log "Mode: domaine existant -> création/check de la zone reverse." "INFO"
        # Créer reverse zone si non existante
        Import-Module DnsServer -ErrorAction Stop
        $networkId = $ReverseNetwork
        try {
            $exists = Get-DnsServerZone -ErrorAction Stop | Where-Object { $_.ZoneName -like ("*"+($networkId.Split('/')[0].Split('.')[2])+"*") } -ErrorAction SilentlyContinue
        } catch {
            $exists = $null
        }
        # Simpler check: try Add and catch if exists
        try {
            Add-DnsServerPrimaryZone -NetworkId $networkId -ReplicationScope "Domain" -PassThru -ErrorAction Stop | Out-Null
            Write-Log "Zone reverse $networkId créée avec réplication 'Domain'." "INFO"
        } catch {
            Write-Log "La zone reverse $networkId existe peut-être déjà ou erreur: $_" "WARN"
        }
        Write-Log "Terminé (domaine déjà existant)." "INFO"
        exit 0
    }

    # Si on arrive ici -> pas de domaine : promotion requise
    Write-Log "Préparation à la promotion en contrôleur de domaine pour le domaine '$DomainName'." "INFO"

    # Préparer le mot de passe DSRM (utilisateur a demandé Azerty47)
    $secureDSRM = ConvertTo-SecureString -String $DSRMPlain -AsPlainText -Force

    # Préparer script de post-installation (création zone reverse) et tâche planifiée
    $postScriptPath = "C:\Windows\Temp\ADDS_PostInstall_CreateReverse.ps1"
    $taskName = "ADDS_PostInstall_CreateReverse_Task"

    $postScript = @"
# Script post-install exécuté après la promotion/redémarrage pour créer la zone reverse et nettoyer la tâche.
param(\$ReverseNetwork = '$ReverseNetwork')

Import-Module DnsServer -ErrorAction Stop
Start-Sleep -Seconds 10

try {
    Write-Host "Post-install: vérification AD et DNS..."
    # attendre que ADDS/DNS soient pleinement opérationnels
    `$attempt = 0
    while (`$attempt -lt 30) {
        try {
            # Test simple : Get-ADDomainController (si disponible)
            Import-Module ActiveDirectory -ErrorAction Stop
            `$dc = Get-ADDomainController -ErrorAction Stop
            if (`$dc) { break }
        } catch {
            # attendre
        }
        Start-Sleep -Seconds 10
        `$attempt++
    }

    Write-Host "Création de la zone reverse `$ReverseNetwork (si non existante)..."
    try {
        Add-DnsServerPrimaryZone -NetworkId `$ReverseNetwork -ReplicationScope "Domain" -ErrorAction Stop
        Write-Host "Zone reverse créée: `$ReverseNetwork"
    } catch {
        Write-Host "Erreur/zone existe déjà: $_"
    }

} catch {
    Write-Host "Erreur dans le post-install script: $_"
}

# Supprimer la tâche planifiée et ce script
try {
    Unregister-ScheduledTask -TaskName '$taskName' -Confirm:\$false -ErrorAction SilentlyContinue
} catch {}
try { Remove-Item -Path '$postScriptPath' -Force -ErrorAction SilentlyContinue } catch {}

Write-Host "Post-install terminé."
"@

    # Ecrire le script post-install sur disque
    Write-Log "Création du script post-install : $postScriptPath" "INFO"
    $postScript | Out-File -FilePath $postScriptPath -Encoding UTF8 -Force

    # Créer une tâche planifiée qui exécutera le script post-install au prochain démarrage (Highest Privilege)
    Write-Log "Création de la tâche planifiée '$taskName' pour exécuter le post-install après reboot." "INFO"
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$postScriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable)

    Register-ScheduledTask -TaskName $taskName -InputObject $task -Force

    Write-Log "Tâche planifiée créée. Lancement de la promotion AD (Install-ADDSForest)..." "INFO"

    # Lancer la promotion (cela redémarrera la machine automatiquement)
    Install-ADDSForest -DomainName $DomainName -SafeModeAdministratorPassword $secureDSRM -InstallDns -NoRebootOnCompletion:$false -Force

    # NOTE: Install-ADDSForest redémarre automatiquement; le script ne devrait pas continuer après cette ligne.
} catch {
    Write-Log "Erreur majeure détectée : $_" "ERROR"
    throw
}