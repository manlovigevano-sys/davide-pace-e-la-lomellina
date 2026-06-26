require 'date'
require 'json'
require 'yaml'

FIELDS = %w[
  pid original_pid label summary object_type media_type creator display_date place repository reference
  extent subjects subject_vocabularies description rights license current_location exhibit_section exhibit_url
  order layout collection thumbnail full manifest canonical_item hide_from_collection search_exclude published
].freeze

PID_OVERRIDES = {
  'davide-pace-b01-f004-avventura-gropello' => 'davide-pace-b01-f004',
  'davide-pace-contesto-alpino-scat12-f255-ud001' => 'davide-pace-scat12-f255-ud001',
  'davide-pace-dosso-marone-tutela' => 'davide-pace-scat10-f227-f228',
  'davide-pace-passerini-scat12-4-fasc286-doc17-19' => 'davide-pace-scat12-4-f286-doc17-19',
  'davide-pace-santo-spirito-scavi-f266' => 'davide-pace-scat12-2-f266',
  'davide-pace-sul-campo-indagine-1965' => 'davide-pace-scat12-f256-ud001',
  'davide-pace-sul-campo-lanfranchi-tomba3' => 'davide-pace-b04-f106-ud009',
  'davide-pace-sul-campo-passerini-fornace-f246' => 'davide-pace-scat11-f246-ud003',
  'davide-pace-sul-campo-santo-spirito-1965' => 'davide-pace-scat08-f204-ud013',
  'nucleo2-embrice-carteggio-b02-f035' => 'davide-pace-b02-f035-doc09-10',
  'nucleo2-embrice-fasc192-fotografie' => 'davide-pace-scat08-f192-doc01-02',
  'nucleo2-embrice-rinvenimento-b02-f035' => 'davide-pace-b02-f035-ud001-004',
  'nucleo2-ispettorato-b01-f002-doc1-2' => 'davide-pace-b01-f002-doc01-02',
  'nucleo3-foto-scavo-b5-f140-positive' => 'davide-pace-b05-f140-fotografie-positive',
  'nucleo3-giornale-scavo-b5-f139' => 'davide-pace-b05-f139',
  'nucleo3-manoscritti-b5-f140' => 'davide-pace-b05-f140-manoscritti',
  'tomba-balsamario-archivio-b06-f146-ud002' => 'davide-pace-b06-f146-ud002',
  'tomba-fascicolo-corredo-b06-f146' => 'davide-pace-b06-f146',
  'tomba-relazione-pace-b06-f145' => 'davide-pace-b06-f145',
  'tomba-relazione-pace-b06-f148' => 'davide-pace-b06-f148',
  'tomba-schizzo-deposizione-b06-f145-ud005' => 'davide-pace-b06-f145-ud005',
  'tomba-scoperta-b06-f145-ud001' => 'davide-pace-b06-f145-ud001',
  'tomba-statuetta-b06-f146-ud003' => 'davide-pace-b06-f146-ud003',
  'tomba-vetrina-antiquarium-scat07-fasc186-ud001' => 'tomba-vetrina-antiquarium-scat07-fasc186-ud001',
  'tomba-vetrina-antiquarium-scat07-fasc189-ud001' => 'tomba-vetrina-antiquarium-scat07-fasc189-ud001',
  'tomba-vetrina-antiquarium-scat07-fasc189-ud002' => 'tomba-vetrina-antiquarium-scat07-fasc189-ud002'
}.freeze

KEYS = {
  'PID' => 'pid',
  'PID precedente' => 'original_pid',
  'Titolo' => 'label',
  'Sintesi' => 'summary',
  'Tipologia' => 'object_type',
  'Tipologia archivistica/documentaria' => 'object_type',
  'Tipo di contenuto digitale' => 'media_type',
  'Creatore' => 'creator',
  'Data' => 'display_date',
  'Luogo' => 'place',
  'Archivio / istituto' => 'repository',
  'Repository' => 'repository',
  'Riferimento' => 'reference',
  'Segnatura archivistica' => 'reference',
  'Consistenza' => 'extent',
  'Consistenza digitale' => 'extent',
  'Soggetti' => 'subjects',
  'Soggettario / thesaurus' => 'subject_vocabularies',
  'Descrizione' => 'description',
  'Diritti' => 'rights',
  'Licenza' => 'license',
  'Collocazione attuale' => 'current_location',
  'Sezione mostra' => 'exhibit_section',
  'Rimando alla sezione' => 'exhibit_url'
}.freeze

def read_doc(path)
  front = File.read(path, encoding: 'UTF-8')[/\A---\s*\n(.*?)\n---/m, 1] || ''
  YAML.safe_load(front, permitted_classes: [Date], aliases: true) || {}
end

def write_doc(path, data)
  ordered = {}
  FIELDS.each { |field| ordered[field] = data[field] if data.key?(field) && !data[field].nil? && data[field].to_s.strip != '' }
  (data.keys - ordered.keys).sort.each { |field| ordered[field] = data[field] if !data[field].nil? && data[field].to_s.strip != '' }
  yaml = YAML.dump(ordered, line_width: -1).sub(/\A---\n/, "---\n")
  File.write(path, "#{yaml}---\n", encoding: 'UTF-8')
end

def manifest_doc(path)
  raw = File.read(path, encoding: 'UTF-8')
  raw = raw.sub(/\A\uFEFF/, '').sub(/\A---\s*\n.*?\n---\s*\n/m, '')
  JSON.parse(raw)
end

def local_path(value)
  text = value.to_s
  return text if text.start_with?('/')

  match = text.match(%r{['"](/[^'"]+)['"]\s*\|\s*(?:absolute_url|relative_url)})
  match ? match[1] : text
end

def add_subject(data, subject)
  subjects = data['subjects'].to_s.split(';').map(&:strip).reject(&:empty?)
  subjects << subject unless subjects.include?(subject)
  data['subjects'] = subjects.join('; ')
end

changed = 0
Dir['_pace/*.md'].sort.each do |path|
  slug = File.basename(path, '.md')
  data = read_doc(path)
  label_is_slug = data['label'].to_s == slug.tr('-', ' ')
  reference_empty = data['reference'].to_s =~ /Archivio Davide Pace,\s*\z/
  manifest_missing = data['manifest'].to_s.strip.empty?
  next unless label_is_slug || reference_empty || manifest_missing

  manifest_slug = PID_OVERRIDES[slug] || data['pid'].to_s
  manifest_path = "img/derivatives/iiif/#{manifest_slug}/manifest.json"
  next unless File.exist?(manifest_path)

  doc = manifest_doc(manifest_path)
  restored = data.dup
  restored['manifest'] = "/#{manifest_path}"
  restored['thumbnail'] = local_path(doc['thumbnail'])
  restored['full'] = local_path(doc['full'] || doc.dig('sequences', 0, 'canvases', 0, 'images', 0, 'resource', '@id'))
  restored['full'] = local_path(doc['fullwidth']) if restored['full'].to_s.empty? || restored['full'].include?('/full/full/')

  (doc['metadata'] || []).each do |entry|
    key = KEYS[entry['label'].to_s]
    next unless key

    restored[key] = entry['value'].to_s.strip
  end
  restored['pid'] = manifest_slug if restored['pid'].to_s.strip.empty? || label_is_slug
  restored['original_pid'] = slug
  restored['layout'] = 'pace_iiif_item'
  restored['collection'] = 'pace'
  restored['media_type'] = 'image' if restored['media_type'].to_s.strip.empty?
  add_subject(restored, 'Davide Pace') if [restored['label'], restored['summary'], restored['description']].join(' ') =~ /Davide Pace/i
  add_subject(restored, 'Francesco Pace') if [restored['label'], restored['summary'], restored['description']].join(' ') =~ /Francesco Pace/i
  add_subject(restored, 'Luciano Milanesi') if [restored['label'], restored['summary'], restored['description']].join(' ') =~ /Luciano Milanesi/i

  write_doc(path, restored)
  changed += 1
end

puts "Rebuilt pace records from manifests: #{changed}"
