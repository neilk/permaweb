#!/usr/bin/perl -wl

while (<>) {
  s/<\/body>//g and print;
}