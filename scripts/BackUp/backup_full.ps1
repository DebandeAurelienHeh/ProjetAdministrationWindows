Import-Module WindowsServerBackup
. "C:\Scripts\config.ps1"

Log-Write "Démarrage Sauvegarde COMPLÈTE"

if (-not (Connect-Nas)) {
    exit
}

if (-not (Test-Path $NAS_SHARE)) {
    Log-Write "ERREUR CRITIQUE : Le NAS $NAS_SHARE est inaccessible. Abandon."
    exit
}

Try {
    $BackupLocation = New-WBBackupTarget -NetworkPath $NAS_SHARE
    $Policy = New-WBPolicy

    # Ajout de tous les volumes
    Add-WBVolume -Policy $Policy -Volume (Get-WBVolume -allVolumes)
    
    # Mode VSS Full (Pour la sauvegarde hebdo)
    Set-WBVssBackupOptions -Policy $Policy -VssFullBackup

    Add-WBBackupTarget -Policy $Policy -Target $BackupLocation
    
    # Lancement
    Start-WBBackup -Policy $Policy -ErrorAction Stop
    Log-Write "SUCCÈS : Sauvegarde Complète terminée."
    
    # Nettoyage des anciens backups
    Remove-OldBackups -Days $RETENTION_DAYS
}
Catch {
    Log-Write "ERREUR : Échec de la sauvegarde. $_"
}