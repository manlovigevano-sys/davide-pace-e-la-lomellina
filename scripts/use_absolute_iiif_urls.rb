Dir['img/derivatives/iiif/**/*.json'].sort.each do |path|
  text = File.read(path, encoding: 'UTF-8')
  updated = text.gsub(/\{\{\s*'\/'\s*\|\s*relative_url\s*\}\}(img\/[^"']+)/) do
    "{{ '/#{$1}' | absolute_url }}"
  end
  File.write(path, updated, encoding: 'UTF-8') if updated != text
end

puts 'Converted IIIF JSON paths to absolute_url Liquid filters.'
