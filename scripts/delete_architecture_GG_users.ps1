$LogPath = "C:\Scripts\cleanup_log.txt"
$Domain = "espagne.lan"
$RootDN = "DC=espagne,DC=lan"
$BaseOU = "OU=Utilisateurs,$RootDN"
$GroupsOU = "OU=Groupes,$RootDN"

# Fonction de Log 
function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $Msg = "[$(Get-Date -Format 'HH:mm:ss')] [$Type] $Message"
    Add-Content -Path $LogPath -Value $Msg -ErrorAction SilentlyContinue
    switch ($Type) {
        "ERROR" { Write-Host $Msg -ForegroundColor Red }
        "SUCCESS" { Write-Host $Msg -ForegroundColor Green }
        "WARNING" { Write-Host $Msg -ForegroundColor Yellow }
        "CRITICAL" { Write-Host $Msg -ForegroundColor Magenta }
        default { Write-Host $Msg }
    }
}

# Vérification Admin 
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Ce script doit être lancé en tant qu'administrateur !" "CRITICAL"
    exit
}

Clear-Host
Write-Host "  NETTOYAGE COMPLET ACTIVE DIRECTORY" -ForegroundColor Red
Write-Host ""
Write-Host "CE SCRIPT VA SUPPRIMER :" -ForegroundColor Yellow
Write-Host "  - Tous les utilisateurs dans OU=Utilisateurs" -ForegroundColor Yellow
Write-Host "  - Tous les groupes dans OU=Groupes" -ForegroundColor Yellow
Write-Host "  - Toutes les OUs sous Utilisateurs" -ForegroundColor Yellow
Write-Host "  - L'OU Groupes" -ForegroundColor Yellow
Write-Host "  - L'OU Utilisateurs" -ForegroundColor Yellow
Write-Host ""
Write-Host "ATTENTION : CETTE ACTION EST IRREVERSIBLE !" -ForegroundColor Red
Write-Host ""

# Demande de confirmation
$Confirmation = Read-Host "Tapez 'OUI' pour confirmer"

if ($Confirmation -ne "OUI") {
    Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Green
    exit
}

Write-Log "DEBUT DU NETTOYAGE" "WARNING"

# Import Module AD
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log "Module AD chargé" "SUCCESS"
} catch {
    Write-Log "Erreur chargement module AD : $_" "ERROR"
    exit
}

# SUPPRESSION DES UTILISATEURS

Write-Log "Suppression des utilisateurs" "WARNING"

try {
    # Vérifier si l'OU Utilisateurs existe
    $UsersOUExists = Get-ADOrganizationalUnit -Identity $BaseOU -ErrorAction SilentlyContinue
    
    if ($UsersOUExists) {
        # Récupérer tous les utilisateurs dans l'OU Utilisateurs et ses sous-OUs
        $Users = Get-ADUser -Filter * -SearchBase $BaseOU -SearchScope Subtree
        
        if ($Users.Count -gt 0) {
            Write-Log "Utilisateurs trouvés : $($Users.Count)" "INFO"
            
            foreach ($User in $Users) {
                try {
                    Remove-ADUser -Identity $User.SamAccountName -Confirm:$false -ErrorAction Stop
                    Write-Log "  Supprimé : $($User.SamAccountName)" "SUCCESS"
                } catch {
                    Write-Log "  ERREUR suppression $($User.SamAccountName) : $_" "ERROR"
                }
            }
        } else {
            Write-Log "Aucun utilisateur trouvé dans OU=Utilisateurs" "INFO"
        }
    } else {
        Write-Log "L'OU Utilisateurs n'existe pas" "INFO"
    }
} catch {
    Write-Log "Erreur lors de la récupération des utilisateurs : $_" "ERROR"
}

# SUPPRESSION DES GROUPES

Write-Log "Suppression des groupes" "WARNING"

try {
    # Vérifier si l'OU Groupes existe
    $GroupsOUExists = Get-ADOrganizationalUnit -Identity $GroupsOU -ErrorAction SilentlyContinue
    
    if ($GroupsOUExists) {
        # Récupérer tous les groupes dans l'OU Groupes
        $Groups = Get-ADGroup -Filter * -SearchBase $GroupsOU -SearchScope Subtree
        
        if ($Groups.Count -gt 0) {
            Write-Log "Groupes trouvés : $($Groups.Count)" "INFO"
            
            foreach ($Group in $Groups) {
                try {
                    Remove-ADGroup -Identity $Group.SamAccountName -Confirm:$false -ErrorAction Stop
                    Write-Log "  Supprimé : $($Group.Name)" "SUCCESS"
                } catch {
                    Write-Log "  ERREUR suppression $($Group.Name) : $_" "ERROR"
                }
            }
        } else {
            Write-Log "Aucun groupe trouvé dans OU=Groupes" "INFO"
        }
    } else {
        Write-Log "L'OU Groupes n'existe pas" "INFO"
    }
} catch {
    Write-Log "Erreur lors de la récupération des groupes : $_" "ERROR"
}

# SUPPRESSION DES SOUS-UOs

Write-Log "Suppression des sous-UOs" "WARNING"

try {
    if ($UsersOUExists) {
        # Récupérer toutes les sous-UOs dans l'OU Utilisateurs (du plus profond au plus haut)
        $SubOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $BaseOU -SearchScope Subtree | 
                  Sort-Object -Property @{Expression={($_.DistinguishedName -split ',').Count}} -Descending
        
        if ($SubOUs.Count -gt 0) {
            Write-Log "Sous-UOs trouvées : $($SubOUs.Count)" "INFO"
            
            foreach ($OU in $SubOUs) {
                try {
                    # Désactiver la protection contre suppression accidentelle
                    Set-ADOrganizationalUnit -Identity $OU.DistinguishedName -ProtectedFromAccidentalDeletion $false -ErrorAction Stop
                    
                    # Supprimer l'OU
                    Remove-ADOrganizationalUnit -Identity $OU.DistinguishedName -Confirm:$false -ErrorAction Stop
                    Write-Log "  Supprimée : $($OU.Name)" "SUCCESS"
                } catch {
                    Write-Log "  ERREUR suppression $($OU.Name) : $_" "ERROR"
                }
            }
        } else {
            Write-Log "Aucune sous-UO trouvée" "INFO"
        }
    }
} catch {
    Write-Log "Erreur lors de la suppression des sous-UOs : $_" "ERROR"
}

# SUPPRESSION DE L'UO GROUPES

Write-Log "Suppression de l'OU Groupes" "WARNING"

try {
    if ($GroupsOUExists) {
        # Désactiver la protection
        Set-ADOrganizationalUnit -Identity $GroupsOU -ProtectedFromAccidentalDeletion $false -ErrorAction Stop
        
        # Supprimer l'OU
        Remove-ADOrganizationalUnit -Identity $GroupsOU -Confirm:$false -ErrorAction Stop
        Write-Log "OU Groupes supprimée" "SUCCESS"
    } else {
        Write-Log "L'OU Groupes n'existe pas" "INFO"
    }
} catch {
    Write-Log "Erreur suppression OU Groupes : $_" "ERROR"
}

# SUPPRESSION DE L'UO UTILISATEURS

Write-Log "Suppression de l'OU Utilisateurs" "WARNING"

try {
    if ($UsersOUExists) {
        # Désactiver la protection
        Set-ADOrganizationalUnit -Identity $BaseOU -ProtectedFromAccidentalDeletion $false -ErrorAction Stop
        
        # Supprimer l'OU
        Remove-ADOrganizationalUnit -Identity $BaseOU -Confirm:$false -ErrorAction Stop
        Write-Log "OU Utilisateurs supprimée" "SUCCESS"
    } else {
        Write-Log "L'OU Utilisateurs n'existe pas" "INFO"
    }
} catch {
    Write-Log "Erreur suppression OU Utilisateurs : $_" "ERROR"
}
# LOG FINAL

Write-Log "NETTOYAGE TERMINE" "SUCCESS"

Write-Host "`nNETTOYAGE TERMINE" -ForegroundColor Green
Write-Host "Vous pouvez maintenant relancer vos scripts de création :" -ForegroundColor Cyan
Write-Host "  1. Script de structure AD (OUs)" -ForegroundColor White
Write-Host "  2. Script de création des groupes" -ForegroundColor White
Write-Host "  3. Script de création des utilisateurs" -ForegroundColor White
Write-Host ""
Write-Host "Log disponible : $LogPath" -ForegroundColor Yellow