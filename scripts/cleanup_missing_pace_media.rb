require 'date'
require 'yaml'

FIELDS = %w[
  pid original_pid label summary object_type creator display_date place repository reference
  extent subjects description rights license current_location exhibit_section order layout collection
  thumbnail full manifest
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

changed = 0

Dir['_pace/*.md'].sort.each do |path|
  data, body = read_doc(path)
  before = data.dup

  %w[thumbnail full].each do |field|
    value = data[field].to_s
    next if value.empty? || File.exist?(value.sub(%r{\A/}, ''))

    data[field] = '/assets/default.png'
  end

  manifest = data['manifest'].to_s
  data.delete('manifest') if !manifest.empty? && !File.exist?(manifest.sub(%r{\A/}, ''))

  data.each do |key, value|
    data[key] = value.gsub('localitÃ ', 'località') if value.is_a?(String)
  end

  next if data == before

  write_doc(path, data, body)
  changed += 1
end

puts "Cleaned #{changed} _pace records with missing media or mojibake."
