package CP::Chord;

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

use CP::Global qw/$Opt $KeyShift $Nstring $Scale @Fscale/;

#
# Returns the chord part of the string as individual elements in an array
# and also the chord as a string. (Removes any parentheses G#(maj7) -> G#maj7 )
#
sub new {
  my($proto,$c) = @_;
  my $class = ref($proto) || $proto;
  my $self = [];
  #            1         2      3               4         5      6             7
  if ($c =~ /^([A-G]{1})([#b]?)([\(\)a-z\d]*)\/([A-G]{1})([#b]?)([\(\)a-z\d]*)(\s*.*)/) {
    # Find 'C/G text' with any variants to the chord component
    $self = [$1, $2, $3, '/', $4, $5, $6, $7];
    $self->[2] =~ s/[()]//g;
    $self->[6] =~ s/[()]//g;
    $c = join('', @$self);
  #                 1         2      3             4
  } elsif ($c =~ /^([A-G]{1})([#b]?)([\(\)a-z\d]*)(\s*.*)/) {
    # Find 'C text' with any variants to the chord component
    # Will also pick up C//
    $self = [$1, $2, $3, $4];
    $self->[2] =~ s/[()]//g;
    $c = join('', @$self);
  } else {
    # Not a chord - just text
    $self = [$c];
    $c = "";
  }
  bless $self, $class;
  ($self,$c);
}

# Transpose a Chord object and return a string.
sub trans2str {
  my($self,$pro) = @_;

  my $ch = "";
  if ($KeyShift && $self->[0] =~ /^[A-G]/) {
    my($a,$b) = _tr($pro,$self->[0],$self->[1]);
    if (@$self > 1) {
      $ch = $a.$b.$self->[2].$self->[3];
      if (@$self > 4) {
	($a,$b) = _tr($pro,$self->[4],$self->[5]);
	$ch .= $a.$b.$self->[6].$self->[7];
      }
    } else {
      $ch = $a;
    }
  } else {
    $ch = join('', @{$self});
  }
  $ch;
}

# Transpose a Chord object and return it.
sub trans2obj {
  my($self,$pro) = @_;

  if ($KeyShift && $self->[0] =~ /^[A-G]/) {
    my $copy = [];
    foreach (@$self) {
      push(@$copy, $_);
    }
    if (@$copy > 1) {
      ($copy->[0],$copy->[1]) = _tr($pro,$copy->[0],$copy->[1]);
      if (@$self > 4) {
	($copy->[4],$copy->[5]) = _tr($pro,$copy->[4],$copy->[5]);
      }
    }
    bless $copy, "CP::Chord";
    return $copy;
  } else {
    return $self;
  }
}

sub _tr {
  my($pro,$c,$sf) = @_;

  my $i = 0;
  while ($c ne $Scale->[$i]) {
    $i++;
  }
  $i += $KeyShift;
  $i += ($sf eq '#') ? 1 : ($sf eq 'b') ? -1 : 0;
  $i %= 12;
  $c = $Scale->[$i];
  if ($c =~ /[a-g]/) {
    $c = uc($c);
    $sf = ($Scale == \@Fscale) ? 'b' : '#';
  } else {
    $sf = "";
  }
  return($c,$sf);
}

my %Tune = (
  Banjo    => 'G D G B D',
  Bass4    => 'E A D G',
  Bass5    => 'B E A D G',
  Mandolin => 'G D A E',
  Ukelele  => 'G C E A',
    );
sub makeFile {
  my($home) = shift;

  foreach my $c (@{$Opt->{Instruments}}) {
    next if ($c eq 'Guitar');
    my $ns = ($c eq 'Bass5' || $c eq 'Banjo') ? 5 : 4;
    open OFH, '>', "$home/$c.chd";
    print OFH "#!/usr/bin/perl\n";
    print OFH "\$Nstring = $ns;\n";
    print OFH "\@Tuning = (qw/$Tune{$c}/);\n";
    print OFH "%Fingers = ();\n";
    print OFH "1;\n";
    close(OFH);
  }
  open OFH, '>', "$home/Guitar.chd";
  print OFH "#!/usr/bin/perl\n";
  print OFH "\$Nstring = 6;\n";
  print OFH "\@Tuning = (qw/E A D G B E/);\n";
  print OFH <<'EOT';
%Fingers = (
'A'=>{base=>1,fret=>[qw/0 0 2 2 2 0/]},
'A#'=>{base=>1,fret=>[qw/X 1 3 3 3 1/]},
'A#+'=>{base=>1,fret=>[qw/X X 0 3 3 2/]},
'A#4'=>{base=>1,fret=>[qw/X X 3 3 4 1/]},
'A#7'=>{base=>3,fret=>[qw/X X 1 1 1 2/]},
'A#dim'=>{base=>1,fret=>[qw/X X 2 3 2 3/]},
'A#m'=>{base=>1,fret=>[qw/X 1 3 3 2 1/]},
'A#m7'=>{base=>1,fret=>[qw/X 1 3 1 2 1/]},
'A#maj'=>{base=>1,fret=>[qw/X 1 3 3 3 1/]},
'A#maj7'=>{base=>1,fret=>[qw/X 1 3 2 3 X/]},
'A#m'=>{base=>1,fret=>[qw/X 1 3 3 2 1/]},
'A#sus'=>{base=>1,fret=>[qw/X X 3 3 4 1/]},
'A#sus4'=>{base=>1,fret=>[qw/X X 3 3 4 1/]},
'A+'=>{base=>1,fret=>[qw/X 0 3 2 2 1/]},
'A/D'=>{base=>1,fret=>[qw/X X 0 0 2 2/]},
'A/F#'=>{base=>1,fret=>[qw/2 0 2 2 2 0/]},
'A/G#'=>{base=>1,fret=>[qw/4 0 2 2 2 0/]},
'A11'=>{base=>1,fret=>[qw/X 4 2 4 3 3/]},
'A13'=>{base=>5,fret=>[qw/X 0 1 2 3 1/]},
'A4'=>{base=>1,fret=>[qw/0 0 2 2 0 0/]},
'A6'=>{base=>1,fret=>[qw/X X 2 2 2 2/]},
'A7'=>{base=>1,fret=>[qw/X 0 2 0 2 0/]},
'A7(9+)'=>{base=>1,fret=>[qw/X 2 2 2 2 3/]},
'A7+'=>{base=>1,fret=>[qw/X X 3 2 2 1/]},
'A7sus4'=>{base=>1,fret=>[qw/0 0 2 0 3 0/]},
'A9'=>{base=>1,fret=>[qw/X 0 2 1 0 0/]},
'A9sus'=>{base=>1,fret=>[qw/X 0 2 1 0 0/]},
'Ab'=>{base=>4,fret=>[qw/1 3 3 2 1 1/]},
'Ab+'=>{base=>1,fret=>[qw/X X 2 1 1 0/]},
'Ab11'=>{base=>4,fret=>[qw/1 3 1 3 1 1/]},
'Ab4'=>{base=>1,fret=>[qw/X X 1 1 2 4/]},
'Ab7'=>{base=>1,fret=>[qw/X X 1 1 1 2/]},
'Abdim'=>{base=>1,fret=>[qw/X X 0 1 0 1/]},
'Abm'=>{base=>4,fret=>[qw/1 3 3 1 1 1/]},
'Abm7'=>{base=>4,fret=>[qw/X X 1 1 1 1/]},
'Abmaj'=>{base=>4,fret=>[qw/1 3 3 2 1 1/]},
'Abmaj7'=>{base=>1,fret=>[qw/X X 1 1 1 3/]},
'Abm'=>{base=>4,fret=>[qw/1 3 3 1 1 1/]},
'Absus'=>{base=>1,fret=>[qw/X X 1 1 2 4/]},
'Absus4'=>{base=>1,fret=>[qw/X X 1 1 2 4/]},
'Adim'=>{base=>1,fret=>[qw/X X 1 2 1 2/]},
'Am'=>{base=>1,fret=>[qw/X 0 2 2 1 0/]},
'Am#7'=>{base=>1,fret=>[qw/X X 2 1 1 0/]},
'Am(7#)'=>{base=>1,fret=>[qw/X 0 2 2 1 4/]},
'Am/G'=>{base=>1,fret=>[qw/3 0 2 2 1 0/]},
'Am6'=>{base=>1,fret=>[qw/X 0 2 2 1 2/]},
'Am7'=>{base=>1,fret=>[qw/X 0 2 2 1 3/]},
'Am7sus4'=>{base=>1,fret=>[qw/0 0 0 0 3 0/]},
'Am9'=>{base=>5,fret=>[qw/X 0 1 1 1 3/]},
'Amadd9'=>{base=>1,fret=>[qw/0 2 2 2 1 0/]},
'Amaj'=>{base=>1,fret=>[qw/X 0 2 2 2 0/]},
'Amaj7'=>{base=>1,fret=>[qw/X 0 2 1 2 0/]},
'Am'=>{base=>1,fret=>[qw/X 0 2 2 1 0/]},
'Asus'=>{base=>1,fret=>[qw/X X 2 2 3 0/]},
'Asus2'=>{base=>1,fret=>[qw/0 0 2 2 0 0/]},
'Asus4'=>{base=>1,fret=>[qw/X X 2 2 3 0/]},
'B'=>{base=>1,fret=>[qw/X 2 4 4 4 2/]},
'B+'=>{base=>1,fret=>[qw/X X 1 0 0 4/]},
'B/F#'=>{base=>2,fret=>[qw/0 2 2 2 0 0/]},
'B11'=>{base=>7,fret=>[qw/1 3 3 2 0 0/]},
'B11/13'=>{base=>2,fret=>[qw/X 1 1 1 1 3/]},
'B13'=>{base=>1,fret=>[qw/X 2 1 2 0 4/]},
'B4'=>{base=>2,fret=>[qw/X X 3 3 4 1/]},
'B7'=>{base=>1,fret=>[qw/0 2 1 2 0 2/]},
'B7#9'=>{base=>1,fret=>[qw/X 2 1 2 3 X/]},
'B7(#9)'=>{base=>1,fret=>[qw/X 2 1 2 3 X/]},
'B7+'=>{base=>1,fret=>[qw/X 2 1 2 0 3/]},
'B7+5'=>{base=>1,fret=>[qw/X 2 1 2 0 3/]},
'B9'=>{base=>7,fret=>[qw/1 3 1 2 1 3/]},
'BaddE'=>{base=>1,fret=>[qw/X 2 4 4 0 0/]},
'BaddE/F#'=>{base=>1,fret=>[qw/2 X 4 4 0 0/]},
'Bb'=>{base=>1,fret=>[qw/X 1 3 3 3 1/]},
'Bb+'=>{base=>1,fret=>[qw/X X 0 3 3 2/]},
'Bb11'=>{base=>6,fret=>[qw/1 3 1 3 4 1/]},
'Bb4'=>{base=>1,fret=>[qw/X X 3 3 4 1/]},
'Bb6'=>{base=>1,fret=>[qw/X X 3 3 3 3/]},
'Bb7'=>{base=>3,fret=>[qw/X X 1 1 1 2/]},
'Bb9'=>{base=>6,fret=>[qw/1 3 1 2 1 3/]},
'Bbdim'=>{base=>1,fret=>[qw/X X 2 3 2 3/]},
'Bbm'=>{base=>1,fret=>[qw/X 1 3 3 2 1/]},
'Bbm7'=>{base=>1,fret=>[qw/X 1 3 1 2 1/]},
'Bbm9'=>{base=>6,fret=>[qw/X X X 1 1 3/]},
'Bbmaj'=>{base=>1,fret=>[qw/X 1 3 3 3 1/]},
'Bbmaj7'=>{base=>1,fret=>[qw/X 1 3 2 3 X/]},
'Bbm'=>{base=>1,fret=>[qw/X 1 3 3 2 1/]},
'Bbsus'=>{base=>1,fret=>[qw/X X 3 3 4 1/]},
'Bbsus4'=>{base=>1,fret=>[qw/X X 3 3 4 1/]},
'Bdim'=>{base=>1,fret=>[qw/X X 0 1 0 1/]},
'Bm'=>{base=>1,fret=>[qw/X 2 4 4 3 2/]},
'Bm6'=>{base=>1,fret=>[qw/X X 4 4 3 4/]},
'Bm7'=>{base=>2,fret=>[qw/X 1 3 1 2 1/]},
'Bm7b5'=>{base=>1,fret=>[qw/1 2 4 2 3 1/]},
'Bmaj'=>{base=>1,fret=>[qw/X 2 4 3 4 X/]},
'Bmaj7'=>{base=>1,fret=>[qw/X 2 4 3 4 X/]},
'Bm'=>{base=>1,fret=>[qw/X 2 4 4 3 2/]},
'Bmmaj7'=>{base=>1,fret=>[qw/X 1 4 4 3 X/]},
'Bmsus9'=>{base=>1,fret=>[qw/X X 4 4 2 2/]},
'Bsus'=>{base=>2,fret=>[qw/X X 3 3 4 1/]},
'Bsus4'=>{base=>2,fret=>[qw/X X 3 3 4 1/]},
'C'=>{base=>1,fret=>[qw/X 3 2 0 1 0/]},
'C#'=>{base=>1,fret=>[qw/X X 3 1 2 1/]},
'C#+'=>{base=>1,fret=>[qw/X X 3 2 2 1/]},
'C#4'=>{base=>4,fret=>[qw/X X 3 3 4 1/]},
'C#7'=>{base=>1,fret=>[qw/X X 3 4 2 4/]},
'C#7(b5)'=>{base=>1,fret=>[qw/X 2 1 2 1 2/]},
'C#add9'=>{base=>4,fret=>[qw/X 1 3 3 1 1/]},
'C#dim'=>{base=>1,fret=>[qw/X X 2 3 2 3/]},
'C#m'=>{base=>1,fret=>[qw/X X 2 1 2 0/]},
'C#m7'=>{base=>1,fret=>[qw/X X 2 4 2 4/]},
'C#maj'=>{base=>1,fret=>[qw/X 4 3 1 1 1/]},
'C#maj7'=>{base=>1,fret=>[qw/X 4 3 1 1 1/]},
'C#m'=>{base=>1,fret=>[qw/X X 2 1 2 0/]},
'C#sus'=>{base=>4,fret=>[qw/X X 3 3 4 1/]},
'C#sus4'=>{base=>4,fret=>[qw/X X 3 3 4 1/]},
'C+'=>{base=>1,fret=>[qw/X X 2 1 1 0/]},
'C/B'=>{base=>1,fret=>[qw/X 2 2 0 1 0/]},
'C11'=>{base=>3,fret=>[qw/X 1 3 1 4 1/]},
'C3'=>{base=>3,fret=>[qw/X 1 3 3 2 1/]},
'C4'=>{base=>1,fret=>[qw/X X 3 0 1 3/]},
'C6'=>{base=>1,fret=>[qw/X 0 2 2 1 3/]},
'C7'=>{base=>1,fret=>[qw/0 3 2 3 1 0/]},
'C9'=>{base=>8,fret=>[qw/1 3 1 2 1 3/]},
'C9(11)'=>{base=>1,fret=>[qw/X 3 3 3 3 X/]},
'Cadd2/B'=>{base=>1,fret=>[qw/X 2 0 0 1 0/]},
'Cadd9'=>{base=>1,fret=>[qw/X 3 2 0 3 0/]},
'Cdim'=>{base=>1,fret=>[qw/X X 1 2 1 2/]},
'Cm'=>{base=>3,fret=>[qw/X 1 3 3 2 1/]},
'Cm11'=>{base=>3,fret=>[qw/X 1 3 1 4 X/]},
'Cm7'=>{base=>3,fret=>[qw/X 1 3 1 2 1/]},
'Cmaj'=>{base=>1,fret=>[qw/0 3 2 0 1 0/]},
'Cmaj7'=>{base=>1,fret=>[qw/X 3 2 0 0 0/]},
'Cm'=>{base=>3,fret=>[qw/X 1 3 3 2 1/]},
'Csus'=>{base=>1,fret=>[qw/X X 3 0 1 3/]},
'Csus2'=>{base=>1,fret=>[qw/X 3 0 0 1 X/]},
'Csus4'=>{base=>1,fret=>[qw/X X 3 0 1 3/]},
'Csus9'=>{base=>7,fret=>[qw/X X 4 1 2 4/]},
'D'=>{base=>1,fret=>[qw/X X 0 2 3 2/]},
'D#'=>{base=>3,fret=>[qw/X X 3 1 2 1/]},
'D#+'=>{base=>1,fret=>[qw/X X 1 0 0 4/]},
'D#4'=>{base=>1,fret=>[qw/X X 1 3 4 4/]},
'D#7'=>{base=>1,fret=>[qw/X X 1 3 2 3/]},
'D#dim'=>{base=>1,fret=>[qw/X X 1 2 1 2/]},
'D#m'=>{base=>1,fret=>[qw/X X 4 3 4 2/]},
'D#m7'=>{base=>1,fret=>[qw/X X 1 3 2 2/]},
'D#maj'=>{base=>3,fret=>[qw/X X 3 1 2 1/]},
'D#maj7'=>{base=>1,fret=>[qw/X X 1 3 3 3/]},
'D#m'=>{base=>1,fret=>[qw/X X 4 3 4 2/]},
'D#sus'=>{base=>1,fret=>[qw/X X 1 3 4 4/]},
'D#sus4'=>{base=>1,fret=>[qw/X X 1 3 4 4/]},
'D+'=>{base=>1,fret=>[qw/X X 0 3 3 2/]},
'D/A'=>{base=>1,fret=>[qw/X 0 0 2 3 2/]},
'D/B'=>{base=>1,fret=>[qw/X 2 0 2 3 2/]},
'D/C'=>{base=>1,fret=>[qw/X 3 0 2 3 2/]},
'D/C#'=>{base=>1,fret=>[qw/X 4 0 2 3 2/]},
'D/E'=>{base=>7,fret=>[qw/X 1 1 1 1 X/]},
'D/G'=>{base=>1,fret=>[qw/3 X 0 2 3 2/]},
'D11'=>{base=>1,fret=>[qw/3 0 0 2 1 0/]},
'D4'=>{base=>1,fret=>[qw/X X 0 2 3 3/]},
'D5/E'=>{base=>7,fret=>[qw/0 1 1 1 X X/]},
'D6'=>{base=>1,fret=>[qw/X 0 0 2 0 2/]},
'D7'=>{base=>1,fret=>[qw/X X 0 2 1 2/]},
'D7(#9)'=>{base=>4,fret=>[qw/X 2 1 2 3 3/]},
'D7sus2'=>{base=>1,fret=>[qw/X 0 0 2 1 0/]},
'D7sus4'=>{base=>1,fret=>[qw/X 0 0 2 1 3/]},
'D9'=>{base=>10,fret=>[qw/1 3 1 2 1 3/]},
'D9add6'=>{base=>10,fret=>[qw/1 3 3 2 0 0/]},
'Dadd9'=>{base=>1,fret=>[qw/0 0 0 2 3 2/]},
'Db'=>{base=>1,fret=>[qw/X X 3 1 2 1/]},
'Db+'=>{base=>1,fret=>[qw/X X 3 2 2 1/]},
'Db7'=>{base=>1,fret=>[qw/X X 3 4 2 4/]},
'Dbdim'=>{base=>1,fret=>[qw/X X 2 3 2 3/]},
'Dbm'=>{base=>1,fret=>[qw/X X 2 1 2 0/]},
'Dbm7'=>{base=>1,fret=>[qw/X X 2 4 2 4/]},
'Dbmaj'=>{base=>1,fret=>[qw/X X 3 1 2 1/]},
'Dbmaj7'=>{base=>1,fret=>[qw/X 4 3 1 1 1/]},
'Dbm'=>{base=>1,fret=>[qw/X X 2 1 2 0/]},
'Dbsus'=>{base=>4,fret=>[qw/X X 3 3 4 1/]},
'Dbsus4'=>{base=>4,fret=>[qw/X X 3 3 4 1/]},
'Ddim'=>{base=>1,fret=>[qw/X X 0 1 0 1/]},
'Dm'=>{base=>1,fret=>[qw/X X 0 2 3 1/]},
'Dm(#5)'=>{base=>1,fret=>[qw/X X 0 3 3 2/]},
'Dm(#7)'=>{base=>1,fret=>[qw/X X 0 2 2 1/]},
'Dm/A'=>{base=>1,fret=>[qw/X 0 0 2 3 1/]},
'Dm/B'=>{base=>1,fret=>[qw/X 2 0 2 3 1/]},
'Dm/C'=>{base=>1,fret=>[qw/X 3 0 2 3 1/]},
'Dm/C#'=>{base=>1,fret=>[qw/X 4 0 2 3 1/]},
'Dm6(5b)'=>{base=>1,fret=>[qw/X X 0 1 0 1/]},
'Dm7'=>{base=>1,fret=>[qw/X X 0 2 1 1/]},
'Dm9'=>{base=>1,fret=>[qw/X X 3 2 1 0/]},
'Dmaj'=>{base=>1,fret=>[qw/X X 0 2 3 2/]},
'Dmaj7'=>{base=>1,fret=>[qw/X X 0 2 2 2/]},
'Dm'=>{base=>1,fret=>[qw/X X 0 2 3 1/]},
'Dsus'=>{base=>1,fret=>[qw/X X 0 2 3 3/]},
'Dsus2'=>{base=>1,fret=>[qw/0 0 0 2 3 0/]},
'Dsus4'=>{base=>1,fret=>[qw/X X 0 2 3 3/]},
'E'=>{base=>1,fret=>[qw/0 2 2 1 0 0/]},
'E+'=>{base=>1,fret=>[qw/X X 2 1 1 0/]},
'E11'=>{base=>1,fret=>[qw/1 1 1 1 2 2/]},
'E5'=>{base=>7,fret=>[qw/0 1 3 3 X X/]},
'E6'=>{base=>9,fret=>[qw/X X 3 3 3 3/]},
'E7'=>{base=>1,fret=>[qw/0 2 2 1 3 0/]},
'E7(#9)'=>{base=>1,fret=>[qw/0 2 2 1 3 3/]},
'E7(11)'=>{base=>1,fret=>[qw/0 2 2 2 3 0/]},
'E7(5b)'=>{base=>1,fret=>[qw/X 1 0 1 3 0/]},
'E7(b9)'=>{base=>1,fret=>[qw/0 2 0 1 3 2/]},
'E7b9'=>{base=>1,fret=>[qw/0 2 0 1 3 2/]},
'E9'=>{base=>1,fret=>[qw/1 3 1 2 1 3/]},
'Eb'=>{base=>3,fret=>[qw/X X 3 1 2 1/]},
'Eb+'=>{base=>1,fret=>[qw/X X 1 0 0 4/]},
'Eb4'=>{base=>1,fret=>[qw/X X 1 3 4 4/]},
'Eb7'=>{base=>1,fret=>[qw/X X 1 3 2 3/]},
'Ebadd9'=>{base=>1,fret=>[qw/X 1 1 3 4 1/]},
'Ebdim'=>{base=>1,fret=>[qw/X X 1 2 1 2/]},
'Ebm'=>{base=>1,fret=>[qw/X X 4 3 4 2/]},
'Ebm7'=>{base=>1,fret=>[qw/X X 1 3 2 2/]},
'Ebmaj'=>{base=>1,fret=>[qw/X X 1 3 3 3/]},
'Ebmaj7'=>{base=>1,fret=>[qw/X X 1 3 3 3/]},
'Ebm'=>{base=>1,fret=>[qw/X X 4 3 4 2/]},
'Ebsus'=>{base=>1,fret=>[qw/X X 1 3 4 4/]},
'Ebsus4'=>{base=>1,fret=>[qw/X X 1 3 4 4/]},
'Edim'=>{base=>1,fret=>[qw/X X 2 3 2 3/]},
'Em'=>{base=>1,fret=>[qw/0 2 2 0 0 0/]},
'Em/B'=>{base=>1,fret=>[qw/X 2 2 0 0 0/]},
'Em/D'=>{base=>1,fret=>[qw/X X 0 0 0 0/]},
'Em6'=>{base=>1,fret=>[qw/0 2 2 0 2 0/]},
'Em7'=>{base=>1,fret=>[qw/0 2 2 0 3 0/]},
'Em7/D'=>{base=>1,fret=>[qw/X X 0 0 0 0/]},
'Emadd9'=>{base=>1,fret=>[qw/0 2 4 0 0 0/]},
'Emaj'=>{base=>1,fret=>[qw/0 2 2 1 0 0/]},
'Emaj7'=>{base=>1,fret=>[qw/0 2 1 1 0 X/]},
'Em'=>{base=>1,fret=>[qw/0 2 2 0 0 0/]},
'Emsus4'=>{base=>1,fret=>[qw/0 0 2 0 0 0/]},
'Esus'=>{base=>1,fret=>[qw/0 2 2 2 0 0/]},
'Esus4'=>{base=>1,fret=>[qw/0 2 2 2 0 0/]},
'F'=>{base=>1,fret=>[qw/1 3 3 2 1 1/]},
'F#'=>{base=>1,fret=>[qw/2 4 4 3 2 2/]},
'F#+'=>{base=>1,fret=>[qw/X X 4 3 3 2/]},
'F#/E'=>{base=>1,fret=>[qw/0 4 4 3 2 2/]},
'F#11'=>{base=>1,fret=>[qw/2 4 2 4 2 2/]},
'F#4'=>{base=>1,fret=>[qw/X X 4 4 2 2/]},
'F#7'=>{base=>1,fret=>[qw/X X 4 3 2 0/]},
'F#9'=>{base=>1,fret=>[qw/X 1 2 1 2 2/]},
'F#dim'=>{base=>1,fret=>[qw/X X 1 2 1 2/]},
'F#m'=>{base=>1,fret=>[qw/2 4 4 2 2 2/]},
'F#m/C#m'=>{base=>1,fret=>[qw/X X 4 2 2 2/]},
'F#m6'=>{base=>1,fret=>[qw/X X 1 2 2 2/]},
'F#m7'=>{base=>1,fret=>[qw/X X 2 2 2 2/]},
'F#m7-5'=>{base=>2,fret=>[qw/1 0 2 3 3 3/]},
'F#maj'=>{base=>1,fret=>[qw/2 4 4 3 2 2/]},
'F#maj7'=>{base=>1,fret=>[qw/X X 4 3 2 1/]},
'F#m'=>{base=>1,fret=>[qw/2 4 4 2 2 2/]},
'F#sus'=>{base=>1,fret=>[qw/X X 4 4 2 2/]},
'F#sus4'=>{base=>1,fret=>[qw/X X 4 4 2 2/]},
'F+'=>{base=>1,fret=>[qw/X X 3 2 2 1/]},
'F+7+11'=>{base=>1,fret=>[qw/1 3 3 2 0 0/]},
'F/A'=>{base=>1,fret=>[qw/X 0 3 2 1 1/]},
'F/C'=>{base=>1,fret=>[qw/X X 3 2 1 1/]},
'F/D'=>{base=>1,fret=>[qw/X X 0 2 1 1/]},
'F/G'=>{base=>1,fret=>[qw/3 3 3 2 1 1/]},
'F11'=>{base=>1,fret=>[qw/1 3 1 3 1 1/]},
'F4'=>{base=>1,fret=>[qw/X X 3 3 1 1/]},
'F6'=>{base=>1,fret=>[qw/X 3 3 2 3 X/]},
'F7'=>{base=>1,fret=>[qw/1 3 1 2 1 1/]},
'F7/A'=>{base=>1,fret=>[qw/X 0 3 0 1 1/]},
'F9'=>{base=>1,fret=>[qw/2 4 2 3 2 4/]},
'Fadd9'=>{base=>1,fret=>[qw/3 0 3 2 1 1/]},
'FaddG'=>{base=>1,fret=>[qw/1 X 3 2 1 3/]},
'Fdim'=>{base=>1,fret=>[qw/X X 0 1 0 1/]},
'Fm'=>{base=>1,fret=>[qw/1 3 3 1 1 1/]},
'Fm6'=>{base=>1,fret=>[qw/X X 0 1 1 1/]},
'Fm7'=>{base=>1,fret=>[qw/1 3 1 1 1 1/]},
'Fmaj'=>{base=>1,fret=>[qw/1 3 3 2 1 1/]},
'Fmaj7'=>{base=>1,fret=>[qw/X 3 3 2 1 0/]},
'Fmaj7(+5)'=>{base=>1,fret=>[qw/X X 3 2 2 0/]},
'Fmaj7/A'=>{base=>1,fret=>[qw/X 0 3 2 1 0/]},
'Fmaj7/C'=>{base=>1,fret=>[qw/X 3 3 2 1 0/]},
'Fm'=>{base=>1,fret=>[qw/1 3 3 1 1 1/]},
'Fmmaj7'=>{base=>1,fret=>[qw/X 3 3 1 1 0/]},
'Fsus'=>{base=>1,fret=>[qw/X X 3 3 1 1/]},
'Fsus4'=>{base=>1,fret=>[qw/X X 3 3 1 1/]},
'G'=>{base=>1,fret=>[qw/3 2 0 0 0 3/]},
'G#'=>{base=>4,fret=>[qw/1 3 3 2 1 1/]},
'G#+'=>{base=>1,fret=>[qw/X X 2 1 1 0/]},
'G#4'=>{base=>4,fret=>[qw/1 3 3 1 1 1/]},
'G#7'=>{base=>1,fret=>[qw/X X 1 1 1 2/]},
'G#dim'=>{base=>1,fret=>[qw/X X 0 1 0 1/]},
'G#m'=>{base=>4,fret=>[qw/1 3 3 1 1 1/]},
'G#m6'=>{base=>1,fret=>[qw/X X 1 1 0 1/]},
'G#m7'=>{base=>4,fret=>[qw/X X 1 1 1 1/]},
'G#m9maj7'=>{base=>1,fret=>[qw/X X 1 3 0 3/]},
'G#maj'=>{base=>4,fret=>[qw/1 3 3 2 1 1/]},
'G#maj7'=>{base=>1,fret=>[qw/X X 1 1 1 3/]},
'G#m'=>{base=>4,fret=>[qw/1 3 3 1 1 1/]},
'G#sus'=>{base=>1,fret=>[qw/X X 1 1 2 4/]},
'G#sus4'=>{base=>1,fret=>[qw/X X 1 1 2 4/]},
'G+'=>{base=>1,fret=>[qw/X X 1 0 0 4/]},
'G/A'=>{base=>1,fret=>[qw/X 0 0 0 0 3/]},
'G/B'=>{base=>1,fret=>[qw/X 2 0 0 0 3/]},
'G/D'=>{base=>4,fret=>[qw/X 2 2 1 0 0/]},
'G/F#'=>{base=>1,fret=>[qw/2 2 0 0 0 3/]},
'G11'=>{base=>1,fret=>[qw/3 X 0 2 1 1/]},
'G4'=>{base=>1,fret=>[qw/X X 0 0 1 3/]},
'G6'=>{base=>1,fret=>[qw/3 X 0 0 0 0/]},
'G6sus4'=>{base=>1,fret=>[qw/0 2 0 0 1 0/]},
'G7'=>{base=>1,fret=>[qw/3 2 0 0 0 1/]},
'G7(#9)'=>{base=>3,fret=>[qw/1 3 X 2 4 4/]},
'G7(b9)'=>{base=>1,fret=>[qw/X X 0 1 0 1/]},
'G7sus4'=>{base=>1,fret=>[qw/3 3 0 0 1 1/]},
'G7+'=>{base=>1,fret=>[qw/X X 4 3 3 2/]},
'G7b9'=>{base=>1,fret=>[qw/X X 0 1 0 1/]},
'G7sus4'=>{base=>1,fret=>[qw/3 3 0 0 1 1/]},
'G9'=>{base=>1,fret=>[qw/3 X 0 2 0 1/]},
'G9(11)'=>{base=>3,fret=>[qw/1 3 1 3 1 3/]},
'Gadd9'=>{base=>3,fret=>[qw/1 3 X 2 1 3/]},
'Gb'=>{base=>1,fret=>[qw/2 4 4 3 2 2/]},
'Gb+'=>{base=>1,fret=>[qw/X X 4 3 3 2/]},
'Gb7'=>{base=>1,fret=>[qw/X X 4 3 2 0/]},
'Gb9'=>{base=>1,fret=>[qw/X 1 2 1 2 2/]},
'Gbdim'=>{base=>1,fret=>[qw/X X 1 2 1 2/]},
'Gbm'=>{base=>1,fret=>[qw/2 4 4 2 2 2/]},
'Gbm7'=>{base=>1,fret=>[qw/X X 2 2 2 2/]},
'Gbmaj'=>{base=>1,fret=>[qw/2 4 4 3 2 2/]},
'Gbmaj7'=>{base=>1,fret=>[qw/X X 4 3 2 1/]},
'Gbm'=>{base=>1,fret=>[qw/2 4 4 2 2 2/]},
'Gbsus'=>{base=>1,fret=>[qw/X X 4 4 2 2/]},
'Gbsus4'=>{base=>1,fret=>[qw/X X 4 4 2 2/]},
'Gdim'=>{base=>1,fret=>[qw/X X 2 3 2 3/]},
'Gm'=>{base=>3,fret=>[qw/1 3 3 1 1 1/]},
'Gm/Bb'=>{base=>4,fret=>[qw/3 2 2 1 X X/]},
'Gm6'=>{base=>1,fret=>[qw/X X 2 3 3 3/]},
'Gm7'=>{base=>3,fret=>[qw/1 3 1 1 1 1/]},
'Gmaj'=>{base=>1,fret=>[qw/3 2 0 0 0 3/]},
'Gmaj7'=>{base=>2,fret=>[qw/X X 4 3 2 1/]},
'Gmaj7sus4'=>{base=>1,fret=>[qw/X X 0 0 1 2/]},
'Gmaj9'=>{base=>2,fret=>[qw/1 1 4 1 2 1/]},
'Gm'=>{base=>3,fret=>[qw/1 3 3 1 1 1/]},
'Gsus'=>{base=>1,fret=>[qw/X X 0 0 1 3/]},
'Gsus4'=>{base=>1,fret=>[qw/X X 0 0 1 1/]},
);
1;
EOT
  close(OFH);
}

1;
