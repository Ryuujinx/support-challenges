#!/usr/bin/env ruby

require 'rubygems'
require 'fog'



#This  will read from ~/.rackspace_cloud_credentials
#The format should be
#username: <User>
#api_key: <Api_key>


#If you have two nextgen servers with the same name, it will use whichever one is returned first from the API. Use the UUID instead in this case. 


#Make sure we pass in a servername/uuid
unless ARGV.size > 0
	puts "usage: #{$0} servername|uuid"
	exit(1)
end

#Save ARGV[1] so we can manipulate the variable later. We could only accept UUIDs, but this allows more flexibility

servname = ARGV[0]



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




#Some Logic to try and figure out if ARGV[1] is a UUID or a Server.
# First try it as a UUID
server = conn.servers.get(servname)
	if server.nil?	 #Apparently whoever wrote Fog decided it would be cute to return Nil instead of Fog::Compute::RackspaceV2::NotFound, so we check for that and then try to find a matching name.
		conn.servers.all.each do |servobj|
			if servobj.name == servname
				server = conn.servers.get(servobj.id)
				break  #No reason to keep going, we have our server. 
			end
		end
	end
raise "ServerNotFound" if server.nil?
	


#Now we make an image, yay

image = server.create_image("#{server.name}-Clone-#{Time.new.strftime("%Y-%m-%d")}")
puts "Started Creating Image..."


until image.ready?
	#Block Until the image is created
	puts "Waiting on image to complete, this step can take a while..."
	sleep 10
	image.reload
end




t = Time.new

newserv = conn.servers.create(:flavor_id => server.flavor.id, :image_id => image.id, :name => "#{server.name}-clone-#{t.iso8601}")
puts "Starting Build..."
newserv.reload	
until ! newserv.public_ip_address.empty?
	#Block until We have an IP
	puts "Build Started, waiting on IP..."
	newserv.reload
	sleep 10
end

puts "==========#{server.name}-clone-#{t.iso8601} Information========="
puts "Public IP Address: #{newserv.public_ip_address}"
puts "Password: #{newserv.password}"

