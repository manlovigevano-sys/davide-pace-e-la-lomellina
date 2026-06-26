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

function New-IiifManifest($manifestPid, $label, $pages, $reference, $subject, $thumbnailSuffix) {
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
      [ordered] @{ label = 'Tipologia'; value = 'documentazione fotografica' }
      [ordered] @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
      [ordered] @{ label = 'Riferimento'; value = "$reference, $($page.doc)" }
      [ordered] @{ label = 'Soggetto'; value = 'Squadra Volante Archeologica Antona; attivit? sul campo; comunit? locale' }
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
    [ordered] @{ label = 'Tipologia'; value = 'documentazione fotografica' }
    [ordered] @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
    [ordered] @{ label = 'Riferimento'; value = $reference }
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

$b03Pages = @(
  @{ doc = 'doc. 5'; suffix = 'doc5-r'; source = 'assets/images/nucleo-2/b03-f067/FDP_B03_F067_UD005_ME_R_1.jpg'; file = 'FDP_B03_F067_UD005_ME_R_1.jpg'; canvasLabel = 'Documentazione della Squadra Volante Archeologica Antona, doc. 5' }
)

$b04Pages = @(
  @{ doc = 'doc. 1'; suffix = 'doc1-r'; source = 'assets/images/nucleo-2/b04-f104/FDP_B04_F104_UD001_R_ME.jpg'; file = 'FDP_B04_F104_UD001_R_ME.jpg'; canvasLabel = 'Attivit? sul campo della Squadra Volante Archeologica Antona, doc. 1' },
  @{ doc = 'doc. 2'; suffix = 'doc2-r'; source = 'assets/images/nucleo-2/b04-f104/FDP_B04_F104_UD002_R_ME.jpg'; file = 'FDP_B04_F104_UD002_R_ME.jpg'; canvasLabel = 'Gruppo di collaboratori sul campo, doc. 2' },
  @{ doc = 'doc. 11'; suffix = 'doc11-r'; source = 'assets/images/nucleo-2/b04-f104/FDP_B04_F104_UD011_R_ME.jpg'; file = 'FDP_B04_F104_UD011_R_ME.jpg'; canvasLabel = 'Collaboratori e volontari sul campo, doc. 11' },
  @{ doc = 'doc. 16'; suffix = 'doc16-r'; source = 'assets/images/nucleo-2/b04-f104/FDP_B04_F104_UD016_R_ME.jpg'; file = 'FDP_B04_F104_UD016_R_ME.jpg'; canvasLabel = 'Gruppo di collaboratori sul campo, doc. 16' },
  @{ doc = 'doc. 17'; suffix = 'doc17-r'; source = 'assets/images/nucleo-2/b04-f104/FDP_B04_F104_UD017_R_ME.jpg'; file = 'FDP_B04_F104_UD017_R_ME.jpg'; canvasLabel = 'Collaboratori con reperto durante attivit? sul campo, doc. 17' }
)

$b05Pages = @(
  @{ doc = 'doc. 1'; suffix = 'doc1-r'; source = 'assets/images/nucleo-2/b05-f123/FDP_B05_F0123_UD001_ME_R.jpg'; file = 'FDP_B05_F0123_UD001_ME_R.jpg'; canvasLabel = 'Collaboratori e comunit? locale durante attivit? sul campo, doc. 1' }
)

New-IiifManifest `
  'nucleo2-antona-b03-f067' `
  'Squadra Volante Archeologica Antona, b. 3, fasc. 67' `
  $b03Pages `
  'Fondo Pace, b. 3, fasc. 67' `
  'documentazione fotografica; Squadra Volante Archeologica Antona; attivit? sul campo' `
  'doc5-r'

New-IiifManifest `
  'nucleo2-antona-b04-f104' `
  'Squadra Volante Archeologica Antona, b. 4, fasc. 104' `
  $b04Pages `
  'Fondo Pace, b. 4, fasc. 104' `
  'documentazione fotografica; Squadra Volante Archeologica Antona; volontari; collaboratori; attivit? sul campo' `
  'doc1-r'

New-IiifManifest `
  'nucleo2-antona-b05-f123' `
  'Squadra Volante Archeologica Antona, b. 5, fasc. 123' `
  $b05Pages `
  'Fondo Pace, b. 5, fasc. 123' `
  'documentazione fotografica; Squadra Volante Archeologica Antona; comunit? locale; attivit? sul campo' `
  'doc1-r'
