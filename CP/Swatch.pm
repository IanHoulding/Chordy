package CP::Swatch;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

use strict;

use CP::Global qw/:FUNC :OPT/;

sub new {
  my($proto) = @_;
  my $class = ref($proto) || $proto;

  my $self = [];
  bless $self, $class;

  if (-e "$Path->{Swatch}") {
    load($self);
  } else {
    $self = [qw/#ffe0e0 #ffffe0 #ffe0ff #e0ffe0 #e0ffff #e0e0ff #ffe4b5 #eee886
	     #700070 #b00000 #009000 #0000b0 #eec900 #407070 #ee00ee #ee9572/];
    save($self);
  }
  return($self);
}

sub set {
  my($self, @list) = @_;

  foreach my $i (0..$#list) {
    $self->[$i] = $list[$i];
  }
}

sub load {
  my($self) = shift;

  our @swatch;
  do "$Path->{Swatch}";
  set($self, @swatch);
}

sub save {
  my($self) = shift;

  my $OFH = openConfig("$Path->{Swatch}");
  return(0) if ($OFH == 0);

  print $OFH "\@swatch = (qw/".join(' ', @{$self})."/);\n1;\n";

  close($OFH);
}

1;
