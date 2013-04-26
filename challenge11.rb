#!/usr/bin/env ruby


require 'rubygems'
require 'fog'
require 'openssl'
require './challenge11-config.rb'


#This will read from ~/.rackspace_cloud_credentials
#The format should be
#username=<User>
#api_key=<Api_key>



mutex = Mutex.new
bsmutex = Mutex.new

#Get seed name
unless ARGV.size > 1
        puts "usage: #{$0} baseservername numberofnodes CIDR" 
        exit(1)
end

srvname = ARGV[0]
nmbnode = ARGV[1].to_i
cidr = ARGV[2]


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



#Generate subject line
subject = $values.collect do |x|
		x.collect do |k, v|
			"/#{k}=#{v}"
		end
end.join



#Create a keypair
key = OpenSSL::PKey::RSA.generate(2048)
pub = key.public_key

#Make a new cert and sign it
cert = OpenSSL::X509::Certificate.new
cert.subject = cert.issuer = OpenSSL::X509::Name.parse(subject)
cert.not_before = Time.now
cert.not_after = Time.now + 365 * 24 * 60 * 60
cert.public_key = pub
cert.serial = 0x0
cert.version = 2
cert.sign(key, OpenSSL::Digest::SHA1.new)
 



bsconn = Fog::Rackspace::BlockStorage.new(
	:rackspace_api_key => api_key,
	:rackspace_username => username,
)



#Start all the BS threads
bsthreads = Array.new
vols = Array.new
1.upto(nmbnode) do |var|
	puts "Starting CBS build #{var} out of #{nmbnode}"
	bsthreads << Thread.new do
		vol = bsconn.volumes.create(:size => 100)
		bsmutex.synchronize do
			vols << vol.id
		end
		vol.reload
		until vol.ready?
			sleep 10
			vol.reload
		end
	end
end






compconn = Fog::Compute.new(
	:provider => 'Rackspace',
	:rackspace_api_key => api_key,
	:rackspace_username => username,
	:version => :v2
)



#Create network
network = compconn.networks.create(:label => srvname, :cidr => cidr)
netarray = Array.new
netarray << {:uuid => network.id}
netarray << {:uuid => '00000000-0000-0000-0000-000000000000'}
netarray << {:uuid => '11111111-1111-1111-1111-111111111111'}




#Start all the server threads.
threads = Array.new
servs = Array.new
1.upto(nmbnode) do |var|
	sleep 3
	puts "Starting server build #{var} out of #{nmbnode}"
	threads << Thread.new do
		#There isn't an easy way to add a network, so we call the create_server directly and then mess with the response
		response = compconn.create_server(srvname, 'a10eacf7-ac15-4225-b533-5744f1fe47c1', 2 , 1, 1, {:networks => netarray})    
		server = compconn.servers.get(response.body["server"]["id"])
		mutex.synchronize do
			servs << {'id' => server.id, 'pass' => response.body["server"]["adminPass"]}
		end
		server.reload
		until server.ready?
			sleep 10
			server.reload
		end
	end
end


#Block Until everything is built.
we_be_blockin = true
while we_be_blockin
	threadcounter1 = 0
	threadcounter2 = 0
	threads.each do |t|
		if t.alive?
			threadcounter1 += 1
		end
	end
	bsthreads.each do |t2|
		if t2.alive?
			threadcounter2 += 1
		end
	end
	if threadcounter1 + threadcounter2 == 0
		we_be_blockin = false
	else
		puts "Still Waiting on #{threadcounter1} server(s) and #{threadcounter2} volume(s) to finish building..."
	end
	sleep 10
end	





toadd = Array.new
servs.each_with_index do |s, i|
	serv = compconn.servers.get(s['id'])
	toadd << {:address => serv.private_ip_address, :port => 80, :condition => 'ENABLED'}
	serv.attach_volume(vols[i])
end





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



until lb.ready?
        puts "Waiting on the LB to finish building..."
        lb.reload
        sleep 10
end



lb.enable_ssl_termination(443, key, cert.to_pem)




#Dump ips to STDOUT
lbip=""
lb.virtual_ips.each do |ips|
        if /^(\d*)\.(\d*)\.(\d*)\.(\d*)$/.match(ips.address)
                lbip=ips.address
        end
end


#Establish DNS Connection
dnsconn = Fog::DNS.new(
        :provider => 'Rackspace',
        :rackspace_api_key => api_key,
        :rackspace_username => username,
)


zoneexists = false
zid = ""
dnsconn.zones.all.each do |var|
        if $values.last["CN"] =~ /#{var.domain}/
                zoneexists = true
                zid = var.id
        end
end
unless zoneexists
        raise "No such Zone, check your spelling or create it."
end




puts "Creating Record for #{$values.last["CN"]} with IP address #{lbip}..."
z = dnsconn.zones.get(zid)
z.records.create(
        :name => $values.last["CN"],
        :type => 'A',
        :value => lbip
)
puts "Record Created."





puts "===========Certificate========="
puts cert.to_pem
puts "===========Key================"
puts key

#Dump ips to STDOUT

puts "============#{srvname}-LB Ip addresses==========="
lb.virtual_ips.each do |ips|
	puts ips.address
end



servs.each do |s|
	#Dump it all to STDOUT and build the array to add things to the LB
	serv = compconn.servers.get(s['id'])
	puts "==========#{serv.name} Information========="
	puts "Public IP Address: #{serv.public_ip_address}"
	puts "Password: #{s['pass']}"
end