#!/usr/bin/env ruby

require 'rubygems'
require 'fog'



mutex = Mutex.new

#This  will read from ~/.rackspace_cloud_credentials
#The format should be
#username=<User>
#api_key=<Api_key>


#Get seed name + number of nodes
unless ARGV.size > 1
	puts "usage: #{$0} baseservername numberofnodes"
	exit(1)
end



srvname = ARGV[0]
nmbnode = ARGV[1].to_i

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


#Start all the threads.
threads = []
servs = []
1.upto(nmbnode) do |var|
	serverbuilt = false
	sleep 3
	puts "Starting build #{var} out of #{nmbnode}"

	threads << Thread.new do
		server = conn.servers.create(:flavor_id => 2, :image_id => 'a10eacf7-ac15-4225-b533-5744f1fe47c1', :name => "#{srvname}#{var}")
		mutex.synchronize do
			servs << {'id' => server.id, 'pass' => server.password}
		end
		server.reload
		until server.ready?
			sleep 10
			server.reload
		end
	end
end




#Block Until all servers are built.
we_be_blockin = true
while we_be_blockin
	threadcounter = 0
	threads.each do |t|
		if t.alive?
			threadcounter += 1
		end
	end
	if threadcounter == 0
		we_be_blockin = false
	else
		puts "Still Waiting on #{threadcounter} servers to finish building..."
	end
	sleep 10
end	

toadd = []
servs.each do |s|
	#Dump it all to STDOUT and build the array to add things to the LB
	serv = conn.servers.get(s['id'])
	puts "==========#{serv.name} Information========="
	puts "Public IP Address: #{serv.public_ip_address}"
	puts "Password: #{s['pass']}"
	toadd << {:address => serv.private_ip_address, :port => 80, :condition => 'ENABLED'}
end




#Establish LB Connection
lbconn = Fog::Rackspace::LoadBalancers.new(
	:rackspace_api_key => api_key,
	:rackspace_username => username
)


#Build an LB and add nodes
lb = lbconn.load_balancers.create(
	:name => "#{srvname}-LB",
	:protocol => 'HTTP',
	:port => 80,
	:virtual_ips => [{:type => 'PUBLIC'}],
	:nodes => toadd
)

#Dump ips to STDOUT

puts "============#{srvname}-LB Ip addresses==========="
lb.virtual_ips.each do |ips|
	puts ips.address
end
