#!/bin/bash
mkdir -p package
pip3 install --target ./package/ -r requirements.txt
cd package
zip -r9 ../process-request.zip .
cd ..
zip -g process-request.zip process-request.py
rm -rf package