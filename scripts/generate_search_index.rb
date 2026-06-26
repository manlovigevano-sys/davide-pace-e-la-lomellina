require 'date'
require 'json'
require 'yaml'

SEARCH_FIELDS = {
  'exhibits' => %w[title label subtitle topic summary keywords],
  'pace' => %w[
    title label summary object_type media_type creator date place repository reference
    extent subjects subject_vocabularies description rights current_location exhibit_section exhibit_url
  ]
}.freeze

def front_matter(path)
  text = File.read(path, encoding: 'UTF-8')
  front = text[/\A---\s*\n(.*?)\n---/m, 1] || ''
  YAML.safe_load(front, permitted_classes: [Date], aliases: true) || {}
end

def permalink_for(collection, path, data)
  return data['permalink'] if data['permalink'].to_s.strip != ''

  slug = File.basename(path, '.md')
  collection == 'exhibits' ? "/exhibits/#{slug}/" : "/#{collection}/#{slug}/"
end

records = []

{
  'exhibits' => '_exhibits/*.md',
  'pace' => '_pace/*.md'
}.each do |collection, glob|
  Dir[glob].sort.each do |path|
    data = front_matter(path)
    next if data['search_exclude'] == true

    record = {}
    SEARCH_FIELDS[collection].each do |field|
      value = field == 'date' ? data['display_date'] : data[field]
      record[field] = value.to_s if value && value.to_s.strip != ''
    end
    record['pid'] = data['pid'].to_s if data['pid'].to_s.strip != ''
    record['original_pid'] = data['original_pid'].to_s if data['original_pid'].to_s.strip != ''
    record['title'] ||= data['label'].to_s if data['label'].to_s.strip != ''
    record['label'] ||= data['title'].to_s if data['title'].to_s.strip != ''
    record['collection'] = collection
    record['thumbnail'] = data['thumbnail'].to_s if data['thumbnail'].to_s.strip != ''
    record['permalink'] = permalink_for(collection, path, data)
    records << record
  end
end

records.each_with_index { |record, index| record['lunr_id'] = index }

File.write(
  'search/index.json',
  "---\nlayout: none\n---\n#{JSON.pretty_generate(records)}\n",
  encoding: 'UTF-8'
)

puts "Generated search/index.json with #{records.length} records."
