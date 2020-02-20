#!/usr/bin/perl
# Hace eco de las variables de ambiente en modo text/plain
#
# Desarrollo:
# 1.0 - Primera versi—n.

print "Content-Type: text/plain\n\n";

print "\n\n";

  foreach $key (keys(%ENV)) {
             print "$key = $ENV{$key}\n";
         };


