require 'json'

def repair_slug_paths(value)
  text = value.to_s
  return text unless text.include?('/img/derivatives/iiif/')

  text.gsub(/doc\. (\d+)/) do
    "ud#{Regexp.last_match(1).to_i.to_s.rjust(3, '0')}"
  end
end

def walk(value)
  case value
  when Hash
    value.each { |key, child| value[key] = walk(child) }
  when Array
    value.map! { |child| walk(child) }
  when String
    repair_slug_paths(value)
  else
    value
  end
end

changed = 0
Dir['img/derivatives/iiif/**/*.json'].sort.each do |path|
  raw = File.read(path, encoding: 'UTF-8')
  raw_without_bom = raw.sub(/\A\uFEFF/, '')
  prefix = raw_without_bom[/\A---\s*\n.*?\n---\s*\n/m] || ''
  json_text = raw_without_bom.sub(/\A---\s*\n.*?\n---\s*\n/m, '')
  doc = JSON.parse(json_text)
  repaired = walk(doc)
  out = "#{prefix}#{JSON.pretty_generate(repaired)}\n"
  next if out == raw

  File.write(path, out, encoding: 'UTF-8')
  changed += 1
rescue JSON::ParserError
  warn "Skipped invalid JSON: #{path}"
end

puts "Repaired IIIF technical slugs: #{changed}"
