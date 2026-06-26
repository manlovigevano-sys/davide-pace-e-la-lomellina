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

function New-IiifManifest($manifestPid, $label, $metadata, $pages, $thumbnailSuffix) {
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

    $canvasMetadata = New-Metadata @(
      @{ label = 'Titolo'; value = $page.canvasLabel }
      @{ label = 'Tipologia'; value = $page.type }
      @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
      @{ label = 'Fondo'; value = 'Fondo Davide Pace' }
      @{ label = 'Riferimento'; value = $page.reference }
      @{ label = 'Luogo'; value = 'Gropello Cairoli, Santo Spirito' }
      @{ label = 'Data'; value = $page.date }
      @{ label = 'Descrizione'; value = $page.description }
      @{ label = 'Soggetto'; value = $page.subject }
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
      metadata = $canvasMetadata
      images = @($annotation)
      '@context' = 'http://iiif.io/api/presentation/2/context.json'
    }
    Write-JekyllJson "img/derivatives/iiif/canvas/$itemPid.json" $canvas
    $canvases += $canvas
  }

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
    metadata = $metadata
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

$base = 'assets/images/davide-pace/rete-documentazione'
$label = 'Gropello Cairoli, Santo Spirito. Indagini archeologiche e documentazione fotografica, novembre 1964'

$manifestMetadata = New-Metadata @(
  @{ label = 'Titolo'; value = $label }
  @{ label = 'Tipologia'; value = 'stampe fotografiche e documentazione archivistica' }
  @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
  @{ label = 'Fondo'; value = 'Fondo Davide Pace' }
  @{ label = 'Riferimento'; value = 'Archivio Davide Pace, scat. 8, fasc. 202, doc. 11; scat. 8, fasc. 205, doc. 9' }
  @{ label = 'Luogo'; value = 'Gropello Cairoli, Santo Spirito' }
  @{ label = 'Data'; value = 'novembre 1964' }
  @{ label = 'Descrizione'; value = 'Il nucleo accosta una ripresa con fascicoli e frammento fittile, utile a documentare le pratiche di inventariazione dell Archivio Davide Pace, e una stampa a colori relativa alle attivit? di ripresa fotografica sul campo durante le indagini archeologiche di Santo Spirito.' }
  @{ label = 'Diritti'; value = 'Direzione regionale Musei nazionali Lombardia - Museo Archeologico Nazionale della Lomellina' }
)

$pages = @(
  @{
    suffix = 'scat08-f202-doc11'
    source = "$base/FDP_SCAT08_F202_UD011_ME.tif"
    file = 'FDP_SCAT08_F202_UD011_ME.tif'
    canvasLabel = 'Santo Spirito. Indagini archeologiche, doc. 11: fascicolo rosso e frammento fittile'
    type = 'stampa a colori'
    reference = 'Archivio Davide Pace, scat. 8, fasc. 202, doc. 11'
    date = 'novembre 1964'
    description = 'Stampa a colori raffigurante un interno con tavolo, fascicolo rosso e frammento fittile. Pur apparendo non pertinente al contesto dello scavo, documenta materiali e pratiche di inventariazione e documentazione archivistica legate all Archivio Davide Pace.'
    subject = 'Archivio Davide Pace; fascicoli archivistici; frammento fittile; inventariazione; documentazione archivistica'
  },
  @{
    suffix = 'scat08-f205-doc09'
    source = "$base/FDP_SC08_F205_UD009_R.jpg"
    file = 'FDP_SC08_F205_UD009_R.jpg'
    canvasLabel = 'Santo Spirito. Indagini archeologiche, doc. 9: ripresa fotografica sul campo'
    type = 'stampa a colori'
    reference = 'Archivio Davide Pace, scat. 8, fasc. 205, doc. 9'
    date = 'aprile 1965'
    description = 'Stampa a colori che documenta le attivit? di ripresa fotografica e registrazione visiva delle indagini archeologiche condotte a Santo Spirito nell aprile 1965.'
    subject = 'Gropello Cairoli; Santo Spirito; indagini archeologiche; ripresa fotografica; documentazione sul campo'
  }
)

New-IiifManifest `
  'davide-pace-rete-documentazione-santo-spirito-doc11' `
  'Gropello Cairoli, Santo Spirito. Indagini archeologiche, novembre 1964: fascicolo rosso e frammento fittile' `
  (New-Metadata @(
    @{ label = 'Titolo'; value = 'Gropello Cairoli, Santo Spirito. Indagini archeologiche, novembre 1964: fascicolo rosso e frammento fittile' }
    @{ label = 'Tipologia'; value = 'stampa a colori' }
    @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
    @{ label = 'Fondo'; value = 'Fondo Davide Pace' }
    @{ label = 'Riferimento'; value = 'Archivio Davide Pace, scat. 8, fasc. 202, doc. 11' }
    @{ label = 'Luogo'; value = 'Gropello Cairoli, Santo Spirito' }
    @{ label = 'Data'; value = 'novembre 1964' }
    @{ label = 'Descrizione'; value = $pages[0].description }
    @{ label = 'Diritti'; value = 'Direzione regionale Musei nazionali Lombardia - Museo Archeologico Nazionale della Lomellina' }
  )) `
  @($pages[0]) `
  'scat08-f202-doc11'

New-IiifManifest `
  'davide-pace-rete-documentazione-santo-spirito-doc9' `
  'Gropello Cairoli, Santo Spirito. Indagini archeologiche, aprile 1965: ripresa fotografica sul campo' `
  (New-Metadata @(
    @{ label = 'Titolo'; value = 'Gropello Cairoli, Santo Spirito. Indagini archeologiche, aprile 1965: ripresa fotografica sul campo' }
    @{ label = 'Tipologia'; value = 'stampa a colori' }
    @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
    @{ label = 'Fondo'; value = 'Fondo Davide Pace' }
    @{ label = 'Riferimento'; value = 'Archivio Davide Pace, scat. 8, fasc. 205, doc. 9' }
    @{ label = 'Luogo'; value = 'Gropello Cairoli, Santo Spirito' }
    @{ label = 'Data'; value = 'aprile 1965' }
    @{ label = 'Descrizione'; value = $pages[1].description }
    @{ label = 'Diritti'; value = 'Direzione regionale Musei nazionali Lombardia - Museo Archeologico Nazionale della Lomellina' }
  )) `
  @($pages[1]) `
  'scat08-f205-doc09'
