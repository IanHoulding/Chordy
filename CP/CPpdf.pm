package CP::CPpdf;

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
use CP::PDFfont;
use CP::Chord;
use CP::FgBgEd qw(&lighten &darken);

my($TextPtr,$GfxPtr);

my $XSIZE = 8;
my $YSIZE = 10;
my $SPACE = 15;

sub new {
  my($proto,$pro,$fn) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;

  my $pdf = PDF::API2->new(-file => "$fn");
  $self->{pdf} = $pdf;
  #
  # Do all the font jiggery-pokery ...
  #
  my $copy;
  foreach my $m (['Title',     TITLE],
		 ['Lyric',     VERSE],
		 ['Chord',     CHORD],
		 ['Tab',       TAB],
		 ['Label',     LABEL],
		 ['Comment',   CMMNT],
		 ['Highlight', HLIGHT]) {
    my($media,$idx) = @{$m};
    my $pfp = $self->{fonts}[$idx] = CP::PDFfont->new($media, $idx, $pdf);
    if ($idx == CMMNT) {
      $self->{fonts}[CMMNTB] = $pfp;
      $copy = $self->{fonts}[CMMNTI] = $pfp->copy();
      $copy->{sl} = $Opt->{Italic};
      $copy->getFont($pdf, CMMNTI);
    }
  }
  $copy = $self->{fonts}[GRID] = $self->{fonts}[CHORD]->copy();
  $copy->{fam} = RESTFONT;
  $copy->{wt} = $copy->{sl} = 0;
  $self->{fonts}[GRID]{font} = $copy->getFont($pdf, GRID);

  $self->{page} = [];
  $self->{ffSize} = 0;

  return($self);
}

sub printSL {
  my($chordy) = shift;

  return if ($CurSet eq '');

  my $tmpMedia = $Opt->{Media};
  $Opt->{Media} = $Opt->{PrintMedia};
  $Media = $Media->change($Opt->{Media});

  my $list = $AllSets->{browser}{selLB}{array};
  my $tmpPDF = "$Path->{Temp}/$CurSet.pdf";
  my $pdf = PDF::API2->new(-file => "$tmpPDF");
  my $pp = $pdf->page;
  #
  # Do the font jiggery-pokery ...
  #
  my $fp = CP::PDFfont->new("Title", TITLE, $pdf);
  my $pfp = $fp->{font};
  my $Tsz = $fp->{sz};
  my $Tdc = $fp->{dc};
  my $Tclr = $fp->{clr};

  my $Lsz = $Media->{Lyric}{size} + 1;
  my $Lclr = $Media->{Lyric}{color};

  my $w = $Media->{width};
  my $h = $Media->{height};

  $pp->mediabox($w, $h);
  $pp->cropbox(0, 0, $w, $h);
  newTextGfx($pp);

  #
  # Set BackGround colour and show the title
  #
  if ($Opt->{PageBG} ne WHITE) {
    $GfxPtr->fillcolor($Opt->{PageBG});
    $GfxPtr->rect(0, 0, $w, $h);
    $GfxPtr->fill();
  }
  $h -= ($Tsz + 3);
  if ($Media->{titleBG} ne WHITE) {
    _bg($Media->{titleBG}, 0, $h, $w, $Tsz + 3);
  }
  _textCenter($w/2, $h + $Tdc + 2, $CurSet, $pfp, $Tsz, $Tclr);
  if ($AllSets->{meta}{date} ne '') {
    _textRight($w - $Opt->{RightMargin}, $h + $Tdc, $AllSets->{meta}{date}, $pfp, $Lsz, $Tclr);
  }

  $h -= 1;
  _hline(0, $h, $w, 1, DBLUE);

  #
  # Show all the meta data (time slots)
  #
  $h -= $Tsz * 2;
  $Tsz += 4;
  my $timew = my $setw = _measure('88:88', $pfp, $Lsz);
  if ($AllSets->{meta}{s1end} ne '' || $AllSets->{meta}{s2end} ne '') {
    $setw += ($timew + _measure(' - ', $pfp, $Lsz));
  }
  my $x = $w - $setw - ($Opt->{RightMargin} * 2);
  my $y = $h - ($Tsz * 4);
  foreach my $xtr (['Setup','setup'], ['Sound Check','soundcheck']) {
    my($lab,$key) = (@{$xtr});
    if (($key = $AllSets->{meta}{$key}) ne '') {
      _textRight($x, $y, "$lab: ", $pfp, $Lsz, $Tclr);
      _textAdd($x, $y, "$key", $pfp, $Lsz, $Lclr);
      $y -= $Tsz;
    }
  }
  if ($AllSets->{meta}{s1start} ne '' || $AllSets->{meta}{s1end} ne '') {
    _textRight($x, $y, "Set 1: ", $pfp, $Lsz, $Tclr);
    if ($AllSets->{meta}{s1start} ne '') {
      _textAdd($x, $y, "$AllSets->{meta}{s1start}", $pfp, $Lsz, $Lclr);
    }
    if ($AllSets->{meta}{s1end} ne '') {
      _textAdd($x + $timew, $y, " - $AllSets->{meta}{s1end}", $pfp, $Lsz, $Lclr);
    }
    $y -= $Tsz;
  }
  if ($AllSets->{meta}{s2start} ne '' || $AllSets->{meta}{s2end} ne '') {
    _textRight($x, $y, "Set 2: ", $pfp, $Lsz, $Tclr);
    if ($AllSets->{meta}{s2start} ne '') {
      _textAdd($x, $y, "$AllSets->{meta}{s2start}", $pfp, $Lsz, $Lclr);
    }
    if ($AllSets->{meta}{s2end} ne '') {
      _textAdd($x + $timew, $y, " - $AllSets->{meta}{s2end}", $pfp, $Lsz, $Lclr);
    }
    $y -= $Tsz;
  }

  #
  # Now the play list
  #
  my $cnt = @{$list};
  for(my $i = 4; $i; $i--) {
    last if (($h - ($Tsz * $cnt)) >= 0);
    $Tsz--;
  }
  while (($h - ($Tsz * $cnt)) < 0) { # deliberately use $Tsz to add extra spacing
    $Tsz--;
    $Lsz--;
  }
  my @pros = ();
  foreach my $fn (@{$list}) {
    my $pro = CP::Pro->new($fn);
    push(@pros, $pro);
    $cnt++ if ($pro->{title} =~ /^INTERVAL$/i);
  }
  my $numw = _measure("99  ", $pfp, $Lsz);
  my $keyw = _measure("G#m  ", $pfp, $Lsz - 3);
  my $indent = $Opt->{LeftMargin} * 2;
  my $num = 1;
  foreach my $pro (@pros) {
    if ($pro->{title} =~ /^INTERVAL$/i) {
      $num = 1;
      $h -= int($Lsz / 2);
      _textAdd($indent, $h, "  INTERVAL", $pfp, $Lsz, RFG);
      $h -= int($Lsz / 2);
    }
    else {
      my $x = $indent + $numw;
      _textRight($x, $h, "$num  ", $pfp, $Lsz, $Tclr);
      _textAdd($x, $h, $pro->{key}, $pfp, $Lsz - 3, RFG);
      _textAdd($x + $keyw, $h, $pro->{title}, $pfp, $Lsz, $Lclr);
      $num++;
    }
    $h -= $Tsz;
  }
  $pdf->update();
  $pdf->end();
  my $print = $Opt->{PDFprint};
  $Opt->{PDFprint} = 69;
  main::PDFprint($tmpPDF) if (main::PDFview($chordy, $tmpPDF));
  $Opt->{PDFprint} = $print;

  $Opt->{Media} = $tmpMedia;
  $Media = $Media->change($Opt->{Media});
}

sub newTextGfx {
  my($pp) = shift;

  $GfxPtr = $pp->gfx();
  $GfxPtr->linecap(1);
  $TextPtr->textend() if (defined $TextPtr);
  $TextPtr = $pp->text();
}

sub newPage {
  my($self,$pro,$pn) = @_;

  my $tFontP = $self->{fonts}[TITLE];
  my $tfp = $tFontP->{font};

  my $w = $Media->{width};
  my $h = $Media->{height};
  my $pp = $self->{pdf}->page;
  push(@{$self->{page}}, $pp);
  $pp->mediabox($w, $h);
  $pp->cropbox(0, 0, $w, $h);
  newTextGfx($pp);

  if ($Opt->{PageBG} ne WHITE) {
    _bg($Opt->{PageBG}, 0, 0, $w, $h);
  }
  $h -= ($tFontP->{sz} + 3);
  $self->{headerBase} = $h + 1;
  if ($Media->{titleBG} ne WHITE) {
    _bg($Media->{titleBG}, 0, $h, $w, $tFontP->{sz} + 3);
  }
  _textCenter($w/2, $self->{headerBase} + $tFontP->{dc},
	      $pro->{title}, $tfp, $tFontP->{sz}, $tFontP->{clr});

  $h -= 1;
  _hline(0, $h, $w, 1, DBLUE);

  my $offset = 0;
  my $tbl = $self->{headerBase} + $tFontP->{dc};
  my $th = $tFontP->{sz} * KEYMUL;
  my $dc = $tFontP->{dc} * KEYMUL;
  my $cc = $tFontP->{clr};

  if ($pro->{key} ne '') {
    my $tw = _textAdd($Opt->{LeftMargin}, $tbl, "Key: ", $tfp, $th, BLACK);
    my $ch = CP::Chord->new($pro->{key});
    $ch = $ch->trans2obj($pro) if ($Opt->{Transpose} ne '-');
    chordAdd($self, $Opt->{LeftMargin} + $tw, $tbl, $ch, $cc, $th);
  }

  if ($pn == 1) {
    my $bgh = 0;
    if ($pro->{note} ne '') {
      $bgh = $th;
    }
    if ($pro->{capo} ne 0 && $Opt->{LyricOnly} == 0) {
      $bgh += $th;
    }
    if ($pro->{tempo} ne 0 && $Opt->{LyricOnly} == 0) {
      $bgh += $th;
    }
    if ($bgh) {
      $bgh += 4;
      _bg('#F0FFFF', 0, $h - $bgh, $w, $bgh);
      $h -= 2;
      if ($pro->{tempo} ne 0) {
	$h -= ($th - $dc);
	$offset = _textAdd($Opt->{LeftMargin}, $h, "Tempo: ", $tfp, $th, BLACK);
	_textAdd($Opt->{LeftMargin} + $offset, $h, "$pro->{tempo}", $tfp, $th, $cc);
	$h -= $dc;
      }
      if ($pro->{note} ne '') {
	$h -= ($th - $dc);
	my $tw = _textAdd($Opt->{LeftMargin}, $h, "Note: ", $tfp, $th, BLACK) + $Opt->{LeftMargin};
	$offset = $tw if ($offset == 0);
	_textAdd($Opt->{LeftMargin} + $offset, $h, $pro->{note}, $tfp, $th, $cc);
	$h -= $dc;
      }
      if ($pro->{capo} ne 0 && $Opt->{LyricOnly} == 0) {
	$h -= ($th - $dc);
	my $tw = _textAdd($Opt->{LeftMargin}, $h, "Capo: ", $tfp, $th, BLACK);
	$offset = $tw if ($offset == 0);
	$tw = _textAdd($Opt->{LeftMargin} + $offset, $h, "$pro->{capo}", $tfp, $th, $cc);
	if ($Opt->{IgnCapo}) {
	  $offset += $tw;
	  $tw = int(($th / 4) * 3);
	  _textAdd($Opt->{LeftMargin} + $offset, $h, "  (ignored)", $tfp, $tw, $cc);
	}
	$h -= $dc;
      }
      $h -= 2;
    }
  }
  if ($offset) {
    $h -= 1;
    _hline(0, $h, $w, 1, DBLUE);
  }

  my $chFontP = $self->{fonts}[CHORD];
  my $chfp = $chFontP->{font};
  if ($Opt->{Grid} != NONE && ($pn == 1 || $Opt->{Grid} == ALLP)) {
    $h -= INDENT;
    $self->{ffSize} = _measure("10", $chfp, $chFontP->{sz} * SUPHT) if ($self->{ffSize} == 0);
    my($cnt,$xinc) = fingersWidth($self);
    my $margin = $Opt->{LeftMargin} * 2;
    $w -= $margin;
    my $maxy = 0;
    my $linex = $margin;
    my @chidx = sort keys %{$pro->{chords}};
    while (@chidx) {
      my $ch = shift(@chidx);
      # Special case for chords like C//
      if ($ch =~ m!//!) {
	$ch =~ s!//.*!!;
	next if (exists $pro->{chords}{$ch});
      }
      my($dx,$dy) = drawFinger($self, $pro, $linex, $h, $ch);
      $linex += $xinc;
      if ($linex > $w && @chidx) {
	$linex = $margin;
	$h -= ($maxy + 5);
	$maxy = 0;
      }
      $maxy = $dy if ($dy > $maxy);
    }
    $h -= ($maxy + INDENT);
    $GfxPtr->fillcolor(DBLUE);
    $GfxPtr->rect(0, $h, $w + $margin, 1);
    $GfxPtr->fill();
    $h -= INDENT;
  }
  return($h - $Opt->{TopMargin});
}

sub pageNum {
  my($self,$npage) = @_;

  my $tifp = $self->{fonts}[TITLE];
  my $fp = $tifp->{font};
  my $h = $self->{headerBase} + $tifp->{dc};
  my $npg = 0 - $npage;
  my $pn = 1;
  my $ptext = $TextPtr;
  my $rightIdx = $Media->{width} - $Opt->{RightMargin};
  my $size = ceil($tifp->{sz} * PAGEMUL);
  while ($npg) {
    my $pp = $self->{page}[$npg++];
    my $page = "Page ".$pn++." of $npage ";
    $TextPtr = $pp->text();
    _textRight($rightIdx, $h, $page, $fp, $size, BROWN);
    $TextPtr->textend;
  }
  $TextPtr = $ptext;
}

#
# Return the height (in points) of one chord finger display
#
sub fingerHeight {
  my($self,$name) = @_;

  my $chfp = $self->{fonts}[CHORD];
  my $tht = $chfp->{sz} * SUPHT;
  my $tdc = $chfp->{dc} * SUPHT;
  my $ly = $chfp->{sz} + $tht + $tdc;
  my $max = 0;
  foreach my $fr (@{$Fingers{$name}{fret}}) {
    $max = $fr if ($fr =~ /\d+/ && $fr > $max);
  }
  $ly += (($max * $YSIZE) + ($YSIZE / 2));
}

#
# Takes an array of chord names, works out how many will
# fit on one line and from that, how high the complete
# display will be.
#
sub fingersHeight {
  my($self,@chords) = @_;

  my($nc,$inc) = fingersWidth($self);
  my $h = 0;
  while (@chords) {
    my $max = 0;
    foreach my $i (1..$nc) {
      last if (@chords == 0);
      my $dy = fingerHeight($self, shift(@chords));
      $max = $dy if ($dy > $max);
    }
    $h += $max;
  }
  $h;
}

#
# Return the number of chords we can display and the
# distance (in points) between the start of each chord
#
sub fingersWidth {
  my($self) = shift;

  my $w = $Media->{width} - ($Opt->{LeftMargin} + $Opt->{RightMargin});
  my $cw = (($Nstring - 1) * $XSIZE) + 2 + $self->{ffSize} + $SPACE; # min size of a chord diagram + spacer
  my $nc = int($w / $cw);                                # number of chords we can draw
  $cw += int(($w - ($nc * $cw) + $SPACE) / ($nc - 1));   # even out any leftover space
  ($nc,$cw);
}

sub drawFinger {
  my($self,$pro,$x,$y,$name) = @_;

  my $ch = CP::Chord->new($name);
  if ($KeyShift) {
    $ch = $ch->trans2obj($pro);
  }
  my $dx = chordLen($self, $ch) / 2;
  my $ns = $Nstring - 1;
  my $ly = $y;
  my $lmy = $y;
  my $mx = $x;

  my $chFontP = $self->{fonts}[CHORD];
  my $chfp = $chFontP->{font};
  my $fc = $chFontP->{clr};
  my $tht = $chFontP->{sz} * SUPHT;
  my $tdc = $chFontP->{dc} * SUPHT;
  my $vsz = $YSIZE/2;
  $ly -= $chFontP->{sz};  # minus Cdc?
  chordAdd($self, $x+(($XSIZE*$ns/2)-$dx), $ly, $ch, $fc);
  $ly -= $tht;

  my $fptr = "";
  # Fingering defined in the Pro hash takes precedence
  # as it was created with a {define:...} directive.
  #
  # For some unknown reason, perl thinks that when Fingers{'Amadd9'}
  # exists, it also thinks that Fingers{'Am(add9)'} exists - I'm
  # guessing that the hash lookup is picking up the () as part of
  # a regex. However, it DOESN'T think that Fingers{'Am(add9)'}{base}
  # exists - HUH??
  # And that, folks, is why we test for the {base} key!
  #
  if (exists $pro->{finger}{$ch->{chord}}{base}) {
    $fptr = \%{$pro->{finger}{$ch->{chord}}};
  } elsif (exists $Fingers{$ch->{chord}}{base}) {
    $fptr = \%{$Fingers{$ch->{chord}}};
  }
  if (ref($fptr) ne "") {
    my $base = $fptr->{base};
    my $frptr = $fptr->{fret};
    my $max = 0;
    foreach (0..$ns) {
      my $fr = $frptr->[$_];
      if ($fr =~ /[-xX0]/) {
	_textCenter($mx, $ly, ($fr eq '0') ? 'o' : 'x', $chfp, $tht, $fc);
      }
      $mx += $XSIZE;
      $max = $fr if ($fr =~ /\d+/ && $fr > $max);
    }
    $ly -= $tdc;
    # Draw Frets
    $GfxPtr->strokecolor(BLACK);
    $GfxPtr->linewidth(1);
    $GfxPtr->linecap(0);
    $lmy = $ly;
    $mx = $ns * $XSIZE;
    for my $f (0..$max) {
      my $dx = $x + $mx;
      $dx += 2 if ($f == 1);
      $GfxPtr->move($x, $lmy);
      $GfxPtr->hline($dx);
      $GfxPtr->stroke();
      $lmy -= $YSIZE;
    }
    # Draw the base fret number to the right of the first fret
    # NOTE: the nut is NOT considered to be a fret.
    _textAdd($x + $mx + 3, $ly - $YSIZE - $tdc, $base, $chfp, $tht, $fc);
    my $bfw = $mx + 3 + $self->{ffSize};
    # Strings and finger positions
    $GfxPtr->linewidth(1);
    $GfxPtr->fillcolor(DBLUE);
    $mx = $x;
    $lmy = $ly - (($max*$YSIZE)+$vsz);
    foreach (0..$ns) {
      my $fr = $frptr->[$_];
      $GfxPtr->move($mx,$ly);
      $GfxPtr->vline($lmy);
      $GfxPtr->stroke();
      if ($fr =~ /[^-xX0]/) {
	$GfxPtr->circle($mx,$ly-($fr*$YSIZE)+$vsz, 2.5);
	$GfxPtr->fill();
      }
      $mx += $XSIZE;
    }
    $mx = $bfw;
  } else {
    $ly -= ($chFontP->{sz}*2);
    _textCenter($x+($XSIZE*$ns/2), $ly, 'X', $chfp, $chFontP->{sz}*2, RED);
    $mx = (($XSIZE * $ns) + 3 + $self->{ffSize});
    $lmy = $ly;
  }
  ($mx,$y-int($lmy + 1));
}

sub chordAdd {
  my($self,$x,$y,$ch,$clr,$ht) = @_;

  my $chfp = $self->{fonts}[CHORD];
  my $fp = $chfp->{font};
  $ht = $chfp->{sz} if (!defined $ht);
  if (@{$ch->{bits}}) {
    my $bits = $ch->{bits};
    $x += _textAdd($x, $y, $bits->[0], $fp, $ht, $clr);
    my $sht = ceil($ht * SUPHT);
    my $sy = $y + ceil($sht * SUPHT);
    my $s = $bits->[1].$bits->[2];
    $x += _textAdd($x, $sy, $s, $fp, $sht, $clr) if ($s ne "");
    if (@{$bits} > 3) {
      $x += _textAdd($x, $y, '/'.$bits->[4], $fp, $ht, $clr);
      $s = $bits->[5].$bits->[6];
      $x += _textAdd($x, $sy, $s, $fp, $sht, $clr) if ($s ne "");
    }
  }
  $x += _textAdd($x, $y, $ch->{text}, $fp, $ht, $clr) if ($ch->{text} ne "");
  $x;
}

sub chordLen {
  my($self, $ch) = @_;

  my $chfp = $self->{fonts}[CHORD];
  my $fp = $chfp->{font};
  my $nx = 0;
  if (@{$ch->{bits}}) {
    my $bits = $ch->{bits};
    $nx = _measure($bits->[0], $fp, $chfp->{sz});
    my $sht = ceil($chfp->{sz} * SUPHT);
    my $s = $bits->[1].$bits->[2];
    $nx += _measure($s, $fp, $sht) if ($s ne "");
    if (@{$bits} > 3) {
      $nx += _measure($bits->[4], $fp, $chfp->{sz});
      $s = $bits->[5].$bits->[6];
      $nx += _measure($s, $fp, $sht) if ($s ne "");
    }
  }
  $nx += _measure($ch->{text}, $fp, $chfp->{sz}) if ($ch->{text} ne "");
  $nx;
}

sub labelAdd {
  my($self,$x,$y,$txt,$clr) = @_;

  my $fp = $self->{fonts}[LABEL];
  if ($Opt->{Center}) {
    $x = ($Media->{width} - ($Opt->{RightMargin} + $Opt->{LeftMargin})) / 2;
    $x = _textCenter($x, $y, $txt, $fp->{font}, $fp->{sz}, $clr);
  } else {
    $x += _textAdd($x, $y, $txt, $fp->{font}, $fp->{sz}, $clr);
  }
}

sub labelLen {
  my($self,$txt) = @_;

  my $fp = $self->{fonts}[LABEL];
  _measure($txt, $fp->{font}, $fp->{sz});
}

sub lyricAdd {
  my($self,$x,$y,$txt,$clr) = @_;

  my $fp = $self->{fonts}[VERSE];
  $x += _textAdd($x, $y, $txt, $fp->{font}, $fp->{sz}, $clr);
}

sub lyricLen {
  my($self,$txt) = @_;

  my $fp = $self->{fonts}[VERSE];
  _measure($txt, $fp->{font}, $fp->{sz});
}

sub commentLen {
  my($self,$ln,$fp) = @_;

  my $x = 0;
  foreach my $s (@{$ln->{segs}}) {
    # Chords
    if ($Opt->{LyricOnly} == 0 && defined $s->{chord}) {
      $x += chordLen($self, $s->{chord});
    }
    # Lyrics
    if ($s->{lyric} ne "") {
      $x += _measure($s->{lyric}, $fp->{font}, $fp->{sz});
    }
  }
  $x;
}

sub hline {
  my($self,$x,$y,$h,$w,$clr) = @_;

  if ($clr ne '') {
    $x = int(($Media->{width} - $w) / 2) if ($Opt->{Center});
    _bg($clr, $x, $y, $w, $h);
  }
}

#____|__________________________________
#____|_______________________________|_
#    |          #                    |
#    |         # #                   |
#    |        #   #                  |
#    as      #     #      #     #    ht
#    |      #########      #   #     |
#    |     #         #      # #      |
#____|____#___________#______#_______|__
#                           #     dc |
#__________________________#______|__|__
#
sub commentAdd {
  my($self,$pro,$ln,$type,$y,$ht) = @_;

  my($bgwid,$x,$txtx) = (0,0,$Opt->{LeftMargin});
  my $chfp = $self->{fonts}[CHORD];
  my $cfp = $self->{fonts}[$type];
  if (($type == HLIGHT && $Opt->{FullLineHL}) || ($type != HLIGHT && $Opt->{FullLineCM})) {
    $bgwid = $Media->{width};
  }
  my $commlen = $self->commentLen($ln, $cfp);
  if ($Opt->{Center}) {
    $txtx += (($Media->{width} - ($Opt->{LeftMargin} + $Opt->{RightMargin})) / 2);
    $txtx -= ($commlen / 2);
  }
  if ($bgwid == 0) {  # Not a full width background
    $bgwid = $commlen + 4;
    $txtx += 2;
    $x = ($Opt->{Center}) ? $txtx - 2 : $Opt->{LeftMargin};
  }
  my $bg = $ln->{bg};
  if ($bg eq "") {
    # These can be changed dynamically in "Background Colours".
    $bg = ($type == HLIGHT) ? $Media->{highlightBG} : $Media->{commentBG};
  }
  _bg($bg, $x, $y, $bgwid, $ht);
  my $relief = $bg = '';
  my $bdwid = 0;
  if ($type == HLIGHT && $Opt->{HborderWidth}) {
    $bg = $Media->{highlightBD};
    $relief = $Opt->{HborderRelief};
    $bdwid = $Opt->{HborderWidth};
  } elsif ($type == CMMNTB) {
    $bg = BLACK;
    $relief = 'flat';
    $bdwid = 1;
  } elsif(($type == CMMNT || $type == CMMNTI) && $Opt->{CborderWidth}) {
    $bg = $Media->{commentBD};
    $relief = $Opt->{CborderRelief};
    $bdwid = $Opt->{CborderWidth};
  }
  if ($bdwid) {
    if ($x == 0) {
      $x += $bdwid;
      $bgwid -= ($bdwid * 2);
    }
    $GfxPtr->linewidth(0);

    my($top,$bot,$rht,$lft);
    if ($relief eq 'raised') {
      $top = lighten($bg,10);
      $rht = darken($bg,5);
      $bot = darken($bg,10);
      $lft = lighten($bg,5);
    } elsif ($relief eq 'sunken') {
      $top = darken($bg,10);
      $rht = lighten($bg,5);
      $bot = lighten($bg,10);
      $lft = darken($bg,5);
    } else { # flat
      $top = $bot = $rht = $lft = $bg;
    }

    my $x1 = $x - $bdwid;   my $y1 = $y - $bdwid;
    my $x2 = $x;            my $y2 = $y;
    my $x3 = $x + $bgwid;      my $y3 = $y + $ht;
    my $x4 = $x3 + $bdwid;  my $y4 = $y3 + $bdwid;

    my @pbot = ($x1,$y1, $x4,$y1, $x3,$y2, $x2,$y2, $x1,$y1);
    my @prht = ($x4,$y1, $x4,$y4, $x3,$y3, $x3,$y2, $x4,$y1);
    my @ptop = ($x1,$y4, $x4,$y4, $x3,$y3, $x2,$y3, $x1,$y4);
    my @plft = ($x1,$y1, $x1,$y4, $x2,$y3, $x2,$y2, $x1,$y1);

    $GfxPtr->fillcolor($bot);
    $GfxPtr->poly(@pbot);
    $GfxPtr->fill();

    $GfxPtr->fillcolor($rht);
    $GfxPtr->poly(@prht);
    $GfxPtr->fill();

    $GfxPtr->fillcolor($top);
    $GfxPtr->poly(@ptop);
    $GfxPtr->fill();

    $GfxPtr->fillcolor($lft);
    $GfxPtr->poly(@plft);
    $GfxPtr->fill();
  }
  $y += ($cfp->{dc} + 2);
  my $clr = ($type == HLIGHT) ? $Media->{Highlight}{color} : $Media->{Comment}{color};
  my $sz = $cfp->{sz};
  foreach my $s (@{$ln->{segs}}) {
    # Chords
    if ($Opt->{LyricOnly} == 0 && defined $s->{chord}) {
      $txtx = $self->chordAdd($txtx, $y, $s->{chord}->trans2obj($pro), $chfp->{clr});
    }
    # Lyrics
    if ($s->{lyric} ne "") {
      $txtx += _textAdd($txtx, $y, $s->{lyric}, $cfp->{font}, $sz, $clr);
    }
  }
}

sub _hline {
  my($x,$y,$xx,$ht,$clr) = @_;

  $GfxPtr->fillcolor($clr);
  $GfxPtr->rect($x, $y, $xx - $x, $ht);
  $GfxPtr->fill();
}

sub _textAdd {
  my($x,$y,$txt,$font,$sz,$fg) = @_;

  $TextPtr->font($font, $sz);
  $TextPtr->fillcolor($fg);
  $TextPtr->translate($x, $y);
  # Returns the width of the text added
  int($TextPtr->text($txt) + 0.5);
}

sub _textRight {
  my($x,$y,$txt,$font,$sz,$fg) = @_;

  $TextPtr->font($font, $sz);
  $TextPtr->fillcolor($fg);
  $TextPtr->translate($x, $y);
  # Returns the width of the text added
  int($TextPtr->text_right($txt) + 0.5);
}

# Centers text on the X axis but with
# the font base-line on the Y axis.
sub _textCenter {
  my($x,$y,$txt,$font,$sz,$fg) = @_;

  $TextPtr->font($font, $sz);
  $TextPtr->fillcolor($fg);

  $TextPtr->translate($x, $y);
  $TextPtr->text_center($txt);
  # Returns where the end of the text is
  int($x + ($TextPtr->advancewidth($txt) / 2) + 0.5);
}

sub _measure {
  my($txt,$font,$sz) = @_;

  $TextPtr->font($font, $sz);
  int($TextPtr->advancewidth($txt) + 0.5);
}

sub _bg {
  my($bg,$x,$y,$width,$ht) = @_;

  if ($bg ne '') {
    $GfxPtr->fillcolor($bg);
    $GfxPtr->rect($x, $y, $width, $ht);
    $GfxPtr->fill();
  }
}

sub close {
  my($self) = shift;
  $self->{pdf}->update();
  $self->{pdf}->end();
}

1;
