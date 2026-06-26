require 'csv'
require 'date'
require 'fileutils'
require 'json'
require 'yaml'

RIGHTS = '&copy; Direzione regionale Musei Nazionali Lombardia - Museo Archeologico Nazionale della Lomellina; CC BY-NC 4.0 https://creativecommons.org/licenses/by-nc/4.0/'
LICENSE = 'https://creativecommons.org/licenses/by-nc/4.0/'
LOCATION = 'Museo Archeologico Nazionale della Lomellina'
SECTION = 'Dal territorio al museo'

ORDERED_FIELDS = %w[
  pid original_pid label summary object_type creator display_date place repository reference
  extent subjects description rights license current_location exhibit_section order layout collection
  thumbnail full manifest
].freeze

def read_doc(path)
  text = File.read(path, encoding: 'UTF-8')
  front = text[/\A---\s*\n(.*?)\n---/m, 1] || ''
  body = text.sub(/\A---\s*\n.*?\n---\s*\n/m, '')
  data = YAML.safe_load(front, permitted_classes: [Date], aliases: true) || {}
  [data, body]
end

def write_doc(path, data, body = "\n")
  ordered = {}
  ORDERED_FIELDS.each { |key| ordered[key] = data[key] if data.key?(key) && !data[key].nil? }
  (data.keys - ordered.keys).sort.each { |key| ordered[key] = data[key] }
  yaml = YAML.dump(ordered, line_width: -1).sub(/\A---\n/, "---\n")
  File.write(path, "#{yaml}---\n#{body}", encoding: 'UTF-8')
end

def repair(value)
  return value unless value.is_a?(String)

  value
    .gsub('localit?', 'località')
    .gsub('attivit?', 'attività')
    .gsub('antichit?', 'antichità')
    .gsub('comunit?', 'comunità')
    .gsub('unit?', 'unità')
    .gsub('Zuccal?', 'Zuccalà')
    .gsub('et?', 'età')
    .gsub('B5_F139', 'b. 5, fasc. 139')
    .gsub('B5_F140', 'b. 5, fasc. 140')
    .gsub('Ã ', 'à')
    .gsub('Ã¨', 'è')
    .gsub('Ã©', 'é')
    .gsub('Ã¬', 'ì')
    .gsub('Ã²', 'ò')
    .gsub('Ã¹', 'ù')
    .gsub('Â«', '«')
    .gsub('Â»', '»')
    .gsub('â€™', '’')
    .gsub('â€“', '-')
end

def repair_hash!(data)
  data.each do |key, value|
    data[key] = value.is_a?(Array) ? value.map { |entry| repair(entry) } : repair(value)
  end
end

def base_record(pid:, original_pid:, label:, summary:, object_type:, creator:, display_date:, place:, repository:, reference:, extent:, subjects:, description:, order:, thumbnail:, full:)
  {
    'pid' => pid,
    'original_pid' => original_pid,
    'label' => label,
    'summary' => summary,
    'object_type' => object_type,
    'creator' => creator,
    'display_date' => display_date,
    'place' => place,
    'repository' => repository,
    'reference' => reference,
    'extent' => extent,
    'subjects' => subjects,
    'description' => description,
    'rights' => RIGHTS,
    'license' => LICENSE,
    'current_location' => LOCATION,
    'exhibit_section' => SECTION,
    'order' => order,
    'layout' => 'pace_item',
    'collection' => 'pace',
    'thumbnail' => thumbnail,
    'full' => full
  }
end

def asset(path)
  "/assets/images/#{path}"
end

def tomba_asset(name)
  asset("tomba-abbraccio/corredo/#{name}")
end

def nucleo3_asset(name)
  asset("nucleo-3/corredo/#{name}")
end

updates = {
  'tomba-olpe-13300' => ['Olpe n. inv. 13300', tomba_asset('13300.png'), tomba_asset('13300.png')],
  'tomba-olpe-13308' => ['Olpe n. inv. 13308', tomba_asset('13308.png'), tomba_asset('13308.png')],
  'tomba-coppa-13303' => ['Coppa n. inv. 13303', tomba_asset('13303.png'), tomba_asset('13303.png')],
  'tomba-coppa-13311' => ['Coppa n. inv. 13311', '/assets/default.png', '/assets/default.png'],
  'tomba-lucerna-13313' => ['Lucerna n. inv. 13313', tomba_asset('13313_R.png'), tomba_asset('13313_R.png')],
  'tomba-statuetta-6884' => ['Statuetta n. inv. 6884', tomba_asset('6884.png'), tomba_asset('6884.png')],
  'tomba-patera-15685' => ['Patera n. inv. 15685', tomba_asset('15685_R.png'), tomba_asset('15685_R.png')],
  'tomba-unguentario-13304' => ['Unguentario n. inv. 13304', tomba_asset('13304.png'), tomba_asset('13304.png')],
  'tomba-balsamario-13305' => ['Balsamario n. inv. 13305', tomba_asset('13305.png'), tomba_asset('13305.png')],
  'tomba-specchio-13312' => ['Specchio n. inv. 13312', tomba_asset('13312.png'), tomba_asset('13312.png')]
}

Dir['_pace/*.md'].sort.each do |path|
  data, body = read_doc(path)
  repair_hash!(data)

  slug = File.basename(path, '.md')
  if updates.key?(slug)
    label, thumb, full = updates[slug]
    data['label'] = label
    data['thumbnail'] = thumb
    data['full'] = full
    data.delete('manifest')
  end

  case slug
  when 'nucleo2-embrice-fasc192-fotografie'
    data['label'] = 'Iscrizione ATILIVS, scat. 8, fasc. 192'
    data['summary'] = 'Documentazione fotografica dell’iscrizione ATILIVS proveniente da Santo Spirito, Gropello Cairoli.'
    data['place'] = 'Gropello Cairoli, promontorio di Santo Spirito'
    data['reference'] = 'Fondo Pace, scat. 8, fasc. 192, doc. 1-2'
    data['subjects'] = 'Gropello Cairoli; Santo Spirito; ATILIVS; iscrizioni; documentazione fotografica; reperti archeologici'
    data['description'] = data['summary']
  when 'nucleo3-giornale-scavo-b5-f139'
    data['label'] = 'Giornale di scavo e documentazione, b. 5, fasc. 139'
    data['summary'] = 'Giornale di scavo e documentazione del fascicolo b. 5, fasc. 139, località Marone, settore Panzarasa.'
    data['place'] = 'Gropello Cairoli, località Marone, settore Panzarasa'
    data['reference'] = 'Fondo Pace, b. 5, fasc. 139, doc. 1-4'
    data['subjects'] = 'Gropello Cairoli; località Marone; settore Panzarasa; scavi archeologici; documentazione archivistica; corredo funerario'
    data['description'] = data['summary']
  when 'nucleo3-foto-scavo-b5-f140-positive', 'nucleo3-manoscritti-b5-f140', 'nucleo3-negativi-positivi-b5-f140'
    data['place'] = 'Gropello Cairoli, località Marone, settore Panzarasa'
    data['subjects'] = [data['subjects'], 'Gropello Cairoli; località Marone; settore Panzarasa; scavi archeologici; documentazione archivistica'].compact.join('; ')
    data['subjects'] = data['subjects'].split(/\s*;\s*/).reject(&:empty?).uniq.join('; ')
  end

  write_doc(path, data, body)
end

new_records = {
  'nucleo3-olla-7336' => base_record(
    pid: 'manlo-n-inv-7336', original_pid: 'nucleo3-olla-7336',
    label: 'Olla n. inv. 7336',
    summary: 'Olla in ceramica comune dalla Tomba VIII della necropoli del Marone.',
    object_type: 'fotografia del reperto', creator: LOCATION, display_date: '1961',
    place: 'Gropello Cairoli, località Marone, settore Panzarasa', repository: LOCATION,
    reference: 'n. inv. 7336', extent: '1 risorsa digitale',
    subjects: 'Gropello Cairoli; località Marone; settore Panzarasa; Tomba VIII; corredo funerario; ceramica comune; reperti archeologici',
    description: 'Olla in ceramica comune, corpo ovoide-globulare, proveniente dal corredo della Tomba VIII.',
    order: '60', thumbnail: nucleo3_asset('7336.png'), full: nucleo3_asset('7336.png')
  ),
  'nucleo3-patera-7335' => base_record(
    pid: 'manlo-n-inv-7335', original_pid: 'nucleo3-patera-7335',
    label: 'Patera n. inv. 7335',
    summary: 'Patera a vernice nera dalla Tomba VIII della necropoli del Marone.',
    object_type: 'fotografia del reperto', creator: LOCATION, display_date: '1961',
    place: 'Gropello Cairoli, località Marone, settore Panzarasa', repository: LOCATION,
    reference: 'n. inv. 7335', extent: '1 risorsa digitale',
    subjects: 'Gropello Cairoli; località Marone; settore Panzarasa; Tomba VIII; corredo funerario; ceramica a vernice nera; reperti archeologici',
    description: 'Patera a vernice nera, forma Lamboglia 5/7, con bollo M. Coeli.',
    order: '61', thumbnail: nucleo3_asset('7335_R.png'), full: nucleo3_asset('7335_R.png')
  ),
  'nucleo3-fusaiola-7338' => base_record(
    pid: 'manlo-n-inv-7338', original_pid: 'nucleo3-fusaiola-7338',
    label: 'Fusaiola n. inv. 7338',
    summary: 'Fusaiola in argilla dalla Tomba VIII della necropoli del Marone.',
    object_type: 'fotografia del reperto e modello 3D', creator: LOCATION, display_date: '1961',
    place: 'Gropello Cairoli, località Marone, settore Panzarasa', repository: LOCATION,
    reference: 'n. inv. 7338', extent: '1 risorsa digitale',
    subjects: 'Gropello Cairoli; località Marone; settore Panzarasa; Tomba VIII; corredo funerario; strumenti per la filatura; fotogrammetria e modelli 3D; reperti archeologici',
    description: 'Fusaiola in argilla di forma biconica, selezionata anche per la digitalizzazione 3D.',
    order: '62', thumbnail: nucleo3_asset('7338_R.png'), full: nucleo3_asset('7338_R.png')
  ),
  'nucleo3-armilla-7337a' => base_record(
    pid: 'manlo-n-inv-7337a', original_pid: 'nucleo3-armilla-7337a',
    label: 'Armilla A n. inv. 7337A',
    summary: 'Armilla in bronzo dalla Tomba VIII della necropoli del Marone.',
    object_type: 'fotografia del reperto e modello 3D', creator: LOCATION, display_date: '1961',
    place: 'Gropello Cairoli, località Marone, settore Panzarasa', repository: LOCATION,
    reference: 'n. inv. 7337A', extent: '1 risorsa digitale',
    subjects: 'Gropello Cairoli; località Marone; settore Panzarasa; Tomba VIII; corredo funerario; ornamenti personali; bronzo; fotogrammetria e modelli 3D; reperti archeologici',
    description: 'Armilla in bronzo a sezione ovale, proveniente dal corredo della Tomba VIII.',
    order: '63', thumbnail: nucleo3_asset('7337A.png'), full: nucleo3_asset('7337A.png')
  ),
  'nucleo3-armilla-7337b' => base_record(
    pid: 'manlo-n-inv-7337b', original_pid: 'nucleo3-armilla-7337b',
    label: 'Armilla B n. inv. 7337B',
    summary: 'Armilla in bronzo dalla Tomba VIII della necropoli del Marone.',
    object_type: 'fotografia del reperto e modello 3D', creator: LOCATION, display_date: '1961',
    place: 'Gropello Cairoli, località Marone, settore Panzarasa', repository: LOCATION,
    reference: 'n. inv. 7337B', extent: '1 risorsa digitale',
    subjects: 'Gropello Cairoli; località Marone; settore Panzarasa; Tomba VIII; corredo funerario; ornamenti personali; bronzo; fotogrammetria e modelli 3D; reperti archeologici',
    description: 'Armilla in bronzo a sezione ovale, proveniente dal corredo della Tomba VIII.',
    order: '64', thumbnail: nucleo3_asset('7337B.png'), full: nucleo3_asset('7337B.png')
  ),
  'nucleo3-fibule-7339ab' => base_record(
    pid: 'manlo-n-inv-7339ab', original_pid: 'nucleo3-fibule-7339ab',
    label: 'Fibule A-B n. inv. 7339A-B',
    summary: 'Coppia di fibule in bronzo dalla Tomba VIII della necropoli del Marone.',
    object_type: 'fotografia del reperto', creator: LOCATION, display_date: '1961',
    place: 'Gropello Cairoli, località Marone, settore Panzarasa', repository: LOCATION,
    reference: 'n. inv. 7339A-B', extent: '1 risorsa digitale',
    subjects: 'Gropello Cairoli; località Marone; settore Panzarasa; Tomba VIII; corredo funerario; ornamenti personali; bronzo; reperti archeologici',
    description: 'Fibula in bronzo a cerniera e fibula in bronzo a balestra con molla composta.',
    order: '65', thumbnail: nucleo3_asset('7339AB.png'), full: nucleo3_asset('7339AB.png')
  ),
  'nucleo3-moneta-7340' => base_record(
    pid: 'manlo-n-inv-7340', original_pid: 'nucleo3-moneta-7340',
    label: 'Moneta n. inv. 7340',
    summary: 'Moneta bronzea dalla Tomba VIII della necropoli del Marone.',
    object_type: 'fotografia del reperto', creator: LOCATION, display_date: '1961',
    place: 'Gropello Cairoli, località Marone, settore Panzarasa', repository: LOCATION,
    reference: 'n. inv. 7340', extent: '1 risorsa digitale',
    subjects: 'Gropello Cairoli; località Marone; settore Panzarasa; Tomba VIII; corredo funerario; numismatica; bronzo; reperti archeologici',
    description: 'Asse sestantale romano con Giano bifronte e prua di nave.',
    order: '66', thumbnail: nucleo3_asset('7340_R.png'), full: nucleo3_asset('7340_R.png')
  )
}

new_records.each do |slug, data|
  write_doc("_pace/#{slug}.md", data)
end

manifest_map = {}
Dir['_pace/*.md'].sort.each do |path|
  data, body = read_doc(path)
  next if data['manifest'].to_s.strip.empty?

  old_manifest = data['manifest'].to_s
  old_slug = File.basename(File.dirname(old_manifest))
  new_slug = data['pid'].to_s
  next if new_slug.empty? || old_slug == new_slug

  old_dir = File.join('img/derivatives/iiif', old_slug)
  new_dir = File.join('img/derivatives/iiif', new_slug)
  if Dir.exist?(old_dir)
    FileUtils.cp_r(old_dir, new_dir) unless Dir.exist?(new_dir)
    manifest_path = File.join(new_dir, 'manifest.json')
    if File.exist?(manifest_path)
      text = File.read(manifest_path, encoding: 'UTF-8')
      text = text.gsub("/img/derivatives/iiif/#{old_slug}/", "/img/derivatives/iiif/#{new_slug}/")
      text = text.gsub("img/derivatives/iiif/#{old_slug}/", "img/derivatives/iiif/#{new_slug}/")
      File.write(manifest_path, text, encoding: 'UTF-8')
    end
    data['manifest'] = "/img/derivatives/iiif/#{new_slug}/manifest.json"
    write_doc(path, data, body)
    manifest_map[old_slug] = new_slug
  end
end

manifest_map.each do |old_slug, new_slug|
  Dir['_exhibits/*.md', 'pages/*.md', '_includes/*.html'].flatten.each do |path|
    next unless File.file?(path)
    text = File.read(path, encoding: 'UTF-8')
    updated = text.gsub("/img/derivatives/iiif/#{old_slug}/manifest.json", "/img/derivatives/iiif/#{new_slug}/manifest.json")
    File.write(path, updated, encoding: 'UTF-8') if updated != text
  end
end

CSV.open('_data/pace.csv', 'w', encoding: 'UTF-8') do |csv|
  csv << ORDERED_FIELDS
  Dir['_pace/*.md'].sort.each do |path|
    data, = read_doc(path)
    csv << ORDERED_FIELDS.map { |field| data[field].to_s }
  end
end

puts "Updated metadata, added #{new_records.length} records, aligned #{manifest_map.length} manifest paths."
