require 'date'
require 'yaml'

FIELDS = %w[
  pid original_pid label summary object_type media_type creator display_date place repository reference
  extent subjects subject_vocabularies description rights license current_location exhibit_section exhibit_url
  order layout collection thumbnail full manifest canonical_item hide_from_collection search_exclude published
].freeze

EXHIBITS = {
  'La tomba dell\'abbraccio' => '/exhibits/tomba-abbraccio/',
  'Comunità locale e tutela' => '/exhibits/comunita-locale/',
  'Documentare l\'invisibile' => '/exhibits/documentare-invisibile/',
  'Davide Pace' => '/pages/davide-pace/',
  'Dal territorio al museo' => '/pages/territorio-museo/'
}.freeze

def frontmatter_blocks(text)
  text.scan(/(?:\A|\n)\uFEFF?---\s*\n(.*?)\n---\s*\n?/m).map(&:first)
end

def parse_block(block)
  YAML.safe_load(block, permitted_classes: [Date], aliases: true) || {}
rescue Psych::SyntaxError
  {}
end

def write_doc(path, data)
  ordered = {}
  FIELDS.each { |field| ordered[field] = data[field] if data.key?(field) && !data[field].nil? && data[field].to_s.strip != '' }
  (data.keys - ordered.keys).sort.each { |field| ordered[field] = data[field] if !data[field].nil? && data[field].to_s.strip != '' }
  yaml = YAML.dump(ordered, line_width: -1).sub(/\A---\n/, "---\n")
  File.write(path, "#{yaml}---\n", encoding: 'UTF-8')
end

def score(data)
  %w[manifest thumbnail full reference label description summary].sum { |key| data[key].to_s.strip.empty? ? 0 : 1 }
end

def add_subject(data, subject)
  subjects = data['subjects'].to_s.split(';').map(&:strip).reject(&:empty?)
  subjects << subject unless subjects.include?(subject)
  data['subjects'] = subjects.join('; ')
end

def section_for(slug, data)
  text = [slug, data['pid'], data['original_pid'], data['label'], data['summary'], data['description'], data['reference'], data['place']].join(' ')
  return 'La tomba dell\'abbraccio' if slug.start_with?('tomba-') || text =~ /Tomba dell'abbraccio|Frascate|Garaldi|6884|1330|1331|15685|Fortunati/i
  return 'Documentare l\'invisibile' if slug.start_with?('nucleo3-') || text =~ /b05-f139|b05-f140|Marone|Panzarasa|733[5-9]|7340/i
  return 'Comunità locale e tutela' if slug.start_with?('nucleo2-') || text =~ /Antona|embrice|Santo Spirito|Ispettorato|b01-f002|b02-f035|b03-f067|b04-f104|b05-f123/i
  return 'Dal territorio al museo' if text =~ /Passerini|fornace|Repetto|carta archeologica|territorio|contesto alpino/i
  return 'Davide Pace' if slug.start_with?('davide-pace-')

  'Dal territorio al museo'
end

updated = []
Dir['_pace/*.md'].sort.each do |path|
  text = File.read(path, encoding: 'UTF-8')
  blocks = frontmatter_blocks(text)
  next if blocks.empty?

  slug = File.basename(path, '.md')
  candidates = blocks.map { |block| parse_block(block) }.reject(&:empty?)
  data = candidates.max_by { |candidate| [score(candidate), candidate.keys.length] } || candidates.last

  section = section_for(slug, data)
  data['exhibit_section'] = section
  data['exhibit_url'] = EXHIBITS.fetch(section)

  subject_text = [data['label'], data['summary'], data['description']].join(' ')
  add_subject(data, 'Davide Pace') if subject_text =~ /Davide Pace/i
  add_subject(data, 'Francesco Pace') if subject_text =~ /Francesco Pace/i
  add_subject(data, 'Luciano Milanesi') if subject_text =~ /Luciano Milanesi/i

  write_doc(path, data)
  updated << path if blocks.length > 1 || subject_text =~ /Davide Pace|Francesco Pace|Luciano Milanesi/i
end

puts "Repaired pace front matter and links: #{updated.length}"
