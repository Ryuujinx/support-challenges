#!/usr/bin/env ruby

require 'rubygems'
require 'fog'


#This  will read from ~/.rackspace_cloud_credentials
#The format should be
#username=<User>
#api_key=<Api_key>


#Get Fqdn, Image and flavorID
unless ARGV.size > 2
	puts "usage: #{$0} fqdn imageID flavorID"
	exit(1)
end



fqdn = ARGV[0]
imageid = ARGV[1]
flavorid = ARGV[2]

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




#Set up our Compute object.
conn = Fog::Compute.new(
	:provider => 'Rackspace',
	:rackspace_api_key => api_key,
	:rackspace_username => username,
	:version => :v2
)


#a10eacf7-ac15-4225-b533-5744f1fe47c1 is a debian image. 
server = conn.servers.create(:flavor_id => flavorid, :image_id => imageid, :name => "#{fqdn}")

puts "Starting Build..."
server.reload
until ! server.public_ip_address.empty?
	#Block until We have an IP
	puts "Build Started, waiting on IP..."
	server.reload
	sleep 10
end


#Build done, time to add DNS

#Set up DNS
dnsconn = Fog::DNS.new(
	:provider => 'Rackspace',
	:rackspace_api_key => api_key,
	:rackspace_username => username,
)


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


z = dnsconn.zones.get(zid)
z.records.create(
	:name => fqdn,
	:type => 'A',
	:value => server.public_ip_address
)

puts "DNS Added."


puts "==========#{fqdn} Information========="
puts "Public IP Address: #{server.public_ip_address}"
puts "Password: #{server.password}"
