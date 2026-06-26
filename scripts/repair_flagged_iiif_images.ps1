$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$issuesPath = Join-Path $root 'outputs\iiif_image_issues_full.csv'
$imagesRoot = Join-Path $root 'img\derivatives\iiif\images'

if (-not (Test-Path -LiteralPath $issuesPath)) {
  throw "Issue CSV not found: $issuesPath"
}

function Test-ValidJpeg {
  param([string] $Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return $false
  }

  $stream = [IO.File]::OpenRead($Path)
  try {
    if ($stream.Length -lt 4) {
      return $false
    }
    $bytes = New-Object byte[] 2
    [void] $stream.Read($bytes, 0, 2)
    return ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8)
  } finally {
    $stream.Dispose()
  }
}

function Get-ImageIdFromUrl {
  param([string] $Url)

  if ($Url -match '/img/derivatives/iiif/images/([^/]+)/') {
    return $Matches[1]
  }
  return $null
}

function Get-WidthFromIssue {
  param($Issue)

  if ($Issue.Kind -match '^size-(\d+)$') {
    return [int] $Matches[1]
  }
  if ($Issue.Url -match '/full/(\d+),/0/default\.jpg') {
    return [int] $Matches[1]
  }
  return $null
}

function Find-AssetSource {
  param([string] $FileName)

  if ([string]::IsNullOrWhiteSpace($FileName)) {
    return $null
  }

  $key = $FileName.ToLowerInvariant()
  if ($assetByName.ContainsKey($key)) {
    return $assetByName[$key]
  }

  return $null
}

function Convert-JsonWithoutFrontMatter {
  param([string] $Path)

  $raw = Get-Content -Raw -LiteralPath $Path
  if ($raw.StartsWith("---")) {
    $parts = $raw -split "(?m)^---\s*$", 3
    if ($parts.Count -ge 3) {
      $raw = $parts[2]
    }
  }
  return $raw | ConvertFrom-Json
}

$assetByName = @{}
Get-ChildItem -LiteralPath (Join-Path $root 'assets\images') -Recurse -File | ForEach-Object {
  $assetByName[$_.Name.ToLowerInvariant()] = $_.FullName
}

$fallbackSources = @{
  'carta-repetto-gropello' = Join-Path $root 'assets\images\territorio\carta-repetto-gropello.png'
  'davide-pace-b01-f004-avventura-gropello-doc. 1' = Join-Path $root 'assets\images\davide-pace\b01-f004\FDP_B01_F004_UD001_ME_R.jpg'
  'davide-pace-contesto-alpino-scat12-f255-ud001-recto' = Join-Path $root 'assets\images\davide-pace\valtellina\FDP_SCAT12_F255_UD001_ME.JPG'
}

$issues = Import-Csv -LiteralPath $issuesPath
$byImage = @{}
foreach ($issue in $issues) {
  $imageId = Get-ImageIdFromUrl $issue.Url
  if (-not $imageId) {
    continue
  }
  if (-not $byImage.ContainsKey($imageId)) {
    $byImage[$imageId] = New-Object System.Collections.Generic.List[object]
  }
  $byImage[$imageId].Add($issue)
}

$repaired = New-Object System.Collections.Generic.List[object]
$skipped = New-Object System.Collections.Generic.List[object]

foreach ($imageId in ($byImage.Keys | Sort-Object)) {
  $imageDir = Join-Path $imagesRoot $imageId
  $fullImage = Join-Path $imageDir 'full\full\0\default.jpg'
  $source = $null

  if (Test-ValidJpeg $fullImage) {
    $source = $fullImage
  }

  if (-not $source) {
    $sourceFile = ($byImage[$imageId] | Where-Object { -not [string]::IsNullOrWhiteSpace($_.SourceFile) } | Select-Object -First 1 -ExpandProperty SourceFile)
    $source = Find-AssetSource $sourceFile
  }

  if (-not $source -and $fallbackSources.ContainsKey($imageId)) {
    $source = $fallbackSources[$imageId]
  }

  if (-not $source -or -not (Test-Path -LiteralPath $source)) {
    $skipped.Add([pscustomobject]@{ ImageId = $imageId; Reason = 'source-not-found' }) | Out-Null
    continue
  }

  New-Item -ItemType Directory -Force -Path (Join-Path $imageDir 'full\full\0') | Out-Null

  $dimensions = & magick identify -format '%w %h' $source
  if ($LASTEXITCODE -ne 0) {
    $skipped.Add([pscustomobject]@{ ImageId = $imageId; Reason = 'identify-failed' }) | Out-Null
    continue
  }
  $parts = $dimensions -split ' '
  $sourceWidth = [int] $parts[0]

  if (-not (Test-ValidJpeg $fullImage)) {
    & magick $source -auto-orient -strip -quality 92 $fullImage
    if ($LASTEXITCODE -ne 0) {
      $skipped.Add([pscustomobject]@{ ImageId = $imageId; Reason = 'full-generate-failed' }) | Out-Null
      continue
    }
  }

  $widths = New-Object System.Collections.Generic.HashSet[int]
  [void] $widths.Add(250)
  [void] $widths.Add(1140)
  [void] $widths.Add($sourceWidth)

  $infoPath = Join-Path $imageDir 'info.json'
  if (Test-Path -LiteralPath $infoPath) {
    try {
      $info = Convert-JsonWithoutFrontMatter $infoPath
      foreach ($size in @($info.sizes)) {
        if ($null -ne $size.width) {
          [void] $widths.Add([int] $size.width)
        }
      }
    } catch {
      # The manifest check already reports invalid info JSON; image cuts can still be repaired.
    }
  }

  foreach ($issue in $byImage[$imageId]) {
    $issueWidth = Get-WidthFromIssue $issue
    if ($null -ne $issueWidth) {
      [void] $widths.Add($issueWidth)
    }
  }

  foreach ($width in ($widths | Sort-Object)) {
    if ($width -le 0) {
      continue
    }
    $targetDir = Join-Path $imageDir "full\$width,\0"
    $target = Join-Path $targetDir 'default.jpg'
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    & magick $source -auto-orient -strip -resize "${width}x" -quality 90 $target
    if ($LASTEXITCODE -ne 0) {
      $skipped.Add([pscustomobject]@{ ImageId = $imageId; Reason = "resize-$width-failed" }) | Out-Null
    }
  }

  $repaired.Add([pscustomobject]@{ ImageId = $imageId; Source = $source }) | Out-Null
}

Write-Output "REPAIRED=$($repaired.Count)"
Write-Output "SKIPPED=$($skipped.Count)"
if ($skipped.Count -gt 0) {
  $skipped | Format-Table -AutoSize | Out-String -Width 180 | Write-Output
}
