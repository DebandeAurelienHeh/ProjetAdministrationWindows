. "C:\Scripts\config.ps1"

Log-Write "Configuration des tâches planifiées"

$TaskUser = "Domaine\NomUser"  # "DOMAINE\user" du user qui a les droits sur le domaine
$TaskPassword = "Root1234"

Try {
    # Sauvegarde Complète : Dimanche 22h00
    Log-Write "Création tâche : Backup Full"
    
    Register-ScheduledTask `
        -Action (New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\backup_full.ps1") `
        -Trigger (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 22:00) `
        -TaskName "Backup_Full_Weekly" `
        -User $TaskUser `
        -Password $TaskPassword `
        -RunLevel Highest `
        -Force | Out-Null

    Log-Write "Tâche Backup_Full_Weekly créée"

    # Sauvegarde Quotidienne : Lundi-Samedi 23h00
    Log-Write "Création tâche : Backup Quotidien"
    
    Register-ScheduledTask `
        -Action (New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\backup_inc.ps1") `
        -Trigger (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday,Saturday -At 23:00) `
        -TaskName "Backup_Inc_Daily" `
        -User $TaskUser `
        -Password $TaskPassword `
        -RunLevel Highest `
        -Force | Out-Null

    Log-Write "Tâche Backup_Inc_Daily créée"

    # Export Configs : Quotidien 20h00
    Log-Write "Création tâche : Export Configs"
    
    Register-ScheduledTask `
        -Action (New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\export_config.ps1") `
        -Trigger (New-ScheduledTaskTrigger -Daily -At 20:00) `
        -TaskName "Backup_Exports" `
        -User $TaskUser `
        -Password $TaskPassword `
        -RunLevel Highest `
        -Force | Out-Null

    Log-Write "Tâche Backup_Exports créée"

    # System State : Quotidien 21h00
    Log-Write "Création tâche : System State"
    
    Register-ScheduledTask `
        -Action (New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\backup_systemstate.ps1") `
        -Trigger (New-ScheduledTaskTrigger -Daily -At 21:00) `
        -TaskName "Backup_SystemState" `
        -User $TaskUser `
        -Password $TaskPassword `
        -RunLevel Highest `
        -Force | Out-Null

    Log-Write "Tâche Backup_SystemState créée"

    Log-Write "SUCCÈS : Toutes les tâches sont créées"
    
    # Affichage des tâches créées
    Get-ScheduledTask | Where-Object { $_.TaskName -like 'Backup_*' } | Format-Table TaskName, State
}
Catch {
    Log-Write "ERREUR lors de la configuration : $_"
}