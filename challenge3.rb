#!/usr/bin/env ruby

require 'rubygems'
require 'fog'
require 'find'

#This  will read from ~/.rackspace_cloud_credentials
#The format should be
#username=<User>
#api_key=<Api_key>


#You can override the ~/.rackspace_cloud_credentials here if you want. 
username = ""
api_key = ""


#Make sure we pass in directory/container
unless ARGV.size > 1
	puts "usage: #{$0} directory container"
	exit(1)
end


path = ARGV[0]
target = ARGV[1]



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

#Make sure the path is valid.
if ! File.exists?(path)
	raise "No such file or directory #{path}"
end


#Initial run to make sure we can read everything.	
Find.find(path) do |var|
	if ! File.readable?(var)
		raise "Permission Denied, #{var} is not readable."
	end
end


# Set up our storage object.
conn = Fog::Storage.new(
        :provider => 'Rackspace',
        :rackspace_api_key => api_key,
        :rackspace_username => username
)

#Get the container, make one if it doesn't exist.
cont = conn.directories.get(target)
if cont.nil? #again with the not raising exceptions
        conn.directories.create(:key => target)
        cont = conn.directories.get(target)
end



#Make sure the path ends in a slash so we can regexp it out
if  /^.*\/$/.match(path).nil?
	path = "#{path}/"
end

#Now we want to upload...finally.
Find.find(path) do |abspath|
	fname = abspath.gsub(/#{path}/,"")
	if ! fname.empty?
		puts "Uploading file #{abspath}..."
		if File.directory?(abspath)
			cont.files.create(
				:key => fname,
				:body => "",
				:content_type => "application/directory"
			)
		else
			File.open(abspath, "r") do |fobj|
				cont.files.create(
					:key => fname,
					:body => fobj
				)
			end
		end
	end
end
