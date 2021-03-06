support-challenges
==================

Various API Challenges for support. 


Requirements
===========
* Ruby 1.9.x
* Fog(https://github.com/rackspace/fog)


Challenge 1
==========
* Write a script that builds three 512 MB Cloud Servers that following a similar naming convention. (ie., web1, web2, web3) and returns the IP and login credentials for each server. Use any image you want


Challenge 2
===========
* Write a script that clones a server (takes an image and deploys the image as a new server).

Challenge 3
===========
* Write a script that accepts a directory as an argument as well as a container name. The script should upload the contents of the specified directory to the container (or create it if it doesn't exist). The script should handle errors appropriately. (Check for invalid paths, etc.)

Challenge 4
===========
* Write a script that uses Cloud DNS to create a new A record when passed a FQDN and IP address as arguments.


Challenge 5
===========
* Write a script that creates a Cloud Database instance. This instance should contain at least one database, and the database should have at least one user that can connect to it

Challenge 6
==========
* Write a script that creates a CDN-enabled container in Cloud Files.

Challenge 7
==========
* Write a script that will create 2 Cloud Servers and add them as nodes to a new Cloud Load Balancer. 

Challenge 8
==========
* Write a script that will create a static webpage served out of Cloud Files. The script must create a new container, cdn enable it, enable it to serve an index file, create an index file object, upload the object to the container, and create a CNAME record pointing to the CDN URL of the container.

Challenge 9
==========
* Write an application that when passed the arguments FQDN, image, and flavor it creates a server of the specified image and flavor with the same name as the fqdn, and creates a DNS entry for the fqdn pointing to the server's public IP.

Challenge 10
===========
Write an application that:
* Creates 2 servers, supplying a ssh key to be installed at /root/.ssh/authorized_keys.
* Creates a load balancer
* Adds the 2 new servers to the LB
* Sets up LB monitor and custom error page.
* Creates a DNS record based on a FQDN for the LB VIP.
* Write the error page html to a file in cloud files for backup.

Challenge 11
==========
Write an application that:
* Creates an SSL terminated load balancer (Create self-signed certificate.)
* Creates a DNS record that should be pointed to the load balancer.
* Creates Three servers as nodes behind the LB.
* Each server should have a CBS volume attached to it. (Size and type are irrelevant.)
* All three servers should have a private Cloud Network shared between them.
* Login information to all three servers returned in a readable format as the result of the script, including connection information.


Notes
=====

* The ~/.rackspace_cloud_credentials are expected to be in the format that is in the repo and located in that location. All scripts have a manual override if you want to just plug in your credentials there.
* Most challenges accept a numberofnodes instead of having building a static number of nodes. 
* challenge1.rb will build [seedname]1/2/3. This is not configurable. 
* challenge2.rb will work with either a UUID or Server Name. It only works with nextgen. If you use a server name, and you have two servers named the same thing, it will use the first one returned by the API.
* challenge4.rb requires a valid IPv4 address and the zone to already exist. 
* challenge6.rb will create an empty container if it does not exist, or enable an already existing container. 
* challenge7.rb will name the servers [seedname]-1/2/(howevermany you specify) and the load balancer [seedname]-lb
* challenge10.rb will requires an error.html and sshkey.pub in the working direcrly. It will upload the error file to a container named Backup and will write it to error.html. It will overwrite any existing error.html, because that's how it works.
* Challenge11.rb requires openssl in order to generate a cert. It also requires you modify the challenge11-config.rb file to adjust the cert you generate. THis file is how it determines the fqdn as well.  
