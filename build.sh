#!/bin/sh

git submodule update --init --recursive; make PREFIX="${HOME}/SwiftLint" prefix_install 
