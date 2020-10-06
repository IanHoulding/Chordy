#!/Applications/Chordy.app/Chordy
# Windows ignores the above but a Mac needs it.

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

BEGIN {
  use FindBin 1.51 qw( $RealBin );
  use lib (($^O =~ /win32/i) ? $RealBin : ($^O =~ /darwin/i) ? '/Applications/Chordy.app/lib' : '/usr/local/lib/Chordy');
  if ($^O =~ /win32/i) {
    $ENV{PATH} = "C:\\Program Files\\Chordy\\Tcl\\bin;$ENV{PATH}";
  }
}

use strict;
use warnings;

use CP::Cconst qw/:OS :PATH/;
use CP::Global qw/:FUNC :WIN/;
use CP::CHedit;

use Getopt::Std;

our($opt_d);
getopts('d');

if (! -e ERRLOG) {
  open OFH, ">", ERRLOG;
  print OFH "Created: ".localtime."\n";
  close OFH;
}
if (!defined $opt_d) {
  open STDERR, '>>', ERRLOG or die "Can't redirect STDERR: $!";
  if (OS eq 'aqua') {
    open STDOUT, ">&STDERR" or die "Can't dup STDOUT to STDERR: $!";
  }
}

CHedit('Save');

$SIG{CHLD} = sub {wait if (shift eq "CHLD");};

$MW->g_wm_deiconify();
$MW->g_raise();
Tkx::MainLoop();
