package CP::PDFfont;

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

use POSIX qw/ceil/;
use CP::Cconst qw/:FONT :MUSIC :TEXT :INDEX :COLOUR/;
use CP::Global qw/:FUNC :OPT :WIN :CHORD :SCALE :SETL/;
use PDF::API2;
use CP::Chord;

my $SUPHT = 0.6;

sub new {
  my($proto,$media,$idx,$pdf) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;

  my $fp = $Media->{"$media"};
  $self->{fam} = $fp->{family};
  $self->{sz} = my $size = ceil($fp->{size});
  $self->{wt} = ($fp->{weight} eq 'bold') ? $Opt->{Bold} : ($fp->{weight} eq 'heavy') ? $Opt->{Heavy} : 0;
  $self->{sl} = ($fp->{slant} eq 'roman') ? 0 : $Opt->{Italic};
  my $pfp = getFont($self, $pdf, $idx);
  $self->{clr} = $fp->{color};
  $self->{hscale} = 100;

  return($self);
}

sub copy {
  my($self) = shift;

  my $new = {};
  bless $new, ref($self);

  foreach my $k (keys %{$self}) {
    $new->{$k} = $self->{$k};
  }
  $new;
}

# getFont assumes that the keys for family, size,
# weight and slant have all been initialised.
sub getFont {
  my($self,$pdf,$idx) = @_;

  my $fam = $self->{fam};
  if (! defined $FontList{"$fam"}) {
    errorPrint("Font '$fam' not found.\nSubstituting 'Times New Roman'");
    $fam = 'Times New Roman';
  }
  my $pfp = $pdf->ttfont($FontList{"$fam"}{Path}.'/'.$FontList{"$fam"}{Regular});
  if ($self->{wt} || $self->{sl}) {
    $pfp = $pdf->synfont($pfp, -bold => $self->{wt}, -oblique => $self->{sl});
  }
  # Font metrics don't seem to follow the accepted standard where the total
  # height used by a font is (ascender + descender) and where the ascender
  # includes any extra height added by the composer.
  my $size = $self->{sz};
  $self->{dc} = abs(ceil(($pfp->descender * $size) / 1000)) + 1;
  if ($idx == CHORD) {
    $self->{as} = $size;
    $self->{ssz} = ceil($size * $SUPHT * 2) / 2;
  } else {
    if ($idx == CMMNT || $idx == HLIGHT) {
      $self->{as} = ceil(($pfp->ascender * $size) / 1000);
    } else {
      # This is essentially the height of a Capital + a little bit.
      $self->{as} = $size - $self->{dc};
    }
  }
  $self->{font} = $pfp;
}

# This converts from a Tk font description string:
#   {font name} size weight slant
# to the individual components needed for a PDF font but retains
# the old size, weight and slant if not in the new definition.
sub fontAttr {
  my($self,$tkFont) = @_;

  my ($sz,$wt,$sl);
  if ($tkFont =~ /\{/) {
    ($self->{fam},$sz,$wt,$sl) = ($tkFont =~ /^\s*\{([^\}]+)\}\s*(\d*)\s*(\S*)\s*(\S*)/);
  } else {
    ($self->{fam},$sz,$wt,$sl) = ($tkFont =~ /^\s*(\S+)\s*(\d*)\s*(\S*)\s*(\S*)/);
  }
  my $nwt = ($wt eq 'bold') ? $Opt->{Bold} : ($wt eq 'heavy') ? $Opt->{Heavy} : 0;
  my $nsl = ($sl eq 'italic') ? $Opt->{Italic} : 0;
  $self->{sz} = $sz if ($sz ne '');
  $self->{wt} = $nwt if ($nwt);
  $self->{sl} = $nsl if ($nsl);
}

sub chordSize {
  my($self,$mypdf,$size) = @_;

  if (!defined $size || $size eq '') {
    $size = $Media->{Chord}{size};
  }
  $self->{as} = $self->{sz} = $size;
  $self->{dc} = abs(ceil(($self->{font}->descender * $size) / 1000)) + 2;
  $self->{ssz} = ceil($size * $SUPHT * 2) / 2;
  $mypdf->{ffSize} = CP::CPpdf::_measure("10", $self->{font}, $self->{sz} * $SUPHT); # if (defined $TextPtr);
}

# Called in response to a {chordfont} directive.
sub chordFont {
  my($self,$mypdf,$font) = @_;

  if (!defined $font || $font eq '') {
    $mypdf->{fonts}[CHORD] = new(ref($self), 'Chord', CHORD, $mypdf->{pdf});
  } else {
    fontAttr($self, $font);
    getFont($self, $mypdf->{pdf}, CHORD);
    $mypdf->{ffSize} = CP::CPpdf::_measure("10", $self->{font}, $self->{sz} * $SUPHT); # if (defined $TextPtr);
  }
}

sub lyricSize {
  my($self,$size) = @_;

  if (!defined $size || $size eq '') {
    $size = $Media->{Lyric}{size};
  }
  $self->{sz} = $size;
  $self->{dc} = abs(ceil(($self->{font}->descender * $size) / 1000)) + 2;
  $self->{as} = $size - $self->{dc};
}

# Called in response to a {textfont} directive.
sub lyricFont {
  my($self,$mypdf,$font) = @_;

  if (!defined $font || $font eq '') {
    $mypdf->{fonts}[VERSE] = new('CP::PDFfont', 'Lyric', VERSE, $mypdf->{pdf});
  } else {
    fontAttr($self, $font);
    getFont($self, $mypdf->{pdf}, VERSE);
  }
}

sub tabSize {
  my($self,$size) = @_;

  if (!defined $size || $size eq '') {
    $size = $Media->{Tab}{size};
  } 
  $self->{sz} = $size;
  $self->{dc} = abs(ceil(($self->{font}->descender * $size) / 1000)) + 2;
  $self->{as} = $size - $self->{dc};
}

# Called in response to a {textfont} directive.
sub tabFont {
  my($self,$mypdf,$font) = @_;

  if (!defined $font || $font eq '') {
    $mypdf->{fonts}[TAB] = new('CP::PDFfont', 'Tab', TAB, $mypdf->{pdf});
  } else {
    fontAttr($self, $font);
    getFont($self, $mypdf->{pdf}, TAB);
  }
}

1;
