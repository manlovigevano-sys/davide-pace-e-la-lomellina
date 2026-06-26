$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '.local-server-root'
$prefix = 'http://127.0.0.1:4000/'

if (-not (Test-Path -LiteralPath $root)) {
  throw "Cartella pubblicata non trovata: $root"
}

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Parse('127.0.0.1'), 4000)
$listener.Start()
Write-Host "Serving $root at $prefix"

$contentTypes = @{
  '.html' = 'text/html; charset=utf-8'
  '.htm'  = 'text/html; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.js'   = 'application/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.jpg'  = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.png'  = 'image/png'
  '.gif'  = 'image/gif'
  '.svg'  = 'image/svg+xml'
  '.webp' = 'image/webp'
  '.ico'  = 'image/x-icon'
  '.woff' = 'font/woff'
  '.woff2'= 'font/woff2'
  '.ttf'  = 'font/ttf'
}

try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
      $requestLine = $reader.ReadLine()
      if ([string]::IsNullOrWhiteSpace($requestLine)) {
        continue
      }

      while (-not [string]::IsNullOrEmpty($reader.ReadLine())) {}

      $parts = $requestLine.Split(' ')
      $urlPath = if ($parts.Length -ge 2) { $parts[1].Split('?')[0] } else { '/' }
      $requestPath = [Uri]::UnescapeDataString($urlPath.TrimStart('/'))
      $requestPath = $requestPath -replace '/', [IO.Path]::DirectorySeparatorChar

      $target = Join-Path $root $requestPath
      if (Test-Path -LiteralPath $target -PathType Container) {
        $target = Join-Path $target 'index.html'
      }

      if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        $bytes = [Text.Encoding]::UTF8.GetBytes('404 - Not found')
        $header = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
        $headerBytes = [Text.Encoding]::ASCII.GetBytes($header)
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        $stream.Write($bytes, 0, $bytes.Length)
        continue
      }

      $resolvedRoot = [IO.Path]::GetFullPath($root)
      $resolvedTarget = [IO.Path]::GetFullPath($target)
      if (-not $resolvedTarget.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        $bytes = [Text.Encoding]::UTF8.GetBytes('403 - Forbidden')
        $header = "HTTP/1.1 403 Forbidden`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
        $headerBytes = [Text.Encoding]::ASCII.GetBytes($header)
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        $stream.Write($bytes, 0, $bytes.Length)
        continue
      }

      $extension = [IO.Path]::GetExtension($target).ToLowerInvariant()
      if ($contentTypes.ContainsKey($extension)) {
        $contentType = $contentTypes[$extension]
      } else {
        $contentType = 'application/octet-stream'
      }

      $bytes = [IO.File]::ReadAllBytes($target)
      $header = "HTTP/1.1 200 OK`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
      $headerBytes = [Text.Encoding]::ASCII.GetBytes($header)
      $stream.Write($headerBytes, 0, $headerBytes.Length)
      $stream.Write($bytes, 0, $bytes.Length)
    } catch {
      Write-Warning $_.Exception.Message
    } finally {
      $client.Close()
    }
      continue
  }
} finally {
  $listener.Stop()
}
