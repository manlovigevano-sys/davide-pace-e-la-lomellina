$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$iiifRoot = Join-Path $repoRoot 'img\derivatives\iiif'
$outputDir = Join-Path $repoRoot 'outputs'
$outputPath = Join-Path $outputDir 'iiif_metadata_review.xlsx'
$publicBase = 'https://manlovigevano-sys.github.io/davide-pace-e-la-lomellina'

function Convert-LiquidJson {
  param([string]$Text)

  $json = $Text -replace "(?s)\A---\s*\r?\n.*?\r?\n---\s*\r?\n", ''
  $json = [regex]::Replace($json, "\{\{\s*'([^']+)'\s*\|\s*absolute_url\s*\}\}", {
    param($m)
    $path = $m.Groups[1].Value
    if ($path.StartsWith('/')) { return $publicBase + $path }
    return "$publicBase/$path"
  })
  $json = [regex]::Replace($json, "\{\{\s*'([^']+)'\s*\|\s*relative_url\s*\}\}", {
    param($m)
    $path = $m.Groups[1].Value
    if ($path.StartsWith('/')) { return '/davide-pace-e-la-lomellina' + $path }
    return "/davide-pace-e-la-lomellina/$path"
  })
  return $json
}

function Get-MetadataMap {
  param($Items)
  $map = @{}
  if ($null -eq $Items) { return $map }
  foreach ($item in $Items) {
    if ($null -eq $item.label) { continue }
    $label = [string]$item.label
    $value = if ($null -eq $item.value) { '' } else { [string]$item.value }
    $map[$label] = $value
  }
  return $map
}

function Get-First {
  param($Map, [string[]]$Keys)
  foreach ($key in $Keys) {
    if ($Map.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace([string]$Map[$key])) {
      return [string]$Map[$key]
    }
  }
  return ''
}

function Get-CellRef {
  param([int]$Row, [int]$Col)
  $name = ''
  $n = $Col
  while ($n -gt 0) {
    $n--
    $name = [char]([int](65 + ($n % 26))) + $name
    $n = [math]::Floor($n / 26)
  }
  return "$name$Row"
}

function Escape-Xml {
  param($Value)
  if ($null -eq $Value) { return '' }
  $text = [string]$Value
  $text = [regex]::Replace($text, '[\x00-\x08\x0B\x0C\x0E-\x1F]', '')
  return [System.Security.SecurityElement]::Escape($text)
}

function New-CellXml {
  param([int]$Row, [int]$Col, $Value, [int]$Style = 0)
  $ref = Get-CellRef -Row $Row -Col $Col
  $stylePart = if ($Style -gt 0) { " s=`"$Style`"" } else { '' }
  if ($null -ne $Value -and $Value -is [int]) {
    return "<c r=`"$ref`"$stylePart><v>$Value</v></c>"
  }
  if ($null -ne $Value -and $Value -is [double]) {
    $num = ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0}', $Value))
    return "<c r=`"$ref`"$stylePart><v>$num</v></c>"
  }
  return "<c r=`"$ref`" t=`"inlineStr`"$stylePart><is><t xml:space=`"preserve`">$(Escape-Xml $Value)</t></is></c>"
}

function New-SheetXml {
  param(
    [string]$Name,
    [array]$Headers,
    [array]$Rows,
    [int[]]$Widths
  )

  $colCount = $Headers.Count
  $rowCount = $Rows.Count + 1
  $lastRef = Get-CellRef -Row $rowCount -Col $colCount
  $xml = New-Object System.Text.StringBuilder
  [void]$xml.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
  [void]$xml.Append('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
  [void]$xml.Append("<dimension ref=`"A1:$lastRef`"/>")
  [void]$xml.Append('<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>')
  [void]$xml.Append('<cols>')
  for ($i = 0; $i -lt $Headers.Count; $i++) {
    $width = if ($i -lt $Widths.Count) { $Widths[$i] } else { 18 }
    $col = $i + 1
    [void]$xml.Append("<col min=`"$col`" max=`"$col`" width=`"$width`" customWidth=`"1`"/>")
  }
  [void]$xml.Append('</cols><sheetData>')

  [void]$xml.Append('<row r="1" ht="24" customHeight="1">')
  for ($c = 1; $c -le $Headers.Count; $c++) {
    [void]$xml.Append((New-CellXml -Row 1 -Col $c -Value $Headers[$c - 1] -Style 1))
  }
  [void]$xml.Append('</row>')

  $r = 2
  foreach ($row in $Rows) {
    [void]$xml.Append("<row r=`"$r`">")
    for ($c = 1; $c -le $Headers.Count; $c++) {
      $value = $row[$c - 1]
      [void]$xml.Append((New-CellXml -Row $r -Col $c -Value $value -Style 0))
    }
    [void]$xml.Append('</row>')
    $r++
  }

  [void]$xml.Append('</sheetData>')
  [void]$xml.Append("<autoFilter ref=`"A1:$lastRef`"/>")
  [void]$xml.Append('</worksheet>')
  return $xml.ToString()
}

if (-not (Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$imageHeaders = @(
  'Stato revisione',
  'Note revisione',
  'Manifest slug',
  'Manifest label',
  'Manifest PID',
  'PID precedente',
  'Sezione mostra',
  'Manifest tipologia',
  'Tipo supporto/documento',
  'Creatore',
  'Data manifest',
  'Luogo manifest',
  'Archivio / istituto',
  'Riferimento manifest',
  'Soggetti manifest',
  'Soggettario / thesaurus',
  'Descrizione manifest',
  'Diritti',
  'Licenza',
  'Ordine canvas',
  'Canvas label',
  'Titolo canvas',
  'Tipologia canvas',
  'Data canvas',
  'Luogo canvas',
  'Riferimento canvas',
  'File sorgente',
  'Larghezza px',
  'Altezza px',
  'Formato',
  'Thumbnail URL',
  'Full image URL',
  'IIIF service ID',
  'Manifest URL',
  'Canvas URL',
  'Annotation URL',
  'Manifest file'
)

$manifestHeaders = @(
  'Manifest slug',
  'Manifest label',
  'PID',
  'PID precedente',
  'Immagini canvas',
  'Consistenza',
  'Sezione mostra',
  'Tipologia',
  'Creatore',
  'Data',
  'Luogo',
  'Riferimento',
  'Manifest URL',
  'Manifest file'
)

$uniqueHeaders = @(
  'Stato revisione',
  'Note revisione',
  'IIIF service ID',
  'Full image URL',
  'Thumbnail URL',
  'File sorgente',
  'Canvas label',
  'Titolo canvas',
  'Tipologia canvas',
  'Data canvas',
  'Luogo canvas',
  'Riferimento canvas',
  'Larghezza px',
  'Altezza px',
  'Formato',
  'Occorrenze manifest',
  'Manifest slug associati',
  'Manifest label associati',
  'Manifest PID',
  'PID precedente',
  'Sezione mostra',
  'Creatore',
  'Data manifest',
  'Luogo manifest',
  'Riferimento manifest',
  'Soggetti manifest',
  'Diritti',
  'Licenza',
  'Canvas URL',
  'Annotation URL'
)

$imageRows = New-Object System.Collections.Generic.List[object]
$manifestRows = New-Object System.Collections.Generic.List[object]

$manifestFiles = Get-ChildItem -LiteralPath $iiifRoot -Directory |
  ForEach-Object { Join-Path $_.FullName 'manifest.json' } |
  Where-Object { Test-Path -LiteralPath $_ } |
  Sort-Object

foreach ($manifestFile in $manifestFiles) {
  $raw = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8
  $json = Convert-LiquidJson -Text $raw
  try {
    $manifest = $json | ConvertFrom-Json
  } catch {
    Write-Warning "Manifest non leggibile: $manifestFile"
    continue
  }

  $manifestSlug = Split-Path -Leaf (Split-Path -Parent $manifestFile)
  $manifestMeta = Get-MetadataMap $manifest.metadata
  $manifestLabel = [string]$manifest.label
  $manifestUrl = [string]$manifest.'@id'
  $manifestRel = (Resolve-Path -LiteralPath $manifestFile).Path.Substring($repoRoot.Length + 1)
  $canvases = @()
  foreach ($sequence in @($manifest.sequences)) {
    $canvases += @($sequence.canvases)
  }

  $manifestRows.Add(@(
    $manifestSlug,
    $manifestLabel,
    (Get-First $manifestMeta @('PID')),
    (Get-First $manifestMeta @('PID precedente')),
    [int]$canvases.Count,
    (Get-First $manifestMeta @('Consistenza')),
    (Get-First $manifestMeta @('Sezione mostra')),
    (Get-First $manifestMeta @('Tipologia')),
    (Get-First $manifestMeta @('Creatore')),
    (Get-First $manifestMeta @('Data')),
    (Get-First $manifestMeta @('Luogo')),
    (Get-First $manifestMeta @('Riferimento')),
    $manifestUrl,
    $manifestRel
  )) | Out-Null

  $i = 1
  foreach ($canvas in $canvases) {
    $canvasMeta = Get-MetadataMap $canvas.metadata
    $annotation = @($canvas.images)[0]
    $resource = $annotation.resource
    $service = $resource.service
    $width = if ($null -ne $canvas.width) { [int]$canvas.width } elseif ($null -ne $resource.width) { [int]$resource.width } else { $null }
    $height = if ($null -ne $canvas.height) { [int]$canvas.height } elseif ($null -ne $resource.height) { [int]$resource.height } else { $null }

    $imageRows.Add(@(
      '',
      '',
      $manifestSlug,
      $manifestLabel,
      (Get-First $manifestMeta @('PID')),
      (Get-First $manifestMeta @('PID precedente')),
      (Get-First $manifestMeta @('Sezione mostra')),
      (Get-First $manifestMeta @('Tipologia')),
      (Get-First $manifestMeta @('Tipo supporto/documento')),
      (Get-First $manifestMeta @('Creatore')),
      (Get-First $manifestMeta @('Data')),
      (Get-First $manifestMeta @('Luogo')),
      (Get-First $manifestMeta @('Archivio / istituto')),
      (Get-First $manifestMeta @('Riferimento')),
      (Get-First $manifestMeta @('Soggetti')),
      (Get-First $manifestMeta @('Soggettario / thesaurus')),
      (Get-First $manifestMeta @('Descrizione', 'Sintesi')),
      (Get-First $manifestMeta @('Diritti')),
      (Get-First $manifestMeta @('Licenza')),
      [int]$i,
      [string]$canvas.label,
      (Get-First $canvasMeta @('Titolo')),
      (Get-First $canvasMeta @('Tipologia')),
      (Get-First $canvasMeta @('Data')),
      (Get-First $canvasMeta @('Luogo')),
      (Get-First $canvasMeta @('Riferimento')),
      (Get-First $canvasMeta @('File sorgente')),
      $width,
      $height,
      [string]$resource.format,
      [string]$canvas.thumbnail,
      [string]$resource.'@id',
      [string]$service.'@id',
      $manifestUrl,
      [string]$canvas.'@id',
      [string]$annotation.'@id',
      $manifestRel
    )) | Out-Null
    $i++
  }
}

$uniqueRows = New-Object System.Collections.Generic.List[object]
$groups = $imageRows.ToArray() | Group-Object { if ([string]::IsNullOrWhiteSpace([string]$_[32])) { [string]$_[31] } else { [string]$_[32] } }
$usedServices = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($group in ($groups | Sort-Object Name)) {
  $rows = @($group.Group)
  $first = $rows[0]
  [void]$usedServices.Add([string]$group.Name)
  $manifestSlugs = ($rows | ForEach-Object { [string]$_[2] } | Where-Object { $_ } | Sort-Object -Unique) -join '; '
  $manifestLabels = ($rows | ForEach-Object { [string]$_[3] } | Where-Object { $_ } | Sort-Object -Unique) -join '; '
  $uniqueRows.Add(@(
    '',
    '',
    [string]$first[32],
    [string]$first[31],
    [string]$first[30],
    [string]$first[26],
    [string]$first[20],
    [string]$first[21],
    [string]$first[22],
    [string]$first[23],
    [string]$first[24],
    [string]$first[25],
    $first[27],
    $first[28],
    [string]$first[29],
    [int]$rows.Count,
    $manifestSlugs,
    $manifestLabels,
    [string]$first[4],
    [string]$first[5],
    [string]$first[6],
    [string]$first[9],
    [string]$first[10],
    [string]$first[11],
    [string]$first[13],
    [string]$first[14],
    [string]$first[17],
    [string]$first[18],
    [string]$first[34],
    [string]$first[35]
  )) | Out-Null
}

$infoFiles = Get-ChildItem -LiteralPath (Join-Path $iiifRoot 'images') -Recurse -File -Filter info.json | Sort-Object FullName
foreach ($infoFile in $infoFiles) {
  $raw = Get-Content -LiteralPath $infoFile.FullName -Raw -Encoding UTF8
  $json = Convert-LiquidJson -Text $raw
  try {
    $info = $json | ConvertFrom-Json
  } catch {
    Write-Warning "Info.json non leggibile: $($infoFile.FullName)"
    continue
  }

  $serviceId = [string]$info.'@id'
  if ([string]::IsNullOrWhiteSpace($serviceId)) {
    $relService = (Split-Path -Parent $infoFile.FullName).Substring($repoRoot.Length).Replace('\', '/')
    $serviceId = $publicBase + $relService
  }
  if ($usedServices.Contains($serviceId)) { continue }

  $serviceSlug = Split-Path -Leaf (Split-Path -Parent $infoFile.FullName)
  $infoWidth = if ($null -ne $info.width) { [int]$info.width } else { $null }
  $infoHeight = if ($null -ne $info.height) { [int]$info.height } else { $null }
  $uniqueRows.Add(@(
    '',
    '',
    $serviceId,
    "$serviceId/full/full/0/default.jpg",
    "$serviceId/full/250,/0/default.jpg",
    '',
    $serviceSlug,
    $serviceSlug,
    '',
    '',
    '',
    '',
    $infoWidth,
    $infoHeight,
    '',
    0,
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    ''
  )) | Out-Null
}

$temp = Join-Path $env:TEMP ("iiif_xlsx_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
New-Item -ItemType Directory -Path (Join-Path $temp '_rels') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $temp 'xl') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $temp 'xl\_rels') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $temp 'xl\worksheets') | Out-Null

$uniqueWidths = @(16, 32, 58, 62, 58, 34, 42, 42, 30, 18, 34, 38, 14, 14, 18, 18, 42, 52, 24, 24, 24, 22, 18, 34, 38, 46, 58, 34, 58, 58)
$imageWidths = @(16, 32, 28, 42, 24, 24, 24, 28, 26, 22, 18, 34, 26, 38, 46, 38, 52, 58, 34, 14, 42, 42, 30, 18, 34, 38, 34, 14, 14, 18, 58, 62, 58, 58, 58, 58, 42)
$manifestWidths = @(30, 44, 24, 24, 15, 20, 24, 30, 22, 18, 34, 42, 58, 42)

Set-Content -LiteralPath (Join-Path $temp 'xl\worksheets\sheet1.xml') -Encoding UTF8 -Value (New-SheetXml -Name 'Immagini IIIF' -Headers $uniqueHeaders -Rows $uniqueRows.ToArray() -Widths $uniqueWidths)
Set-Content -LiteralPath (Join-Path $temp 'xl\worksheets\sheet2.xml') -Encoding UTF8 -Value (New-SheetXml -Name 'Occorrenze manifest' -Headers $imageHeaders -Rows $imageRows.ToArray() -Widths $imageWidths)
Set-Content -LiteralPath (Join-Path $temp 'xl\worksheets\sheet3.xml') -Encoding UTF8 -Value (New-SheetXml -Name 'Manifest' -Headers $manifestHeaders -Rows $manifestRows.ToArray() -Widths $manifestWidths)

Set-Content -LiteralPath (Join-Path $temp '[Content_Types].xml') -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
'@

Set-Content -LiteralPath (Join-Path $temp '_rels\.rels') -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
'@

Set-Content -LiteralPath (Join-Path $temp 'xl\workbook.xml') -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Immagini IIIF" sheetId="1" r:id="rId1"/>
    <sheet name="Occorrenze manifest" sheetId="2" r:id="rId2"/>
    <sheet name="Manifest" sheetId="3" r:id="rId3"/>
  </sheets>
</workbook>
'@

Set-Content -LiteralPath (Join-Path $temp 'xl\_rels\workbook.xml.rels') -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/>
  <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
'@

Set-Content -LiteralPath (Join-Path $temp 'xl\styles.xml') -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font><sz val="10"/><name val="Aptos"/></font>
    <font><b/><color rgb="FFFFFFFF"/><sz val="10"/><name val="Aptos"/></font>
  </fonts>
  <fills count="3">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF8B4B35"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border><left/><right/><top/><bottom style="thin"><color rgb="FFD9D2C8"/></bottom><diagonal/></border>
  </borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="2">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
  </cellXfs>
  <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>
'@

$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
New-Item -ItemType Directory -Path (Join-Path $temp 'docProps') | Out-Null
Set-Content -LiteralPath (Join-Path $temp 'docProps\core.xml') -Encoding UTF8 -Value @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>IIIF metadata review</dc:title>
  <dc:creator>Codex</dc:creator>
  <cp:lastModifiedBy>Codex</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>
</cp:coreProperties>
"@

Set-Content -LiteralPath (Join-Path $temp 'docProps\app.xml') -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Codex</Application>
  <DocSecurity>0</DocSecurity>
  <ScaleCrop>false</ScaleCrop>
  <HeadingPairs><vt:vector size="2" baseType="variant"><vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant><vt:variant><vt:i4>3</vt:i4></vt:variant></vt:vector></HeadingPairs>
  <TitlesOfParts><vt:vector size="3" baseType="lpstr"><vt:lpstr>Immagini IIIF</vt:lpstr><vt:lpstr>Occorrenze manifest</vt:lpstr><vt:lpstr>Manifest</vt:lpstr></vt:vector></TitlesOfParts>
</Properties>
'@

if (Test-Path -LiteralPath $outputPath) {
  Remove-Item -LiteralPath $outputPath -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($temp, $outputPath)
Remove-Item -LiteralPath $temp -Recurse -Force

[pscustomobject]@{
  Output = $outputPath
  UniqueImageRows = $uniqueRows.Count
  OccurrenceRows = $imageRows.Count
  ManifestRows = $manifestRows.Count
}
