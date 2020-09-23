package CP::Line;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

use strict;

use CP::Cconst qw/:MUSIC/;
use CP::Seg;
use CP::Chord;

sub new {
  my($proto,$type,$text,$blk,$bg) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
    blk_no => $blk,
    ly_cnt => 0,
    ch_cnt => 0,
    type   => $type,
    label  => 0,   # Only used before the first line of a Verse/Chorus etc.
    text   => $text,
    bg     => $bg, # this is only set if a colour is defined within a directive.
    segs   => [],
  };
  bless $self, $class;
  return($self);
}

sub measure {
  my($self,$pro,$mypdf) = @_;

  my $x = 0;
  foreach my $s (@{$self->{segs}}) {
    $s->{x} = $x;
    $x += $s->maxlen($pro,$mypdf);
  }
  $x;
}

sub clone {
  my($self,$blk) = @_;
  
  my $l = CP::Line->new($self->{type}, $self->{text}, $blk, $self->{bg});
  $l->{ly_cnt} = $self->{ly_cnt};
  $l->{ch_cnt} = $self->{ch_cnt};
  $l->{segs} = $self->{segs};
  $l->{num} = $self->{num};
  return($l);
}

sub segment {
  my($self,$pro,$line) = @_;

  my $segno = 0;
  # Look for a line starting with anything other than a '['
  # and leave the '[' plus whatever follows to be processed.
  if ($line =~ /^([^\[]+)(.*)/) {
    $line = $2;
    my $seg = CP::Seg->new($1);
    $self->{segs}[$segno++] = $seg;
    $self->{ly_cnt}++;
  }
  return if ($line eq '');
  # What we should have left is (possibly) a chord
  # followed by a bit of lyric - repeated.
  #                  [.....]     1+  anything other than [
  while ($line =~ /(\[([^\]]*)\])?([^\[]*)/g) {
    last if (!defined $2 && !defined $3);
    my $seg = CP::Seg->new($3);
    $self->{ly_cnt}++ if ($3 ne "");
    $self->{segs}[$segno++] = $seg;
    if ($2 ne "") {
      my($chord,$name) = CP::Chord->new($2);
      if (@$chord > 1) {
	my $ch = '';
	for(my $i = 0; $i < @$chord; $i++) {
	  last if ($chord->[$i] =~ /\s+/);
	  $ch .= $chord->[$i];
	}
	$pro->{chords}{$ch} = 1;
      }
      $seg->{chord} = $chord;
      $self->{ch_cnt}++;
    }
  }
}

1;
