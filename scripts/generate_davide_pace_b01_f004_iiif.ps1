$ErrorActionPreference = 'Stop'

function IiifUrl([string] $path) {
  return "{{ '/' | relative_url }}$path"
}

function Write-JekyllJson([string] $path, $object) {
  $json = $object | ConvertTo-Json -Depth 50
  $json = $json -replace '\\u0027', "'"
  $content = @('---', 'layout: none', '---', $json)
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

function New-Metadata($pairs) {
  $metadata = New-Object System.Collections.ArrayList
  foreach ($pair in $pairs) {
    if (-not [string]::IsNullOrWhiteSpace($pair.value)) {
      $metadata.Add([ordered] @{ label = $pair.label; value = $pair.value }) | Out-Null
    }
  }
  return $metadata
}

function New-Page($number, $label, $type, $author, $recipient, $date, $place, $subject) {
  $suffix = 'ud{0:D3}' -f $number
  return @{
    suffix = $suffix
    source = "assets/images/davide-pace/b01-f004/FDP_B01_F004_UD{0:D3}_ME_R.jpg" -f $number
    file = "FDP_B01_F004_UD{0:D3}_ME_R.jpg" -f $number
    canvasLabel = $label
    type = $type
    reference = "Archivio Davide Pace, b. 1, fasc. 4, doc. {0}" -f $number
    author = $author
    recipient = $recipient
    date = $date
    place = $place
    subject = $subject
  }
}

function New-IiifManifest($manifestPid, $label, $pages, $thumbnailSuffix) {
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

    $metadata = New-Metadata @(
      @{ label = 'Titolo'; value = $page.canvasLabel }
      @{ label = 'Tipologia'; value = $page.type }
      @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
      @{ label = 'Fondo'; value = 'Fondo Davide Pace' }
      @{ label = 'Riferimento'; value = $page.reference }
      @{ label = 'Autore / mittente'; value = $page.author }
      @{ label = 'Destinatario'; value = $page.recipient }
      @{ label = 'Data'; value = $page.date }
      @{ label = 'Luogo'; value = $page.place }
      @{ label = 'Soggetto'; value = $page.subject }
      @{ label = 'Lingua'; value = 'italiano' }
      @{ label = 'Diritti'; value = 'Direzione regionale Musei nazionali Lombardia - Museo Archeologico Nazionale della Lomellina' }
      @{ label = 'File sorgente'; value = $page.file }
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
    [ordered] @{ label = 'Tipologia'; value = 'relazione dattiloscritta e carteggio' }
    [ordered] @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
    [ordered] @{ label = 'Fondo'; value = 'Fondo Davide Pace' }
    [ordered] @{ label = 'Riferimento'; value = 'Archivio Davide Pace, b. 1, fasc. 4, unit? documentarie 1-11' }
    [ordered] @{ label = 'Autore principale'; value = 'Davide Pace' }
    [ordered] @{ label = 'Corrispondenti'; value = 'Arrigo Arrigoni' }
    [ordered] @{ label = 'Cronologia'; value = '1955-1958' }
    [ordered] @{ label = 'Luogo'; value = 'Gropello Cairoli; Milano' }
    [ordered] @{ label = 'Soggetto'; value = 'prime ricerche archeologiche a Gropello Cairoli; Antiquarium di Gropello; Arrigo Arrigoni; relazione; carteggio' }
    [ordered] @{ label = 'Lingua'; value = 'italiano' }
    [ordered] @{ label = 'Diritti'; value = 'Direzione regionale Musei nazionali Lombardia - Museo Archeologico Nazionale della Lomellina' }
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

$relationTitle = "Avventura ufficiale nell'antichit? di Gropello. Dal natale dell'indagine al natale del museo"
$relationSubject = "Avventura ufficiale nell'antichit? di Gropello; prime ricerche archeologiche; Antiquarium di Gropello; Gropello Cairoli"
$pages = @()

1..8 | ForEach-Object {
  $date = '1955-1956'
  if ($_ -eq 8) { $date = '9 dicembre 1958' }
  $pages += New-Page `
    $_ `
    "$relationTitle, p. $_" `
    'relazione dattiloscritta' `
    'Davide Pace' `
    'destinata alla pubblicazione' `
    $date `
    'Gropello Cairoli' `
    $relationSubject
}

$pages += New-Page 9 `
  'Lettera di Davide Pace ad Arrigo Arrigoni, 8 dicembre 1958' `
  'lettera dattiloscritta' `
  'Davide Pace' `
  'Arrigo Arrigoni' `
  '8 dicembre 1958' `
  'Milano' `
  'Davide Pace; Arrigo Arrigoni; preparazione editoriale; Antiquarium di Gropello'

$pages += New-Page 10 `
  'Lettera di Davide Pace ad Arrigo Arrigoni, 9 dicembre 1958' `
  'lettera dattiloscritta con annotazioni manoscritte' `
  'Davide Pace' `
  'Arrigo Arrigoni' `
  '9 dicembre 1958' `
  '' `
  'Davide Pace; Arrigo Arrigoni; correzioni editoriali; pubblicazione'

$pages += New-Page 11 `
  'Lettera di Arrigo Arrigoni a Davide Pace, 9 dicembre 1958' `
  'lettera dattiloscritta con annotazioni manoscritte' `
  'Arrigo Arrigoni' `
  'Davide Pace' `
  '9 dicembre 1958' `
  'Gropello Cairoli' `
  'Arrigo Arrigoni; Davide Pace; pubblicazione; ricerche archeologiche'

New-IiifManifest `
  'davide-pace-b01-f004-avventura-gropello' `
  $relationTitle `
  $pages `
  'doc. 1'
