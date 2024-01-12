# Get various data and settings from App Search

# Load all gems from Gemfile
require 'bundler/setup'
Bundler.require(:default)

# Load environment variables
Dotenv.load

# Set variables
HOST_IDENTIFIER = ENV['HOST_IDENTIFIER']
ENGINE_NAME = ENV['ENGINE_NAME']
PRIVATE_API_KEY = ENV['PRIVATE_API_KEY']
URL_FIELD = ENV['URL_FIELD'] || 'url'

# Reusable headers
HEADERS = {
  'Content-Type' => 'application/json',
  'Authorization' => "Bearer #{PRIVATE_API_KEY}"
}

# Get the current synonyms for the engine
# Save them to the file ./synonyms.json
# Ex:
# curl -X GET 'https://[HOST_IDENTIFIER].api.swiftype.com/api/as/v1/engines/[ENGINE]/synonyms' \
# -H 'Content-Type: application/json' \
# -H 'Authorization: Bearer [PRIVATE_API_KEY]'
#
# The API can only return 20 results at a time, so we need to paginate through the results

count = HTTParty.get(
  "https://#{HOST_IDENTIFIER}.api.swiftype.com/api/as/v1/engines/#{ENGINE_NAME}/synonyms",
  headers: HEADERS
)

pages = JSON.parse(count.body)['meta']['page']['total_pages']
synonym_sets = []

# Get each page of results
# Pages are 1-indexed
# Ex:
# curl -X GET 'https://host-2376rb.api.swiftype.com/api/as/v1/engines/national-parks-demo/synonyms' \
# -H 'Authorization: Bearer private-xxxxxxxxxxxxxxxxxxxx' \
# -d '{
#   "page": {
#     "size": 20,
#     "current": 2
#   }
# }'

pages_progress_bar = ProgressBar.new(pages)
pages_progress_bar.puts "Getting synonyms"
pages.times do |page|
  pages_progress_bar.increment!
  page += 1
  response = HTTParty.get(
    "https://#{HOST_IDENTIFIER}.api.swiftype.com/api/as/v1/engines/#{ENGINE_NAME}/synonyms",
    headers: {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{PRIVATE_API_KEY}"
    },
    body: {
      page: {
        size: 20,
        current: page
      }
    }.to_json
  )
  
  response = JSON.parse(response.body)
  results = response['results']

  results.each do |result|
    synonym_sets << result['synonyms']
  end
end

# Save the synonyms to a file
File.open('./synonyms.json', 'w') do |f|
  f.write(JSON.pretty_generate(synonym_sets))
end


# Get all curations for the engine
# Example:
# curl -X GET 'https://host-2376rb.api.swiftype.com/api/as/v1/engines/national-parks-demo/curations' \
# -H 'Content-Type: application/json' \
# -H 'Authorization: Bearer private-xxxxxxxxxxxxxxxxxxxxxxxx' \
# -d '{
#   "page": {
#     "size": 20,
#     "current": 2
#   }
# }'

count = HTTParty.get(
  "https://#{HOST_IDENTIFIER}.api.swiftype.com/api/as/v1/engines/#{ENGINE_NAME}/curations",
  headers: HEADERS
)

pages = JSON.parse(count.body)['meta']['page']['total_pages']
curations = []

# Get each page of results
# Pages are 1-indexed

pages_progress_bar = ProgressBar.new(pages)
pages_progress_bar.puts "Getting curations"
pages.times do |page|
  pages_progress_bar.increment!
  page += 1
  response = HTTParty.get(
    "https://#{HOST_IDENTIFIER}.api.swiftype.com/api/as/v1/engines/#{ENGINE_NAME}/curations",
    headers: HEADERS,
    body: {
      page: {
        size: 20,
        current: page
      }
    }.to_json
  )
  
  response = JSON.parse(response.body)
  results = response['results']

  results.each do |result|
    # Remove the "id" field from the result, we don't need it
    result.delete('id')

    # Add the curation to the curations array if it has promoted or hidden results
    curations << result unless result['promoted'].empty? && result['hidden'].empty?
  end
end

# Save the curations to a file
File.open('./curations.json', 'w') do |f|
  f.write(JSON.pretty_generate(curations))
end

# Get the URL associated with each result in each curation
# Update the curations.json file with the URLs, replacing the result IDs
# IDs can be found in the "promoted" and "hidden" arrays inside each curation
# The API call can pass in multiple IDs at once
# Ex:
# curl -X GET 'https://host-2376rb.api.swiftype.com/api/as/v1/engines/national-parks-demo/documents' \
# -H 'Content-Type: application/json' \
# -H 'Authorization: Bearer private-xxxxxxxxxxxxxxxxxxxx' \
# -d '["park_zion", "does_not_exist"]'

curations = JSON.parse(File.read('./curations.json'))

curations_progress_bar = ProgressBar.new(curations.length)
curations_progress_bar.puts "Getting URLs for each result in each curation"
curations.each do |curation|
  curations_progress_bar.increment!
  promoted_ids = curation['promoted']
  hidden_ids = curation['hidden']

  if promoted_ids.empty? && hidden_ids.empty?
    next
  end

  unless promoted_ids.empty?
    # Get the URLs for the promoted results
    promoted_urls = []
    promoted_response = HTTParty.get(
      "https://#{HOST_IDENTIFIER}.api.swiftype.com/api/as/v1/engines/#{ENGINE_NAME}/documents",
      headers: HEADERS,
      body: promoted_ids.to_json
    )
    # Response is an array of documents
    promoted_response = JSON.parse(promoted_response.body)

    # Get the URL for each document
    promoted_response.each do |document|
      promoted_urls << document[URL_FIELD]
    end
  end

  unless hidden_ids.empty?
    # Get the URLs for the hidden results
    hidden_urls = []
    hidden_response = HTTParty.get(
      "https://#{HOST_IDENTIFIER}.api.swiftype.com/api/as/v1/engines/#{ENGINE_NAME}/documents",
      headers: HEADERS,
      body: hidden_ids.to_json
    )
    # Response is an array of documents
    hidden_response = JSON.parse(hidden_response.body)

    # Get the URL for each document
    hidden_response.each do |document|
      hidden_urls << document[URL_FIELD]
    end
  end

  # Replace the IDs in the curations file with the URLs
  curation['promoted'] = promoted_urls unless promoted_urls.nil?
  curation['hidden'] = hidden_urls unless hidden_urls.nil?
end

# Save the updated curations to a file
File.open('./curations.json', 'w') do |f|
  f.write(JSON.pretty_generate(curations))
end


# Get all search settings for the engine
# Example:
# curl -X GET 'https://host-2376rb.api.swiftype.com/api/as/v1/engines/national-parks-demo/search_settings' \
# -H 'Content-Type: application/json' \
# -H 'Authorization: Bearer private-xxxxxxxxxxxxxxxx'

puts "Getting search settings"

response = HTTParty.get(
  "https://#{HOST_IDENTIFIER}.api.swiftype.com/api/as/v1/engines/#{ENGINE_NAME}/search_settings",
  headers: HEADERS
)

search_settings = JSON.parse(response.body)['search_fields']

# Save the search settings to a file
File.open('./search_settings.json', 'w') do |f|
  f.write(JSON.pretty_generate(search_settings))
end

puts "🎉 Done!"

