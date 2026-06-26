require 'csv'
require 'date'
require 'yaml'

FIELDS = %w[
  pid original_pid label summary object_type media_type creator display_date place repository reference
  extent subjects subject_vocabularies description rights license current_location exhibit_section exhibit_url order layout collection
  thumbnail full manifest
  canonical_item hide_from_collection search_exclude
].freeze

CSV.open('_data/pace.csv', 'w', encoding: 'UTF-8') do |csv|
  csv << FIELDS.map { |field| field == 'display_date' ? 'date' : field }
  Dir['_pace/*.md'].sort.each do |path|
    text = File.read(path, encoding: 'UTF-8')
    front = text[/\A---\s*\n(.*?)\n---/m, 1] || ''
    data = YAML.safe_load(front, permitted_classes: [Date], aliases: true) || {}
    next if data['published'] == false

    csv << FIELDS.map { |field| data[field].to_s }
  end
end

puts "Generated _data/pace.csv with #{Dir['_pace/*.md'].length} records."
