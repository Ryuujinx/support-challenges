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



Notes
=====

* The ~/.rackspace_cloud_credentials are expected to be in the format that is in the repo and located in that location. All scripts have a manual override if you want to just plug in your credentials there.
* Challenge1.rb will build web1/2/3. This is not configurable. 
* Challenge2.rb will work with either a UUID or Server Name. It only works with nextgen. If you use a server name, and you have two servers named the same thing, it will use the first one returned by the API. 


