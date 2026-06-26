$ErrorActionPreference = 'Stop'

$path = Join-Path $PSScriptRoot '..\_exhibits\tomba-abbraccio.md'
$windows1252 = [System.Text.Encoding]::GetEncoding(1252)
$utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)

function Repair-Mojibake {
  param([string]$Text)

  $current = $Text
  for ($i = 0; $i -lt 6; $i++) {
    try {
      $bytes = $windows1252.GetBytes($current)
      $decoded = $utf8Strict.GetString($bytes)
    } catch {
      break
    }

    if ($decoded -eq $current) {
      break
    }

    $current = $decoded
  }

  return $current
}

$content = Get-Content -LiteralPath $path -Raw
$content = Repair-Mojibake -Text $content

[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $path), $content, [System.Text.UTF8Encoding]::new($false))
