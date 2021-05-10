#!/bin/bash

wget https://golang.org/dl/go1.16.3.linux-amd64.tar.gz
rm -rf /usr/local/go
tar -C /usr/local -xzf go1.16.3.linux-amd64.tar.gz
ln -s /usr/local/go/bin/go /usr/bin/go
export PATH=$PATH:/usr/local/go/bin