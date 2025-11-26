Import-Module WindowsServerBackup
. "C:\Scripts\config.ps1"

$BackupLocation = New-WBBackupTarget -NetworkPath $NAS_SHARE
$Policy = New-WBPolicy

Add-WBVolume -Policy $Policy -Volume (Get-WBVolume -allVolumes)
Set-WBVssBackupOptions -Policy $Policy -VssFullBackup

Add-WBBackupTarget -Policy $Policy -Target $BackupLocation
Start-WBBackup -Policy $Policy