#!/usr/bin/env ruby

require 'rubygems'
require 'fog'


#This  will read from ~/.rackspace_cloud_credentials
#The format should be
#username=<User>
#api_key=<Api_key>


#Get Fqdn & Contname
unless ARGV.size > 1
	puts "usage: #{$0} containername fqdn"
	exit(1)
end



contname = ARGV[0]
fqdn = ARGV[1]

#You can override the ~/.rackspace_cloud_credentials here if you want. 
username = ""
api_key = ""


#Set up the vars for username and api_key
if File.exists?(File.join(Dir.home, ".rackspace_cloud_credentials")) && username.empty? && api_key.empty?
	f = File.open(File.join(Dir.home, ".rackspace_cloud_credentials"), 'r')
        begin
                username = f.gets.split('=')[1].strip
                api_key = f.gets.split('=')[1].strip
                f.close
        rescue NoMethodError
		f.close
                raise "Invalid credentials file format. Please consult the example file."
        end
elsif ! username.empty? && ! api_key.empty?
	#This is only here so we don't raise an exception if the credentials file isn't there while we're using overrides
else
	raise "~/.rackspace_cloud_credentials not found"
end


#Make CF Connection
puts "Making Cloud Files Connection..."
conn = Fog::Storage.new(
        :provider => 'Rackspace',
        :rackspace_api_key => api_key,
        :rackspace_username => username
)

#CDN Enable Container
puts "CDN Enabling Container..."
cont = conn.directories.get(contname)
if cont.nil? #again with the not raising exceptions
        cont = conn.directories.create(:key => contname, :public => true)
else
	cont.public=(true)
	cont.save
end

#Upload the index file
puts "Uploading index..."
File.open("index.html","r") do |fobj|
	cont.files.create(
		:key => "index.html",
		:body => fobj,
		:content_type => "text/html"
	)
end

#Set metadata
puts "Setting X-Container-Meta-Web-Index to index.html..."
cont.metadata=({"Web-Index" => "index.html"})
cont.save



#Make DNS Connection
dnsconn = Fog::DNS.new(
	:provider => 'Rackspace',
	:rackspace_api_key => api_key,
	:rackspace_username => username,
)


#Does the zone exist? If so set it. If not raise an error. 
zoneexists = false
zid = ""
	dnsconn.zones.all.each do |var|
		if fqdn =~ /#{var.domain}/
			zoneexists = true
			zid = var.id
		end
	end
unless zoneexists
	raise "No such Zone, check your spelling"
end


#Convert CDN URL to Damain
cdn_url = cont.public_url.gsub('http://','')

#Create the record
puts "Creating DNS Record..."
z = dnsconn.zones.get(zid)
z.records.create(
	:name => fqdn,
	:type => 'CNAME',
	:value => cdn_url
)

puts "Record Created"
