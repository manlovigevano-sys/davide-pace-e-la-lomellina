$ErrorActionPreference = 'Stop'

$manifestPid = 'tomba-corredo-fortunati-1979-fig-2'
$label = "Corredo della Tomba dell'abbraccio, Fortunati Zuccal? 1979, fig. 2"
$source = 'assets/images/tomba-abbraccio/corredo/corredo-fortunati-1979-fig-2.png'
$file = 'corredo-fortunati-1979-fig-2.png'

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
  $directory = Split-Path -Parent $path
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines((Resolve-Path -LiteralPath $directory).Path + [System.IO.Path]::DirectorySeparatorChar + (Split-Path -Leaf $path), $content, $encoding)
}

$dim = magick identify -format '%w %h' $source
$parts = $dim -split ' '
$width = [int]$parts[0]
$height = [int]$parts[1]
$largeWidth = $width
$thumbHeight = [Math]::Round(250 * $height / $width)
$mediumHeight = [Math]::Round(1140 * $height / $width)

New-Item -ItemType Directory -Force -Path `
  "img/derivatives/iiif/$manifestPid", `
  'img/derivatives/iiif/canvas', `
  'img/derivatives/iiif/annotation', `
  'img/derivatives/iiif/sequence' | Out-Null

$imageRoot = "img/derivatives/iiif/images/$manifestPid"
New-Item -ItemType Directory -Force -Path `
  $imageRoot, `
  "$imageRoot/full/full/0", `
  "$imageRoot/full/$largeWidth,/0", `
  "$imageRoot/full/1140,/0", `
  "$imageRoot/full/250,/0" | Out-Null

magick $source -auto-orient -strip "$imageRoot/full/full/0/default.jpg"
magick $source -auto-orient -strip "$imageRoot/full/$largeWidth,/0/default.jpg"
magick $source -auto-orient -strip -resize 1140x "$imageRoot/full/1140,/0/default.jpg"
magick $source -auto-orient -strip -resize 250x "$imageRoot/full/250,/0/default.jpg"

$serviceId = IiifUrl $imageRoot
$thumbnail = IiifUrl "$imageRoot/full/250,/0/default.jpg"
$fullImage = IiifUrl "$imageRoot/full/full/0/default.jpg"
$canvasId = IiifUrl "img/derivatives/iiif/canvas/$manifestPid.json"
$annotationId = IiifUrl "img/derivatives/iiif/annotation/$manifestPid.json"

$info = [ordered] @{
  '@context' = 'http://iiif.io/api/image/2/context.json'
  '@id' = $serviceId
  protocol = 'http://iiif.io/api/image'
  width = $width
  height = $height
  sizes = @(
    [ordered] @{ width = 250; height = $thumbHeight }
    [ordered] @{ width = 1140; height = $mediumHeight }
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
Write-JekyllJson "img/derivatives/iiif/annotation/$manifestPid.json" $annotation

$canvas = [ordered] @{
  '@type' = 'sc:Canvas'
  '@id' = $canvasId
  label = 'Fig. 2'
  width = $width
  height = $height
  thumbnail = $thumbnail
  metadata = @(
    [ordered] @{ label = 'Titolo'; value = $label }
    [ordered] @{ label = 'Fonte'; value = 'Fortunati Zuccal?, 1979, fig. 2' }
    [ordered] @{ label = 'File sorgente'; value = $file }
  )
  images = @($annotation)
  '@context' = 'http://iiif.io/api/presentation/2/context.json'
}
Write-JekyllJson "img/derivatives/iiif/canvas/$manifestPid.json" $canvas

$sequence = [ordered] @{
  '@id' = IiifUrl "img/derivatives/iiif/sequence/$manifestPid.json"
  '@type' = 'sc:Sequence'
  canvases = @($canvas)
  '@context' = 'http://iiif.io/api/presentation/2/context.json'
}
Write-JekyllJson "img/derivatives/iiif/sequence/$manifestPid.json" $sequence

$manifest = [ordered] @{
  '@context' = 'http://iiif.io/api/presentation/2/context.json'
  '@id' = IiifUrl "img/derivatives/iiif/$manifestPid/manifest.json"
  '@type' = 'sc:Manifest'
  label = $label
  thumbnail = $thumbnail
  viewingDirection = 'left-to-right'
  viewingHint = 'individuals'
  metadata = @(
    [ordered] @{ label = 'Titolo'; value = $label }
    [ordered] @{ label = 'Fonte'; value = 'Fortunati Zuccal?, 1979, fig. 2' }
    [ordered] @{ label = 'Soggetto'; value = "Corredo della Tomba dell'abbraccio" }
  )
  sequences = @(
    [ordered] @{
      '@id' = IiifUrl "img/derivatives/iiif/sequence/$manifestPid.json"
      '@type' = 'sc:Sequence'
      canvases = @($canvas)
    }
  )
  full = $fullImage
  fullwidth = IiifUrl "$imageRoot/full/1140,/0/default.jpg"
}
Write-JekyllJson "img/derivatives/iiif/$manifestPid/manifest.json" $manifest

Write-Output "Generated IIIF for $manifestPid."
