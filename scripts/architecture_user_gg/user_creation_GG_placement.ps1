$CSVPath = "C:\Scripts\utilisateurs.csv"
$Domain = "espagne.lan"
$RootDN = "DC=espagne,DC=lan"
$BaseOU = "OU=Utilisateurs,$RootDN"
$PasswordExportPath = "C:\Scripts\passwords_export.csv"
$LogPath = "C:\Scripts\creation_users_log.txt"
$PasswordLength = 10
$DirecteurPasswordLength = 15

$DepartmentGroupMapping = @{
    # Direction
    "Direction" = @("GG_Direction")
    
    # Ressources Humaines
    "Gestion_du_personnelRessources_humaines" = @("GG_RessourcesHumaines", "GG_GestionPersonnel")
    "RecrutementRessources_humaines" = @("GG_RessourcesHumaines", "GG_Recrutement")
    
    # R&D
    "RechercheRD" = @("GG_RD", "GG_Recherche")
    "TestingRD" = @("GG_RD", "GG_Testing")
    
    # Marketing
    "Site1Marketting" = @("GG_Marketing", "GG_MarketingSite1")
    "Site2Marketting" = @("GG_Marketing", "GG_MarketingSite2")
    "Site3Marketting" = @("GG_Marketing", "GG_MarketingSite3")
    "Site4Marketting" = @("GG_Marketing", "GG_MarketingSite4")
    
    # Finances
    "ComptabiliteFinances" = @("GG_Finances", "GG_Comptabilite")
    "InvestissementsFinances" = @("GG_Finances", "GG_Investissements")
    
    # Technique
    "AchatTechnique" = @("GG_Technique", "GG_Achat")
    "TechniciensTechnique" = @("GG_Technique", "GG_Techniciens")
    
    # Informatique
    "SystemesInformatique" = @("GG_Informatique", "GG_Systemes")
    "DeveloppementInformatique" = @("GG_Informatique", "GG_Developpement")
    "HotLineInformatique" = @("GG_Informatique", "GG_HotLine")
    
    # Commerciaux
    "SedentairesCommerciaux" = @("GG_Commerciaux", "GG_Sedentaires")
    "TechnicoCommerciaux" = @("GG_Commerciaux", "GG_Technico")
}

$DepartmentOUMapping = @{
    # Direction
    "Direction" = "OU=Direction,$BaseOU"
    
    # Ressources Humaines
    "Gestion_du_personnelRessources_humaines" = "OU=Gestion du personnel,OU=Ressources humaines,$BaseOU"
    "RecrutementRessources_humaines" = "OU=Recrutement,OU=Ressources humaines,$BaseOU"
    "RessourcesHumaines" = "OU=Ressources humaines,$BaseOU"
    
    # R&D
    "RechercheRD" = "OU=Recherche,OU=R&D,$BaseOU"
    "TestingRD" = "OU=Testing,OU=R&D,$BaseOU"
    "RD" = "OU=R&D,$BaseOU"
    
    # Marketing
    "Site1Marketting" = "OU=Site 1,OU=Marketting,$BaseOU"
    "Site2Marketting" = "OU=Site 2,OU=Marketting,$BaseOU"
    "Site3Marketting" = "OU=Site 3,OU=Marketting,$BaseOU"
    "Site4Marketting" = "OU=Site 4,OU=Marketting,$BaseOU"
    "Marketting" = "OU=Marketting,$BaseOU"
    
    # Finances
    "ComptabiliteFinances" = "OU=Comptabilité,OU=Finances,$BaseOU"
    "InvestissementsFinances" = "OU=Investissements,OU=Finances,$BaseOU"
    "Finances" = "OU=Finances,$BaseOU"
    
    # Technique
    "AchatTechnique" = "OU=Achat,OU=Technique,$BaseOU"
    "TechniciensTechnique" = "OU=Techniciens,OU=Technique,$BaseOU"
    "Technique" = "OU=Technique,$BaseOU"
    
    # Informatique
    "SystemesInformatique" = "OU=Systèmes,OU=Informatique,$BaseOU"
    "DeveloppementInformatique" = "OU=Développement,OU=Informatique,$BaseOU"
    "HotLineInformatique" = "OU=HotLine,OU=Informatique,$BaseOU"
    "Informatique" = "OU=Informatique,$BaseOU"
    
    # Commerciaux
    "SedentairesCommerciaux" = "OU=Sédentaires,OU=Commerciaux,$BaseOU"
    "TechnicoCommerciaux" = "OU=Technico,OU=Commerciaux,$BaseOU"
    "Commerciaux" = "OU=Commerciaux,$BaseOU"
    
    # Responsables (dossiers spéciaux)
    "ResponsableDepartement" = "OU=ResponsableDepartement,$BaseOU"
    "ResponsableGestion" = "OU=ResponsableGestion,$BaseOU"
    "ResponsableRecrutement" = "OU=ResponsableRecrutement,$BaseOU"
}

function Generate-ComplexPassword {
    param([int]$Length = 10)
    
    $Uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $Lowercase = "abcdefghijklmnopqrstuvwxyz"
    $Numbers = "0123456789"
    $SpecialChars = "!@#$%^&*()-_=+[]{}|;:,.<>?"
    
    # S'assurer qu'on a au moins 1 de chaque type
    $Password = @()
    $Password += $Uppercase[(Get-Random -Maximum $Uppercase.Length)]
    $Password += $Lowercase[(Get-Random -Maximum $Lowercase.Length)]
    $Password += $Numbers[(Get-Random -Maximum $Numbers.Length)]
    $Password += $SpecialChars[(Get-Random -Maximum $SpecialChars.Length)]
    
    # Remplir le reste aléatoirement
    $AllChars = $Uppercase + $Lowercase + $Numbers + $SpecialChars
    for ($i = $Password.Count; $i -lt $Length; $i++) {
        $Password += $AllChars[(Get-Random -Maximum $AllChars.Length)]
    }
    
    # Mélanger le tableau
    $Password = $Password | Get-Random -Count $Password.Count
    
    return -join $Password
}

function Convert-PrenomToInitials {
    param([string]$Prenom)
    
    # Remplacer underscores par espaces et splitter
    $Parts = $Prenom -replace "_", " " -split " "
    
    if ($Parts.Count -gt 1) {
        # Prénom composé : prendre les initiales
        $Initials = ($Parts | ForEach-Object { $_.Substring(0,1).ToLower() }) -join ""
        return $Initials
    } else {
        # Prénom simple : retourner en minuscules
        return $Prenom.ToLower()
    }
}

function Get-DepartmentGroups {
    param([string]$Departement)
    
    if ($DepartmentGroupMapping.ContainsKey($Departement)) {
        return $DepartmentGroupMapping[$Departement]
    } else {
        Write-Log "AVERTISSEMENT: Aucun groupe défini pour '$Departement'" "WARNING"
        return @()
    }
}

function Get-DepartmentOU {
    param([string]$Departement)
    
    if ($DepartmentOUMapping.ContainsKey($Departement)) {
        return $DepartmentOUMapping[$Departement]
    } else {
        # Si le département n'est pas trouvé, utiliser l'OU de base
        Write-Log "AVERTISSEMENT: Département '$Departement' non trouvé dans la table de correspondance" "WARNING"
        Write-Log "L'utilisateur sera placé dans l'OU de base : $BaseOU" "WARNING"
        return $BaseOU
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Type] $Message"
    Add-Content -Path $LogPath -Value $LogMessage -ErrorAction SilentlyContinue
    
    # Afficher aussi dans la console avec couleur
    switch ($Type) {
        "ERROR" { Write-Host $LogMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        default { Write-Host $LogMessage }
    }
}


# Vérifier que le module Active Directory est chargé
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log "Module Active Directory chargé avec succès" "SUCCESS"
} catch {
    Write-Log "ERREUR: Impossible de charger le module Active Directory - $_" "ERROR"
    exit
}

# Vérifier l'existence du fichier CSV
if (-not (Test-Path $CSVPath)) {
    Write-Log "ERREUR: Fichier CSV introuvable : $CSVPath" "ERROR"
    exit
}

# Charger le CSV
try {
    $Users = Import-Csv -Path $CSVPath -Delimiter ";" -Encoding UTF8
    Write-Log "Fichier CSV chargé : $($Users.Count) utilisateurs trouvés" "SUCCESS"
} catch {
    Write-Log "ERREUR: Impossible de lire le fichier CSV - $_" "ERROR"
    exit
}

# Préparer le tableau pour l'export des mots de passe
$PasswordExport = @()
$SuccessCount = 0
$ErrorCount = 0
$SkipCount = 0

# Traiter chaque utilisateur

foreach ($User in $Users) {
    $Nom = $User.Nom
    $PrenomBrut = $User.Prenom
    $Description = $User.Description
    $Departement = $User.Departement
    $NumeroInterne = $User.N_Interne
    $Bureau = $User.Bureau
    
    Write-Log "Traitement de : $PrenomBrut $Nom" "INFO"
    
    # Déterminer l'OU de destination
    $TargetOU = Get-DepartmentOU -Departement $Departement
    Write-Log "OU de destination : $TargetOU" "INFO"
    
    # Vérifier que l'OU existe
    try {
        $OUExists = Get-ADOrganizationalUnit -Identity $TargetOU -ErrorAction Stop
    } catch {
        Write-Log "ERREUR: L'OU '$TargetOU' n'existe pas !" "ERROR"
        Write-Log "Veuillez créer la structure AD avant de créer les utilisateurs" "ERROR"
        $ErrorCount++
        continue
    }
    
    # Générer le login 
    $PrenomInitiales = Convert-PrenomToInitials -Prenom $PrenomBrut
    $NomLower = $Nom.ToLower()
    $SamAccountName = "$PrenomInitiales.$NomLower"
    
    # Générer le DisplayName
    $PrenomDisplay = $PrenomBrut -replace "_", " "
    $DisplayName = "$PrenomDisplay $Nom"
    
    # Générer l'email
    $Email = "$SamAccountName@$Domain"
    
    # Générer l'UPN
    $UPN = "$SamAccountName@$Domain"
    
    # Changer la longueur du mot de passe si directeur
    if ($Departement -eq "Direction") {
        $PasswordLengthToUse = $DirecteurPasswordLength
    } else {
        $PasswordLengthToUse = $PasswordLength
    }
    
    # Générer le mot de passe
    $Password = Generate-ComplexPassword -Length $PasswordLengthToUse
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    
    Write-Log "Login: $SamAccountName" "INFO"
    Write-Log "DisplayName: $DisplayName" "INFO"
    Write-Log "Email: $Email" "INFO"
    Write-Log "UPN: $UPN" "INFO"
    Write-Log "Département: $Departement" "INFO"
    
    # Vérifier si l'utilisateur existe déjà
    try {
        $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction SilentlyContinue
        if ($ExistingUser) {
            Write-Log "ATTENTION: L'utilisateur $SamAccountName existe déjà - ignoré" "WARNING"
            $SkipCount++
            continue
        }
    } catch {
        Write-Log "Erreur lors de la vérification de l'existence de l'utilisateur - $_" "ERROR"
        $ErrorCount++
        continue
    }
    
    # Créer l'utilisateur AD
    try {
        New-ADUser `
            -SamAccountName $SamAccountName `
            -UserPrincipalName $UPN `
            -Name $DisplayName `
            -DisplayName $DisplayName `
            -GivenName $PrenomDisplay `
            -Surname $Nom `
            -EmailAddress $Email `
            -Description $Description `
            -Department $Departement `
            -Office $Bureau `
            -OfficePhone $NumeroInterne `
            -OtherAttributes @{ipPhone=$NumeroInterne} `
            -AccountPassword $SecurePassword `
            -Enabled $true `
            -ChangePasswordAtLogon $false `
            -PasswordNeverExpires $false `
            -Path $TargetOU `
            -ErrorAction Stop
        
        Set-ADUser -Identity $SamAccountName -Replace @{pwdLastSet=0} -ErrorAction Stop
        Set-ADUser -Identity $SamAccountName -Replace @{pwdLastSet=-1} -ErrorAction Stop
        
        $LogonHours = New-Object byte[] 21
        for ($i = 0; $i -lt 21; $i++) {
            $LogonHours[$i] = 0x00
        }
        for ($day = 0; $day -lt 7; $day++) {
            $baseIndex = $day * 3
            $LogonHours[$baseIndex] = 0xFC
            $LogonHours[$baseIndex + 1] = 0x7F
            $LogonHours[$baseIndex + 2] = 0x00
        }
        Set-ADUser -Identity $SamAccountName -Replace @{logonHours=$LogonHours} -ErrorAction Stop
        
        Write-Log "Utilisateur créé avec succès dans $TargetOU !" "SUCCESS"
        $SuccessCount++
        
        # Ajouter l'utilisateur aux groupes appropriés
        $UserGroups = Get-DepartmentGroups -Departement $Departement
        if ($UserGroups.Count -gt 0) {
            Write-Log "  Ajout aux groupes" "INFO"
            foreach ($GroupName in $UserGroups) {
                try {
                    # Vérifier que le groupe existe
                    $Group = Get-ADGroup -Identity $GroupName -ErrorAction Stop
                    
                    # Ajouter l'utilisateur au groupe
                    Add-ADGroupMember -Identity $GroupName -Members $SamAccountName -ErrorAction Stop
                    Write-Log "Ajouté au groupe : $GroupName" "SUCCESS"
                } catch {
                    Write-Log "ERREUR ajout au groupe $GroupName : $_" "ERROR"
                }
            }
        }
        
        # Ajouter au tableau d'export des mots de passe
        $PasswordExport += [PSCustomObject]@{
            Nom = $Nom
            Prenom = $PrenomDisplay
            Login = $SamAccountName
            Email = $Email
            MotDePasse = $Password
            Departement = $Departement
            OU = $TargetOU
        }
        
    } catch {
        Write-Log "ERREUR lors de la création de l'utilisateur : $_" "ERROR"
        $ErrorCount++
    }
}

# Export des MDP
try {
    $PasswordExport | Export-Csv -Path $PasswordExportPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation
    Write-Log "Fichier des mots de passe exporté : $PasswordExportPath" "SUCCESS"
} catch {
    Write-Log "ERREUR lors de l'export des mots de passe : $_" "ERROR"
}

Write-Log "CREATION DES UTILISATEURS TERMINEE" "INFO"
Write-Log "Total utilisateurs traités : $($Users.Count)" "INFO"
Write-Log "Utilisateurs créés avec succès : $SuccessCount" "SUCCESS"
Write-Log "Utilisateurs ignorés (déjà existants) : $SkipCount" "WARNING"
Write-Log "Erreurs rencontrées : $ErrorCount" "ERROR"

Write-Host "`nRESUME FINAL" -ForegroundColor Cyan
Write-Host "Traités : $($Users.Count) | Créés : $SuccessCount | Ignorés : $SkipCount | Erreurs : $ErrorCount" -ForegroundColor White
