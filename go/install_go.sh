#!/bin/bash

export GOVERSION=`curl -L https://golang.org/VERSION?m=text`
wget "https://dl.google.com/go/$GOVERSION.linux-amd64.tar.gz"
rm -rf /usr/local/go
tar -C /usr/local -xzf $GOVERSION.linux-amd64.tar.gz
ln -s /usr/local/go/bin/go /usr/bin/go
export PATH=$PATH:/usr/local/go/bin
