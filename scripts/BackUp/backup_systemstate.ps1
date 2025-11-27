Import-Module WindowsServerBackup
. "C:\Scripts\config.ps1"

Log-Write "Démarrage Sauvegarde SYSTEM STATE"

if (-not (Connect-Nas)) {
    exit
}

if (-not (Test-Path $NAS_SHARE)) {
    Log-Write "ERREUR CRITIQUE : NAS inaccessible."
    exit
}

Try {
    $BackupLocation = New-WBBackupTarget -NetworkPath $NAS_SHARE
    $Policy = New-WBPolicy

    # Uniquement l'état du système (AD, Registre, Boot files)
    Add-WBSystemState -Policy $Policy
    Add-WBBackupTarget -Policy $Policy -Target $BackupLocation

    Start-WBBackup -Policy $Policy -ErrorAction Stop
    Log-Write "SUCCÈS : Sauvegarde System State terminée."
}
Catch {
    Log-Write "ERREUR : Échec System State. $_"
}