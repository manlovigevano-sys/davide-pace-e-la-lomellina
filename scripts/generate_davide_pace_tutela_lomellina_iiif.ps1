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
      @{ label = 'Luogo'; value = $page.place }
      @{ label = 'Data'; value = $page.date }
      @{ label = 'Soggetto'; value = $page.subject }
      @{ label = 'Tecnica / supporto'; value = $page.support }
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

$base = 'assets/images/davide-pace/tutela-lomellina'
$rights = 'Direzione regionale Musei nazionali Lombardia - Museo Archeologico Nazionale della Lomellina'

$maroneMetadata = New-Metadata @(
  @{ label = 'Titolo'; value = "Gropello Cairoli, Dosso del Marone. Scavi archeologici e tutela dell'area, 1956-1960 (?)" }
  @{ label = 'Tipologia'; value = 'stampe fotografiche' }
  @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
  @{ label = 'Fondo'; value = 'Fondo Davide Pace' }
  @{ label = 'Riferimento'; value = 'Archivio Davide Pace, scat. 10, fasc. 227; scat. 10, fasc. 228' }
  @{ label = 'Luogo'; value = 'Gropello Cairoli, Dosso del Marone' }
  @{ label = 'Data'; value = '1956-1960 (?)' }
  @{ label = 'Datazione'; value = 'data attribuita, sec. XX seconda meta' }
  @{ label = 'Descrizione'; value = "Le fotografie documentano l'area del Dosso del Marone nel quadro delle attivit? di tutela promosse durante gli scavi archeologici. Il nucleo distingue il positivo fotografico conservato nel fasc. 227 dal negativo trasformato in positivo digitale conservato nel fasc. 228; entrambe le immagini mostrano il cartello della Soprintendenza alle antichita della Lombardia con il divieto di effettuare scavi o sterri nell'area." }
  @{ label = 'Soggetto'; value = 'Gropello Cairoli; Dosso del Marone; scavi archeologici; tutela; Soprintendenza alle antichita della Lombardia; divieto di scavi e sterri' }
  @{ label = 'Diritti'; value = $rights }
)

$maronePages = @(
  @{
    suffix = 'scat10-f227-doc. 9'
    source = "$base/FDP_SCAT10_F227_UD009_ME.jpg"
    file = 'FDP_SCAT10_F227_UD009_ME.jpg'
    canvasLabel = 'Dosso del Marone: cartello di tutela della Soprintendenza, positivo fotografico'
    type = 'stampa fotografica'
    reference = 'Archivio Davide Pace, scat. 10, fasc. 227, doc. 9'
    place = 'Gropello Cairoli, Dosso del Marone'
    date = '1956-1960 (?)'
    subject = 'cartello di tutela; Soprintendenza alle antichita della Lombardia; area di scavo; divieto di scavi e sterri'
    support = 'positivo fotografico originale'
  },
  @{
    suffix = 'scat10-f228-doc. 3-fot01'
    source = "$base/FDP_SCAT10_F228_UD003_ME_FOT01_1POS.jpg"
    file = 'FDP_SCAT10_F228_UD003_ME_FOT01_1POS.jpg'
    canvasLabel = 'Dosso del Marone: cartello di tutela della Soprintendenza, negativo trasformato in positivo'
    type = 'positivo digitale da negativo'
    reference = 'Archivio Davide Pace, scat. 10, fasc. 228, doc. 3, fot. 01'
    place = 'Gropello Cairoli, Dosso del Marone'
    date = '1956-1960 (?)'
    subject = 'cartello di tutela; Soprintendenza alle antichita della Lombardia; area di scavo; divieto di scavi e sterri'
    support = 'negativo trasformato in positivo digitale'
  }
)

$santoSpiritoMetadata = New-Metadata @(
  @{ label = 'Titolo'; value = 'Gropello Cairoli, Santo Spirito. Documentazione fotografica delle attivit? di scavo, 1960 (?)' }
  @{ label = 'Tipologia'; value = 'diapositive digitalizzate' }
  @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
  @{ label = 'Fondo'; value = 'Fondo Davide Pace' }
  @{ label = 'Riferimento'; value = 'Archivio Davide Pace, scat. 13.2, fasc. 266' }
  @{ label = 'Luogo'; value = 'Gropello Cairoli, Santo Spirito' }
  @{ label = 'Data'; value = '1960 (?)' }
  @{ label = 'Datazione'; value = 'data incerta' }
  @{ label = 'Descrizione'; value = "Le diapositive digitalizzate documentano le attivit? di scavo sul promontorio di Santo Spirito: vedute d'insieme dell'area, settori interessati da movimenti di terra, profili e porzioni di stratigrafia messi in luce, concentrazioni di ciottoli e laterizi affioranti. La sequenza comprende anche riprese del paesaggio circostante e momenti del lavoro sul campo con strumenti e operatori." }
  @{ label = 'Soggetto'; value = 'Gropello Cairoli; Santo Spirito; promontorio; attivit? di scavo; stratigrafia; ciottoli; laterizi; documentazione fotografica' }
  @{ label = 'Diritti'; value = $rights }
)

$santoSpiritoPages = @(
  @{
    suffix = 'doc. 11-fot01'
    source = "$base/FDP_SCAT12.2_F266_UD011_ME_FOT01.jpg"
    file = 'FDP_SCAT12.2_F266_UD011_ME_FOT01.jpg'
    canvasLabel = "Santo Spirito: veduta dell'area di scavo e dei movimenti di terra"
    type = 'diapositiva digitalizzata'
    reference = 'Archivio Davide Pace, scat. 13.2, fasc. 266, doc. 11, fot. 01'
    place = 'Gropello Cairoli, Santo Spirito'
    date = '1960 (?)'
    subject = "veduta d'insieme; area di scavo; movimenti di terra; paesaggio agricolo"
    support = 'diapositiva digitalizzata'
  },
  @{
    suffix = 'doc. 13-fot01'
    source = "$base/FDP_SCAT12.2_F266_UD013_ME_FOT01.jpg"
    file = 'FDP_SCAT12.2_F266_UD013_ME_FOT01.jpg'
    canvasLabel = 'Santo Spirito: profilo del terreno e area di lavoro sul campo'
    type = 'diapositiva digitalizzata'
    reference = 'Archivio Davide Pace, scat. 13.2, fasc. 266, doc. 13, fot. 01'
    place = 'Gropello Cairoli, Santo Spirito'
    date = '1960 (?)'
    subject = 'profilo del terreno; stratigrafia; strumenti di scavo; operatore'
    support = 'diapositiva digitalizzata'
  },
  @{
    suffix = 'doc. 14-fot01'
    source = "$base/FDP_SCAT12.2_F266_UD014_ME_FOT01.jpg"
    file = 'FDP_SCAT12.2_F266_UD014_ME_FOT01.jpg'
    canvasLabel = "Santo Spirito: dettaglio dell'area di scavo con strumenti e materiali"
    type = 'diapositiva digitalizzata'
    reference = 'Archivio Davide Pace, scat. 13.2, fasc. 266, doc. 14, fot. 01'
    place = 'Gropello Cairoli, Santo Spirito'
    date = '1960 (?)'
    subject = 'area di scavo; strumenti; materiali raccolti; porzioni stratigrafiche'
    support = 'diapositiva digitalizzata'
  },
  @{
    suffix = 'doc. 15-fot01'
    source = "$base/FDP_SCAT12.2_F266_UD015_ME_FOT01.jpg"
    file = 'FDP_SCAT12.2_F266_UD015_ME_FOT01.jpg'
    canvasLabel = 'Santo Spirito: fronte di scavo e profili del terreno'
    type = 'diapositiva digitalizzata'
    reference = 'Archivio Davide Pace, scat. 13.2, fasc. 266, doc. 15, fot. 01'
    place = 'Gropello Cairoli, Santo Spirito'
    date = '1960 (?)'
    subject = 'fronte di scavo; profili del terreno; stratigrafia; strumenti'
    support = 'diapositiva digitalizzata'
  },
  @{
    suffix = 'doc. 16-fot01'
    source = "$base/FDP_SCAT12.2_F266_UD016_ME_FOT01.jpg"
    file = 'FDP_SCAT12.2_F266_UD016_ME_FOT01.jpg'
    canvasLabel = "Santo Spirito: concentrazioni di ciottoli e laterizi nell'area di scavo"
    type = 'diapositiva digitalizzata'
    reference = 'Archivio Davide Pace, scat. 13.2, fasc. 266, doc. 16, fot. 01'
    place = 'Gropello Cairoli, Santo Spirito'
    date = '1960 (?)'
    subject = 'ciottoli; laterizi; area di scavo; paesaggio circostante'
    support = 'diapositiva digitalizzata'
  },
  @{
    suffix = 'doc. 17-fot01'
    source = "$base/FDP_SCAT12.2_F266_UD017_ME_FOT01.jpg"
    file = 'FDP_SCAT12.2_F266_UD017_ME_FOT01.jpg'
    canvasLabel = 'Santo Spirito: veduta del promontorio e del paesaggio circostante'
    type = 'diapositiva digitalizzata'
    reference = 'Archivio Davide Pace, scat. 13.2, fasc. 266, doc. 17, fot. 01'
    place = 'Gropello Cairoli, Santo Spirito'
    date = '1960 (?)'
    subject = 'promontorio; paesaggio circostante; strumenti di scavo; area di lavoro'
    support = 'diapositiva digitalizzata'
  }
)

New-IiifManifest `
  'davide-pace-dosso-marone-tutela' `
  "Gropello Cairoli, Dosso del Marone. Scavi archeologici e tutela dell'area, 1956-1960 (?)" `
  $maroneMetadata `
  $maronePages `
  'scat10-f227-doc. 9'

New-IiifManifest `
  'davide-pace-santo-spirito-scavi-f266' `
  'Gropello Cairoli, Santo Spirito. Documentazione fotografica delle attivit? di scavo, 1960 (?)' `
  $santoSpiritoMetadata `
  $santoSpiritoPages `
  'doc. 11-fot01'
