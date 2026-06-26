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

$base = 'assets/images/davide-pace/sul-campo'

function ManifestMetadata($title, $type, $reference, $place, $date, $description, $subject) {
  return New-Metadata @(
    @{ label = 'Titolo'; value = $title }
    @{ label = 'Tipologia'; value = $type }
    @{ label = 'Archivio / istituto'; value = 'Archivio Davide Pace' }
    @{ label = 'Fondo'; value = 'Fondo Davide Pace' }
    @{ label = 'Riferimento'; value = $reference }
    @{ label = 'Luogo'; value = $place }
    @{ label = 'Data'; value = $date }
    @{ label = 'Descrizione'; value = $description }
    @{ label = 'Soggetto'; value = $subject }
    @{ label = 'Diritti'; value = 'Direzione regionale Musei nazionali Lombardia - Museo Archeologico Nazionale della Lomellina' }
  )
}

$lanfranchiDescription = "Fotografia relativa alla necropoli di Gropello, sepolcreto del dosso Lanfranchi, tomba n. 3. Il recto documenta due operatori impegnati presso il contesto di scavo; il verso conserva l'annotazione manoscritta con l'indicazione del luogo, del soggetto e dell'affioramento iniziale."
$lanfranchiPages = @(
  @{
    suffix = 'r'
    source = "$base/FDP_B04_F106_UD009_R.jpg"
    file = 'FDP_B04_F106_UD009_R.jpg'
    canvasLabel = 'Gropello, dosso Lanfranchi. Tomba n. 3, recto'
    type = 'stampa fotografica in bianco e nero'
    reference = 'Archivio Davide Pace, b. 4, fasc. 106, doc. 9'
    place = 'Gropello Cairoli, dosso Lanfranchi'
    date = ''
    description = $lanfranchiDescription
    subject = 'Gropello Cairoli; necropoli; dosso Lanfranchi; tomba n. 3; scavo archeologico'
  },
  @{
    suffix = 'v'
    source = "$base/FDP_B04_F106_UD009_V.jpg"
    file = 'FDP_B04_F106_UD009_V.jpg'
    canvasLabel = 'Gropello, dosso Lanfranchi. Tomba n. 3, verso con annotazione'
    type = 'verso di stampa fotografica con annotazione manoscritta'
    reference = 'Archivio Davide Pace, b. 4, fasc. 106, doc. 9'
    place = 'Gropello Cairoli, dosso Lanfranchi'
    date = ''
    description = "Verso della stampa con annotazione manoscritta: Gropello, dosso Lanfranchi, tomba n. 3, affioramento iniziale."
    subject = 'annotazione manoscritta; Gropello; dosso Lanfranchi; tomba n. 3'
  }
)

New-IiifManifest `
  'davide-pace-sul-campo-lanfranchi-tomba3' `
  'Gropello, dosso Lanfranchi. Necropoli, tomba n. 3' `
  (ManifestMetadata 'Gropello, dosso Lanfranchi. Necropoli, tomba n. 3' 'stampa fotografica con verso annotato' 'Archivio Davide Pace, b. 4, fasc. 106, doc. 9' 'Gropello Cairoli, dosso Lanfranchi' '' $lanfranchiDescription 'Gropello Cairoli; necropoli; dosso Lanfranchi; tomba n. 3') `
  $lanfranchiPages `
  'r'

$santo1965Description = "Stampa fotografica in bianco e nero relativa alle indagini archeologiche condotte presso il promontorio di Santo Spirito nell'aprile 1965. L'immagine ritrae Davide Pace presso un saggio di scavo, con evidenza del fronte e del profilo del terreno documentati durante le attivit? sul campo."
$santo1965Pages = @(
  @{
    suffix = 'r'
    source = "$base/FDP_SC08_F204_UD013_R.jpg"
    file = 'FDP_SC08_F204_UD013_R.jpg'
    canvasLabel = 'Santo Spirito. Davide Pace presso un saggio di scavo'
    type = 'stampa fotografica in bianco e nero'
    reference = 'Archivio Davide Pace, scat. 8, fasc. 204, doc. 13'
    place = 'Gropello Cairoli, promontorio di Santo Spirito'
    date = 'aprile 1965'
    description = $santo1965Description
    subject = 'Davide Pace; Santo Spirito; saggio di scavo; scavi stratigrafici; profili del terreno'
  }
)

New-IiifManifest `
  'davide-pace-sul-campo-santo-spirito-1965' `
  'Gropello Cairoli, promontorio di Santo Spirito. Davide Pace e saggio di scavo, aprile 1965' `
  (ManifestMetadata 'Gropello Cairoli, promontorio di Santo Spirito. Davide Pace e saggio di scavo, aprile 1965' 'stampa fotografica in bianco e nero' 'Archivio Davide Pace, scat. 8, fasc. 204, doc. 13' 'Gropello Cairoli, promontorio di Santo Spirito' 'aprile 1965' $santo1965Description 'Davide Pace; saggio di scavo; scavi stratigrafici; Santo Spirito') `
  $santo1965Pages `
  'r'

$campo1965Description = "Stampa a colori di documentazione fotografica di indagine sul campo, 12 novembre 1965. L'immagine raffigura Davide Pace insieme a una persona non identificata accanto a un settore di scavo, con attrezzi da lavoro, durante le attivit? di indagine."
$campo1965Pages = @(
  @{
    suffix = 'r-01'
    source = "$base/FDP_SC12_F256_UD001_MASTER_R_01.jpg"
    file = 'FDP_SC12_F256_UD001_MASTER_R_01.jpg'
    canvasLabel = 'Documentazione fotografica di indagine sul campo, 12 novembre 1965'
    type = 'stampa fotografica a colori'
    reference = 'Archivio Davide Pace, scat. 12, fasc. 256, doc. 1'
    place = 'Lomellina'
    date = '12 novembre 1965'
    description = $campo1965Description
    subject = 'Davide Pace; indagine sul campo; settore di scavo; attrezzi da lavoro'
  }
)

New-IiifManifest `
  'davide-pace-sul-campo-indagine-1965' `
  'Documentazione fotografica di indagine sul campo, 12 novembre 1965' `
  (ManifestMetadata 'Documentazione fotografica di indagine sul campo, 12 novembre 1965' 'stampa fotografica a colori' 'Archivio Davide Pace, scat. 12, fasc. 256, doc. 1' 'Lomellina' '12 novembre 1965' $campo1965Description 'Davide Pace; indagine sul campo; scavo archeologico') `
  $campo1965Pages `
  'r-01'

$passeriniDescription = "Ingrandimento fotografico relativo alla fornace romana del podere Passerini, eseguito nell'ambito della serie di fotogrammi dedicati alla documentazione analitica delle strutture. Il nucleo documenta porzioni murarie, elementi laterizi, cavita e dettagli costruttivi della fornace, con annotazioni sul verso riferibili alle riprese di Davide Pace e Francesco Pace."
$passeriniPages = @(
  @{
    suffix = 'r'
    source = "$base/FDP_SCAT11_F246_UD003_ME_R.jpg"
    file = 'FDP_SCAT11_F246_UD003_ME_R.jpg'
    canvasLabel = 'Podere Passerini. Fornace romana, fotogramma ingrandito, recto'
    type = 'stampa fotografica in bianco e nero di grande formato'
    reference = 'Archivio Davide Pace, scat. 11, fasc. 246, doc. 3'
    place = 'Gropello Cairoli, podere Passerini'
    date = '31 luglio 1958 - 10 luglio 1959'
    description = $passeriniDescription
    subject = 'fornace romana; podere Passerini; opus latericium; strutture archeologiche; fotogrammi ingranditi'
  },
  @{
    suffix = 'v'
    source = "$base/FDP_SCAT11_F246_UD003_ME_V.jpg"
    file = 'FDP_SCAT11_F246_UD003_ME_V.jpg'
    canvasLabel = 'Podere Passerini. Fornace romana, fotogramma ingrandito, verso'
    type = 'verso di stampa fotografica con annotazioni manoscritte'
    reference = 'Archivio Davide Pace, scat. 11, fasc. 246, doc. 3'
    place = 'Gropello Cairoli, podere Passerini'
    date = '31 luglio 1958 - 10 luglio 1959'
    description = 'Verso della stampa con annotazioni manoscritte relative al soggetto, alle strutture documentate e alla campagna fotografica della fornace romana.'
    subject = 'annotazioni manoscritte; fornace romana; podere Passerini; Davide Pace; Francesco Pace'
  }
)

New-IiifManifest `
  'davide-pace-sul-campo-passerini-fornace-f246' `
  'Gropello Cairoli, podere Passerini. Fornace romana. Serie dei fotogrammi ingranditi' `
  (ManifestMetadata 'Gropello Cairoli, podere Passerini. Fornace romana. Serie dei fotogrammi ingranditi' 'stampe fotografiche in bianco e nero di grande formato' 'Archivio Davide Pace, scat. 11, fasc. 246, doc. 3' 'Gropello Cairoli, podere Passerini' '31 luglio 1958 - 10 luglio 1959' $passeriniDescription 'fornace romana; podere Passerini; strutture archeologiche; fotogrammi ingranditi') `
  $passeriniPages `
  'r'
