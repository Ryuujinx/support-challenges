#!/usr/bin/env ruby

require 'rubygems'
require 'fog'



#This  will read from ~/.rackspace_cloud_credentials
#The format should be
#username: <User>
#api_key: <Api_key>


#You can override the ~/.rackspace_cloud_credentials here if you want. 
username = ""
api_key = ""


#Set up the vars for username and api_key
if File.exists?(File.join(Dir.home, ".rackspace_cloud_credentials")) && username.empty? && api_key.empty?
	f = File.open(File.join(Dir.home, ".rackspace_cloud_credentials"), 'r')

	username = f.gets.split(':')[1].strip
	api_key = f.gets.split(':')[1].strip
	
	f.close
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


[1,2,3].each do |var|
	server = conn.servers.create(:flavor_id => 2, :image_id => 'a10eacf7-ac15-4225-b533-5744f1fe47c1', :name => "web#{var}")
	puts "Starting Build..."
	server.reload
	until ! server.public_ip_address.empty? 
		#Block until We have an IP 
		puts "Build Started, waiting on IP..." 
		server.reload
		sleep 10 
	end
	puts "==========Web#{var} Information========="
	puts "Public IP Address: #{server.public_ip_address}"
	puts "Password: #{server.password}"
end



