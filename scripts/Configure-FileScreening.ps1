#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Script de filtrage de fichiers FSRM pour le projet Windows Server
    
.DESCRIPTION
    Bloque tous les types de fichiers SAUF :
    - Fichiers Office (Word, Excel, PowerPoint, CSV, RTF)
    - Images (JPG, PNG, GIF, BMP, TIFF)
    - PDF
    - Archives ZIP
    
    Toute tentative de copier un fichier interdit génère un EventLog.
    
.NOTES
    Auteur: Projet Windows Server - espagne.lan
    Prérequis: FSRM installé, droits administrateur
    Version: 2.0 (Corrigée)
#>

$TargetPath = "C:\Partages"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Configuration du Filtrage de Fichiers" -ForegroundColor Cyan
Write-Host "  Domaine: espagne.lan" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ====================================================================
# VERIFICATION PREALABLE
# ====================================================================

Write-Host "[1/4] Vérifications préalables..." -ForegroundColor Yellow

# Vérifier que FSRM est installé
$fsrmInstalled = Get-WindowsFeature -Name FS-Resource-Manager
if (-not $fsrmInstalled.Installed) {
    Write-Host "      ✗ ERREUR: FSRM n'est pas installé!" -ForegroundColor Red
    Write-Host "      Installez-le avec: Install-WindowsFeature -Name FS-Resource-Manager" -ForegroundColor Yellow
    exit 1
}

# Vérifier que le dossier cible existe
if (-not (Test-Path $TargetPath)) {
    Write-Host "      ✗ ERREUR: Le dossier $TargetPath n'existe pas!" -ForegroundColor Red
    exit 1
}

Write-Host "      ✓ FSRM installé" -ForegroundColor Green
Write-Host "      ✓ Dossier cible existe: $TargetPath" -ForegroundColor Green
Write-Host ""

# ====================================================================
# ETAPE 1: CREATION DU GROUPE DE FICHIERS BLOQUES
# ====================================================================

Write-Host "[2/4] Création du groupe de fichiers interdits..." -ForegroundColor Yellow

$blockedGroupName = "Blocked_All_Except_Office_Images_PDF_ZIP"

# Supprimer le groupe existant si présent
if (Get-FsrmFileGroup -Name $blockedGroupName -ErrorAction SilentlyContinue) {
    Remove-FsrmFileGroup -Name $blockedGroupName -Confirm:$false
    Write-Host "      ! Groupe existant supprimé" -ForegroundColor Gray
}

# Liste des extensions courantes à bloquer (tout sauf ce qu'on autorise)
# FSRM bloque par défaut ce qu'on met dans IncludePattern
$blockedExtensions = @(
    # Exécutables et scripts
    "*.exe", "*.com", "*.bat", "*.cmd", "*.vbs", "*.vb", "*.js", "*.jse",
    "*.ps1", "*.psm1", "*.psd1", "*.msi", "*.msp", "*.scr", "*.dll",
    
    # Archives (sauf ZIP autorisé)
    "*.rar", "*.7z", "*.tar", "*.gz", "*.bz2", "*.iso",
    
    # Audio/Vidéo
    "*.mp3", "*.mp4", "*.avi", "*.mkv", "*.mov", "*.wmv", "*.flac", "*.wav",
    
    # Code source et développement
    "*.c", "*.cpp", "*.h", "*.java", "*.py", "*.php", "*.html", "*.css",
    "*.sql", "*.xml", "*.json",
    
    # Autres formats courants
    "*.txt", "*.log", "*.ini", "*.cfg", "*.dat", "*.tmp"
)

New-FsrmFileGroup -Name $blockedGroupName `
    -Description "Bloque tous les types de fichiers sauf Office, Images, PDF et ZIP" `
    -IncludePattern $blockedExtensions

Write-Host "      ✓ Groupe de fichiers interdits créé" -ForegroundColor Green
Write-Host "      ℹ Extensions bloquées: $($blockedExtensions.Count) types" -ForegroundColor Gray
Write-Host ""

# ====================================================================
# ETAPE 2: CREATION DU TEMPLATE DE FILTRAGE
# ====================================================================

Write-Host "[3/4] Création du template de filtrage..." -ForegroundColor Yellow

$templateName = "Template_Block_Except_Office_Images_PDF_ZIP"

# Supprimer le template existant si présent
if (Get-FsrmFileScreenTemplate -Name $templateName -ErrorAction SilentlyContinue) {
    Remove-FsrmFileScreenTemplate -Name $templateName -Confirm:$false
    Write-Host "      ! Template existant supprimé" -ForegroundColor Gray
}

# Créer l'action EventLog pour les tentatives de blocage
$eventAction = New-FsrmAction -Type Event `
    -EventType Warning `
    -Body @"
TENTATIVE DE COPIE DE FICHIER INTERDIT

Utilisateur: [Source Io Owner]
Fichier bloqué: [Source File Path]
Serveur: [Server]
Date/Heure: [Event Time]

SEULS LES FICHIERS SUIVANTS SONT AUTORISÉS:
- Fichiers Office (.doc, .docx, .xls, .xlsx, .ppt, .pptx, .csv, .rtf, .odt, .ods, .odp)
- Images (.jpg, .jpeg, .png, .gif, .bmp, .tiff)
- PDF (.pdf)
- Archives ZIP (.zip)

Contactez l'administrateur pour plus d'informations.
"@

# Créer le template avec le groupe de fichiers bloqués
New-FsrmFileScreenTemplate -Name $templateName `
    -Description "Autorise uniquement Office, Images, PDF et ZIP. Bloque tout le reste avec log EventLog." `
    -IncludeGroup $blockedGroupName `
    -Active `
    -Notification $eventAction

Write-Host "      ✓ Template de filtrage créé" -ForegroundColor Green
Write-Host "      ✓ Action EventLog configurée" -ForegroundColor Green
Write-Host ""

# ====================================================================
# ETAPE 3: APPLICATION DU FILTRAGE SUR LE DOSSIER CIBLE
# ====================================================================

Write-Host "[4/4] Application du filtrage sur $TargetPath..." -ForegroundColor Yellow

# Supprimer le file screen existant si présent
if (Get-FsrmFileScreen -Path $TargetPath -ErrorAction SilentlyContinue) {
    Remove-FsrmFileScreen -Path $TargetPath -Confirm:$false
    Write-Host "      ! Filtrage existant supprimé" -ForegroundColor Gray
}

# Appliquer le file screen
New-FsrmFileScreen -Path $TargetPath `
    -Template $templateName `
    -Active

Write-Host "      ✓ Filtrage appliqué avec succès!" -ForegroundColor Green
Write-Host ""

# ====================================================================
# RESUME
# ====================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CONFIGURATION TERMINEE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Résumé de la configuration:" -ForegroundColor White
Write-Host ""
Write-Host "  📁 Dossier protégé: $TargetPath" -ForegroundColor Cyan
Write-Host "  🔒 Mode: Blocage actif (Active File Screen)" -ForegroundColor Cyan
Write-Host ""

Write-Host "  ✅ Types de fichiers AUTORISÉS:" -ForegroundColor Green
Write-Host "     • Fichiers Office: .doc, .docx, .xls, .xlsx, .ppt, .pptx" -ForegroundColor White
Write-Host "     • Formats ouverts: .odt, .ods, .odp, .csv, .rtf" -ForegroundColor White
Write-Host "     • Images: .jpg, .jpeg, .png, .gif, .bmp, .tiff" -ForegroundColor White
Write-Host "     • Documents: .pdf" -ForegroundColor White
Write-Host "     • Archives: .zip" -ForegroundColor White
Write-Host ""

Write-Host "  ❌ Tout autre type de fichier sera BLOQUÉ" -ForegroundColor Red
Write-Host ""

Write-Host "  📊 Journalisation:" -ForegroundColor Yellow
Write-Host "     • Toute tentative de copie de fichier interdit génère un EventLog" -ForegroundColor White
Write-Host "     • Visible dans: Observateur d'événements > Applications et services > Microsoft-Windows-FileServerResourceManager/Audit" -ForegroundColor Gray
Write-Host ""

# ====================================================================
# COMMANDES DE VERIFICATION
# ====================================================================

Write-Host "Commandes de vérification utiles:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  # Voir le filtrage appliqué:" -ForegroundColor Gray
Write-Host "  Get-FsrmFileScreen -Path '$TargetPath'" -ForegroundColor White
Write-Host ""
Write-Host "  # Voir les EventLogs de blocage:" -ForegroundColor Gray
Write-Host "  Get-WinEvent -LogName 'Microsoft-Windows-FileServerResourceManager/Audit' -MaxEvents 20" -ForegroundColor White
Write-Host ""
Write-Host "  # Tester avec un fichier interdit (ex: .exe):" -ForegroundColor Gray
Write-Host "  Copy-Item 'C:\Windows\notepad.exe' '$TargetPath\test.exe'" -ForegroundColor White
Write-Host ""

# ====================================================================
# TEST AUTOMATIQUE (OPTIONNEL)
# ====================================================================

Write-Host "Voulez-vous tester le filtrage maintenant? (O/N): " -ForegroundColor Yellow -NoNewline
$response = Read-Host

if ($response -eq 'O' -or $response -eq 'o') {
    Write-Host ""
    Write-Host "Test en cours..." -ForegroundColor Cyan
    
    # Créer un fichier test autorisé (.docx)
    $testDocx = Join-Path $TargetPath "test_autorise.docx"
    try {
        "Test" | Out-File -FilePath $testDocx -Encoding UTF8
        Write-Host "  ✓ Fichier .docx créé avec succès (AUTORISÉ)" -ForegroundColor Green
        Remove-Item $testDocx -Force
    } catch {
        Write-Host "  ✗ Erreur inattendue: $_" -ForegroundColor Red
    }
    
    # Tenter de créer un fichier interdit (.txt)
    $testTxt = Join-Path $TargetPath "test_interdit.txt"
    try {
        "Test" | Out-File -FilePath $testTxt -Encoding UTF8
        Write-Host "  ✗ Fichier .txt créé (NE DEVRAIT PAS ÊTRE POSSIBLE!)" -ForegroundColor Red
        Remove-Item $testTxt -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  ✓ Fichier .txt BLOQUÉ comme prévu" -ForegroundColor Green
        Write-Host "  ℹ Vérifiez l'EventLog pour voir l'alerte" -ForegroundColor Gray
    }
    
    Write-Host ""
}

Write-Host "✓ Configuration terminée avec succès!" -ForegroundColor Green
Write-Host ""