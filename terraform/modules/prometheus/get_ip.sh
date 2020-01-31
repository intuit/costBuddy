#!/bin/bash

# Get the public IP address of the system where you are running the 
# terrafrom scripts

my_ip=`curl -s --retry 3 http://checkip.amazonaws.com`


if [[ ! -z $my_ip ]];
then
	echo -n "{\"result\": \"$my_ip/32\"}"
else
	echo -n "{\"no_result\": \"\"}"
fi

# returns a string in JSON format {"result" : "<yout public IP address>"}
# for the terraform external to process
