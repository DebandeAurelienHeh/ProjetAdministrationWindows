Import-Module WindowsServerBackup
. "C:\Scripts\config.ps1"

$BackupLocation = New-WBBackupTarget -NetworkPath $NAS_SHARE
$Policy = New-WBPolicy

Add-WBSystemState -Policy $Policy
Add-WBBackupTarget -Policy $Policy -Target $BackupLocation

Start-WBBackup -Policy $Policy
