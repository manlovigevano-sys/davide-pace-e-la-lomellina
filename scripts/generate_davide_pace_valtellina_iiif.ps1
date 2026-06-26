$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$iiifRoot = Join-Path $root "img\derivatives\iiif"
$imagesRoot = Join-Path $iiifRoot "images"
$manifestDir = Join-Path $iiifRoot "davide-pace-contesto-alpino-scat12-f255-doc. 1"

function IiifUrl([string]$Path) {
    return "/davide-pace-e-la-lomellina/$Path"
}

$item = @{
    Pid = "davide-pace-contesto-alpino-scat12-f255-doc. 1"
    Source = "assets\images\davide-pace\valtellina\FDP_SCAT12_F255_UD001_ME.jpg"
    Suffix = "recto"
    Label = "Davide Pace in contesto alpino, recto"
    Title = "Fotografia di Davide Pace in contesto alpino, agosto 1964"
    Reference = "Archivio Davide Pace, scat. 12, fasc. 255, doc. 1"
    Date = "agosto 1964"
    Description = "Fotografia di Davide Pace in contesto alpino, agosto 1964. L'identificazione del luogo non e certa; l'immagine e collegata alla fase di passaggio dagli studi in Lomellina all'interesse per i contesti alpini."
    Subject = "Davide Pace; contesto alpino; fotografia personale; agosto 1964"
}

function Get-ImageSize {
    param([string]$Path)

    $magick = Get-Command magick -ErrorAction SilentlyContinue
    if (-not $magick) {
        throw "ImageMagick 'magick' non trovato nel PATH."
    }

    $size = & $magick.Source identify -format "%w %h" $Path
    if ($LASTEXITCODE -ne 0) {
        throw "Impossibile leggere dimensioni immagine: $Path"
    }

    $parts = $size -split " "
    return @{ Width = [int]$parts[0]; Height = [int]$parts[1] }
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Data
    )

    $json = $Data | ConvertTo-Json -Depth 30
    $json = $json -replace '\\u0027', "'"
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json, $encoding)
}

New-Item -ItemType Directory -Force -Path $imagesRoot, $manifestDir | Out-Null

$sourcePath = Join-Path $root $item.Source
if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "File sorgente mancante: $sourcePath"
}

$imageId = "$($item.Pid)-$($item.Suffix)"
$imageDir = Join-Path $imagesRoot $imageId
$fullDir = Join-Path $imageDir "full\full\0"
New-Item -ItemType Directory -Force -Path $fullDir | Out-Null

$targetImage = Join-Path $fullDir "default.jpg"
& magick $sourcePath -auto-orient -strip -quality 92 $targetImage
if ($LASTEXITCODE -ne 0) {
    throw "Errore nella generazione dell'immagine IIIF."
}

$size = Get-ImageSize -Path $targetImage
$largeWidth = [Math]::Min($size.Width, 5100)
$largeHeight = [Math]::Round($largeWidth * $size.Height / $size.Width)
$mediumHeight = [Math]::Round(1140 * $size.Height / $size.Width)
$thumbHeight = [Math]::Round(250 * $size.Height / $size.Width)
$largeDir = Join-Path $imageDir "full\$largeWidth,\0"
$mediumDir = Join-Path $imageDir "full\1140,\0"
$thumbDir = Join-Path $imageDir "full\250,\0"
New-Item -ItemType Directory -Force -Path $largeDir, $mediumDir, $thumbDir | Out-Null
& magick $sourcePath -auto-orient -strip -resize "${largeWidth}x" -quality 92 (Join-Path $largeDir "default.jpg")
& magick $sourcePath -auto-orient -strip -resize 1140x -quality 90 (Join-Path $mediumDir "default.jpg")
& magick $sourcePath -auto-orient -strip -resize 250x -quality 85 (Join-Path $thumbDir "default.jpg")

$serviceId = IiifUrl "img/derivatives/iiif/images/$imageId"
$imageUrl = "$serviceId/full/full/0/default.jpg"

$info = [ordered]@{
    "@context" = "http://iiif.io/api/image/2/context.json"
    "@id" = $serviceId
    protocol = "http://iiif.io/api/image"
    width = $size.Width
    height = $size.Height
    sizes = @(
        [ordered]@{ width = 250; height = $thumbHeight },
        [ordered]@{ width = 1140; height = $mediumHeight },
        [ordered]@{ width = $largeWidth; height = $largeHeight },
        [ordered]@{ width = $size.Width; height = $size.Height }
    )
    profile = @(
        "http://iiif.io/api/image/2/level0.json",
        [ordered]@{
            formats = @("jpg")
            qualities = @("default")
            supports = @("sizeByW")
        }
    )
}
Write-JsonFile -Path (Join-Path $imageDir "info.json") -Data $info

$canvasId = IiifUrl "img/derivatives/iiif/$($item.Pid)/canvas/$($item.Suffix)"
$annotationId = "$canvasId/annotation"

$manifest = [ordered]@{
    "@context" = "http://iiif.io/api/presentation/2/context.json"
    "@id" = IiifUrl "img/derivatives/iiif/$($item.Pid)/manifest.json"
    "@type" = "sc:Manifest"
    label = $item.Title
    metadata = @(
        [ordered]@{ label = "Fondo"; value = "Archivio Davide Pace" },
        [ordered]@{ label = "Segnatura"; value = $item.Reference },
        [ordered]@{ label = "Data"; value = $item.Date },
        [ordered]@{ label = "Soggetto"; value = $item.Subject },
        [ordered]@{ label = "Descrizione"; value = $item.Description }
    )
    description = $item.Description
    attribution = "Direzione regionale Musei nazionali Lombardia - Museo Archeologico Nazionale della Lomellina"
    sequences = @(
        [ordered]@{
            "@id" = IiifUrl "img/derivatives/iiif/$($item.Pid)/sequence/normal"
            "@type" = "sc:Sequence"
            label = "Sequenza principale"
            canvases = @(
                [ordered]@{
                    "@id" = $canvasId
                    "@type" = "sc:Canvas"
                    label = $item.Label
                    width = $size.Width
                    height = $size.Height
                    images = @(
                        [ordered]@{
                            "@id" = $annotationId
                            "@type" = "oa:Annotation"
                            motivation = "sc:painting"
                            resource = [ordered]@{
                                "@id" = $imageUrl
                                "@type" = "dctypes:Image"
                                format = "image/jpeg"
                                width = $size.Width
                                height = $size.Height
                                service = [ordered]@{
                                    "@context" = "http://iiif.io/api/image/2/context.json"
                                    "@id" = $serviceId
                                    profile = "http://iiif.io/api/image/2/level0.json"
                                }
                            }
                            on = $canvasId
                        }
                    )
                }
            )
        }
    )
}

Write-JsonFile -Path (Join-Path $manifestDir "manifest.json") -Data $manifest

Write-Host "Generato manifest IIIF: $($item.Pid)"
