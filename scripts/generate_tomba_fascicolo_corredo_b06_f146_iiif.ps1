$ErrorActionPreference = 'Stop'

$manifestPid = 'tomba-fascicolo-corredo-b06-f146'
$label = "Fascicolo della Tomba dell'abbraccio, b. 6, fasc. 146"
$pages = @(
  @{ ud = 'doc. 4 recto'; suffix = 'doc. 4-r'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD004_R_ME.jpg'; file = 'FDP_B06_F146_UD004_R_ME.jpg' },
  @{ ud = 'doc. 4 verso'; suffix = 'doc. 4-v'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD004_V_ME.jpg'; file = 'FDP_B06_F146_UD004_V_ME.jpg' },
  @{ ud = 'doc. 5 recto'; suffix = 'doc. 5-r'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD005_R_ME.jpg'; file = 'FDP_B06_F146_UD005_R_ME.jpg' },
  @{ ud = 'doc. 6 recto'; suffix = 'doc. 6-r'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD006_R_ME.jpg'; file = 'FDP_B06_F146_UD006_R_ME.jpg' },
  @{ ud = 'doc. 6 verso'; suffix = 'doc. 6-v'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD006_V_ME.jpg'; file = 'FDP_B06_F146_UD006_V_ME.jpg' },
  @{ ud = 'doc. 7 recto'; suffix = 'doc. 7-r'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD007_R_ME.jpg'; file = 'FDP_B06_F146_UD007_R_ME.jpg' },
  @{ ud = 'doc. 8 recto'; suffix = 'doc. 8-r'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD008_R_ME.jpg'; file = 'FDP_B06_F146_UD008_R_ME.jpg' },
  @{ ud = 'doc. 9 recto'; suffix = 'doc. 9-r'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD009_R_ME.jpg'; file = 'FDP_B06_F146_UD009_R_ME.jpg' },
  @{ ud = 'doc. 10 recto'; suffix = 'doc. 10-r'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD010_R_ME.jpg'; file = 'FDP_B06_F146_UD010_R_ME.jpg' },
  @{ ud = 'doc. 11 recto'; suffix = 'doc. 11-r'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD011_R_ME.jpg'; file = 'FDP_B06_F146_UD011_R_ME.jpg' },
  @{ ud = 'doc. 12 recto'; suffix = 'doc. 12-r'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD012_R_ME.jpg'; file = 'FDP_B06_F146_UD012_R_ME.jpg' },
  @{ ud = 'doc. 13 recto'; suffix = 'doc. 13-r'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD013_R_ME.jpg'; file = 'FDP_B06_F146_UD013_R_ME.jpg' },
  @{ ud = 'doc. 14 recto'; suffix = 'doc. 14-r'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD014_R_ME.jpg'; file = 'FDP_B06_F146_UD014_R_ME.jpg' },
  @{ ud = 'doc. 15 recto'; suffix = 'doc. 15-r'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD015_R_ME_.jpg'; file = 'FDP_B06_F146_UD015_R_ME_.jpg' },
  @{ ud = 'doc. 16 verso'; suffix = 'doc. 16-v'; source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD016_V_ME.jpg'; file = 'FDP_B06_F146_UD016_V_ME.jpg' }
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
    label = $page.ud
    width = $width
    height = $height
    thumbnail = $thumbnail
    metadata = @(
      [ordered] @{ label = 'Titolo'; value = $label }
      [ordered] @{ label = 'Riferimento'; value = "Fondo Pace, Davide, b. 6, fasc. 146, $($page.ud)" }
      [ordered] @{ label = 'File sorgente'; value = $page.file }
    )
    images = @($annotation)
    '@context' = 'http://iiif.io/api/presentation/2/context.json'
  }
  Write-JekyllJson "img/derivatives/iiif/canvas/$itemPid.json" $canvas
  $canvases += $canvas
}

$metadata = @(
  [ordered] @{ label = 'Titolo'; value = $label }
  [ordered] @{ label = 'Tipologia'; value = 'annotazioni manoscritte e fotografie' }
  [ordered] @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
  [ordered] @{ label = 'Riferimento'; value = 'Fondo Pace, Davide, b. 6, fasc. 146' }
  [ordered] @{ label = 'Luogo'; value = 'Gropello Cairoli, localit? Frascate, vigna Garaldi' }
  [ordered] @{ label = 'Soggetto'; value = "Tomba dell'abbraccio; corredo funerario; reperti; annotazioni inventariali" }
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
  thumbnail = IiifUrl "img/derivatives/iiif/images/$manifestPid-doc. 4-r/full/250,/0/default.jpg"
  viewingDirection = 'left-to-right'
  viewingHint = 'individuals'
  metadata = $metadata
  sequences = @(
    [ordered] @{
      '@id' = IiifUrl "img/derivatives/iiif/sequence/$manifestPid.json"
      '@type' = 'sc:Sequence'
      canvases = $canvases
    }
  )
  full = IiifUrl "img/derivatives/iiif/images/$manifestPid-doc. 4-r/full/full/0/default.jpg"
  fullwidth = IiifUrl "img/derivatives/iiif/images/$manifestPid-doc. 4-r/full/1140,/0/default.jpg"
}
Write-JekyllJson "img/derivatives/iiif/$manifestPid/manifest.json" $manifest

Write-Output "Generated IIIF for $manifestPid with $($pages.Count) canvases."
