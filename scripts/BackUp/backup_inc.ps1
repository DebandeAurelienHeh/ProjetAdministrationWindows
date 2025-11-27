Import-Module WindowsServerBackup
. "C:\Scripts\config.ps1"

Log-Write "Démarrage Sauvegarde QUOTIDIENNE"

if (-not (Connect-Nas)) {
    exit
}

if (-not (Test-Path $NAS_SHARE)) {
    Log-Write "ERREUR CRITIQUE : NAS inaccessible"
    exit
}

Try {
    $BackupLocation = New-WBBackupTarget -NetworkPath $NAS_SHARE
    $Policy = New-WBPolicy

    Add-WBVolume -Policy $Policy -Volume (Get-WBVolume -allVolumes)
    
    # Mode VSS Copy 
    Set-WBVssBackupOptions -Policy $Policy -VssCopyBackup

    Add-WBBackupTarget -Policy $Policy -Target $BackupLocation
    
    Start-WBBackup -Policy $Policy -ErrorAction Stop
    Log-Write "SUCCÈS : Sauvegarde Quotidienne terminée"
}
Catch {
    Log-Write "ERREUR : Échec de la sauvegarde quotidienne $_"
}