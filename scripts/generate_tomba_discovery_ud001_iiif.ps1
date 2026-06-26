$ErrorActionPreference = 'Stop'

$itemPid = 'tomba-scoperta-b06-f145-ud001'
$source = 'assets/images/tomba-abbraccio/archivio/FDP_B06_F145_UD001_MASTER_R.jpg'
$label = "Relazione di Davide Pace sulla necropoli di Gropello, doc. 1"
$width = 2215
$height = 2747

function IiifUrl([string] $path) {
  return "{{ '/' | absolute_url }}$path"
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

$imageRoot = "img/derivatives/iiif/images/$itemPid"
New-Item -ItemType Directory -Force -Path `
  "img/derivatives/iiif/$itemPid", `
  $imageRoot, `
  "$imageRoot/full/full/0", `
  "$imageRoot/full/1140,/0", `
  "$imageRoot/full/250,/0", `
  'img/derivatives/iiif/canvas', `
  'img/derivatives/iiif/annotation', `
  'img/derivatives/iiif/sequence' | Out-Null

magick $source -auto-orient -strip "$imageRoot/full/full/0/default.jpg"
magick $source -auto-orient -resize 1140x "$imageRoot/full/1140,/0/default.jpg"
magick $source -auto-orient -resize 250x "$imageRoot/full/250,/0/default.jpg"

$serviceId = IiifUrl $imageRoot
$thumbnail = IiifUrl "$imageRoot/full/250,/0/default.jpg"
$fullImage = IiifUrl "$imageRoot/full/full/0/default.jpg"
$fullWidth = IiifUrl "$imageRoot/full/1140,/0/default.jpg"
$canvasId = IiifUrl "img/derivatives/iiif/canvas/$itemPid.json"
$annotationId = IiifUrl "img/derivatives/iiif/annotation/$itemPid.json"

$info = [ordered] @{
  '@context' = 'http://iiif.io/api/image/2/context.json'
  '@id' = $serviceId
  protocol = 'http://iiif.io/api/image'
  width = $width
  height = $height
  sizes = @(
    [ordered] @{ width = 250; height = 310 }
    [ordered] @{ width = 1140; height = 1414 }
    [ordered] @{ width = $width; height = $height }
  )
  profile = @(
    'http://iiif.io/api/image/2/level0.json'
    [ordered] @{ supports = @('sizeByW') }
  )
}
Write-JekyllJson "$imageRoot/info.json" $info

$metadata = @(
  [ordered] @{ label = 'Titolo'; value = $label }
  [ordered] @{ label = 'Tipologia'; value = 'relazione dattiloscritta' }
  [ordered] @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
  [ordered] @{ label = 'Riferimento'; value = 'Fondo Pace, Davide, b. 6, fasc. 145, doc. 1' }
  [ordered] @{ label = 'Data'; value = '10 dicembre 1955' }
  [ordered] @{ label = 'Luogo'; value = 'Gropello Cairoli, localit? Frascate, vigna Garaldi' }
  [ordered] @{ label = 'Soggetto'; value = "Necropoli di Gropello; ricognizioni, scavi e reperti; Tomba dell'abbraccio" }
  [ordered] @{ label = 'File sorgente'; value = 'FDP_B06_F145_UD001_MASTER_R.jpg' }
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
  label = 'doc. 1'
  width = $width
  height = $height
  thumbnail = $thumbnail
  metadata = $metadata
  images = @($annotation)
  '@context' = 'http://iiif.io/api/presentation/2/context.json'
}
Write-JekyllJson "img/derivatives/iiif/canvas/$itemPid.json" $canvas

$sequence = [ordered] @{
  '@id' = IiifUrl "img/derivatives/iiif/sequence/$itemPid.json"
  '@type' = 'sc:Sequence'
  canvases = @($canvas)
  '@context' = 'http://iiif.io/api/presentation/2/context.json'
}
Write-JekyllJson "img/derivatives/iiif/sequence/$itemPid.json" $sequence

$manifest = [ordered] @{
  '@context' = 'http://iiif.io/api/presentation/2/context.json'
  '@id' = IiifUrl "img/derivatives/iiif/$itemPid/manifest.json"
  '@type' = 'sc:Manifest'
  label = $label
  thumbnail = $thumbnail
  viewingDirection = 'left-to-right'
  viewingHint = 'individuals'
  metadata = $metadata
  sequences = @(
    [ordered] @{
      '@id' = IiifUrl "img/derivatives/iiif/sequence/$itemPid.json"
      '@type' = 'sc:Sequence'
      canvases = @($canvas)
    }
  )
  full = $fullImage
  fullwidth = $fullWidth
}
Write-JekyllJson "img/derivatives/iiif/$itemPid/manifest.json" $manifest

Write-Output "Generated IIIF for $itemPid."
