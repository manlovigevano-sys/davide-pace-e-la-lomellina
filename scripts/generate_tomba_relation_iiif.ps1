$ErrorActionPreference = 'Stop'

$itemPid = 'tomba-relazione-pace-b06-f145'
$label = "Relazione di Davide Pace sulla Tomba dell'abbraccio"
$width = 5100
$height = 6600
$pages = 1..13

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
  "img/derivatives/iiif/$itemPid", `
  'img/derivatives/iiif/canvas', `
  'img/derivatives/iiif/annotation', `
  'img/derivatives/iiif/sequence' | Out-Null

$canvases = @()

foreach ($page in $pages) {
  $udLower = 'ud{0:D3}' -f $page
  $udLabel = 'UD{0:D3}' -f $page
  $pagePid = "$itemPid-$udLower"
  $imagePath = "img/derivatives/iiif/images/$pagePid"
  $serviceId = IiifUrl $imagePath
  $thumbnail = IiifUrl "$imagePath/full/250,/0/default.jpg"
  $fullImage = IiifUrl "$imagePath/full/full/0/default.jpg"
  $canvasId = IiifUrl "img/derivatives/iiif/canvas/$pagePid.json"
  $annotationId = IiifUrl "img/derivatives/iiif/annotation/$pagePid.json"

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
  Write-JekyllJson "img/derivatives/iiif/images/$pagePid/info.json" $info

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
  Write-JekyllJson "img/derivatives/iiif/annotation/$pagePid.json" $annotation

  $canvas = [ordered] @{
    '@type' = 'sc:Canvas'
    '@id' = $canvasId
    label = $udLabel
    width = $width
    height = $height
    thumbnail = $thumbnail
    images = @($annotation)
    '@context' = 'http://iiif.io/api/presentation/2/context.json'
  }
  Write-JekyllJson "img/derivatives/iiif/canvas/$pagePid.json" $canvas

  $canvases += $canvas
}

$sequence = [ordered] @{
  '@id' = IiifUrl "img/derivatives/iiif/sequence/$itemPid.json"
  '@type' = 'sc:Sequence'
  canvases = $canvases
  '@context' = 'http://iiif.io/api/presentation/2/context.json'
}
Write-JekyllJson "img/derivatives/iiif/sequence/$itemPid.json" $sequence

$manifest = [ordered] @{
  '@context' = 'http://iiif.io/api/presentation/2/context.json'
  '@id' = IiifUrl "img/derivatives/iiif/$itemPid/manifest.json"
  '@type' = 'sc:Manifest'
  label = $label
  thumbnail = IiifUrl "img/derivatives/iiif/images/$itemPid-ud001/full/250,/0/default.jpg"
  viewingDirection = 'left-to-right'
  viewingHint = 'individuals'
  metadata = @(
    [ordered] @{ label = 'Archivio'; value = 'Fondo Pace, Davide, b. 6, fasc. 145' }
    [ordered] @{ label = 'Struttura'; value = 'UA con unit? documentarie sequenziali doc. 1-doc. 13' }
  )
  sequences = @(
    [ordered] @{
      '@id' = IiifUrl "img/derivatives/iiif/sequence/$itemPid.json"
      '@type' = 'sc:Sequence'
      canvases = $canvases
    }
  )
  full = IiifUrl "img/derivatives/iiif/images/$itemPid-ud001/full/full/0/default.jpg"
  fullwidth = IiifUrl "img/derivatives/iiif/images/$itemPid-ud001/full/1140,/0/default.jpg"
}
Write-JekyllJson "img/derivatives/iiif/$itemPid/manifest.json" $manifest

Write-Output "Generated IIIF for $($pages.Count) UD pages."
