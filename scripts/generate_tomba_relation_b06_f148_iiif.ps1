$ErrorActionPreference = 'Stop'

$manifestPid = 'tomba-relazione-pace-b06-f148'
$label = "Relazione di Davide Pace sulla Tomba dell'abbraccio, fasc. 148"
$width = 5100
$height = 6600
$pages = 1..6 | ForEach-Object {
  $ud = 'UD{0:D3}' -f $_
  [ordered] @{
    pid = "$manifestPid-$($ud.ToLowerInvariant())"
    ud = $ud
    source = "assets/images/tomba-abbraccio/archivio/FDP_B06_F148_${ud}_R_ME.jpg"
    file = "FDP_B06_F148_${ud}_R_ME.jpg"
  }
}

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
  [System.IO.File]::WriteAllLines((Resolve-Path -LiteralPath (Split-Path -Parent $path)).Path + [System.IO.Path]::DirectorySeparatorChar + (Split-Path -Leaf $path), $content, $encoding)
}

New-Item -ItemType Directory -Force -Path `
  "img/derivatives/iiif/$manifestPid", `
  'img/derivatives/iiif/canvas', `
  'img/derivatives/iiif/annotation', `
  'img/derivatives/iiif/sequence' | Out-Null

$canvases = @()

foreach ($page in $pages) {
  $imageRoot = "img/derivatives/iiif/images/$($page.pid)"
  New-Item -ItemType Directory -Force -Path `
    $imageRoot, `
    "$imageRoot/full/full/0", `
    "$imageRoot/full/$width,/0", `
    "$imageRoot/full/1140,/0", `
    "$imageRoot/full/250,/0" | Out-Null

  magick $page.source -auto-orient -strip "$imageRoot/full/full/0/default.jpg"
  magick $page.source -auto-orient -strip "$imageRoot/full/$width,/0/default.jpg"
  magick $page.source -auto-orient -resize 1140x "$imageRoot/full/1140,/0/default.jpg"
  magick $page.source -auto-orient -resize 250x "$imageRoot/full/250,/0/default.jpg"

  $serviceId = IiifUrl $imageRoot
  $thumbnail = IiifUrl "$imageRoot/full/250,/0/default.jpg"
  $fullImage = IiifUrl "$imageRoot/full/full/0/default.jpg"
  $canvasId = IiifUrl "img/derivatives/iiif/canvas/$($page.pid).json"
  $annotationId = IiifUrl "img/derivatives/iiif/annotation/$($page.pid).json"

  $info = [ordered] @{
    '@context' = 'http://iiif.io/api/image/2/context.json'
    '@id' = $serviceId
    protocol = 'http://iiif.io/api/image'
    width = $width
    height = $height
    sizes = @(
      [ordered] @{ width = 250; height = 324 }
      [ordered] @{ width = 1140; height = 1475 }
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
  Write-JekyllJson "img/derivatives/iiif/annotation/$($page.pid).json" $annotation

  $canvas = [ordered] @{
    '@type' = 'sc:Canvas'
    '@id' = $canvasId
    label = $page.ud
    width = $width
    height = $height
    thumbnail = $thumbnail
    metadata = @(
      [ordered] @{ label = 'Titolo'; value = $label }
      [ordered] @{ label = 'Riferimento'; value = "Fondo Pace, Davide, b. 6, fasc. 148, $($page.ud)" }
      [ordered] @{ label = 'File sorgente'; value = $page.file }
    )
    images = @($annotation)
    '@context' = 'http://iiif.io/api/presentation/2/context.json'
  }
  Write-JekyllJson "img/derivatives/iiif/canvas/$($page.pid).json" $canvas
  $canvases += $canvas
}

$metadata = @(
  [ordered] @{ label = 'Titolo'; value = $label }
  [ordered] @{ label = 'Tipologia'; value = 'relazione dattiloscritta' }
  [ordered] @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
  [ordered] @{ label = 'Riferimento'; value = 'Fondo Pace, Davide, b. 6, fasc. 148' }
  [ordered] @{ label = 'Luogo'; value = 'Gropello Cairoli, localit? Frascate, vigna Garaldi' }
  [ordered] @{ label = 'Soggetto'; value = "Necropoli di Gropello; scavi; Tomba dell'abbraccio" }
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
  thumbnail = IiifUrl "img/derivatives/iiif/images/$manifestPid-ud001/full/250,/0/default.jpg"
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
  full = IiifUrl "img/derivatives/iiif/images/$manifestPid-ud001/full/full/0/default.jpg"
  fullwidth = IiifUrl "img/derivatives/iiif/images/$manifestPid-ud001/full/1140,/0/default.jpg"
}
Write-JekyllJson "img/derivatives/iiif/$manifestPid/manifest.json" $manifest

Write-Output "Generated IIIF for $manifestPid."
