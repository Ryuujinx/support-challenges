#!/usr/bin/env ruby

require 'rubygems'
require 'fog'



#This will read from ~/.rackspace_cloud_credentials
#The format should be
#username=<User>
#api_key=<Api_key>


mutex = Mutex.new

#Get seed name
unless ARGV.size > 2
        puts "usage: #{$0} baseservername numberofnodes fqdn"
        exit(1)
end

srvname = ARGV[0]
nmbnode = ARGV[1].to_i
fqdn = ARGV[2]


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



#We need to load the SSH key into a var so we can pass it later.
if File.exists?("sshkey.pub")
	f = File.open("sshkey.pub", "rb")
	key = f.read
        f.close
else
	puts "No key file found, please have the public key at #{Dir.pwd}/sshkey.pub"
	exit(1)
end



#We Load the HTML content into a variable here, so we don't wait for multiple servers to build before realizing it doesn't exist.
if File.exists?("error.html")
        f = File.open("error.html", "rb")
        errorhtml = f.read
        f.close
else
        puts "No error file found, please have the error.html file at #{Dir.pwd}/error.html"
        exit(1)
end


puts "Prereqs checked, starting process..."






puts "Establishing connection to Compute API..."

#Set up our Compute object.
servconn = Fog::Compute.new(
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
        puts "Starting build #{var} out of #{nmbnode}..."

        threads << Thread.new do
                server = servconn.servers.create(
                        :flavor_id => 2,
                        :image_id => 'a10eacf7-ac15-4225-b533-5744f1fe47c1',
                        :name => "#{srvname}#{var}",
                        :personality => [{ 'path' => '/root/.ssh/authorized_keys', 'contents' => Base64.encode64(key) }])
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

puts "Server builds finished."

toadd = []
servs.each do |s|
        #Dump it all to STDOUT and build the array to add things to the LB
        serv = servconn.servers.get(s['id'])
        puts "==========#{serv.name} Information========="
        puts "Public IP Address: #{serv.public_ip_address}"
        puts "Password: #{s['pass']}"
        toadd << {:address => serv.private_ip_address, :port => 80, :condition => 'ENABLED'}
end



puts "\n\n Establishing connection to LB API..."

#Establish LB Connection
lbconn = Fog::Rackspace::LoadBalancers.new(
        :rackspace_api_key => api_key,
        :rackspace_username => username
)

puts "Starting LB build..."
#Build an LB and add nodes
lb = lbconn.load_balancers.create(
        :name => "#{srvname}-LB",
        :protocol => 'HTTP',
        :port => 80,
        :virtual_ips => [{:type => 'PUBLIC'}],
        :nodes => toadd
)



#Dump ips to STDOUT
lbip=""
puts "============#{srvname}-LB Ip addresses==========="
lb.virtual_ips.each do |ips|
        puts ips.address
        if /^(\d*)\.(\d*)\.(\d*)\.(\d*)$/.match(ips.address)
                lbip=ips.address
        end
end



#Block until the LB  finisheses building
until lb.ready?
        puts "Waiting on the LB to finish building..."
        lb.reload
        sleep 10
end


#Now we set up Health Monitoring on it and make an error page.
puts "Setting up health monitor..."
lb.enable_health_monitor("CONNECT", 10, 5, 2)
lb.reload

#Now block until the LB is ready again.
until lb.ready?
        puts "Waiting for the LB to finish setting up the health monitor..."
        lb.reload
        sleep 10
end


puts "Creating custom error page..."
lb.error_page=(errorhtml)



puts "Establishing connection to DNS API..."
#Establish DNS Connection
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


puts "Creating Record for #{fqdn} with IP address #{lbip}..."
z = dnsconn.zones.get(zid)
z.records.create(
        :name => fqdn,
        :type => 'A',
        :value => lbip
)
puts "Record Created."


puts "Establishing connection to Storage API..."

#making CF connection for the last part
cfconn = Fog::Storage.new(
        :provider => 'Rackspace',
        :rackspace_api_key => api_key,
        :rackspace_username => username
)

#Create Container if needed
cont = cfconn.directories.get("backup")
if cont.nil? #again with the not raising exceptions
        puts "Backup container not found, creating."
        cont = cfconn.directories.create(:key => "backup")
end


#Upload the file
puts "Uploading error.html..."
cont.files.create(
        :key => "error.html",
        :body => errorhtml,
        :content_type => "text/html"
)

puts "File uploaded"
puts "Process Completed."