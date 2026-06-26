$ErrorActionPreference = 'Stop'

function IiifUrl([string] $path) {
  return "{{ '/' | relative_url }}$path"
}

function Write-JekyllJson([string] $path, $object) {
  $json = $object | ConvertTo-Json -Depth 50
  $json = $json -replace '\\u0027', "'"
  $content = @(
    '---'
    'layout: none'
    '---'
    $json
  )
  $encoding = New-Object System.Text.UTF8Encoding($false)
  $directory = Split-Path -Parent $path
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
  [System.IO.File]::WriteAllLines((Resolve-Path -LiteralPath $directory).Path + [System.IO.Path]::DirectorySeparatorChar + (Split-Path -Leaf $path), $content, $encoding)
}

function Get-ImageDimensions([string] $path) {
  $line = magick identify -format '%w %h' $path
  $parts = $line -split ' '
  return @{ width = [int]$parts[0]; height = [int]$parts[1] }
}

function New-IiifManifest($manifestPid, $label, $pages, $reference, $typeLabel, $subject, $thumbnailSuffix) {
  New-Item -ItemType Directory -Force -Path `
    "img/derivatives/iiif/$manifestPid", `
    'img/derivatives/iiif/canvas', `
    'img/derivatives/iiif/annotation', `
    'img/derivatives/iiif/sequence' | Out-Null

  $canvases = @()

  foreach ($page in $pages) {
    $itemPid = "$manifestPid-$($page.suffix)"
    $dimensions = Get-ImageDimensions $page.source
    $width = $dimensions.width
    $height = $dimensions.height
    $largeWidth = [Math]::Min($width, 5100)
    $thumbHeight = [Math]::Round(250 * $height / $width)
    $largeHeight = [Math]::Round($largeWidth * $height / $width)
    $mediumHeight = [Math]::Round(1140 * $height / $width)

    $imageRoot = "img/derivatives/iiif/images/$itemPid"
    New-Item -ItemType Directory -Force -Path `
      $imageRoot, `
      "$imageRoot/full/full/0", `
      "$imageRoot/full/$largeWidth,/0", `
      "$imageRoot/full/1140,/0", `
      "$imageRoot/full/250,/0" | Out-Null

    magick $page.source -auto-orient -strip "$imageRoot/full/full/0/default.jpg"
    magick $page.source -auto-orient -strip -resize "${largeWidth}x" "$imageRoot/full/$largeWidth,/0/default.jpg"
    magick $page.source -auto-orient -strip -resize 1140x "$imageRoot/full/1140,/0/default.jpg"
    magick $page.source -auto-orient -strip -resize 250x "$imageRoot/full/250,/0/default.jpg"

    $serviceId = IiifUrl $imageRoot
    $thumbnail = IiifUrl "$imageRoot/full/250,/0/default.jpg"
    $fullImage = IiifUrl "$imageRoot/full/full/0/default.jpg"
    $canvasId = IiifUrl "img/derivatives/iiif/canvas/$itemPid.json"
    $annotationId = IiifUrl "img/derivatives/iiif/annotation/$itemPid.json"

    $info = [ordered] @{
      '@context' = 'http://iiif.io/api/image/2/context.json'
      '@id' = $serviceId
      protocol = 'http://iiif.io/api/image'
      width = $width
      height = $height
      sizes = @(
        [ordered] @{ width = 250; height = $thumbHeight }
        [ordered] @{ width = 1140; height = $mediumHeight }
        [ordered] @{ width = $largeWidth; height = $largeHeight }
        [ordered] @{ width = $width; height = $height }
      )
      profile = @(
        'http://iiif.io/api/image/2/level0.json'
        [ordered] @{ supports = @('sizeByW') }
      )
    }
    Write-JekyllJson "$imageRoot/info.json" $info

    $metadata = @(
      [ordered] @{ label = 'Titolo'; value = $page.canvasLabel }
      [ordered] @{ label = 'Tipologia'; value = $typeLabel }
      [ordered] @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
      [ordered] @{ label = 'Riferimento'; value = "Fondo Pace, b. 5, fasc. 140, $($page.doc)" }
      [ordered] @{ label = 'Data'; value = '27 gennaio 1961' }
      [ordered] @{ label = 'Luogo'; value = 'Dosso Vughera, settore Panzarasa, Gropello Cairoli' }
      [ordered] @{ label = 'File sorgente'; value = $page.file }
    )

    $resource = [ordered] @{
      '@id' = $fullImage
      '@type' = 'dcterms:Image'
      format = 'image/jpeg'
      service = [ordered] @{
        '@context' = 'http://iiif.io/api/image/2/context.json'
        '@id' = $serviceId
        profile = 'http://iiif.io/api/image/2/level0.json'
      }
      width = $width
      height = $height
    }

    $annotation = [ordered] @{
      '@type' = 'oa:Annotation'
      '@id' = $annotationId
      motivation = 'sc:painting'
      resource = $resource
      on = $canvasId
      '@context' = 'http://iiif.io/api/presentation/2/context.json'
    }
    Write-JekyllJson "img/derivatives/iiif/annotation/$itemPid.json" $annotation

    $canvas = [ordered] @{
      '@type' = 'sc:Canvas'
      '@id' = $canvasId
      label = $page.canvasLabel
      width = $width
      height = $height
      thumbnail = $thumbnail
      metadata = $metadata
      images = @($annotation)
      '@context' = 'http://iiif.io/api/presentation/2/context.json'
    }
    Write-JekyllJson "img/derivatives/iiif/canvas/$itemPid.json" $canvas
    $canvases += $canvas
  }

  $manifestMetadata = @(
    [ordered] @{ label = 'Titolo'; value = $label }
    [ordered] @{ label = 'Tipologia'; value = $typeLabel }
    [ordered] @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
    [ordered] @{ label = 'Riferimento'; value = $reference }
    [ordered] @{ label = 'Data'; value = '27 gennaio 1961' }
    [ordered] @{ label = 'Luogo'; value = 'Dosso Vughera, settore Panzarasa, Gropello Cairoli' }
    [ordered] @{ label = 'Soggetto'; value = $subject }
  )

  $sequence = [ordered] @{
    '@id' = IiifUrl "img/derivatives/iiif/sequence/$manifestPid.json"
    '@type' = 'sc:Sequence'
    canvases = $canvases
    '@context' = 'http://iiif.io/api/presentation/2/context.json'
  }
  Write-JekyllJson "img/derivatives/iiif/sequence/$manifestPid.json" $sequence

  $manifest = [ordered] @{
    '@context' = 'http://iiif.io/api/presentation/2/context.json'
    '@id' = IiifUrl "img/derivatives/iiif/$manifestPid/manifest.json"
    '@type' = 'sc:Manifest'
    label = $label
    thumbnail = IiifUrl "img/derivatives/iiif/images/$manifestPid-$thumbnailSuffix/full/250,/0/default.jpg"
    viewingDirection = 'left-to-right'
    viewingHint = 'individuals'
    metadata = $manifestMetadata
    sequences = @(
      [ordered] @{
        '@id' = IiifUrl "img/derivatives/iiif/sequence/$manifestPid.json"
        '@type' = 'sc:Sequence'
        canvases = $canvases
      }
    )
    full = IiifUrl "img/derivatives/iiif/images/$manifestPid-$thumbnailSuffix/full/full/0/default.jpg"
    fullwidth = IiifUrl "img/derivatives/iiif/images/$manifestPid-$thumbnailSuffix/full/1140,/0/default.jpg"
  }
  Write-JekyllJson "img/derivatives/iiif/$manifestPid/manifest.json" $manifest

  Write-Output "Generated IIIF for $manifestPid with $($pages.Count) canvases."
}

$positivePages = @(
  @{ doc = 'doc. 1 recto'; suffix = 'doc1-r'; source = 'assets/images/nucleo-3/carte/b5-f140/FDP_B05_F140_UD001_ME_R_02.jpg'; file = 'FDP_B05_F140_UD001_ME_R_02.jpg'; canvasLabel = 'Stampa fotografica dello scavo, doc. 1 recto' },
  @{ doc = 'doc. 1 verso'; suffix = 'doc1-v-01'; source = 'assets/images/nucleo-3/carte/b5-f140/FDP_B05_F140_UD001_ME_V_01.jpg'; file = 'FDP_B05_F140_UD001_ME_V_01.jpg'; canvasLabel = 'Retro della stampa fotografica, doc. 1 verso' },
  @{ doc = 'doc. 2 recto'; suffix = 'doc2-r-01'; source = 'assets/images/nucleo-3/carte/b5-f140/FDP_B05_F140_UD002_ME_R_01.jpg'; file = 'FDP_B05_F140_UD002_ME_R_01.jpg'; canvasLabel = 'Stampa fotografica dello scavo, doc. 2 recto' },
  @{ doc = 'doc. 2 verso'; suffix = 'doc2-v'; source = 'assets/images/nucleo-3/carte/b5-f140/FDP_B05_F140_UD002_ME_V_01.jpg'; file = 'FDP_B05_F140_UD002_ME_V_01.jpg'; canvasLabel = 'Retro della stampa fotografica, doc. 2 verso' }
)

$negativePages = @(
  @{ doc = 'doc. 3, fot. 2'; suffix = 'doc3-fot02-pos'; source = 'assets/images/nucleo-3/carte/b5-f140/FDP_B05_F140_UD003_ME_V_FOT02_01POS.jpg'; file = 'FDP_B05_F140_UD003_ME_V_FOT02_01POS.jpg'; canvasLabel = 'Negativo trasformato in positivo, fot. 2' },
  @{ doc = 'doc. 3, fot. 7'; suffix = 'doc3-fot07-pos'; source = 'assets/images/nucleo-3/carte/b5-f140/FDP_B05_F140_UD003_ME_V_FOT07_01POS.jpg'; file = 'FDP_B05_F140_UD003_ME_V_FOT07_01POS.jpg'; canvasLabel = 'Negativo trasformato in positivo, fot. 7' }
)

$manuscriptFiles = @(
  'FDP_B05_F140_UD004_ME_R.jpg',
  'FDP_B05_F140_UD004_ME_V.jpg',
  'FDP_B05_F140_UD005_ME_V.jpg',
  'FDP_B05_F140_UD006_ME_R.jpg',
  'FDP_B05_F140_UD007_ME_R.jpg',
  'FDP_B05_F140_UD008_ME_R.jpg',
  'FDP_B05_F140_UD009_ME_R.jpg',
  'FDP_B05_F140_UD010_ME_R.jpg',
  'FDP_B05_F140_UD011_ME_R.jpg',
  'FDP_B05_F140_UD012_ME_R.jpg',
  'FDP_B05_F140_UD013_ME_R.jpg',
  'FDP_B05_F140_UD013_ME_V.jpg',
  'FDP_B05_F140_UD014_ME_R.jpg',
  'FDP_B05_F140_UD014_ME_V.jpg',
  'FDP_B05_F140_UD015_ME_R.jpg',
  'FDP_B05_F140_UD015_ME_V.jpg',
  'FDP_B05_F140_UD016_ME_R.jpg',
  'FDP_B05_F140_UD016_ME_V.jpg',
  'FDP_B05_F140_UD017_ME_R.jpg',
  'FDP_B05_F140_UD017_ME_V.jpg',
  'FDP_B05_F140_UD018_ME_R.jpg',
  'FDP_B05_F140_UD018_ME_V.jpg',
  'FDP_B05_F140_UD019_ME_R.jpg',
  'FDP_B05_F140_UD019_ME_V.jpg',
  'FDP_B05_F140_UD020_ME_R.jpg',
  'FDP_B05_F140_UD020_ME_V.jpg',
  'FDP_B05_F140_UD021_ME_R.jpg',
  'FDP_B05_F140_UD021_ME_V.jpg',
  'FDP_B05_F140_UD022_ME_R.jpg',
  'FDP_B05_F140_UD022_ME_V.jpg',
  'FDP_B05_F140_UD023_ME_R.jpg',
  'FDP_B05_F140_UD023_ME_V.jpg',
  'FDP_B05_F140_UD024_ME_R.jpg',
  'FDP_B05_F140_UD024_ME_V.jpg',
  'FDP_B05_F140_UD025_ME_R.jpg'
)

$manuscriptPages = foreach ($file in $manuscriptFiles) {
  if ($file -match 'UD(\d+)_ME_([RV])') {
    $docNumber = [int]$Matches[1]
    $side = if ($Matches[2] -eq 'R') { 'recto' } else { 'verso' }
    $sideSuffix = if ($Matches[2] -eq 'R') { 'r' } else { 'v' }
    @{
      doc = "doc. $docNumber $side"
      suffix = "doc$docNumber-$sideSuffix"
      source = "assets/images/nucleo-3/carte/b5-f140/$file"
      file = $file
      canvasLabel = "Documentazione manoscritta e grafica, doc. $docNumber $side"
    }
  }
}

New-IiifManifest `
  'nucleo3-foto-scavo-b5-f140-positive' `
  'Fotografie digitalizzate dello scavo, b. 5, fasc. 140' `
  $positivePages `
  'Fondo Pace, b. 5, fasc. 140, doc. 1-2' `
  'documentazione fotografica di scavo' `
  'fotografie di scavo; tomba; ustrino; corredo funerario; retro con annotazioni' `
  'doc1-r'

New-IiifManifest `
  'nucleo3-negativi-positivi-b5-f140' `
  'Negativi trasformati in positivo dello scavo, b. 5, fasc. 140' `
  $negativePages `
  'Fondo Pace, b. 5, fasc. 140, doc. 3' `
  'negativi trasformati in positivo' `
  'negativi fotografici; positivo digitale; tomba; ustrino; corredo funerario' `
  'doc3-fot02-pos'

New-IiifManifest `
  'nucleo3-manoscritti-b5-f140' `
  'Documentazione manoscritta e grafica dello scavo, b. 5, fasc. 140' `
  $manuscriptPages `
  'Fondo Pace, b. 5, fasc. 140, doc. 4-25' `
  'giornale di scavo, annotazioni tecniche e disegni dei reperti' `
  'giornale di scavo; sepolcrum; ustrino; zona cinerea; corredo funerario; disegni dei reperti; note dimensionali' `
  'doc4-r'
