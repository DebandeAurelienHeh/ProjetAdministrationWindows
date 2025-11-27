$LogPath = "C:\Scripts\cleanup_users_log.txt"
$RootDN = "DC=espagne,DC=lan"
$BaseOU = "OU=Utilisateurs,$RootDN"

# FONCTION LOG

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $Msg = "[$(Get-Date -Format 'HH:mm:ss')] [$Type] $Message"
    Add-Content -Path $LogPath -Value $Msg -ErrorAction SilentlyContinue
    switch ($Type) {
        "ERROR" { Write-Host $Msg -ForegroundColor Red }
        "SUCCESS" { Write-Host $Msg -ForegroundColor Green }
        "WARNING" { Write-Host $Msg -ForegroundColor Yellow }
        default { Write-Host $Msg }
    }
}

# VERIF ADMIN

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Ce script doit être lancé en tant qu'administrateur" "ERROR"
    exit
}

Write-Host "CE SCRIPT VA SUPPRIMER :" -ForegroundColor Yellow
Write-Host "Tous les utilisateurs dans OU=Utilisateurs" -ForegroundColor Yellow

$Confirmation = Read-Host "Tapez 'OUI' pour confirmer"

if ($Confirmation -ne "OUI") {
    Write-Host "Opération annulée" -ForegroundColor Green
    exit
}

# IMPORT MODULE AD

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
    $UsersOUExists = Get-ADOrganizationalUnit -Identity $BaseOU -ErrorAction SilentlyContinue
    
    if ($UsersOUExists) {
        $Users = Get-ADUser -Filter * -SearchBase $BaseOU -SearchScope Subtree
        
        if ($Users.Count -gt 0) {
            Write-Log "Utilisateurs trouvés : $($Users.Count)" "INFO"
            
            foreach ($User in $Users) {
                try {
                    Remove-ADUser -Identity $User.SamAccountName -Confirm:$false -ErrorAction Stop
                    Write-Log "Supprimé : $($User.SamAccountName)" "SUCCESS"
                } catch {
                    Write-Log "ERREUR suppression $($User.SamAccountName) : $_" "ERROR"
                }
            }
        } else {
            Write-Log "Aucun utilisateur trouvé" "INFO"
        }
    } else {
        Write-Log "L'OU Utilisateurs n'existe pas" "INFO"
    }
} catch {
    Write-Log "Erreur lors de la récupération des utilisateurs : $_" "ERROR"
}

# LOG FINAL

Write-Log "NETTOYAGE DES UTILISATEURS TERMINE" "SUCCESS"