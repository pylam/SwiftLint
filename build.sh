#!/bin/sh

git submodule update --init --recursive; make PREFIX=~/SwiftLint prefix_install 
