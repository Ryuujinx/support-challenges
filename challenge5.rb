#!/usr/bin/env ruby

require 'rubygems'
require 'fog'
require 'find'
require 'securerandom'



#This  will read from ~/.rackspace_cloud_credentials
#The format should be
#username=<User>
#api_key=<Api_key>


#You can override the ~/.rackspace_cloud_credentials here if you want. 
username = ""
api_key = ""


#Make sure we pass in directory/container
unless ARGV.size > 1
        puts "usage: #{$0} dbname dbusername [dbpassword]"
        exit(1)
end


dbname = ARGV[0]
dbuser = ARGV[1]
if ! ARGV[2].nil? 
	dbpass = ARGV[2] 
else
	dbpass = SecureRandom.urlsafe_base64(20)
end



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
conn = Fog::Rackspace::Databases.new(
#	:provider => 'Rackspace',
	:rackspace_api_key => api_key,
	:rackspace_username => username,
)


#Make an instance
built = false
until built
	dbi = conn.instances.create(
	        :flavor_id => '2',
        	:volume_size => '4',
	        :name => dbname
	)
	until dbi.state != "BUILD"
		p dbi
		dbi.reload
		sleep 10
	end
	if dbi.state != "ACTIVE"
		dbi.destroy
	else
		built = true
	end
end

p dbi.name

db = dbi.databases.create(
	:name => dbname
)
dbi.users.create(
	:identity => dbuser,
	:password => dbpass,
	:databases => dbname
	)
