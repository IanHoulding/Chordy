#!/usr/bin/perl

###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
#
# This was originally a perl application, called gedi, implementing a text editor.
# gedi is short for Greg's EDItor. The "g" being pronounced like a "j".
##################################################################################

BEGIN {
  use FindBin 1.51 qw( $RealBin );
  use lib (($^O =~ /win32/i) ? $RealBin : ($^O =~ /darwin/i) ? '/Applications/Chordy.app/lib' : '/usr/local/lib/Chordy');
  if ($^O =~ /win32/i) {
    $ENV{PATH} = "C:\\Program Files\\Chordy\\Tcl\\bin;$ENV{PATH}";
  }
}

use strict;
use warnings;

use Tkx;
use Getopt::Std;
use CP::Cconst qw/:OS :PATH/;
use CP::Editor;

###########################################
# check command line parameter.
# if none, start with blank page
# if filename, open file or die
###########################################

our($opt_d,$opt_h);
getopts('dh');

if (defined $opt_h) {
  print "\n$0 expects (optionally) one command line argument: \n";
  print "   the name of the file to edit\n";
  exit(1);
}

if (! -e ERRLOG) {
  open OFH, ">", ERRLOG;
  print OFH "Created: ".localtime."\n";
  close OFH;
}
if (! defined $opt_d) {
  open STDERR, '>>', ERRLOG or die "Can't redirect STDERR: $!";
  if (OS ne 'aqua') {
    open STDOUT, ">&STDERR" or die "Can't dup STDOUT to STDERR: $!";
  }
}

CP::Editor::Edit((@ARGV == 0) ? '' : $ARGV[0]);

#$SIG{CHLD} = sub {wait if (shift eq "CHLD");};

#Tkx::MainLoop();
