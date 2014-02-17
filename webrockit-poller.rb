#!/usr/bin/env ruby

require 'json'
require 'uri'
require 'time'
require 'optparse'
require 'timeout'

# see https://github.com/macbre/phantomas for more parameters to be added later

options = {}
options[:phantomas_bin] = "/opt/phantomjs/collectoids/phantomas/bin/phantomas.js"
options[:phantomas_opts] = "--format=json "
options[:phantomas_extra_ops] = [ ]
options[:critical] = 30
options[:debug] = false

OptionParser.new do |opts|
	opts.banner = "Usage: #{$0} [options]"

	opts.on("-u", "--url [STRING]", "URL to query" ) do |u|
		options[:url] = u
                options[:domain] = u.sub(/^https?\:\/\//, '').split("/")[0]
	end
	opts.on("-p", "--phantomas [PATH]", "Path to Phantomas binary (default: #{options[:phantomas_bin]})") do |p|
		options[:phantomas_bin] = p
	end
	opts.on("-d", "--debug", "Enable debug output") do
		options[:debug] = true
	end
	opts.on("-l", "--ps-extra-opts [STRING]", "Extra Phantomas Options (default: no options) [eg -l 'debug' -l 'proxy=localhost']") do |l|
		options[:phantomas_extra_ops] << "--" + l.to_s
	end
	opts.on("-i", "--ip [IP ADDRESS]", "Override DNS or provide IP for request (default: use dns)") do |i|
		begin
			if i =~ /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\Z/
				options[:ip_address] = i
			else
				raise
			end
		rescue
			puts "Please use --ip x.x.x.x"
			exit 3
		end
	end
end.parse!

unless File.executable?(options[:phantomas_bin])
	puts "Could not find Phantomas binary (#{options[:phantomas_bin]})"
	exit 3
end
if !options[:ip_address].to_s.empty?
   cmd = Array.new
   cmd << "sudo /usr/local/bin/ghost modify "+options[:domain]+" "+options[:ip_address]
   cmd << "2> /dev/null"
   warn "Ghost cmd is: " + cmd.join(" ") if options[:debug]
   @pipe = IO.popen(cmd.join(" "))
   output = @pipe.read
   Process.wait(@pipe.pid)
end

website_url = URI(options[:url])
website_load_time = 0.0

# Run Phantomas
output = ""
nowstamp = Time.now.to_i 
begin
	Timeout::timeout(options[:critical].to_i + 3) do
		cmd = Array.new
		cmd << options[:phantomas_bin]
		cmd << options[:phantomas_opts]
		cmd << options[:phantomas_extra_ops]
		cmd << " --url " + website_url.to_s
		cmd << "2> /dev/null"
		warn "Phantomas cmd is: " + cmd.join(" ") if options[:debug]
		@pipe = IO.popen(cmd.join(" "))
		output = @pipe.read
		Process.wait(@pipe.pid)
	end
rescue Timeout::Error => e
	critical_time_ms = options[:critical].to_i * 1000
	puts "Critical: #{website_url.to_s}: Timeout after: #{options[:critical]} | load_time=#{critical_time_ms.to_s}"
	Process.kill(9, @pipe.pid)
	Process.wait(@pipe.pid)
	exit 2
end

begin
	warn "JSON Output:\n" + output if options[:debug]
	hash = JSON.parse(output)
rescue
	puts "Unkown: Could not parse JSON from phantomas"
	exit 3
end

metrics = ['requests', 
'gzipRequests', 
'postRequests', 
'httpsRequests', 
'redirects', 
'notFound', 
'timeToFirstByte', 
'timeToLastByte', 
'bodySize', 
'contentLength', 
'ajaxRequests', 
'htmlCount', 
'htmlSize', 
'cssCount', 
'cssSize', 
'jsCount', 
'jsSize', 
'jsonCount', 
'jsonSize', 
'imageCount', 
'imageSize', 
'webfontCount', 
'webfontSize', 
'base64Count', 
'base64Size', 
'otherCount', 
'otherSize', 
'cacheHits', 
'cacheMisses', 
'cachingNotSpecified', 
'cachingTooShort', 
'cachingDisabled', 
'domains', 
'maxRequestsPerDomain', 
'medianRequestsPerDomain', 
'DOMqueries', 
'DOMqueriesById', 
'DOMqueriesByClassName', 
'DOMqueriesByTagName', 
'DOMqueriesByQuerySelectorAll', 
'DOMinserts', 
'DOMqueriesDuplicated', 
'eventsBound', 
'headersCount', 
'headersSentCount', 
'headersRecvCount', 
'headersSize', 
'headersSentSize', 
'headersRecvSize', 
'documentWriteCalls', 
'evalCalls', 
'jQueryVersion', 
'jQueryOnDOMReadyFunctions', 
'jQuerySizzleCalls', 
'assetsNotGzipped', 
'assetsWithQueryString', 
'smallImages', 
'multipleRequests', 
'timeToFirstCss', 
'timeToFirstJs', 
'timeToFirstImage', 
'onDOMReadyTime', 
'onDOMReadyTimeEnd', 
'windowOnLoadTime', 
'windowOnLoadTimeEnd', 
'httpTrafficCompleted', 
'windowAlerts', 
'windowConfirms', 
'windowPrompts', 
'consoleMessages', 
'cookiesSent', 
'cookiesRecv', 
'domainsWithCookies', 
'documentCookiesLength', 
'documentCookiesCount', 
'bodyHTMLSize', 
'iframesCount', 
'imagesWithoutDimensions', 
'commentsSize', 
'hiddenContentSize', 
'whiteSpacesSize', 
'DOMelementsCount', 
'DOMelementMaxDepth', 
'nodesWithInlineCSS', 
'globalVariables', 
'jsErrors', 
'localStorageEntries', 
'smallestResponse', 
'biggestResponse', 
'fastestResponse', 
'slowestResponse', 
'medianResponse']
metrics.each { |metric| 
   metricvalue = hash['metrics'][metric]
   if metricvalue.to_s.empty?
      metricvalue = 0
   end
   puts metric.downcase + "\t#{metricvalue}\t#{nowstamp}\n"
}

exit 0
