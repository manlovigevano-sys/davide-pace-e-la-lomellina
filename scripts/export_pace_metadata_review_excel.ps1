$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $repoRoot 'outputs'
$outPath = Join-Path $outDir 'pace_metadata_review.xlsx'
if (-not (Test-Path -LiteralPath $outDir)) {
  New-Item -ItemType Directory -Path $outDir | Out-Null
}

$fields = @(
  'pid', 'original_pid', 'label', 'summary', 'object_type', 'media_type', 'creator', 'display_date',
  'place', 'repository', 'reference', 'extent', 'subjects', 'subject_vocabularies', 'description',
  'rights', 'license', 'current_location', 'exhibit_section', 'exhibit_url', 'manifest', 'thumbnail',
  'full', 'layout', 'collection', 'hide_from_collection', 'search_exclude', 'published'
)
$headers = @('Anomalie') + $fields + @('Scheda locale')
$allowedObject = @(
  'fascicolo archivistico', 'relazione dattiloscritta', 'corrispondenza',
  'documentazione fotografica', 'documentazione grafica', 'inventario',
  'giornale di scavo', 'repertorio'
)
$allowedMedia = @('text', 'image', 'audio', 'video', 'application/pdf')

function Get-FrontMatterValue {
  param([string]$Text, [string]$Key)
  $match = [regex]::Match($Text, "(?m)^$([regex]::Escape($Key)):\s*(.*)$")
  if (-not $match.Success) { return '' }
  $value = $match.Groups[1].Value.Trim()
  if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
    $value = $value.Substring(1, $value.Length - 2)
  }
  return [System.Net.WebUtility]::HtmlDecode($value)
}

function Get-CellRef {
  param([int]$Row, [int]$Col)
  $name = ''
  $n = [int]$Col
  while ($n -gt 0) {
    $n = [int]($n - 1)
    $name = [string]([char]([int](65 + ($n % 26)))) + $name
    $n = [int][math]::Floor($n / 26)
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
  param([int]$Row, [int]$Col, $Value, [int]$StyleId = 0)
  $ref = Get-CellRef -Row $Row -Col $Col
  $stylePart = if ($StyleId -gt 0) { " s=`"$StyleId`"" } else { '' }
  return "<c r=`"$ref`" t=`"inlineStr`"$stylePart><is><t xml:space=`"preserve`">$(Escape-Xml $Value)</t></is></c>"
}

function New-SheetXml {
  param([array]$Headers, [array]$Rows, [int[]]$Widths)
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
    $width = if ($i -lt $Widths.Count) { $Widths[$i] } else { 24 }
    $col = $i + 1
    [void]$xml.Append("<col min=`"$col`" max=`"$col`" width=`"$width`" customWidth=`"1`"/>")
  }
  [void]$xml.Append('</cols><sheetData>')
  [void]$xml.Append('<row r="1" ht="26" customHeight="1">')
  for ($c = 1; $c -le $Headers.Count; $c++) {
    [void]$xml.Append((New-CellXml -Row 1 -Col $c -Value $Headers[$c - 1] -StyleId 1))
  }
  [void]$xml.Append('</row>')
  $r = 2
  foreach ($row in $Rows) {
    [void]$xml.Append("<row r=`"$r`">")
    for ($c = 1; $c -le $Headers.Count; $c++) {
      [void]$xml.Append((New-CellXml -Row $r -Col $c -Value $row[$c - 1]))
    }
    [void]$xml.Append('</row>')
    $r++
  }
  [void]$xml.Append('</sheetData>')
  [void]$xml.Append("<autoFilter ref=`"A1:$lastRef`"/>")
  [void]$xml.Append('</worksheet>')
  return $xml.ToString()
}

$rows = New-Object System.Collections.Generic.List[object]
Get-ChildItem -LiteralPath (Join-Path $repoRoot '_pace') -Filter '*.md' | Sort-Object Name | ForEach-Object {
  $text = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
  $values = @{}
  foreach ($field in $fields) {
    $values[$field] = Get-FrontMatterValue -Text $text -Key $field
  }

  $anomalies = @()
  if ($allowedObject -notcontains $values['object_type']) { $anomalies += 'object_type fuori vocabolario' }
  if ($allowedMedia -notcontains $values['media_type']) { $anomalies += 'media_type fuori vocabolario' }
  if ($values['repository'] -ne 'Archivio Davide Pace') { $anomalies += 'repository non uniforme' }
  if ($values['current_location'] -ne 'Museo Archeologico Nazionale della Lomellina') { $anomalies += 'current_location non uniforme' }
  if ($values['subjects'] -match 'Dattiloscritti|Fotografie|Carteggi|Manoscritti|Disegni|Negativi|Diapositive') { $anomalies += 'subjects contiene supporto documentario' }
  if ([string]::IsNullOrWhiteSpace($values['description']) -or $values['description'] -eq $values['label']) { $anomalies += 'description da rivedere' }
  if ([string]::IsNullOrWhiteSpace($values['exhibit_url'])) { $anomalies += 'exhibit_url mancante' }

  $slug = [IO.Path]::GetFileNameWithoutExtension($_.Name)
  $row = @($anomalies -join '; ')
  foreach ($field in $fields) { $row += $values[$field] }
  $row += "/pace/$slug/"
  $rows.Add($row) | Out-Null
}

$temp = Join-Path $env:TEMP ('pace_metadata_xlsx_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp, (Join-Path $temp '_rels'), (Join-Path $temp 'xl'), (Join-Path $temp 'xl/_rels'), (Join-Path $temp 'xl/worksheets'), (Join-Path $temp 'docProps') | Out-Null
$widths = @(28, 28, 28, 42, 42, 26, 18, 22, 18, 34, 28, 45, 20, 50, 44, 70, 58, 34, 34, 28, 28, 42, 58, 58, 24, 20, 18, 18, 18, 28)
Set-Content -LiteralPath (Join-Path $temp 'xl/worksheets/sheet1.xml') -Encoding UTF8 -Value (New-SheetXml -Headers $headers -Rows $rows.ToArray() -Widths $widths)

Set-Content -LiteralPath (Join-Path $temp '[Content_Types].xml') -Encoding UTF8 -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>'
Set-Content -LiteralPath (Join-Path $temp '_rels/.rels') -Encoding UTF8 -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>'
Set-Content -LiteralPath (Join-Path $temp 'xl/workbook.xml') -Encoding UTF8 -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Metadata item" sheetId="1" r:id="rId1"/></sheets></workbook>'
Set-Content -LiteralPath (Join-Path $temp 'xl/_rels/workbook.xml.rels') -Encoding UTF8 -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>'
Set-Content -LiteralPath (Join-Path $temp 'xl/styles.xml') -Encoding UTF8 -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="10"/><name val="Aptos"/></font><font><b/><color rgb="FFFFFFFF"/><sz val="10"/><name val="Aptos"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF8B4B35"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border><left/><right/><top/><bottom style="thin"><color rgb="FFD9D2C8"/></bottom><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/><xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>'

$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
Set-Content -LiteralPath (Join-Path $temp 'docProps/core.xml') -Encoding UTF8 -Value "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><cp:coreProperties xmlns:cp=`"http://schemas.openxmlformats.org/package/2006/metadata/core-properties`" xmlns:dc=`"http://purl.org/dc/elements/1.1/`" xmlns:dcterms=`"http://purl.org/dc/terms/`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`"><dc:title>Archivio Davide Pace metadata review</dc:title><dc:creator>Codex</dc:creator><cp:lastModifiedBy>Codex</cp:lastModifiedBy><dcterms:created xsi:type=`"dcterms:W3CDTF`">$now</dcterms:created><dcterms:modified xsi:type=`"dcterms:W3CDTF`">$now</dcterms:modified></cp:coreProperties>"
Set-Content -LiteralPath (Join-Path $temp 'docProps/app.xml') -Encoding UTF8 -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>Codex</Application><DocSecurity>0</DocSecurity><ScaleCrop>false</ScaleCrop><HeadingPairs><vt:vector size="2" baseType="variant"><vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant><vt:variant><vt:i4>1</vt:i4></vt:variant></vt:vector></HeadingPairs><TitlesOfParts><vt:vector size="1" baseType="lpstr"><vt:lpstr>Metadata item</vt:lpstr></vt:vector></TitlesOfParts></Properties>'

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
if (Test-Path -LiteralPath $outPath) { Remove-Item -LiteralPath $outPath -Force }
$zip = [System.IO.Compression.ZipFile]::Open($outPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  Get-ChildItem -LiteralPath $temp -Recurse -File | ForEach-Object {
    $entryName = $_.FullName.Substring($temp.Length + 1).Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entryName) | Out-Null
  }
} finally {
  $zip.Dispose()
}
Remove-Item -LiteralPath $temp -Recurse -Force

[pscustomobject]@{
  Output = $outPath
  Rows = $rows.Count
  AnomalyRows = ($rows | Where-Object { $_[0] -ne '' }).Count
}
