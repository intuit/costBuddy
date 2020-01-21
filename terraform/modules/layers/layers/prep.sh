#!/bin/bash

rm -rf /foo/python

pip install -r /foo/requirements.txt --no-deps -t /foo/python


exit 0
