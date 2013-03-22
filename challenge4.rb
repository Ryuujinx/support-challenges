#!/usr/bin/env ruby

require 'rubygems'
require 'fog'


#This will read from ~/.rackspace_cloud_credentials
#The format should be
#username=<User>
#api_key=<Api_key>



#Make sure we pass in a fqdn/ip
unless ARGV.size > 1
	puts "usage: #{$0} fqdn ip"
	exit(1)
end



fqdn = ARGV[0]
ip = ARGV[1]


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



conn = Fog::DNS.new(
	:provider => 'Rackspace',
	:rackspace_api_key => api_key,
	:rackspace_username => username,
)


#Does the zone exist? If so set it. If not raise an error. 
zoneexists = false
zid = ""
conn.zones.all.each do |var|
	if fqdn =~ /#{var.domain}/
		zoneexists = true
		zid = var.id
	end
end
unless zoneexists
	raise "No such Zone, check your spelling"
end
		
#Is this an IPv4 Address? If so, make the record, if not raise an error.

#First check - are there 4 groups?
if /^(\d*)\.(\d*)\.(\d*)\.(\d*)$/.match(ip)
	#Second Check, make sure each group is less then 256.
	ip.split(".").each do |num|
		p num
		if num.to_i > 255	
			raise "Invalid IP Address, check your input."
		end
	end
	puts "Creating Record for #{fqdn} with IP address #{ip}..."
	z = conn.zones.get(zid)
	z.records.create(
		:name => fqdn,
		:type => 'A',
		:value => ip
	)
	puts "Record Created."
else
	raise "Invalid IP Address, check your input."
end
