$ErrorActionPreference = 'Stop'

$path = '_exhibits/tomba-abbraccio.md'
$text = Get-Content -Raw -LiteralPath $path

$text = [regex]::Replace(
  $text,
  '(?s)\s*<a class="secondary-button" href="\{\{ ''/pace/tomba-corredo-fortunati-1979-fig-2/'' \| relative_url \}\}">Apri la scheda IIIF</a>',
  '',
  1
)

$newSection = @'
<section class="case-section statuette-focus">
  <div class="case-two-col case-two-col-top">
    <div class="case-copy-column">
      <p class="case-section-label">La statuetta dell'abbraccio</p>
      <h2>Il reperto che dà identità al nucleo</h2>
      <p>All'interno del corredo, la statuetta fittile raffigurante due figure abbracciate occupa una posizione di particolare rilievo, sia per la sua collocazione nella deposizione sia per il valore simbolico che le è stato attribuito.</p>
      <p>L'interno è cavo e il corpo risulta composto da due metà saldate tra loro, poi ritoccate con aggiunte di argilla e rifinite mediante l'uso di una stecca, strumento impiegato per modellare e definire i dettagli della superficie.</p>
      <p>Tali interventi sono particolarmente evidenti nella rifinitura delle chiome di entrambe le figure, nella resa della capigliatura e degli orecchini della figura femminile, nonché nelle ciocche della figura maschile.</p>
      <p>La statuetta della “Tomba dell'abbraccio” si inserisce nel più ampio fenomeno della produzione coroplastica lomellina, ben documentato nelle necropoli del territorio. In particolare, le statuette fittili costituiscono una classe numerosa e diffusa, spesso realizzate a stampo bivalve, con ritocchi a stecca e aggiunte di argilla. Si tratta di produzioni formalmente semplici, ma culturalmente rilevanti, nelle quali modelli iconografici di ascendenza colta vengono rielaborati in forme locali e popolari. Le due figure, raffigurate nell'atto di abbracciarsi, testimoniano il tema della coppia, richiamando valori simbolici legati alla fedeltà coniugale e all'amore, intesi come legami che perdurano oltre la dimensione terrena (Invernizzi, 2021).</p>
    </div>
    <div class="case-iiif-viewer case-statuette-archive-viewer">
      {% include osd_iiif_image_viewer.html manifest='/img/derivatives/iiif/tomba-statuetta-b06-f146-doc. 3/manifest.json' viewer_id='osd-statuetta-f146-doc. 3' %}
      <p class="case-iiif-caption">
        Fotografia della statuetta dell'abbraccio, Fondo Pace, Davide, b. 6, fasc. 146, doc. 3.
      </p>
    </div>
  </div>
</section>

<section class="case-section model-section"
'@

$text = [regex]::Replace(
  $text,
  '(?s)<section class="case-section statuette-focus">.*?</section>\s*<section class="case-section model-section"',
  $newSection,
  1
)

$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $path), $text, $encoding)

Write-Output 'Updated statuette section.'
