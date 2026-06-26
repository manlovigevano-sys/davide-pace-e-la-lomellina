require 'cgi'
require 'date'
require 'yaml'

GENERIC_PATTERNS = [
  /Documentazione fotografica collegata all'Archivio Davide Pace/,
  /Fascicolo archivistico dell'Archivio Davide Pace/,
  /Unità documentaria testuale conservata nell'Archivio Davide Pace/,
  /Documento grafico collegato all'Archivio Davide Pace/,
  /Riproduzione digitale di materiale bibliografico/
].freeze

def read_doc(path)
  text = File.read(path, encoding: 'UTF-8')
  front = text[/\A---\s*\n(.*?)\n---/m, 1] || ''
  body = text.sub(/\A---\s*\n.*?\n---\s*\n/m, '')
  [YAML.safe_load(front, permitted_classes: [Date], aliases: true) || {}, body]
end

def write_doc(path, data, body)
  yaml = YAML.dump(data, line_width: -1).sub(/\A---\n/, "---\n")
  File.write(path, "#{yaml}---\n#{body}", encoding: 'UTF-8')
end

def normalize_text(value)
  text = value.to_s
  text = text.gsub(/<[^>]+>/, '')
  text = CGI.unescapeHTML(text)
  text = text.gsub('&middot;', '·')
  text = text.gsub(/\s+/, ' ').strip
  text = text.gsub(/\s+([,.;:])/, '\1')
  text
end

def extract_attrs(tag)
  attrs = {}
  tag.scan(/([A-Za-z_][\w-]*)\s*=\s*("(?:[^"\\]|\\.)*"|'[^']*')/m) do |key, raw|
    value = raw[1..-2]
    attrs[key] = normalize_text(value)
  end
  attrs
end

caption_by_manifest = {}
caption_by_slug = {}

Dir['_exhibits/*.md', 'pages/*.md', 'index.md'].each do |path|
  next unless File.exist?(path)

  text = File.read(path, encoding: 'UTF-8')

  text.scan(/\{%\s*include\s+iiif_figure\.html\s+(.*?)%\}/m) do |match|
    attrs = extract_attrs(match.first)
    caption = attrs['caption']
    next if caption.to_s.strip.empty?

    caption_by_manifest[attrs['manifest']] = caption if attrs['manifest']
    if attrs['href'].to_s =~ %r{/pace/([^/]+)/?}
      caption_by_slug[Regexp.last_match(1)] = caption
    end
  end

  text.scan(/\{%\s*include\s+corredo_reperto_card\.html\s+(.*?)%\}/m) do |match|
    attrs = extract_attrs(match.first)
    caption = attrs['description']
    next if caption.to_s.strip.empty?

    if attrs['href'].to_s =~ %r{/pace/([^/]+)/?}
      caption_by_slug[Regexp.last_match(1)] = caption
    end
  end

  text.scan(/<div class="case-iiif-caption">\s*(.*?)<a[^>]+href="\{\{\s*'\/pace\/([^\/]+)\/'\s*\|\s*relative_url\s*\}\}"[^>]*>/m) do |caption_html, slug|
    caption = normalize_text(caption_html)
    caption_by_slug[slug] = caption unless caption.empty?
  end
end

updated = []

Dir['_pace/*.md'].sort.each do |path|
  data, body = read_doc(path)
  slug = File.basename(path, '.md')
  label = data['label'].to_s.strip
  summary = data['summary'].to_s.strip
  current = data['description'].to_s.strip
  manifest = data['manifest'].to_s.strip

  generic = current.empty? || current == label || GENERIC_PATTERNS.any? { |pattern| current =~ pattern }
  next unless generic

  candidate = caption_by_slug[slug] || caption_by_manifest[manifest]
  candidate = summary if candidate.to_s.strip.empty? && !summary.empty? && summary != label
  candidate = normalize_text(candidate)
  next if candidate.empty? || candidate == label

  data['description'] = candidate
  write_doc(path, data, body)
  updated << "#{slug}: #{candidate}"
end

puts "Restored descriptions: #{updated.length}"
updated.each { |line| puts line }
