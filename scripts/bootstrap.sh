#!/usr/bin/env bash

## print servers IP address
echo "The IP of the host $(hostname) is $(hostname -I | awk '{print $2}')"
