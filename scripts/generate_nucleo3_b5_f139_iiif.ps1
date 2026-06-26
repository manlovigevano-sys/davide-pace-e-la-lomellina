$ErrorActionPreference = 'Stop'

$manifestPid = 'nucleo3-giornale-scavo-b5-f139'
$label = 'Giornale di scavo e documentazione del fascicolo B5_F139'
$pages = @(
  @{ doc = 'doc. 1 recto'; suffix = 'doc. 1-r'; source = 'assets/images/nucleo-3/carte/b5-f139/FDP_B05_F139_UD001_ME_R.jpg'; file = 'FDP_B05_F139_UD001_ME_R.jpg'; canvasLabel = 'Giornale di scavo manoscritto, recto' },
  @{ doc = 'doc. 1 verso'; suffix = 'doc. 1-v'; source = 'assets/images/nucleo-3/carte/b5-f139/FDP_B05_F139_UD001_ME_V.jpg'; file = 'FDP_B05_F139_UD001_ME_V.jpg'; canvasLabel = 'Giornale di scavo manoscritto, verso con disegno dei reperti' },
  @{ doc = 'doc. 2 recto'; suffix = 'doc. 2-r'; source = 'assets/images/nucleo-3/carte/b5-f139/FDP_B05_F139_UD002_ME_R.jpg'; file = 'FDP_B05_F139_UD002_ME_R.jpg'; canvasLabel = 'Annotazione manoscritta collegata allo scavo' },
  @{ doc = 'doc. 3 recto'; suffix = 'doc. 3-r'; source = 'assets/images/nucleo-3/carte/b5-f139/FDP_B05_F139_UD003_ME_R.jpg'; file = 'FDP_B05_F139_UD003_ME_R.jpg'; canvasLabel = 'Disegno planimetrico schematico dell''area di scavo' },
  @{ doc = 'doc. 4 recto'; suffix = 'doc. 4-r'; source = 'assets/images/nucleo-3/carte/b5-f139/FDP_B05_F139_UD004_ME_R.jpg'; file = 'FDP_B05_F139_UD004_ME_R.jpg'; canvasLabel = 'Copia dattiloscritta del giornale di scavo, recto' },
  @{ doc = 'doc. 4 verso'; suffix = 'doc. 4-v'; source = 'assets/images/nucleo-3/carte/b5-f139/FDP_B05_F139_UD004_ME_V.jpg'; file = 'FDP_B05_F139_UD004_ME_V.jpg'; canvasLabel = 'Copia dattiloscritta del giornale di scavo, verso' }
)

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
    [ordered] @{ label = 'Tipologia'; value = 'giornale di scavo, annotazioni e disegni' }
    [ordered] @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
    [ordered] @{ label = 'Riferimento'; value = "Fondo Pace, b. 5, fasc. 139, $($page.doc)" }
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
  [ordered] @{ label = 'Tipologia'; value = 'fascicolo di documentazione archeologica' }
  [ordered] @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
  [ordered] @{ label = 'Riferimento'; value = 'Fondo Pace, b. 5, fasc. 139, doc. 1-4' }
  [ordered] @{ label = 'Data'; value = '27 gennaio 1961' }
  [ordered] @{ label = 'Luogo'; value = 'Dosso Vughera, settore Panzarasa, Gropello Cairoli' }
  [ordered] @{ label = 'Soggetto'; value = 'giornale di scavo; tomba; ustrino; corredo funerario; disegni di scavo' }
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
  thumbnail = IiifUrl "img/derivatives/iiif/images/$manifestPid-doc. 1-r/full/250,/0/default.jpg"
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
  full = IiifUrl "img/derivatives/iiif/images/$manifestPid-doc. 1-r/full/full/0/default.jpg"
  fullwidth = IiifUrl "img/derivatives/iiif/images/$manifestPid-doc. 1-r/full/1140,/0/default.jpg"
}
Write-JekyllJson "img/derivatives/iiif/$manifestPid/manifest.json" $manifest

Write-Output "Generated IIIF for $manifestPid with $($pages.Count) canvases."
