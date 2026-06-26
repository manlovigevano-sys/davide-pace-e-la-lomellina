require 'date'
require 'json'
require 'yaml'

RIGHTS_TEXT = '© Direzione regionale Musei Nazionali Lombardia - Museo Archeologico Nazionale della Lomellina; CC BY-NC 4.0 https://creativecommons.org/licenses/by-nc/4.0/'
LICENSE_URL = 'https://creativecommons.org/licenses/by-nc/4.0/'
REPOSITORY = 'Archivio Davide Pace'
CURRENT_LOCATION = 'Museo Archeologico Nazionale della Lomellina'
VOCABULARIES = 'Nuovo soggettario BNCF; Getty Art & Architecture Thesaurus (AAT); ICCD - normative e vocabolari catalografici'

FIELDS = %w[
  pid original_pid label summary object_type media_type creator display_date place repository reference
  extent subjects subject_vocabularies description rights license current_location exhibit_section exhibit_url
  order layout collection thumbnail full manifest canonical_item hide_from_collection search_exclude published
].freeze

EXHIBITS = {
  tomba: ['La tomba dell\'abbraccio', '/exhibits/tomba-abbraccio/'],
  comunita: ['Comunità locale e tutela', '/exhibits/comunita-locale/'],
  invisibile: ['Documentare l\'invisibile', '/exhibits/documentare-invisibile/'],
  davide: ['Davide Pace', '/pages/davide-pace/'],
  territorio: ['Dal territorio al museo', '/pages/territorio-museo/']
}.freeze

PID_OVERRIDES = {
  'tomba-dettaglio-01' => 'davide-pace-b06-f145-dettaglio-01',
  'tomba-dettaglio-02' => 'davide-pace-b06-f145-dettaglio-02',
  'tomba-documentazione-attuale' => 'manlo-tomba-abbraccio-documentazione-attuale',
  'tomba-statuetta-full' => 'manlo-n-inv-6884-documentazione'
}.freeze

DETAIL_DEFAULTS = {
  'tomba-dettaglio-01' => {
    'label' => 'Dettaglio della statuetta dell\'abbraccio',
    'summary' => 'Ripresa di dettaglio della statuetta fittile con due figure abbracciate.',
    'description' => 'Ripresa digitale di dettaglio della statuetta fittile proveniente dalla Tomba dell\'abbraccio, utile alla lettura dei particolari morfologici e dello stato di conservazione del reperto.',
    'order' => '04'
  },
  'tomba-dettaglio-02' => {
    'label' => 'Dettaglio dei volti della statuetta',
    'summary' => 'Ripresa di dettaglio dei volti delle figure abbracciate.',
    'description' => 'Ripresa digitale ravvicinata dei volti della statuetta fittile con due figure abbracciate, collegata alla documentazione del corredo della Tomba dell\'abbraccio.',
    'order' => '05'
  },
  'tomba-documentazione-attuale' => {
    'label' => 'Documentazione attuale della statuetta',
    'summary' => 'Ripresa attuale della statuetta fittile della Tomba dell\'abbraccio.',
    'description' => 'Documentazione digitale attuale della statuetta fittile con due figure abbracciate, realizzata per collegare il reperto conservato in museo alla documentazione archivistica del Fondo Pace.',
    'order' => '09'
  },
  'tomba-statuetta-full' => {
    'label' => 'Statuetta fittile con due figure abbracciate',
    'summary' => 'Documentazione digitale della statuetta che dà nome al nucleo della Tomba dell\'abbraccio.',
    'description' => 'Riproduzione digitale della statuetta fittile con due figure abbracciate, presentata come reperto chiave per la ricostruzione del contesto funerario della Tomba dell\'abbraccio.',
    'order' => '03'
  }
}.freeze

def repair_mojibake(text)
  current = text.dup
  markers = [0x00c3, 0x00c2, 0x00e2]
  3.times do
    break unless current.each_codepoint.any? { |cp| markers.include?(cp) }

    repaired = current.encode('Windows-1252').force_encoding('UTF-8')
    break unless repaired.valid_encoding?
    break if repaired == current

    current = repaired
  rescue EncodingError
    break
  end
  current
end

def repair_file(path)
  text = File.read(path, encoding: 'UTF-8')
  repaired = repair_mojibake(text)
  File.write(path, repaired, encoding: 'UTF-8') if repaired != text
end

def read_doc(path)
  text = File.read(path, encoding: 'UTF-8')

  if text.include?('---\n')
    unescaped = text.gsub('\\n', "\n")
    matches = unescaped.scan(/\A---\s*\n(.*?)\n---\s*\n?/m)
    matches = unescaped.scan(/---\s*\n(.*?)\n---\s*\n?/m) if matches.empty?
    front = matches.last&.first || ''
    data = YAML.safe_load(front, permitted_classes: [Date], aliases: true) || {}
    body = ''
    return [data, body]
  end

  front = text[/\A---\s*\n(.*?)\n---/m, 1] || ''
  body = text.sub(/\A---\s*\n.*?\n---\s*\n/m, '')
  [YAML.safe_load(front, permitted_classes: [Date], aliases: true) || {}, body]
end

def write_doc(path, data, body)
  ordered = {}
  FIELDS.each { |field| ordered[field] = data[field] if data.key?(field) && !data[field].nil? && data[field].to_s.strip != '' }
  (data.keys - ordered.keys).sort.each { |field| ordered[field] = data[field] if !data[field].nil? && data[field].to_s.strip != '' }
  yaml = YAML.dump(ordered, line_width: -1).sub(/\A---\n/, "---\n")
  File.write(path, "#{yaml}---\n#{body}", encoding: 'UTF-8')
end

def words(data, slug)
  [slug, data['pid'], data['original_pid'], data['label'], data['summary'], data['object_type'], data['description'], data['reference']].join(' ')
end

def exhibit_for(slug, data)
  text = words(data, slug)
  return EXHIBITS[:tomba] if slug.start_with?('tomba-') || text =~ /Tomba dell'abbraccio|Frascate|Garaldi|6884|1330|1331|15685|Fortunati/i
  return EXHIBITS[:invisibile] if slug.start_with?('nucleo3-') || text =~ /b05-f139|b05-f140|Marone|Panzarasa|733[5-9]|7340/i
  return EXHIBITS[:comunita] if slug.start_with?('nucleo2-') || text =~ /Antona|embrice|Santo Spirito|Ispettorato|b01-f002|b02-f035|b03-f067|b04-f104|b05-f123/i
  return EXHIBITS[:territorio] if text =~ /Passerini|fornace|Repetto|carta archeologica|territorio|contesto alpino/i
  return EXHIBITS[:davide] if slug.start_with?('davide-pace-')

  EXHIBITS[:territorio]
end

def object_type_for(slug, data)
  text = words(data, slug)
  return 'relazione dattiloscritta' if text =~ /relazione|dattiloscritt|avventura ufficiale/i
  return 'corrispondenza' if text =~ /lettera|carteggio|appunti sul rinvenimento/i
  return 'giornale di scavo' if text =~ /giornale di scavo|annotazioni tecniche|scavo, b\. 5, fasc\. 140/i
  return 'documentazione grafica' if text =~ /schizzo|disegno|carta archeologica|cartograf|rilievi/i
  return 'inventario' if text =~ /inventario/i
  return 'repertorio' if text =~ /Fortunati|bibliograf|fig\. 2|Repetto/i
  return 'fascicolo archivistico' if text =~ /Ispettorato|circolare|regolamento|avviso|fascicolo|manoscritt|documentazione d'archivio/i
  return 'documentazione fotografica' if text =~ /fotograf|negativ|diapositiv|reperto|render|immagine|vetrina|corredo|statuetta|coppa|olpe|lucerna|patera|specchio|unguentario|balsamario|armilla|fibul|fusaiola|moneta|embrice/i

  'fascicolo archivistico'
end

def media_type_for(object_type)
  %w[fascicolo\ archivistico relazione\ dattiloscritta corrispondenza inventario giornale\ di\ scavo].include?(object_type) ? 'text' : 'image'
end

def place_for(slug, data)
  text = words(data, slug)
  return 'Gropello Cairoli (PV), località Frascate, vigna Garaldi' if slug.start_with?('tomba-') || text =~ /Frascate|Garaldi|Tomba dell'abbraccio|6884|1330|1331|15685/i
  return 'Gropello Cairoli (PV), località Marone, Settore Panzarasa' if slug.start_with?('nucleo3-') || text =~ /Panzarasa|Marone|Vughera|733[5-9]|7340|b05-f139|b05-f140/i
  return 'Gropello Cairoli (PV), Settore Lanfranchi' if text =~ /Lanfranchi/i
  return 'Gropello Cairoli (PV), podere Passerini' if text =~ /Passerini|fornace/i
  return 'Gropello Cairoli (PV), località Santo Spirito' if text =~ /Santo Spirito|embrice|ATILIVS|13418/i
  return 'contesto alpino non identificato' if text =~ /alpino/i
  return 'Gropello Cairoli (PV), località Marone' if text =~ /Dosso del Marone|Marone/i

  'Gropello Cairoli (PV)'
end

def normalize_reference(value, slug, data)
  text = repair_mojibake(value.to_s.strip)
  text = text.gsub(/\AFondo Pace,\s*(?:Davide,\s*)?/i, "#{REPOSITORY}, ")
  text = text.gsub(/\AArchivio Pace,\s*/i, "#{REPOSITORY}, ")
  text = text.gsub(/\AFondo Davide Pace,\s*/i, "#{REPOSITORY}, ")
  text = text.gsub(/\AMANLo,\s*/i, "#{REPOSITORY}, documentazione collegata a ")
  text = text.gsub(/\An\. inv\.\s*/i, "#{REPOSITORY}, documentazione collegata a n. inv. ")
  text = text.gsub(/\bdocumenti\s+/i, 'doc. ')
  text = text.gsub(/\bU\.D\.\s*/i, 'doc. ')
  text = text.gsub(/\bUD\s*/i, 'doc. ')
  text = text.gsub(/\bFASC\s+/, 'fasc. ')
  text = text.gsub(/\bfasc(?:\.\s*)+\s*/i, 'fasc. ')
  text = text.gsub(/\bb\.\s*(\d+)\s+fasc\./i, 'b. \1, fasc.')
  text = text.gsub(/\bdoc\.\s*0+(\d+)/i, 'doc. \1')
  text = text.gsub(/\bfasc\.\s*(\d+),\s*(\d{2}\/\d{2}\/\d{4})/i, 'fasc. \1, doc. \2')
  text = text.gsub(/\s+/, ' ').strip

  if text.empty? || text =~ /\Anon identificato\z/i
    if slug.start_with?('tomba-')
      return "#{REPOSITORY}, b. 6, fasc. 145"
    elsif slug.start_with?('nucleo3-')
      return "#{REPOSITORY}, b. 5, fasc. 140"
    end
  end

  text.start_with?(REPOSITORY) ? text : "#{REPOSITORY}, #{text}"
end

def extent_for(data)
  manifest = data['manifest'].to_s.sub(%r{\A/}, '')
  count = nil
  if !manifest.empty? && File.exist?(manifest)
    raw = File.read(manifest, encoding: 'UTF-8').sub(/\A---\s*\n.*?\n---\s*\n/m, '')
    json = JSON.parse(raw)
    count = (json.dig('items') || json.dig('sequences', 0, 'canvases') || []).length
  end
  count ||= 1
  count == 1 ? '1 immagine digitale' : "#{count} immagini digitali"
rescue JSON::ParserError
  '1 immagine digitale'
end

def add_subject(subjects, value)
  subjects << value unless subjects.include?(value)
end

def subjects_for(slug, data)
  text = words(data, slug)
  subjects = []
  add_subject(subjects, 'Gropello Cairoli') if text =~ /Gropello|Antona|embrice|Ispettorato|Santo Spirito|Frascate|Marone|Lanfranchi|Passerini|Tomba dell'abbraccio/i
  add_subject(subjects, 'località Frascate') if slug.start_with?('tomba-') || text =~ /Frascate|Garaldi|6884|1330|1331|15685/i
  add_subject(subjects, 'località Marone') if slug.start_with?('nucleo3-') || text =~ /Marone|Panzarasa|733[5-9]|7340/i
  add_subject(subjects, 'Settore Panzarasa') if slug.start_with?('nucleo3-') || text =~ /Panzarasa|Vughera/i
  add_subject(subjects, 'Settore Lanfranchi') if text =~ /Lanfranchi/i
  add_subject(subjects, 'Santo Spirito') if text =~ /Santo Spirito|embrice|ATILIVS|13418/i
  add_subject(subjects, 'podere Passerini') if text =~ /Passerini/i
  add_subject(subjects, 'scavi archeologici') if text =~ /scav|indagin|saggio|rinvenimento|necropoli|sepolcreto/i
  add_subject(subjects, 'tutela archeologica') if text =~ /tutela|Ispettorato|Soprintendenza|Squadra Volante|regolamento|avviso/i
  add_subject(subjects, 'necropoli') if text =~ /necropoli|Tomba dell'abbraccio|tomba|sepolcreto/i
  add_subject(subjects, 'corredo funerario') if text =~ /corredo|statuetta|balsamario|lucerna|olpe|patera|specchio|unguentario|armilla|fibul|fusaiola|moneta/i
  add_subject(subjects, 'reperti archeologici') if text =~ /reperto|embrice|lucerna|olpe|patera|specchio|unguentario|balsamario|armilla|fibul|fusaiola|moneta|statuetta|coppa/i
  add_subject(subjects, 'iscrizioni') if text =~ /iscrizion|iscritto|ATILIVS/i
  add_subject(subjects, 'fornaci romane') if text =~ /fornace/i
  add_subject(subjects, 'allestimenti museali') if text =~ /vetrina|Antiquarium|museo/i
  add_subject(subjects, 'rilievi archeologici') if text =~ /schizzo|disegno|rilievi|carta archeologica/i
  add_subject(subjects, 'fotogrammetria e modelli 3D') if text =~ /modello 3D|render|fotogrammetria/i
  add_subject(subjects, 'Davide Pace') if text =~ /Davide Pace/i
  add_subject(subjects, 'Francesco Pace') if text =~ /Francesco Pace/i
  add_subject(subjects, 'Luciano Milanesi') if text =~ /Luciano Milanesi/i
  subjects.join('; ')
end

def description_for(data, object_type, place)
  label = data['label'].to_s.strip
  summary = data['summary'].to_s.strip
  description = data['description'].to_s.strip
  return description if !description.empty? && description != label

  case object_type
  when 'relazione dattiloscritta'
    "Documento testuale conservato nell'Archivio Davide Pace, relativo a #{label.downcase}; contribuisce alla ricostruzione delle attività di ricerca e tutela nel territorio di #{place}."
  when 'corrispondenza'
    "Corrispondenza e appunti conservati nell'Archivio Davide Pace, utili a ricostruire il contesto di rinvenimento, le comunicazioni con gli enti di tutela e le informazioni sul territorio di #{place}."
  when 'giornale di scavo'
    "Giornale di scavo e annotazioni tecniche dell'Archivio Davide Pace, con dati sul rinvenimento, sulla disposizione dei materiali e sulle osservazioni effettuate nel contesto di #{place}."
  when 'documentazione grafica'
    "Documento grafico collegato all'Archivio Davide Pace, utile alla lettura topografica o alla ricostruzione del contesto archeologico di #{place}."
  when 'repertorio'
    "Riproduzione digitale di materiale bibliografico o repertoriale collegato alla ricostruzione dei contesti documentati dall'Archivio Davide Pace."
  when 'fascicolo archivistico'
    "Fascicolo archivistico dell'Archivio Davide Pace con documentazione relativa alle attività di ricerca, tutela e descrizione dei rinvenimenti nel territorio di #{place}."
  else
    "Documentazione fotografica collegata all'Archivio Davide Pace e al contesto archeologico di #{place}."
  end
end

def metadata_entry(label, value)
  value = value.to_s.strip
  return nil if value.empty?

  { 'label' => label, 'value' => value }
end

Dir['_pace/*.md'].sort.each do |path|
  repair_file(path)
  data, body = read_doc(path)
  slug = File.basename(path, '.md')
  defaults = DETAIL_DEFAULTS.fetch(slug, {})
  defaults.each { |key, value| data[key] = value if data[key].to_s.strip.empty? || data[key].to_s == '{}' }

  data['original_pid'] = slug if data['original_pid'].to_s.strip.empty?
  data['pid'] = PID_OVERRIDES.fetch(slug, data['pid'].to_s.strip.empty? ? slug : data['pid'])
  data['label'] = data['label'].to_s.strip.empty? ? slug.tr('-', ' ') : data['label'].to_s.strip
  data['summary'] = data['summary'].to_s.strip.empty? ? data['label'] : data['summary'].to_s.strip

  object_type = object_type_for(slug, data)
  place = place_for(slug, data)
  exhibit_section, exhibit_url = exhibit_for(slug, data)

  data['object_type'] = object_type
  data['media_type'] = media_type_for(object_type)
  data['creator'] = data['creator'].to_s.strip.empty? ? 'Davide Pace' : data['creator']
  data['display_date'] = data['display_date'].to_s.strip.empty? ? 's.d.' : data['display_date']
  data['place'] = place
  data['repository'] = REPOSITORY
  data['reference'] = normalize_reference(data['reference'], slug, data)
  data['extent'] = extent_for(data)
  data['subjects'] = subjects_for(slug, data)
  data['subject_vocabularies'] = VOCABULARIES
  data['description'] = description_for(data, object_type, place)
  data['rights'] = RIGHTS_TEXT
  data['license'] = LICENSE_URL
  data['current_location'] = CURRENT_LOCATION
  data['exhibit_section'] = exhibit_section
  data['exhibit_url'] = exhibit_url
  data['layout'] = data['layout'].to_s.strip.empty? ? 'pace_item' : data['layout']
  data['collection'] = 'pace'
  data.each do |key, value|
    data[key] = repair_mojibake(value) if value.is_a?(String)
  end

  if defaults.any?
    data['thumbnail'] ||= '/assets/images/tomba-abbraccio/corredo/6884.png'
    data['full'] ||= data['thumbnail']
    data['canonical_item'] ||= '/pace/tomba-statuetta-6884/'
    data['hide_from_collection'] = true
    data['search_exclude'] = true
  end

  write_doc(path, data, body)
end

Dir['_exhibits/*.md'].each { |path| repair_file(path) }
%w[index.md _config.yml pages/about.md pages/archivio-sia.md pages/collection.md pages/credits.md pages/davide-pace.md pages/exhibits.md pages/progetto.md pages/territorio-museo.md].each do |path|
  repair_file(path) if File.exist?(path)
end

Dir['_pace/*.md'].sort.each do |path|
  data, = read_doc(path)
  manifest = data['manifest'].to_s.sub(%r{\A/}, '')
  next if manifest.empty? || !File.exist?(manifest)

  repair_file(manifest)
  raw = File.read(manifest, encoding: 'UTF-8')
  prefix = raw[/\A---\s*\n.*?\n---\s*\n/m] || ''
  json_text = raw.sub(/\A---\s*\n.*?\n---\s*\n/m, '')
  doc = JSON.parse(json_text)
  doc['label'] = data['label'] if data['label'].to_s.strip != ''
  doc['metadata'] = [
    metadata_entry('PID', data['pid']),
    metadata_entry('PID precedente', data['original_pid']),
    metadata_entry('Titolo', data['label']),
    metadata_entry('Tipologia archivistica/documentaria', data['object_type']),
    metadata_entry('Tipo di contenuto digitale', data['media_type']),
    metadata_entry('Creatore', data['creator']),
    metadata_entry('Data', data['display_date']),
    metadata_entry('Luogo', data['place']),
    metadata_entry('Repository', data['repository']),
    metadata_entry('Segnatura archivistica', data['reference']),
    metadata_entry('Consistenza digitale', data['extent']),
    metadata_entry('Soggetti', data['subjects']),
    metadata_entry('Soggettario / thesaurus', data['subject_vocabularies']),
    metadata_entry('Descrizione', data['description']),
    metadata_entry('Diritti', data['rights']),
    metadata_entry('Licenza', data['license']),
    metadata_entry('Collocazione attuale', data['current_location']),
    metadata_entry('Sezione mostra', data['exhibit_section']),
    metadata_entry('Rimando alla sezione', data['exhibit_url'])
  ].compact
  File.write(manifest, "#{prefix}#{JSON.pretty_generate(doc)}\n", encoding: 'UTF-8')
end

puts 'Uniformati metadati _pace, accenti e manifest IIIF.'
