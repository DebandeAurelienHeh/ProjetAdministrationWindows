# ============================================
# VARIABLES DE CONFIGURATION
# ============================================
$CSVPath = "C:\chemin\vers\utilisateurs.csv"
$Domain = "espagne.lan"
$BaseOU = "OU=Utilisateurs,DC=espagne,DC=lan"
$PasswordExportPath = "C:\chemin\vers\passwords_export.csv"
$LogPath = "C:\chemin\vers\creation_users.log"
$PasswordLength = 10

# ============================================
# FONCTION : GENERATION MOT DE PASSE COMPLEXE
# ============================================
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

# ============================================
# FONCTION : CONVERTIR PRENOM EN INITIALES
# ============================================
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

# ============================================
# FONCTION : ECRIRE DANS LE LOG
# ============================================
function Write-Log {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Type] $Message"
    Add-Content -Path $LogPath -Value $LogMessage
    
    # Afficher aussi dans la console avec couleur
    switch ($Type) {
        "ERROR" { Write-Host $LogMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        default { Write-Host $LogMessage }
    }
}

# ============================================
# DEBUT DU SCRIPT
# ============================================
Write-Log "=== DEBUT DE LA CREATION DES UTILISATEURS ===" "INFO"

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

# ============================================
# TRAITEMENT DE CHAQUE UTILISATEUR
# ============================================
foreach ($User in $Users) {
    $Nom = $User.Nom
    $PrenomBrut = $User.Prenom
    $Description = $User.Description
    $Departement = $User.Departement
    $NumeroInterne = $User.N_Interne
    $Bureau = $User.Bureau
    
    Write-Log "----------------------------------------" "INFO"
    Write-Log "Traitement de : $PrenomBrut $Nom" "INFO"
    
    # Générer le login (SamAccountName)
    $PrenomInitiales = Convert-PrenomToInitials -Prenom $PrenomBrut
    $NomLower = $Nom.ToLower()
    $SamAccountName = "$PrenomInitiales.$NomLower"
    
    # Générer le DisplayName
    $PrenomDisplay = $PrenomBrut -replace "_", " "
    $DisplayName = "$PrenomDisplay $Nom"
    
    # Générer l'email
    $Email = "$SamAccountName@$Departement.es"
    
    # Générer l'UPN
    $UPN = "$SamAccountName@$Domain"
    
    # Générer le mot de passe
    $Password = Generate-ComplexPassword -Length $PasswordLength
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    
    Write-Log "  Login: $SamAccountName" "INFO"
    Write-Log "  DisplayName: $DisplayName" "INFO"
    Write-Log "  Email: $Email" "INFO"
    Write-Log "  UPN: $UPN" "INFO"
    
    # Vérifier si l'utilisateur existe déjà
    try {
        $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction SilentlyContinue
        if ($ExistingUser) {
            Write-Log "  ATTENTION: L'utilisateur $SamAccountName existe déjà - ignoré" "WARNING"
            continue
        }
    } catch {
        Write-Log "  Erreur lors de la vérification de l'existence de l'utilisateur - $_" "ERROR"
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
            -AccountPassword $SecurePassword `
            -Enabled $true `
            -ChangePasswordAtLogon $false `
            -PasswordNeverExpires $false `
            -Path $BaseOU
        
        # Configurer l'expiration du mot de passe à 30 jours
        Set-ADUser -Identity $SamAccountName -Replace @{pwdLastSet=0}
        Set-ADUser -Identity $SamAccountName -Replace @{pwdLastSet=-1}
        
        Write-Log "  Utilisateur créé avec succès !" "SUCCESS"
        
        # Ajouter au tableau d'export des mots de passe
        $PasswordExport += [PSCustomObject]@{
            Nom = $Nom
            Prenom = $PrenomDisplay
            Login = $SamAccountName
            Email = $Email
            MotDePasse = $Password
            Departement = $Departement
        }
        
    } catch {
        Write-Log "  ERREUR lors de la création de l'utilisateur : $_" "ERROR"
    }
}

# ============================================
# EXPORT DES MOTS DE PASSE
# ============================================
try {
    $PasswordExport | Export-Csv -Path $PasswordExportPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation
    Write-Log "=== Fichier des mots de passe exporté : $PasswordExportPath ===" "SUCCESS"
} catch {
    Write-Log "ERREUR lors de l'export des mots de passe : $_" "ERROR"
}

Write-Log "=== CREATION DES UTILISATEURS TERMINEE ===" "INFO"
Write-Log "Total utilisateurs traités : $($Users.Count)" "INFO"
Write-Log "Total utilisateurs créés : $($PasswordExport.Count)" "INFO"
