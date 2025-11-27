# SCRIPT : CREATION DES GROUPES GLOBAUX AD

$LogPath = "C:\Scripts\groupes_creation_log.txt"
$Domain = "espagne.lan"
$RootDN = "DC=espagne,DC=lan"
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
        default { Write-Host $Msg }
    }
}

Clear-Host
# Import Module AD
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log "Module AD chargé" "SUCCESS"
} catch {
    Write-Log "Erreur chargement module AD : $_" "ERROR"
    exit
}

# Créer l'OU Groupes si elle n'existe pas
try {
    $GroupsOUExists = Get-ADOrganizationalUnit -Identity $GroupsOU -ErrorAction Stop
    Write-Log "OU Groupes existe déjà" "INFO"
} catch {
    try {
        New-ADOrganizationalUnit -Name "Groupes" -Path $RootDN -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
        Write-Log "OU Groupes créée avec succès" "SUCCESS"
    } catch {
        Write-Log "ERREUR création OU Groupes : $_" "ERROR"
        exit
    }
}
# DEFINITION DES GROUPES A CREER

$Groupes = @(
    # Groupes Direction
    @{Name="GG_Direction"; Description="Membres de la Direction"; OU=$GroupsOU}
    
    # Groupes Ressources Humaines
    @{Name="GG_RessourcesHumaines"; Description="Tous les RH"; OU=$GroupsOU}
    @{Name="GG_GestionPersonnel"; Description="Gestion du personnel"; OU=$GroupsOU}
    @{Name="GG_Recrutement"; Description="Service Recrutement"; OU=$GroupsOU}
    @{Name="GG_Resp_GestionPersonnel"; Description="Responsable Gestion du personnel"; OU=$GroupsOU}
    @{Name="GG_Resp_Recrutement"; Description="Responsable Recrutement"; OU=$GroupsOU}
    
    # Groupes R&D
    @{Name="GG_RD"; Description="Tous les R&D"; OU=$GroupsOU}
    @{Name="GG_Recherche"; Description="Service Recherche"; OU=$GroupsOU}
    @{Name="GG_Testing"; Description="Service Testing"; OU=$GroupsOU}
    @{Name="GG_Resp_Recherche"; Description="Responsable Recherche"; OU=$GroupsOU}
    @{Name="GG_Resp_Testing"; Description="Responsable Testing"; OU=$GroupsOU}
    
    # Groupes Marketing
    @{Name="GG_Marketing"; Description="Tous les Marketing"; OU=$GroupsOU}
    @{Name="GG_MarketingSite1"; Description="Marketing Site 1"; OU=$GroupsOU}
    @{Name="GG_MarketingSite2"; Description="Marketing Site 2"; OU=$GroupsOU}
    @{Name="GG_MarketingSite3"; Description="Marketing Site 3"; OU=$GroupsOU}
    @{Name="GG_MarketingSite4"; Description="Marketing Site 4"; OU=$GroupsOU}
    @{Name="GG_Resp_MarketingSite1"; Description="Responsable Marketing Site 1"; OU=$GroupsOU}
    @{Name="GG_Resp_MarketingSite2"; Description="Responsable Marketing Site 2"; OU=$GroupsOU}
    @{Name="GG_Resp_MarketingSite3"; Description="Responsable Marketing Site 3"; OU=$GroupsOU}
    @{Name="GG_Resp_MarketingSite4"; Description="Responsable Marketing Site 4"; OU=$GroupsOU}
    
    # Groupes Finances
    @{Name="GG_Finances"; Description="Tous les Finances"; OU=$GroupsOU}
    @{Name="GG_Comptabilite"; Description="Service Comptabilité"; OU=$GroupsOU}
    @{Name="GG_Investissements"; Description="Service Investissements"; OU=$GroupsOU}
    @{Name="GG_Resp_Comptabilite"; Description="Responsable Comptabilité"; OU=$GroupsOU}
    @{Name="GG_Resp_Investissements"; Description="Responsable Investissements"; OU=$GroupsOU}
    
    # Groupes Technique
    @{Name="GG_Technique"; Description="Tous les Techniques"; OU=$GroupsOU}
    @{Name="GG_Techniciens"; Description="Techniciens"; OU=$GroupsOU}
    @{Name="GG_Achat"; Description="Service Achat"; OU=$GroupsOU}
    @{Name="GG_Resp_Techniciens"; Description="Responsable Techniciens"; OU=$GroupsOU}
    @{Name="GG_Resp_Achat"; Description="Responsable Achat"; OU=$GroupsOU}
    
    # Groupes Informatique
    @{Name="GG_Informatique"; Description="Tous les IT"; OU=$GroupsOU}
    @{Name="GG_Systemes"; Description="Administrateurs Systèmes"; OU=$GroupsOU}
    @{Name="GG_Developpement"; Description="Développeurs"; OU=$GroupsOU}
    @{Name="GG_HotLine"; Description="Support HotLine"; OU=$GroupsOU}
    @{Name="GG_Resp_Systemes"; Description="Responsable Systèmes"; OU=$GroupsOU}
    @{Name="GG_Resp_Developpement"; Description="Responsable Développement"; OU=$GroupsOU}
    @{Name="GG_Resp_HotLine"; Description="Responsable HotLine"; OU=$GroupsOU}
    
    # Groupes Commerciaux
    @{Name="GG_Commerciaux"; Description="Tous les Commerciaux"; OU=$GroupsOU}
    @{Name="GG_Sedentaires"; Description="Commerciaux Sédentaires"; OU=$GroupsOU}
    @{Name="GG_Technico"; Description="Technico-commerciaux"; OU=$GroupsOU}
    @{Name="GG_Resp_Sedentaires"; Description="Responsable Commerciaux Sédentaires"; OU=$GroupsOU}
    @{Name="GG_Resp_Technico"; Description="Responsable Technico-commerciaux"; OU=$GroupsOU}
    
    # Groupe Tous les Responsables
    @{Name="GG_Tous_Responsables"; Description="Tous les responsables de services"; OU=$GroupsOU}
)
# CREATION DES GROUPES

$SuccessCount = 0
$ExistCount = 0
$ErrorCount = 0

foreach ($Groupe in $Groupes) {
    $GroupName = $Groupe.Name
    Write-Log "Traitement : $GroupName" "INFO"
    
    # Vérifier si le groupe existe
    try {
        $ExistingGroup = Get-ADGroup -Identity $GroupName -ErrorAction SilentlyContinue
        if ($ExistingGroup) {
            Write-Log "  Le groupe $GroupName existe déjà" "WARNING"
            $ExistCount++
            continue
        }
    } catch {
        # Le groupe n'existe pas, on continue
    }
    
    # Créer le groupe
    try {
        New-ADGroup `
            -Name $GroupName `
            -SamAccountName $GroupName `
            -GroupCategory Security `
            -GroupScope Global `
            -DisplayName $GroupName `
            -Path $Groupe.OU `
            -Description $Groupe.Description `
            -ErrorAction Stop
        
        Write-Log "  Groupe créé : $GroupName" "SUCCESS"
        $SuccessCount++
    } catch {
        Write-Log "  ERREUR création $GroupName : $_" "ERROR"
        $ErrorCount++
    }
}

Write-Log "CREATION DES GROUPES TERMINEE" "INFO"
Write-Log "Groupes traités : $($Groupes.Count)" "INFO"
Write-Log "Groupes créés : $SuccessCount" "SUCCESS"
Write-Log "Groupes existants : $ExistCount" "WARNING"
Write-Log "Erreurs : $ErrorCount" "ERROR"
Write-Host "Total: $($Groupes.Count) | Créés: $SuccessCount | Existants: $ExistCount | Erreurs: $ErrorCount" -ForegroundColor White
