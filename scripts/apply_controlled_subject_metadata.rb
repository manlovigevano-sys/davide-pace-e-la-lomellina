require 'date'
require 'json'
require 'yaml'

VOCABULARIES = 'Nuovo soggettario BNCF; Getty Art & Architecture Thesaurus (AAT); ICCD - normative e vocabolari catalografici'

FIELDS = %w[
  pid original_pid label summary object_type media_type creator display_date place repository reference
  extent subjects subject_vocabularies description rights license current_location exhibit_section order layout collection
  thumbnail full manifest canonical_item hide_from_collection search_exclude published
].freeze

def read_doc(path)
  text = File.read(path, encoding: 'UTF-8')
  front = text[/\A---\s*\n(.*?)\n---/m, 1] || ''
  body = text.sub(/\A---\s*\n.*?\n---\s*\n/m, '')
  [YAML.safe_load(front, permitted_classes: [Date], aliases: true) || {}, body]
end

def write_doc(path, data, body)
  ordered = {}
  FIELDS.each { |field| ordered[field] = data[field] if data.key?(field) && !data[field].nil? }
  (data.keys - ordered.keys).sort.each { |field| ordered[field] = data[field] }
  yaml = YAML.dump(ordered, line_width: -1).sub(/\A---\n/, "---\n")
  File.write(path, "#{yaml}---\n#{body}", encoding: 'UTF-8')
end

def add_terms(existing, terms)
  (existing.to_s.split(/\s*;\s*/) + terms).map(&:strip).reject(&:empty?).uniq.join('; ')
end

def classify(data, slug)
  text = [slug, data['label'], data['summary'], data['object_type'], data['description'], data['reference'], data['manifest'], data['thumbnail']].join(' ')
  terms = []

  terms << 'Fotografie in bianco e nero' if text =~ /bianco e nero|b\/n|negative|negativi|fotogrammi ingranditi/i
  terms << 'Fotografie a colori' if text =~ /a colori|colore|stampa fotografica a colori|stampa a colori/i
  terms << 'Negativi' if text =~ /negativ/i
  terms << 'Diapositive' if text =~ /diapositiv/i
  terms << 'Manoscritti' if text =~ /manoscritt|giornale di scavo|annotazioni/i
  terms << 'Dattiloscritti' if text =~ /dattiloscritt/i
  terms << 'Disegni' if text =~ /disegn|schizz|rilievi|carta archeologica|cartografia/i
  terms << 'Fotografie' if terms.empty? && text =~ /fotograf|stampa|immagine|ripresa|documentazione attuale|reperto/i

  terms
end

def metadata_entry(label, value)
  value = value.to_s.strip
  return nil if value.empty?

  { 'label' => label, 'value' => value }
end

Dir['_pace/*.md'].sort.each do |path|
  data, body = read_doc(path)
  slug = File.basename(path, '.md')

  if slug == 'tomba-hero'
    data['hide_from_collection'] = true
    data['search_exclude'] = true
    data['published'] = false
  end

  media_terms = classify(data, slug)
  unless media_terms.empty?
    data['media_type'] = add_terms(data['media_type'], media_terms)
    data['subjects'] = add_terms(data['subjects'], media_terms)
    data['subject_vocabularies'] = VOCABULARIES
  end

  write_doc(path, data, body)
end

Dir['_pace/*.md'].sort.each do |path|
  data, = read_doc(path)
  manifest = data['manifest'].to_s.sub(%r{\A/}, '')
  next if manifest.empty? || !File.exist?(manifest)

  raw = File.read(manifest, encoding: 'UTF-8')
  prefix = raw[/\A---\s*\n.*?\n---\s*\n/m] || ''
  json_text = raw.sub(/\A---\s*\n.*?\n---\s*\n/m, '')
  doc = JSON.parse(json_text)

  doc['label'] = data['label'] if data['label'].to_s.strip != ''
  doc['metadata'] = [
    metadata_entry('PID', data['pid']),
    metadata_entry('PID precedente', data['original_pid']),
    metadata_entry('Titolo', data['label']),
    metadata_entry('Tipologia', data['object_type']),
    metadata_entry('Tipo supporto/documento', data['media_type']),
    metadata_entry('Creatore', data['creator']),
    metadata_entry('Data', data['display_date']),
    metadata_entry('Luogo', data['place']),
    metadata_entry('Archivio / istituto', data['repository']),
    metadata_entry('Riferimento', data['reference']),
    metadata_entry('Consistenza', data['extent']),
    metadata_entry('Soggetti', data['subjects']),
    metadata_entry('Soggettario / thesaurus', data['subject_vocabularies']),
    metadata_entry('Descrizione', data['description']),
    metadata_entry('Diritti', data['rights']),
    metadata_entry('Licenza', data['license']),
    metadata_entry('Collocazione attuale', data['current_location']),
    metadata_entry('Sezione mostra', data['exhibit_section'])
  ].compact

  File.write(manifest, "#{prefix}#{JSON.pretty_generate(doc)}\n", encoding: 'UTF-8')
end

puts 'Applied controlled media subjects and updated IIIF manifest metadata.'
