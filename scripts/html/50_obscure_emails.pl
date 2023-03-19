#!/usr/bin/perl -wln

s/(\w+)@([\w\.]+?)\.(\w+)/$1 . ' at ' . $2 . ' dot ' . $3/ge;

print;