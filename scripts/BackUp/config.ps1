
# Fichier de configuration 
$NAS_IP = "192.168.1.11"
$NAS_SHARE = "\\$NAS_IP\HyperV_BackUp"
$LogFile = "C:\Scripts\backup_log.txt"

$NAS_User = "siheh"  
$NAS_Pass = "Root1234"

$RETENTION_DAYS = 30

Function Log-Write {
    Param ([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$TimeStamp - $Message"
}

Function Connect-Nas {
    Log-Write "Tentative de connexion au NAS"

    $SecurePass = ConvertTo-SecureString $NAS_Pass -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential ($NAS_User, $SecurePass)

    if (-not (Get-SmbMapping -RemotePath $NAS_SHARE -ErrorAction SilentlyContinue)) {
        Try {
            New-SmbMapping -RemotePath $NAS_SHARE -Credential $Credential -ErrorAction Stop | Out-Null
            Log-Write "Connexion NAS réussie"
            return $true
        }
        Catch {
            Log-Write "ERREUR : Impossible de se connecter au NAS. $_"
            return $false
        }
    }
    else {
        Log-Write "Connexion NAS déjà active"
        return $true
    }
}

Function Remove-OldBackups {
    Param([int]$Days = $RETENTION_DAYS)
    
    Log-Write "Nettoyage des backups > $Days jours"
    
    Try {
        $CutoffDate = (Get-Date).AddDays(-$Days)
        $BackupRoot = "$NAS_SHARE\WindowsImageBackup"
        
        if (Test-Path $BackupRoot) {
            $BackupFolders = Get-ChildItem -Path $BackupRoot -Recurse -Directory -ErrorAction SilentlyContinue |
                             Where-Object { $_.LastWriteTime -lt $CutoffDate -and $_.Name -like "Backup*" }
            
            foreach ($folder in $BackupFolders) {
                Remove-Item -Path $folder.FullName -Recurse -Force
                Log-Write "Supprimé : $($folder.Name)"
            }
            
            Log-Write "Nettoyage terminé : $($BackupFolders.Count) fichiers supprimés"
        }
        
        # Nettoyage des exports
        $ExportRoot = "$NAS_SHARE\Exports_Configs"
        if (Test-Path $ExportRoot) {
            $OldExports = Get-ChildItem -Path $ExportRoot -Directory -ErrorAction SilentlyContinue |
                          Where-Object { $_.LastWriteTime -lt $CutoffDate }
            
            foreach ($export in $OldExports) {
                Remove-Item -Path $export.FullName -Recurse -Force
                Log-Write "Export supprimé : $($export.Name)"
            }
        }
    }
    Catch {
        Log-Write "ERREUR Nettoyage : $_"
    }
}
