# This is a template for a Ruby scraper on morph.io (https://morph.io)
# including some code snippets below that you should find helpful

require 'bundler'
Bundler.setup
require 'scraperwiki'
require 'mechanize'
require 'pp'

BASEURL = "https://maps.kingston.gov.uk/propertyServices/planning/"

agent = Mechanize.new
agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
#
# # Read in a page
page = agent.get("https://maps.kingston.gov.uk/propertyServices/planning/Summary?weekListType=SRCH&recFrom=01/Jan/2017&recTo=01/Feb/2017&ward=ALL&appTyp=ALL&wardTxt=All%20Wards&appTypTxt=All%20Application%20Types&limit=50")
#
# page = Nokogiri::HTML(open("page.html"))

apps = page.search("#planningApplication")

apps.each do |app|
  @title = app.at("h4").inner_text
  @id = @title.match(/\d+\/\d+\/\w+/)[0]
  puts @id
  app.search("a").each do |link|
    @url = BASEURL + link['href'].strip if link['href'].match(/Details\.aspx/)
    puts @url
    @map_url = link['href'].strip if link['href'].match(/\?map=/)
  end
  spans = app.search("span")
  @description = spans[0].inner_text
  @address = spans[1].inner_text
  @ward = spans[2].inner_text
  
  begin
    @date_valid = Date.parse(spans[3].inner_text)
    @date_valid_text = nil
  rescue ArgumentError
    @date_valid = nil
    @date_valid_text = spans[3].inner_text
  end
  
  ScraperWiki.save_sqlite(["id"],
    { 'id' => @id,
      'url' => @url,
      'title' => @title, 
      'description' => @description,
      'address' => @address,
      'ward' => @ward,
      'date_valid' => @date_valid,
      'date_valid_text' => @date_valid_text,
      'map_url' => @map_url
  })
end
