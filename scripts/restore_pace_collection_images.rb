require 'date'
require 'yaml'

FIELDS = %w[
  pid original_pid label summary object_type creator display_date place repository reference
  extent subjects description rights license current_location exhibit_section order layout collection
  thumbnail full manifest
].freeze

RESTORE = {
  'davide-pace-contesto-alpino-scat12-f255-ud001' => [
    '/img/derivatives/iiif/images/davide-pace-contesto-alpino-scat12-f255-ud001-recto/full/250,/0/default.jpg',
    '/img/derivatives/iiif/images/davide-pace-contesto-alpino-scat12-f255-ud001-recto/full/1140,/0/default.jpg'
  ],
  'tomba-archivio-01' => [
    '/assets/images/tomba-abbraccio/archivio/FDP_B06_F145_UD001_MASTER_R.jpg',
    '/assets/images/tomba-abbraccio/archivio/FDP_B06_F145_UD001_MASTER_R.jpg'
  ],
  'tomba-archivio-02' => [
    '/assets/images/tomba-abbraccio/archivio/FDP_B06_F145_UD005_MASTER_R.jpg',
    '/assets/images/tomba-abbraccio/archivio/FDP_B06_F145_UD005_MASTER_R.jpg'
  ],
  'tomba-dettaglio-01' => [
    '/assets/images/tomba-abbraccio/corredo/6884.png',
    '/assets/images/tomba-abbraccio/corredo/6884.png'
  ],
  'tomba-dettaglio-02' => [
    '/assets/images/tomba-abbraccio/corredo/6884.png',
    '/assets/images/tomba-abbraccio/corredo/6884.png'
  ],
  'tomba-documentazione-attuale' => [
    '/assets/images/tomba-abbraccio/corredo/6884.png',
    '/assets/images/tomba-abbraccio/corredo/6884.png'
  ],
  'tomba-foto-storica-01' => [
    '/assets/images/tomba-abbraccio/archivio/FDP_B06_F145_UD001_MASTER_R.jpg',
    '/assets/images/tomba-abbraccio/archivio/FDP_B06_F145_UD001_MASTER_R.jpg'
  ],
  'tomba-foto-storica-02' => [
    '/assets/images/tomba-abbraccio/archivio/FDP_B06_F145_UD005_MASTER_R.jpg',
    '/assets/images/tomba-abbraccio/archivio/FDP_B06_F145_UD005_MASTER_R.jpg'
  ],
  'tomba-manoscritto-01' => [
    '/assets/images/tomba-abbraccio/archivio/FDP_B06_F145_UD005_MASTER_R.jpg',
    '/assets/images/tomba-abbraccio/archivio/FDP_B06_F145_UD005_MASTER_R.jpg'
  ],
  'tomba-manoscritto-02' => [
    '/assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD005_R_ME.jpg',
    '/assets/images/tomba-abbraccio/archivio/FDP_B06_F146_UD005_R_ME.jpg'
  ],
  'tomba-render-3d' => [
    '/assets/images/home/rete-relazioni-statuetta.png',
    '/assets/images/home/rete-relazioni-statuetta.png'
  ],
  'tomba-statuetta-full' => [
    '/assets/images/tomba-abbraccio/corredo/6884.png',
    '/assets/images/tomba-abbraccio/corredo/6884.png'
  ]
}.freeze

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

changed = 0

RESTORE.each do |slug, (thumbnail, full)|
  path = "_pace/#{slug}.md"
  next unless File.exist?(path)

  data, body = read_doc(path)
  data['thumbnail'] = thumbnail
  data['full'] = full
  data.each do |key, value|
    next unless value.is_a?(String)

    data[key] = value
      .gsub('localitÃ ', 'località')
      .gsub('dÃ ', 'dà')
  end
  write_doc(path, data, body)
  changed += 1
end

puts "Restored images for #{changed} collection records."
