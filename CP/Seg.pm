package CP::Seg;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

use strict;
use warnings;

use CP::Global qw/:OPT/;

my $BG = '';

sub new {
  my($proto,$text) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    x     => 0,
    lyric => "$text",
    bg    => '',
  };
  bless $self, $class;
  return($self);
}

sub maxlen {
  my($self,$pro,$mypdf) = @_;

  my($cl,$ll) = _measure($self,$pro,$mypdf);
  return(($cl > $ll) ? $cl : $ll);
}

sub _measure {
  my($self,$pro,$mypdf) = @_;

  my $cl =  my $ll = 0;
  if ($Opt->{LyricOnly} == 0) {
    $cl = $mypdf->chordLen($self->{chord}->trans2obj($pro)) if (defined $self->{chord});
  }
  if ($self->{lyric} ne '') {
    $ll = $mypdf->lyricLen($self->{lyric});
  }
  ($cl,$ll);
}

1;
