$inputFile  = "Employes.csv"
$outputFile = "utilisateurs.csv"

# Fonction pour retirer accents et caractères problématiques
function Normalize-ADString {
    param([string]$text)
    if (-not $text) { return "" }
    # Supprimer les espaces 
    $clean = $text.Trim()
    # Remplacer les accents
    $clean = $clean.Normalize("FormD") -replace "\p{Mn}", ""
    # Remplacer les espaces internes par underscore
    $clean = $clean -replace "\s+", "_"
    # Supprimer caracteres non autorises pour AD
    $clean = $clean -replace "[^A-Za-z0-9_\-]", ""
    return $clean
}

$data = Import-Csv $inputFile -Delimiter ";" -Encoding Default

# Nettoyage de chaque colonne
$cleaned = foreach ($row in $data) {
    $newRow = [ordered]@{}
    foreach ($col in $row.PSObject.Properties.Name) {
        $cleanColName = Normalize-ADString $col
        $newRow[$cleanColName] = Normalize-ADString $row.$col
    }
    [PSCustomObject]$newRow
}

$cleaned | Export-Csv $outputFile -Delimiter ";" -NoTypeInformation -Encoding UTF8
Write-Host "Fichier nettoyé : $outputFile"
