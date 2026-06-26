$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$site = Join-Path $root '_site'
$base = '/davide-pace-e-la-lomellina/'
$issues = New-Object System.Collections.Generic.List[object]

function Convert-ToLocalPath {
  param([string] $Url)

  if ([string]::IsNullOrWhiteSpace($Url)) {
    return $null
  }

  $path = $Url
  if ($path -match '^https?://[^/]+/(.*)$') {
    $path = '/' + $Matches[1]
  }

  if ($path.StartsWith($base)) {
    $path = $path.Substring($base.Length)
  } elseif ($path.StartsWith('/davide-pace-e-la-lomellina/')) {
    $path = $path.Substring('/davide-pace-e-la-lomellina/'.Length)
  } elseif ($path.StartsWith('/')) {
    $path = $path.Substring(1)
  }

  return Join-Path $site ($path -replace '/', [IO.Path]::DirectorySeparatorChar)
}

function Add-Issue {
  param(
    [string] $Manifest,
    [string] $Kind,
    [string] $Url,
    [string] $Reason,
    [string] $SourceFile
  )

  $issues.Add([pscustomobject]@{
    Manifest = $Manifest
    Kind = $Kind
    Url = $Url
    Reason = $Reason
    SourceFile = $SourceFile
  }) | Out-Null
}

function Test-JpegUrl {
  param(
    [string] $Manifest,
    [string] $Kind,
    [string] $Url,
    [string] $SourceFile
  )

  $path = Convert-ToLocalPath $Url
  if (-not $path -or -not (Test-Path -LiteralPath $path)) {
    Add-Issue $Manifest $Kind $Url 'missing' $SourceFile
    return
  }

  $stream = [IO.File]::OpenRead($path)
  try {
    if ($stream.Length -lt 4) {
      Add-Issue $Manifest $Kind $Url 'too-small' $SourceFile
      return
    }

    $bytes = New-Object byte[] 2
    [void] $stream.Read($bytes, 0, 2)
    if (-not ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8)) {
      Add-Issue $Manifest $Kind $Url ('bad-header:' + [BitConverter]::ToString($bytes)) $SourceFile
    }
  } finally {
    $stream.Dispose()
  }
}

function Test-ServiceSizes {
  param(
    [string] $Manifest,
    [string] $ServiceUrl,
    [string] $SourceFile
  )

  if ([string]::IsNullOrWhiteSpace($ServiceUrl)) {
    return
  }

  $service = $ServiceUrl.TrimEnd('/')
  $infoUrl = "$service/info.json"
  $infoPath = Convert-ToLocalPath $infoUrl
  if (-not (Test-Path -LiteralPath $infoPath)) {
    Add-Issue $Manifest 'info.json' $infoUrl 'missing' $SourceFile
    return
  }

  try {
    $info = Get-Content -Raw -LiteralPath $infoPath | ConvertFrom-Json
  } catch {
    Add-Issue $Manifest 'info.json' $infoUrl 'invalid-json' $SourceFile
    return
  }

  foreach ($size in @($info.sizes)) {
    if ($null -ne $size.width) {
      Test-JpegUrl $Manifest "size-$($size.width)" "$service/full/$($size.width),/0/default.jpg" $SourceFile
    }
  }

  Test-JpegUrl $Manifest 'full-full' "$service/full/full/0/default.jpg" $SourceFile
}

$iiifRoot = Join-Path $site 'img\derivatives\iiif'
Get-ChildItem -LiteralPath $iiifRoot -Recurse -Filter manifest.json | ForEach-Object {
  $manifestPath = $_.FullName
  $manifestRel = $manifestPath.Substring($site.Length + 1)

  try {
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
  } catch {
    Add-Issue $manifestRel 'manifest' $manifestPath 'invalid-json' ''
    return
  }

  if ($manifest.thumbnail) {
    Test-JpegUrl $manifestRel 'manifest.thumbnail' ([string] $manifest.thumbnail) ''
  }
  if ($manifest.full) {
    Test-JpegUrl $manifestRel 'manifest.full' ([string] $manifest.full) ''
  }
  if ($manifest.fullwidth) {
    Test-JpegUrl $manifestRel 'manifest.fullwidth' ([string] $manifest.fullwidth) ''
  }

  foreach ($sequence in @($manifest.sequences)) {
    foreach ($canvas in @($sequence.canvases)) {
      $sourceFile = ''
      foreach ($metadata in @($canvas.metadata)) {
        if ($metadata.label -eq 'File sorgente') {
          $sourceFile = [string] $metadata.value
        }
      }

      if ($canvas.thumbnail) {
        Test-JpegUrl $manifestRel 'canvas.thumbnail' ([string] $canvas.thumbnail) $sourceFile
      }

      foreach ($image in @($canvas.images)) {
        $resource = $image.resource
        if ($resource.'@id') {
          Test-JpegUrl $manifestRel 'canvas.resource' ([string] $resource.'@id') $sourceFile
        }
        if ($resource.service -and $resource.service.'@id') {
          Test-ServiceSizes $manifestRel ([string] $resource.service.'@id') $sourceFile
        }
      }
    }
  }
}

$out = Join-Path $root 'outputs\iiif_image_issues_full.csv'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
$issues | Sort-Object Manifest, Url, Kind | Export-Csv -NoTypeInformation -Encoding UTF8 $out

Write-Output "ISSUES=$($issues.Count)"
$issues | Group-Object Reason | Sort-Object Count -Descending | ForEach-Object {
  Write-Output "$($_.Name)=$($_.Count)"
}

if ($issues.Count -gt 0) {
  $issues | Select-Object -First 80 | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
}
