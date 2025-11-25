# STRUCTURE AD 

$LogPath = "C:\Scripts\structure_log.txt"

# --- Fonction de Log ---
function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $Msg = "[$(Get-Date -Format 'HH:mm:ss')] [$Type] $Message"
    Add-Content -Path $LogPath -Value $Msg -ErrorAction SilentlyContinue
    switch ($Type) {
        "ERROR" { Write-Host $Msg -ForegroundColor Red }
        "SUCCESS" { Write-Host $Msg -ForegroundColor Green }
        "CRITICAL" { Write-Host $Msg -ForegroundColor Magenta }
        "WARNING" { Write-Host $Msg -ForegroundColor Yellow }
        default { Write-Host $Msg }
    }
}

# --- Vérification Admin ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Ce script doit être lancé en tant qu'administrateur !" "CRITICAL"
    exit
}

Clear-Host
Write-Log "=== DEMARRAGE ARCHITECTURE ===" "INFO"

# --- Import Module Active Directory ---
Write-Log "Chargement du module Active Directory..." "INFO"
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log "Module Active Directory chargé avec succès" "SUCCESS"
} catch {
    Write-Log "ERREUR : Impossible de charger le module Active Directory" "CRITICAL"
    Write-Log "Détails : $_" "ERROR"
    Write-Log "Installez les outils RSAT ou exécutez ce script sur un contrôleur de domaine" "WARNING"
    exit
}

# 1. Détection du Domaine
Write-Log "Détection du domaine Active Directory..." "INFO"
try {
    $Domain = Get-ADDomain -ErrorAction Stop
    $RootDN = $Domain.DistinguishedName
    Write-Log "Domaine détecté : $($Domain.DNSRoot)" "SUCCESS"
    Write-Log "DN Racine : $RootDN" "INFO"
} catch {
    Write-Log "ERREUR : Impossible de lire le domaine AD" "CRITICAL"
    Write-Log "Détails : $_" "ERROR"
    Write-Log "Vérifiez que vous êtes sur un contrôleur de domaine ou que vous avez accès au domaine" "WARNING"
    exit
}

# 2. Création de la Racine "Utilisateurs"
$BaseOU_Name = "Utilisateurs"
$BaseOU_DN = "OU=$BaseOU_Name,$RootDN"

Write-Log "Vérification de la racine : OU=$BaseOU_Name" "INFO"

try {
    $ExistingBaseOU = Get-ADOrganizationalUnit -Identity $BaseOU_DN -ErrorAction Stop
    Write-Log "La racine '$BaseOU_Name' existe déjà." "INFO"
} catch {
    Write-Log "La racine '$BaseOU_Name' n'existe pas, création en cours..." "INFO"
    try {
        New-ADOrganizationalUnit -Name $BaseOU_Name -Path $RootDN -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
        Write-Log "Racine '$BaseOU_Name' créée avec succès !" "SUCCESS"
    } catch {
        Write-Log "ECHEC CRITIQUE création racine : $_" "CRITICAL"
        exit
    }
}

# 3. Fonction pour créer les sous-dossiers
function Ensure-OU {
    param(
        [string]$Name, 
        [string]$ParentDN
    )
    
    $TargetDN = "OU=$Name,$ParentDN"
    
    try {
        # Tenter de récupérer l'OU
        $ExistingOU = Get-ADOrganizationalUnit -Identity $TargetDN -ErrorAction Stop
        Write-Log "  Existe déjà : $Name" "INFO"
    } catch {
        # L'OU n'existe pas, on la crée
        try {
            New-ADOrganizationalUnit -Name $Name -Path $ParentDN -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
            Write-Log "  Créé : $Name" "SUCCESS"
        } catch {
            Write-Log "  ERREUR création '$Name' : $_" "ERROR"
        }
    }
    
    return $TargetDN
}

# 4. Création de l'arborescence
Write-Log "--- Construction des Départements (Niveau 1) ---" "INFO"

# Niveau 1 - Départements principaux
$DirectionOU    = Ensure-OU -Name "Direction" -ParentDN $BaseOU_DN
$RH_OU          = Ensure-OU -Name "Ressources humaines" -ParentDN $BaseOU_DN
$RD_OU          = Ensure-OU -Name "R&D" -ParentDN $BaseOU_DN
$MarketingOU    = Ensure-OU -Name "Marketting" -ParentDN $BaseOU_DN
$FinancesOU     = Ensure-OU -Name "Finances" -ParentDN $BaseOU_DN
$TechniqueOU    = Ensure-OU -Name "Technique" -ParentDN $BaseOU_DN
$InformatiqueOU = Ensure-OU -Name "Informatique" -ParentDN $BaseOU_DN
$CommerciauxOU  = Ensure-OU -Name "Commerciaux" -ParentDN $BaseOU_DN

Write-Log "--- Construction des Sous-Départements (Niveau 2) ---" "INFO"

# Niveau 2 - Ressources Humaines
Write-Log "Sous-départements RH..." "INFO"
Ensure-OU -Name "Gestion du personnel" -ParentDN $RH_OU | Out-Null
Ensure-OU -Name "Recrutement" -ParentDN $RH_OU | Out-Null

# Niveau 2 - R&D
Write-Log "Sous-départements R&D..." "INFO"
Ensure-OU -Name "Recherche" -ParentDN $RD_OU | Out-Null
Ensure-OU -Name "Testing" -ParentDN $RD_OU | Out-Null

# Niveau 2 - Marketing
Write-Log "Sous-départements Marketing..." "INFO"
Ensure-OU -Name "Site 1" -ParentDN $MarketingOU | Out-Null
Ensure-OU -Name "Site 2" -ParentDN $MarketingOU | Out-Null
Ensure-OU -Name "Site 3" -ParentDN $MarketingOU | Out-Null
Ensure-OU -Name "Site 4" -ParentDN $MarketingOU | Out-Null

# Niveau 2 - Finances
Write-Log "Sous-départements Finances..." "INFO"
Ensure-OU -Name "Comptabilité" -ParentDN $FinancesOU | Out-Null
Ensure-OU -Name "Investissements" -ParentDN $FinancesOU | Out-Null

# Niveau 2 - Technique
Write-Log "Sous-départements Technique..." "INFO"
Ensure-OU -Name "Techniciens" -ParentDN $TechniqueOU | Out-Null
Ensure-OU -Name "Achat" -ParentDN $TechniqueOU | Out-Null

# Niveau 2 - Informatique
Write-Log "Sous-départements Informatique..." "INFO"
Ensure-OU -Name "Systèmes" -ParentDN $InformatiqueOU | Out-Null
Ensure-OU -Name "Développement" -ParentDN $InformatiqueOU | Out-Null
Ensure-OU -Name "HotLine" -ParentDN $InformatiqueOU | Out-Null

# Niveau 2 - Commerciaux
Write-Log "Sous-départements Commerciaux..." "INFO"
Ensure-OU -Name "Sédentaires" -ParentDN $CommerciauxOU | Out-Null
Ensure-OU -Name "Technico" -ParentDN $CommerciauxOU | Out-Null

# Dossiers Spéciaux pour Responsables (à la racine Utilisateurs)
Write-Log "--- Création dossiers Responsables ---" "INFO"
Ensure-OU -Name "ResponsableDepartement" -ParentDN $BaseOU_DN | Out-Null
Ensure-OU -Name "ResponsableGestion" -ParentDN $BaseOU_DN | Out-Null
Ensure-OU -Name "ResponsableRecrutement" -ParentDN $BaseOU_DN | Out-Null

Write-Log "=== ARCHITECTURE TERMINEE ===" "SUCCESS"
Write-Log "Consultez le fichier de log pour les détails : $LogPath" "INFO"

# Afficher un résumé
Write-Host "`n=== RESUME ===" -ForegroundColor Cyan
try {
    $AllOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $BaseOU_DN | Measure-Object
    Write-Host "Total d'OUs créées sous 'Utilisateurs' : $($AllOUs.Count)" -ForegroundColor Green
} catch {
    Write-Host "Impossible de compter les OUs créées" -ForegroundColor Yellow
}