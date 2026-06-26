$ErrorActionPreference = 'Stop'

function IiifUrl([string] $path) {
  return "{{ '/' | relative_url }}$path"
}

function Write-JekyllJson([string] $path, $object) {
  $json = $object | ConvertTo-Json -Depth 60
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
  [System.IO.File]::WriteAllLines(
    (Resolve-Path -LiteralPath $directory).Path + [System.IO.Path]::DirectorySeparatorChar + (Split-Path -Leaf $path),
    $content,
    $encoding
  )
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

    $sizes = @(
      [ordered] @{ width = 250; height = $thumbHeight }
      [ordered] @{ width = 1140; height = $mediumHeight }
    )
    if ($largeWidth -ne 1140 -and $largeWidth -ne $width) {
      $sizes += [ordered] @{ width = $largeWidth; height = $largeHeight }
    }
    $sizes += [ordered] @{ width = $width; height = $height }

    $info = [ordered] @{
      '@context' = 'http://iiif.io/api/image/2/context.json'
      '@id' = $serviceId
      protocol = 'http://iiif.io/api/image'
      width = $width
      height = $height
      sizes = $sizes
      profile = @(
        'http://iiif.io/api/image/2/level0.json'
        [ordered] @{ supports = @('sizeByW') }
      )
    }
    Write-JekyllJson "$imageRoot/info.json" $info

    $metadata = @(
      [ordered] @{ label = 'Titolo'; value = $page.canvasLabel }
      [ordered] @{ label = 'Tipologia'; value = $page.type }
      [ordered] @{ label = 'Archivio / istituto'; value = $page.repository }
      [ordered] @{ label = 'Riferimento'; value = $page.reference }
      [ordered] @{ label = 'Soggetto'; value = $subject }
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
    [ordered] @{ label = 'Tipologia'; value = 'documentazione fotografica e archivistica' }
    [ordered] @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace; Museo Archeologico Nazionale della Lomellina' }
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

$root = 'assets/images/nucleo-2/embrice-iscritto'

$currentObject = @(
  @{
    suffix = 'reperto'
    source = "$root/13418.png"
    file = '13418.png'
    canvasLabel = 'Embrice iscritto, fotografia attuale'
    type = 'fotografia del reperto'
    repository = 'Museo Archeologico Nazionale della Lomellina'
    reference = 'MANLo, n. inv. 13418'
  }
)

$currentDetail = @(
  @{
    suffix = 'dettaglio-iscrizione'
    source = "$root/embrice-iscritto-dettaglio-watermark.png"
    file = 'embrice-iscritto-dettaglio-watermark.png'
    canvasLabel = 'Embrice iscritto, dettaglio dell''iscrizione'
    type = 'fotografia del reperto, dettaglio'
    repository = 'Museo Archeologico Nazionale della Lomellina'
    reference = 'MANLo, n. inv. 13418'
  }
)

$discoveryPhotos = @(
  @{ suffix = 'doc. 1-r'; source = "$root/b02-f035/FDP_B02_F035_UD001_ME_R.jpg"; file = 'FDP_B02_F035_UD001_ME_R.jpg'; canvasLabel = 'Vigna Carlo Nicola, Santo Spirito'; type = 'documentazione fotografica'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, b. 2, fasc. 35, doc. 1' }
  @{ suffix = 'doc. 2-r'; source = "$root/b02-f035/FDP_B02_F035_UD002_ME_R.jpg"; file = 'FDP_B02_F035_UD002_ME_R.jpg'; canvasLabel = 'Frammenti dell''embrice nel terreno'; type = 'documentazione fotografica'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, b. 2, fasc. 35, doc. 2' }
  @{ suffix = 'doc. 3-r'; source = "$root/b02-f035/FDP_B02_F035_UD003_ME_R.jpg"; file = 'FDP_B02_F035_UD003_ME_R.jpg'; canvasLabel = 'Ragazzi e collaboratori nel luogo del rinvenimento'; type = 'documentazione fotografica'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, b. 2, fasc. 35, doc. 3' }
  @{ suffix = 'doc. 4-r'; source = "$root/b02-f035/FDP_B02_F035_UD004_ME_R.jpg"; file = 'FDP_B02_F035_UD004_ME_R.jpg'; canvasLabel = 'Embrice iscritto ricomposto'; type = 'documentazione fotografica'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, b. 2, fasc. 35, doc. 4' }
)

$papers = @(
  @{ suffix = 'doc. 9-r'; source = "$root/b02-f035/FDP_B02_F035_UD009_ME_R.jpg"; file = 'FDP_B02_F035_UD009_ME_R.jpg'; canvasLabel = 'Lettera di Davide Pace alla Soprintendenza, recto'; type = 'carteggio dattiloscritto'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, b. 2, fasc. 35, doc. 9 recto' }
  @{ suffix = 'doc. 9-v'; source = "$root/b02-f035/FDP_B02_F035_UD009_ME_V.jpg"; file = 'FDP_B02_F035_UD009_ME_V.jpg'; canvasLabel = 'Lettera di Davide Pace alla Soprintendenza, verso'; type = 'carteggio dattiloscritto'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, b. 2, fasc. 35, doc. 9 verso' }
  @{ suffix = 'doc. 10-r'; source = "$root/b02-f035/FDP_B02_F035_UD010_ME_R.jpg"; file = 'FDP_B02_F035_UD010_ME_R.jpg'; canvasLabel = 'Appunti manoscritti sul rinvenimento, recto'; type = 'appunto manoscritto'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, b. 2, fasc. 35, doc. 10 recto' }
  @{ suffix = 'doc. 10-v'; source = "$root/b02-f035/FDP_B02_F035_UD010_ME_V.jpg"; file = 'FDP_B02_F035_UD010_ME_V.jpg'; canvasLabel = 'Schizzo topografico della vigna, verso'; type = 'schizzo topografico manoscritto'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, b. 2, fasc. 35, doc. 10 verso' }
)

$fasc192Photos = @(
  @{ suffix = 'scat08-doc. 1-r'; source = "$root/scat08-fasc192/FDP_SCAT08_FASC192_UD001_ME_R_04.jpg"; file = 'FDP_SCAT08_FASC192_UD001_ME_R_04.jpg'; canvasLabel = 'Dettaglio dell''iscrizione, fotografia storica'; type = 'documentazione fotografica'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, scat. 8, fasc. 192, doc. 1' }
  @{ suffix = 'scat08-doc. 1-v'; source = "$root/scat08-fasc192/FDP_SCAT08_FASC192_UD001_ME_V.jpg"; file = 'FDP_SCAT08_FASC192_UD001_ME_V.jpg'; canvasLabel = 'Verso con annotazione Atilius'; type = 'verso fotografico con annotazione'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, scat. 8, fasc. 192, doc. 1 verso' }
  @{ suffix = 'scat08-doc. 2-r'; source = "$root/scat08-fasc192/FDP_SCAT08_FASC192_UD002_ME_R_03.jpg"; file = 'FDP_SCAT08_FASC192_UD002_ME_R_03.jpg'; canvasLabel = 'Fotografia del luogo del rinvenimento'; type = 'documentazione fotografica'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, scat. 8, fasc. 192, doc. 2 recto' }
  @{ suffix = 'scat08-doc. 2-v'; source = "$root/scat08-fasc192/FDP_SCAT08_FASC192_UD002_ME_V.jpg"; file = 'FDP_SCAT08_FASC192_UD002_ME_V.jpg'; canvasLabel = 'Verso con annotazioni sul promontorio di Santo Spirito'; type = 'verso fotografico con annotazioni'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, scat. 8, fasc. 192, doc. 2 verso' }
)

$fasc192Doc2 = @(
  @{ suffix = 'scat08-doc. 2-r'; source = "$root/scat08-fasc192/FDP_SCAT08_FASC192_UD002_ME_R_03.jpg"; file = 'FDP_SCAT08_FASC192_UD002_ME_R_03.jpg'; canvasLabel = 'Fotografia del luogo del rinvenimento'; type = 'documentazione fotografica'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, scat. 8, fasc. 192, doc. 2 recto' }
  @{ suffix = 'scat08-doc. 2-v'; source = "$root/scat08-fasc192/FDP_SCAT08_FASC192_UD002_ME_V.jpg"; file = 'FDP_SCAT08_FASC192_UD002_ME_V.jpg'; canvasLabel = 'Verso con annotazioni sul promontorio di Santo Spirito'; type = 'verso fotografico con annotazioni'; repository = 'Archivio Davide Pace'; reference = 'Fondo Pace, scat. 8, fasc. 192, doc. 2 verso' }
)

New-IiifManifest `
  'nucleo2-embrice-reperto-13418' `
  'Embrice iscritto, fotografia attuale' `
  $currentObject `
  'MANLo, n. inv. 13418' `
  'embrice iscritto; Santo Spirito; Gropello Cairoli; gens Atilia' `
  'reperto'

New-IiifManifest `
  'nucleo2-embrice-reperto-13418-dettaglio' `
  'Embrice iscritto, dettaglio dell''iscrizione' `
  $currentDetail `
  'MANLo, n. inv. 13418' `
  'embrice iscritto; iscrizione; Santo Spirito; Gropello Cairoli; gens Atilia' `
  'dettaglio-iscrizione'

New-IiifManifest `
  'nucleo2-embrice-rinvenimento-b02-f035' `
  'Rinvenimento dell''embrice iscritto, b. 2, fasc. 35' `
  $discoveryPhotos `
  'Fondo Pace, b. 2, fasc. 35, doc. 1-4' `
  'rinvenimento; vigna Carlo Nicola; Santo Spirito; embrice iscritto' `
  'doc. 1-r'

New-IiifManifest `
  'nucleo2-embrice-carteggio-b02-f035' `
  'Lettera e appunti sul rinvenimento dell''embrice iscritto' `
  $papers `
  'Fondo Pace, b. 2, fasc. 35, doc. 9-10' `
  'carteggio; appunti manoscritti; schizzo topografico; Santo Spirito' `
  'doc. 9-r'

New-IiifManifest `
  'nucleo2-embrice-fasc192-fotografie' `
  'Documentazione fotografica dell''iscrizione, scat. 8, fasc. 192' `
  $fasc192Photos `
  'Fondo Pace, scat. 8, fasc. 192, doc. 1-2' `
  'iscrizione; ATILIVS; documentazione fotografica; Santo Spirito' `
  'scat08-doc. 1-r'

New-IiifManifest `
  'nucleo2-embrice-fasc192-doc2' `
  'Promontorio di Santo Spirito, scat. 8, fasc. 192, doc. 2' `
  $fasc192Doc2 `
  'Fondo Pace, scat. 8, fasc. 192, doc. 2' `
  'Santo Spirito; documentazione fotografica; iscrizione ATILIVS' `
  'scat08-doc. 2-r'
