require 'date'
require 'json'
require 'yaml'

LICENSE_URL = 'https://creativecommons.org/licenses/by-nc/4.0/'
RIGHTS_TEXT = "&copy; Direzione regionale Musei Nazionali Lombardia - Museo Archeologico Nazionale della Lomellina; CC BY-NC 4.0 #{LICENSE_URL}"
CURRENT_LOCATION = 'Museo Archeologico Nazionale della Lomellina'
EXHIBIT_SECTION = 'Dal territorio al museo'

FIELDS = %w[
  pid label summary object_type creator display_date place repository reference extent
  subjects description rights license current_location exhibit_section
  order layout collection thumbnail full manifest
].freeze

PID_OVERRIDES = {
  'carta-repetto-gropello' => 'repetto-1980-carta-gropello-cairoli',
  'davide-pace-b01-f004-avventura-gropello' => 'davide-pace-b01-f004',
  'davide-pace-contesto-alpino-scat12-f255-ud001' => 'davide-pace-scat12-f255-ud001',
  'davide-pace-dosso-marone-tutela' => 'davide-pace-scat10-f227-f228',
  'davide-pace-passerini-scat12-4-fasc286-doc17-19' => 'davide-pace-scat12-4-f286-doc17-19',
  'davide-pace-rete-documentazione-santo-spirito-doc11' => 'davide-pace-scat08-f202-doc11',
  'davide-pace-rete-documentazione-santo-spirito-doc9' => 'davide-pace-scat08-f205-doc09',
  'davide-pace-santo-spirito-scavi-f266' => 'davide-pace-scat12-2-f266',
  'davide-pace-sul-campo-indagine-1965' => 'davide-pace-scat12-f256-ud001',
  'davide-pace-sul-campo-lanfranchi-tomba3' => 'davide-pace-b04-f106-ud009',
  'davide-pace-sul-campo-passerini-fornace-f246' => 'davide-pace-scat11-f246-ud003',
  'davide-pace-sul-campo-santo-spirito-1965' => 'davide-pace-scat08-f204-ud013',
  'nucleo2-antona-b03-f067' => 'davide-pace-b03-f067',
  'nucleo2-antona-b04-f104' => 'davide-pace-b04-f104',
  'nucleo2-antona-b05-f123' => 'davide-pace-b05-f123',
  'nucleo2-embrice-carteggio-b02-f035' => 'davide-pace-b02-f035-doc09-10',
  'nucleo2-embrice-fasc192-fotografie' => 'davide-pace-scat08-f192-doc01-02',
  'nucleo2-embrice-reperto-13418' => 'manlo-n-inv-13418',
  'nucleo2-embrice-reperto-13418-dettaglio' => 'manlo-n-inv-13418-dettaglio',
  'nucleo2-embrice-rinvenimento-b02-f035' => 'davide-pace-b02-f035-ud001-004',
  'nucleo2-ispettorato-b01-f002-doc1-2' => 'davide-pace-b01-f002-doc01-02',
  'nucleo2-ispettorato-b01-f002-doc3' => 'davide-pace-b01-f002-doc03',
  'nucleo3-foto-scavo-b5-f140-positive' => 'davide-pace-b05-f140-fotografie-positive',
  'nucleo3-giornale-scavo-b5-f139' => 'davide-pace-b05-f139',
  'nucleo3-manoscritti-b5-f140' => 'davide-pace-b05-f140-manoscritti',
  'nucleo3-negativi-positivi-b5-f140' => 'davide-pace-b05-f140-negativi-positivi',
  'tomba-archivio-01' => 'davide-pace-b06-f145-archivio-01',
  'tomba-archivio-02' => 'davide-pace-b06-f145-archivio-02',
  'tomba-balsamario-13305' => 'manlo-n-inv-13305',
  'tomba-balsamario-archivio-b06-f146-ud002' => 'davide-pace-b06-f146-ud002',
  'tomba-coppa-13303' => 'manlo-n-inv-13303',
  'tomba-coppa-13311' => 'manlo-n-inv-13311',
  'tomba-corredo-fortunati-1979-fig-2' => 'fortunati-1979-fig02',
  'tomba-dettaglio-01' => 'davide-pace-b06-f145-dettaglio-01',
  'tomba-dettaglio-02' => 'davide-pace-b06-f145-dettaglio-02',
  'tomba-documentazione-attuale' => 'manlo-tomba-abbraccio-documentazione-attuale',
  'tomba-fascicolo-corredo-b06-f146' => 'davide-pace-b06-f146',
  'tomba-foto-storica-01' => 'davide-pace-b06-f145-foto-01',
  'tomba-foto-storica-02' => 'davide-pace-b06-f145-foto-02',
  'tomba-hero' => 'tomba-abbraccio-hero',
  'tomba-lucerna-13313' => 'manlo-n-inv-13313',
  'tomba-manoscritto-01' => 'davide-pace-b06-f145-manoscritto-01',
  'tomba-manoscritto-02' => 'davide-pace-b06-f145-manoscritto-02',
  'tomba-olpe-13300' => 'manlo-n-inv-13300',
  'tomba-olpe-13308' => 'manlo-n-inv-13308',
  'tomba-patera-15685' => 'manlo-n-inv-15685',
  'tomba-relazione-pace-b06-f145' => 'davide-pace-b06-f145',
  'tomba-relazione-pace-b06-f148' => 'davide-pace-b06-f148',
  'tomba-render-3d' => 'manlo-n-inv-6884-render-3d',
  'tomba-schizzo-deposizione-b06-f145-ud005' => 'davide-pace-b06-f145-ud005',
  'tomba-scoperta-b06-f145-ud001' => 'davide-pace-b06-f145-ud001',
  'tomba-specchio-13312' => 'manlo-n-inv-13312',
  'tomba-statuetta-6884' => 'manlo-n-inv-6884',
  'tomba-statuetta-b06-f146-ud003' => 'davide-pace-b06-f146-ud003',
  'tomba-statuetta-full' => 'manlo-n-inv-6884-documentazione',
  'tomba-unguentario-13304' => 'manlo-n-inv-13304',
  'tomba-vetrina-antiquarium-scat07-fasc186-ud001' => 'davide-pace-scat07-f186-doc01',
  'tomba-vetrina-antiquarium-scat07-fasc189-ud001' => 'davide-pace-scat07-f189-doc01',
  'tomba-vetrina-antiquarium-scat07-fasc189-ud002' => 'davide-pace-scat07-f189-doc02'
}.freeze

def yaml_front_matter(path)
  text = File.read(path, encoding: 'UTF-8')
  front = text[/\A---\s*\n(.*?)\n---/m, 1] || ''
  body = text.sub(/\A---\s*\n.*?\n---\s*\n/m, '')
  data = YAML.safe_load(front, permitted_classes: [Date], aliases: true) || {}
  [data, body]
end

def clean(value)
  value.to_s.strip
end

def first_present(*values)
  values.map { |value| clean(value) }.find { |value| !value.empty? }
end

def repair_text(value)
  clean(value)
    .gsub("\u00C3\u0192\u00C2", 'à')
    .gsub("\u00C3\u00A0", 'à')
    .gsub("\u00C3\u00A8", 'è')
    .gsub("\u00C3\u00A9", 'é')
    .gsub("\u00C3\u00B2", 'ò')
    .gsub("\u00C3\u00B9", 'ù')
    .gsub("\u00C3\u00AC", 'ì')
end

def normalize_inventory(value)
  repair_text(value)
    .gsub(/\bn\.\s*inv\.\s*(?:St\.|n\.\s*inv\.)\s*(\d+)/i, 'n. inv. \1')
    .gsub(/\b(?:St\.|n\.\s*inv\.)\s*(\d+)/i, 'n. inv. \1')
end

def date_for(data)
  base = "#{data['label']} #{data['description']} #{data['reference']} #{data['_date']}"
  return clean(data['_date']) unless clean(data['_date']).empty?
  return '13 giugno 1957; 22 ottobre 1955' if data['pid'] == 'nucleo2-ispettorato-b01-f002-doc1-2'
  return '1955-1957' if data['pid'] == 'nucleo2-ispettorato-b01-f002-doc3'
  return '1955-1958' if data['pid'] == 'davide-pace-b01-f004-avventura-gropello'
  return '27 marzo 1959' if base =~ /Passerini|fornace/i
  return '1960 (?)' if data['pid'] == 'davide-pace-santo-spirito-scavi-f266'
  return 'novembre 1964' if data['pid'] == 'davide-pace-rete-documentazione-santo-spirito-doc11'
  return 'aprile 1965' if data['pid'] == 'davide-pace-rete-documentazione-santo-spirito-doc9'
  return 'aprile 1965' if data['pid'] == 'davide-pace-sul-campo-santo-spirito-1965'
  return '12 novembre 1965' if data['pid'] == 'davide-pace-sul-campo-indagine-1965'
  return 'agosto 1964' if data['pid'] == 'davide-pace-contesto-alpino-scat12-f255-ud001'
  return '1980' if data['pid'] == 'carta-repetto-gropello'
  return '1979' if data['pid'] == 'tomba-corredo-fortunati-1979-fig-2'
  return '1955' if base =~ /10 dicembre 1955|Tomba dell'abbraccio|vigna Garaldi|Frascate/i
  's.d.'
end

def place_for(data)
  text = "#{data['label']} #{data['description']} #{data['reference']}"
  return 'Gropello Cairoli, località Frascate, vigna Garaldi' if text =~ /Frascate|vigna Garaldi|Tomba dell'abbraccio|corredo|(?:St\.|n\.\s*inv\.)\s*(6884|133|15685)/i
  return 'Gropello Cairoli, podere Passerini' if text =~ /Passerini/i
  return 'Gropello Cairoli, promontorio di Santo Spirito' if text =~ /Santo Spirito/i
  return 'Gropello Cairoli, Dosso del Marone' if text =~ /Marone/i
  return 'Gropello Cairoli, dosso Lanfranchi' if text =~ /Lanfranchi/i
  return 'Gropello Cairoli' if text =~ /Gropello|Antona|embrice|Ispettorato|Squadra Volante/i
  return 'contesto alpino non identificato' if data['pid'] == 'davide-pace-contesto-alpino-scat12-f255-ud001'
  'località non identificata'
end

def creator_for(data)
  text = "#{data['pid']} #{data['label']} #{data['description']} #{data['repository']}"
  return 'Arnaldo Repetto' if data['pid'] == 'carta-repetto-gropello'
  return 'M. Fortunati' if text =~ /Fortunati/i
  return 'Davide Pace' if text =~ /Archivio Davide Pace|Pace|Fondo Pace|fotografia d'archivio|documentazione fotografica/i
  return 'Museo Archeologico Nazionale della Lomellina' if text =~ /Museo Archeologico Nazionale della Lomellina/i
  'non identificato'
end

def extent_for(data)
  manifest = clean(data['manifest']).sub(%r{\A/}, '')
  return '1 risorsa digitale' unless File.exist?(manifest)

  raw = File.read(manifest, encoding: 'UTF-8').sub(/\A---\s*\n.*?\n---\s*\n/m, '')
  json = JSON.parse(raw)
  canvases = json.dig('sequences', 0, 'canvases') || []
  count = canvases.length
  return '1 immagine digitale' if count == 1
  "#{count} immagini digitali"
rescue JSON::ParserError
  '1 risorsa digitale'
end

def subjects_for(data)
  text = "#{data['pid']} #{data['label']} #{data['object_type']} #{data['description']} #{data['reference']}"
  subjects = []

  subjects << 'Gropello Cairoli' if text =~ /Gropello|Antona|embrice|Ispettorato|Frascate|Santo Spirito|Marone|Lanfranchi|Passerini/i
  subjects << 'località Frascate' if text =~ /Frascate|vigna Garaldi|Tomba dell'abbraccio|(?:St\.|n\.\s*inv\.)\s*(6884|133|15685)/i
  subjects << 'Santo Spirito' if text =~ /Santo Spirito/i
  subjects << 'Dosso del Marone' if text =~ /Marone/i
  subjects << 'podere Passerini' if text =~ /Passerini/i
  subjects << 'dosso Lanfranchi' if text =~ /Lanfranchi/i
  subjects << 'scavi archeologici' if text =~ /scav|indagin|saggio|stratigraf|necropoli|rinvenimento/i
  subjects << 'tutela archeologica' if text =~ /tutela|Ispettorato|Soprintendenza|Squadra Volante|avviso|regolamento/i
  subjects << 'documentazione fotografica' if text =~ /fotograf|stampa|diapositiv|negativ|positivo|immagine/i
  subjects << 'documentazione archivistica' if text =~ /relazione|manoscritt|appunti|carteggio|fascicolo|documentazione d'archivio|circolare|avviso|regolamento/i
  subjects << 'cartografia archeologica' if text =~ /carta archeologica|Repetto/i
  subjects << 'necropoli' if text =~ /necropoli|Tomba dell'abbraccio|tomba/i
  subjects << 'corredo funerario' if text =~ /corredo|statuetta|balsamario|lucerna|olpe|patera|specchio|unguentario/i
  subjects << 'reperti archeologici' if text =~ /reperto|fittile|ceramica|bronzo|vetro|embrice|iscrizione|lucerna|olpe|patera|specchio|unguentario/i
  subjects << 'iscrizioni' if text =~ /iscrizion|iscritto/i
  subjects << 'fornaci romane' if text =~ /fornace/i
  subjects << 'allestimenti museali' if text =~ /vetrina|Antiquarium|esposto|museo/i
  subjects << 'rilievi e schizzi archeologici' if text =~ /schizzo|disegno|carta/i
  subjects << 'fotogrammetria e modelli 3D' if text =~ /render|modello 3D|digitale/i

  subjects.uniq.join('; ')
end

def normalize_value(value)
  return nil if value.nil?
  value.to_s
end

def write_yaml(path, data, body)
  ordered = {}
  FIELDS.each { |key| ordered[key] = normalize_value(data[key]) if data.key?(key) }
  (data.keys - ordered.keys - ['_date']).sort.each { |key| ordered[key] = normalize_value(data[key]) }
  yaml = YAML.dump(ordered, line_width: -1).sub(/\A---\n/, "---\n")
  File.write(path, "#{yaml}---\n#{body}", encoding: 'UTF-8')
end

Dir['_pace/*.md'].sort.each do |path|
  data, body = yaml_front_matter(path)
  data['original_pid'] = data['pid'] unless data['original_pid']
  data['pid'] = PID_OVERRIDES.fetch(data['original_pid'], data['pid'])
  %w[label summary reference description].each do |key|
    data[key] = normalize_inventory(data[key]) if data.key?(key)
  end
  data['summary'] = first_present(data['summary'], data['description'], data['label'])
  data['creator'] = first_present(data['creator'], creator_for(data))
  data['display_date'] = first_present(data['display_date'], data['date'], data['_date'], date_for(data))
  data.delete('date')
  data['_date'] = data['display_date']
  data['place'] = first_present(data['place'], place_for(data))
  data['reference'] = first_present(data['reference'], 'non identificato')
  data['extent'] = first_present(data['extent'], extent_for(data))
  data['subjects'] = first_present(data['subjects'], subjects_for(data))
  data['rights'] = RIGHTS_TEXT
  data['license'] = LICENSE_URL
  data['current_location'] = CURRENT_LOCATION
  data['exhibit_section'] = EXHIBIT_SECTION
  write_yaml(path, data, body)
end

def metadata_entry(label, value)
  return nil if clean(value).empty?
  { 'label' => label, 'value' => value }
end

Dir['img/derivatives/iiif/*/manifest.json'].sort.each do |path|
  raw = File.read(path, encoding: 'UTF-8')
  prefix = raw[/\A---\s*\n.*?\n---\s*\n/m] || ''
  json_text = raw.sub(/\A---\s*\n.*?\n---\s*\n/m, '')
  manifest = JSON.parse(json_text)
  pid = File.basename(File.dirname(path))
  md_path = "_pace/#{pid}.md"
  next unless File.exist?(md_path)

  data, = yaml_front_matter(md_path)
  manifest['metadata'] = [
    metadata_entry('PID', data['pid']),
    metadata_entry('PID precedente', data['original_pid']),
    metadata_entry('Titolo', data['label']),
    metadata_entry('Tipologia', data['object_type']),
    metadata_entry('Creatore', data['creator']),
    metadata_entry('Data', data['display_date']),
    metadata_entry('Luogo', data['place']),
    metadata_entry('Archivio / istituto', data['repository']),
    metadata_entry('Riferimento', data['reference']),
    metadata_entry('Consistenza', data['extent']),
    metadata_entry('Soggetti', data['subjects']),
    metadata_entry('Descrizione', data['description']),
    metadata_entry('Diritti', data['rights']),
    metadata_entry('Licenza', data['license']),
    metadata_entry('Collocazione attuale', data['current_location']),
    metadata_entry('Sezione mostra', data['exhibit_section'])
  ].compact

  json = JSON.pretty_generate(manifest)
  File.write(path, "#{prefix}#{json}\n", encoding: 'UTF-8')
end

puts 'Normalized _pace front matter and IIIF manifest metadata.'
