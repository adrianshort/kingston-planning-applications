require 'bundler'
Bundler.setup
require 'scraperwiki'
require 'mechanize'
require 'pp'
require 'time'
require 'date'

# Use the column names from planningalerts.org.au:
# https://www.planningalerts.org.au/how_to_write_a_scraper

LA_NAME = "Kingston upon Thames"
LA_GSS = "E09000021" # https://mapit.mysociety.org/area/2480.html
BASEURL = "https://maps.kingston.gov.uk/propertyServices/planning/"

# Parse and save a single planning application
def parse(app)
  record = {}
  
  record['la_name'] = LA_NAME
  record['la_gss'] = LA_GSS
  
  record['council_reference'], record['type'] = app.at("h4").inner_text.split(' - ')
  
  app.search("a").each do |link|
    record['info_url'] = BASEURL + link['href'].strip if link['href'].match(/Details/)
    record['map_url'] = link['href'].strip if link['href'].match(/\?map=/)
    record['images_url'] = BASEURL + link['href'].strip if link['href'].match(/ImageMenu/)
    record['comment_url'] = BASEURL + link['href'].strip if link['href'].match(/PlanningComments/)
  end

  spans = app.search("span")
  record['description'] = spans[0].inner_text
  record['address'] = spans[1].inner_text
  record['ward'] = spans[2].inner_text

  # Decision and decision date
  if matches = spans[4].inner_text.match(/(.+?)\s+(\d{1,2}\/\d{1,2}\/\d{4})/)
    record['decision'] = matches[1]
    record['date_decision'] = Date.parse(matches[2])
  end
  
  # Comments/consultation - consultation end date can change during lifetime of application
  app.search("dd").each do |dd|
    if matches = dd.inner_text.match(/The current closing date for comments on this application is (\d{1,2}-[A-Z][a-z]{2}-\d{4})/)
      record['on_notice_to'] = Date.parse(matches[1])
    end
  end
  
  # Date valid
  begin
    record['date_valid'] = Date.parse(spans[3].inner_text)
    record['date_valid_text'] = nil
  rescue ArgumentError
    record['date_valid'] = nil
    record['date_valid_text'] = spans[3].inner_text
  end
  
  # Scraper timestamps
  record['updated_at'] = Time.now
  record['date_scraped'] = Date.today.to_s
  
  ScraperWiki.save_sqlite(['council_reference'], record)
end

agent = Mechanize.new
agent.verify_mode = OpenSSL::SSL::VERIFY_NONE

# Get all valid applications for the last 12 * 30 days
d = Date.today

12.times do
  d_start = (d - 29).strftime("%d/%m/%Y")
  d_end = d.strftime("%d/%m/%Y")
  
  url = "#{BASEURL}Summary?weekListType=SRCH&recFrom=#{d_start}&recTo=#{d_end}&ward=ALL&appTyp=ALL&wardTxt=All%20Wards&appTypTxt=All%20Application%20Types&limit=500"
  puts url

  page = agent.get(url)
  apps = page.search("#planningApplication")
  puts apps.size, ''
  
  apps.each { |app| parse(app) }
  d -= 30
  sleep 5
end

#  page = Nokogiri::HTML(open("page.html"))
