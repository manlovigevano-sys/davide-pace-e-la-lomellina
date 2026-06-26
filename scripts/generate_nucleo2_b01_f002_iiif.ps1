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
      [ordered] @{ label = 'Tipologia'; value = 'circolare, avviso pubblico, regolamento' }
      [ordered] @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
      [ordered] @{ label = 'Riferimento'; value = "Fondo Pace, b. 1, fasc. 2, $($page.doc)" }
      [ordered] @{ label = 'Data'; value = $page.date }
      [ordered] @{ label = 'Luogo'; value = 'Gropello Cairoli' }
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
    [ordered] @{ label = 'Tipologia'; value = 'circolare, avviso pubblico, regolamento' }
    [ordered] @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
    [ordered] @{ label = 'Riferimento'; value = $reference }
    [ordered] @{ label = 'Cronologia'; value = '1955-1957' }
    [ordered] @{ label = 'Luogo'; value = 'Gropello Cairoli' }
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

$doc12Pages = @(
  @{ doc = 'doc. 1 recto'; suffix = 'doc1-r'; source = 'assets/images/nucleo-2/b01-f002/FDP_B01_F002_UD001_ME_R_01.jpg'; file = 'FDP_B01_F002_UD001_ME_R_01.jpg'; date = '13 giugno 1957'; canvasLabel = 'Regolamento della Squadra Volante Archeologica "Antona", doc. 1 recto' },
  @{ doc = 'doc. 1 verso'; suffix = 'doc1-v'; source = 'assets/images/nucleo-2/b01-f002/FDP_B01_F002_UD001_ME_V_01.jpg'; file = 'FDP_B01_F002_UD001_ME_V_01.jpg'; date = '13 giugno 1957'; canvasLabel = 'Regolamento della Squadra Volante Archeologica "Antona", doc. 1 verso' },
  @{ doc = 'doc. 2 recto'; suffix = 'doc2-r'; source = 'assets/images/nucleo-2/b01-f002/FDP_B01_F002_UD002_ME_R_01.jpg'; file = 'FDP_B01_F002_UD002_ME_R_01.jpg'; date = '22 ottobre 1955'; canvasLabel = 'Avviso ai cittadini e agli agricoltori, doc. 2 recto' },
  @{ doc = 'doc. 2 verso'; suffix = 'doc2-v'; source = 'assets/images/nucleo-2/b01-f002/FDP_B01_F002_UD002_ME_V_01.jpg'; file = 'FDP_B01_F002_UD002_ME_V_01.jpg'; date = '22 ottobre 1955'; canvasLabel = 'Avviso ai cittadini e agli agricoltori, doc. 2 verso' }
)

$doc3Pages = @(
  @{ doc = 'doc. 3'; suffix = 'doc3'; source = 'assets/images/nucleo-2/b01-f002/FDP_B01_F002_UD003_ME.jpg'; file = 'FDP_B01_F002_UD003_ME.jpg'; date = '29 dicembre 1955'; canvasLabel = 'Avviso della Soprintendenza alle Antichita della Lombardia, doc. 3' }
)

New-IiifManifest `
  'nucleo2-ispettorato-b01-f002-doc1-2' `
  'Ispettorato onorario alle antichita, b. 1, fasc. 2, doc. 1-2' `
  $doc12Pages `
  'Fondo Pace, b. 1, fasc. 2, doc. 1-2' `
  'Ispettorato onorario alle antichita; tutela archeologica; Squadra Volante Archeologica Antona; avvisi alla popolazione' `
  'doc1-r'

New-IiifManifest `
  'nucleo2-ispettorato-b01-f002-doc3' `
  'Ispettorato onorario alle antichita, b. 1, fasc. 2, doc. 3' `
  $doc3Pages `
  'Fondo Pace, b. 1, fasc. 2, doc. 3' `
  'Ispettorato onorario alle antichita; tutela archeologica; avviso alla popolazione' `
  'doc3'
