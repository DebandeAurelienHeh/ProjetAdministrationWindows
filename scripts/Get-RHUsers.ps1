<#
.SYNOPSIS
    Liste tous les utilisateurs du département Ressources Humaines
    
.DESCRIPTION
    Ce script affiche tous les utilisateurs présents dans l'UO 
    Ressources humaines et ses sous-UO (Recrutement, Gestion_du_personnel)
    
.NOTES
    Auteur: Administrator
    Domaine: espagne.lan
    Signé numériquement pour garantir l'authenticité
#>

# Définir le chemin de base de l'UO RH
$OuPath = "OU=Ressources humaines,OU=Utilisateurs,DC=espagne,DC=lan"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Utilisateurs - Ressources Humaines" -ForegroundColor Cyan
Write-Host "  Domaine: espagne.lan" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Récupérer tous les utilisateurs de l'UO RH (incluant sous-UO)
    $users = Get-ADUser -Filter * -SearchBase $OuPath -Properties Department, Title, EmailAddress |
             Select-Object Name, SamAccountName, Department, Title, EmailAddress, DistinguishedName
    
    if ($users) {
        Write-Host "Nombre total d'utilisateurs RH: $($users.Count)" -ForegroundColor Green
        Write-Host ""
        
        # Afficher les utilisateurs
        $users | Format-Table -AutoSize Name, SamAccountName, Title, Department
        
        Write-Host ""
        Write-Host "Détails complets:" -ForegroundColor Yellow
        $users | Format-List Name, SamAccountName, Title, Department, EmailAddress, DistinguishedName
        
    } else {
        Write-Host "Aucun utilisateur trouvé dans l'UO Ressources humaines." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Erreur lors de la récupération des utilisateurs: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Script exécuté avec succès!" -ForegroundColor Green
