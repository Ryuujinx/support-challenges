#!/usr/bin/env ruby

require 'rubygems'
require 'fog'



#This  will read from ~/.rackspace_cloud_credentials
#The format should be
#username=<User>
#api_key=<Api_key>


#Get container name
unless ARGV.size > 0
	puts "usage: #{$0} containername"
	exit(1)
end

contname = ARGV[0]


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



# Set up our storage object.
conn = Fog::Storage.new(
        :provider => 'Rackspace',
        :rackspace_api_key => api_key,
        :rackspace_username => username
)


#Get the container, make one if it doesn't exist, make the container public.
cont = conn.directories.get(contname)
if cont.nil? #again with the not raising exceptions
        conn.directories.create(:key => contname, :public => true)
else
	cont.public=(true)
	cont.save
end


puts "Container #{contname} is now public."
