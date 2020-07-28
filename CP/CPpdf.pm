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
use CP::Chord;

my($TextPtr,$GfxPtr);

my $XSIZE = 8;
my $YSIZE = 10;
my $SPACE = 15;
my $FFSIZE = 0;

my $SUPHT = 0.6;

sub new {
  my($proto,$pro,$fn) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  my $pdf = PDF::API2->new(-file => "$fn");
  $self->{pdf} = $pdf;
  #
  # Do all the font jiggery-pokery ...
  #
  foreach my $m (['Title',     TITLE],
		 ['Lyric',     VERSE],
		 ['Chord',     CHORD],
		 ['Tab',       TAB],
		 ['Comment',   CMMNT],
		 ['Highlight', HLIGHT]) {
    my($media,$idx) = @{$m};
    my $cap = substr($media, 0, 1);
    $cap .= 'M' if ($idx == CMMNT);
    $cap .= 'B' if ($idx == TAB);
    my $fp = $Media->{"$media"};
    my $fam = $fp->{family};
    my $size = ceil($fp->{size});
    # return Bold, BoldItalic or Regular
    my $wt = pdfWeight($fp->{weight}, $fp->{slant});
    my $pfp = getFont($pdf, $fam, $wt);
    # Font metrics don't seem to follow the accepted standard where the total
    # height used by a font is (ascender + descender) and where the ascender
    # includes any extra height added by the composer.
    $self->{"${cap}sz"} = $size;
    $self->{"${cap}dc"} = abs(ceil(($pfp->descender * $size) / 1000));
    if ($idx == CHORD) {
      $self->{Cas} = $size;
      $self->{Ssz} = ceil($size * $SUPHT * 2) / 2;
    } else {
      if ($idx == CMMNT || $idx == HLIGHT) {
	$self->{"${cap}as"} = ceil(($pfp->ascender * $size) / 1000);
      } else {
	# This is essentially the height of a Capital.
	$self->{"${cap}as"} = $size - $self->{"${cap}dc"};
      }
      $self->{"${cap}dc"} += 2;
    }
    $self->{"${cap}clr"} = $fp->{color};
    $self->{hscale}[$idx] = 100;
    $self->{font}[$idx] = $pfp;
    if ($idx == CMMNT) {
     $self->{hscale}[CMMNTB] = $self->{hscale}[CMMNTI] = 100;
     $self->{font}[CMMNTB] = $pfp;
     $wt = ($wt eq 'Bold') ? 'BoldItalic' : 'Italic';
     $self->{font}[CMMNTI] = getFont($pdf, $fam, $wt);
    }
    $self->{"${cap}fam"} = $fam;
    $self->{"${cap}wt"} = $wt;
  }
  $self->{font}[GRID] = getFont($pdf, RESTFONT, 'Regular');

  $self->{page} = [];
  $FFSIZE = 0;

  bless $self, $class;
  return($self);
}

sub printSL {
  return if ($CurSet eq '');

  my $tmpMedia = $Opt->{Media};
  $Opt->{Media} = $Opt->{PrintMedia};
  $Media->change(\$Opt->{Media});

  my $list = $AllSets->{browser}{selLB}{array};
  my $tmpPDF = "$Path->{Temp}/$CurSet.pdf";
  my $pdf = PDF::API2->new(-file => "$tmpPDF");
  my $pp = $pdf->page;
  #
  # Do the font jiggery-pokery ...
  #
  my $fp = $Media->{"Title"};
  my $Tfam = $fp->{family};
  my $Tsz = ceil($fp->{size});
  # return Bold, BoldItalic or Regular
  my $Twt = pdfWeight($fp->{weight}, $fp->{slant});
  my $pfp = getFont($pdf, $Tfam, $Twt);
  my $Tdc = abs(ceil(($pfp->descender * $Tsz) / 1000)) + 1;
  my $Tclr = $fp->{color};
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
  if ($Media->{verseBG} ne WHITE) {
    $GfxPtr->fillcolor($Media->{verseBG});
    $GfxPtr->rect(0, 0, $w, $h);
    $GfxPtr->fill();
  }
  my $hht = $Tsz + 3;
  if ($Media->{titleBG} ne WHITE) {
    _hline(0, $h - ($hht / 2), $w, $hht, $Media->{titleBG});
  }
  _textCenter($w/2, $h - ($hht - $Tdc), $CurSet, $pfp, $Tsz, $Tclr);
  if ($AllSets->{meta}{date} ne '') {
    _textRight($w - INDENT, $h - ($hht - $Tdc), $AllSets->{meta}{date}, $pfp, $Lsz, $Tclr);
  }

  $h -= $hht;
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
  my $x = $w - $setw - (INDENT * 2);
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
  my $indent = INDENT * 2;
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
  main::PDFprint($tmpPDF) if (main::PDFview($tmpPDF));
  $Opt->{PDFprint} = $print;

  $Opt->{Media} = $tmpMedia;
  $Media->change(\$Opt->{Media});
}

sub getFont {
  my($pdf,$fam,$wt) = @_;

  my $pfp;
  if (! defined $FontList{"$fam"}) {
    $fam = 'Times New Roman';
    errorPrint("Font '$fam' not found.\nSubstituting 'Times New Roman'");
  }
  my $path = $FontList{"$fam"}{Path};
  my $file = $FontList{"$fam"}{$wt};
  if ($file eq '') {
    my %opts = ();
    if ($wt =~ /Bold/) {
      $opts{'-bold'} = $Opt->{Bold};
    }
    if ($wt =~ /Italic/) {
      $opts{'-oblique'} = $Opt->{Italic};
    }
    my $tmp = $pdf->ttfont($path.'/'.$FontList{"$fam"}{Regular});
    $pfp = $pdf->synfont($tmp, %opts);
  } else {
    $pfp = $pdf->ttfont($path.'/'.$file);
  }
  $pfp;
}

sub chordSize {
  my($self,$size) = @_;

  if (!defined $size || $size eq '') {
    $size = $Media->{Chord}{size};
  }
  my $fp = $self->{font}[CHORD]; 
  $self->{Cas} = $self->{Csz} = $size;
  $self->{Cdc} = abs(ceil(($fp->descender * $size) / 1000)) + 2;
  $self->{Ssz} = ceil($size * $SUPHT * 2) / 2;
  $FFSIZE = _measure("10", $fp, $self->{Csz} * $SUPHT) if (defined $TextPtr);
}

# Called in response to a {chordfont} directive.
sub chordFont {
  my($self,$font) = @_;

  if (!defined $font || $font eq '') {
    my $fp = $Media->{Chord};
    $font = "\{$fp->{family}\} $fp->{size} $fp->{weight} $fp->{slant}";
  }
  my ($fam,$sz,$wt) = fontAttr($self->{Cwt}, $font);

  if (defined $FontList{"$fam"}) {
    my $fp;
    if ($self->{Cfam} ne $fam || $self->{Cwt} ne $wt) {
      $fp = getFont($self->{pdf}, $fam, $wt);
      $self->{font}[CHORD] = $fp;
      $self->{Cfam} = $fam;
      $self->{Cwt} = $wt;
    } else {
      $fp = $self->{font}[CHORD];
    }
    $self->{Cas} = $self->{Csz} = $sz;
    $self->{Cdc} = abs(ceil(($fp->descender * $sz) / 1000)) + 2;
    $self->{Ssz} = ceil($sz * $SUPHT * 2) / 2;
    $FFSIZE = _measure("10", $fp, $self->{Csz} * $SUPHT) if (defined $TextPtr);
  } else {
    error("Chord", $fam, $wt);
  }
}

sub lyricSize {
  my($self,$size) = @_;

  if (!defined $size || $size eq '') {
    $size = $Media->{Lyric}{size};
  }
  my $fp = $self->{font}[VERSE]; 
  $self->{Lsz} = $size;
  $self->{Ldc} = abs(ceil(($fp->descender * $size) / 1000));
  $self->{Las} = $size - $self->{Ldc};
  $self->{Ldc} += 2;
}

# Called in response to a {textfont} directive.
sub lyricFont {
  my($self,$font) = @_;

  if (!defined $font || $font eq '') {
    my $fp = $Media->{Lyric};
    $font = "\{$fp->{family}\} $fp->{size} $fp->{weight} $fp->{slant}";
  }
  my($fam,$sz,$wt) = fontAttr($self->{Lwt},$font);

  if (defined $FontList{"$fam"}) {
    my $fp;
    if ($self->{Lfam} ne $fam || $self->{Lwt} ne $wt) {
      $fp = getFont($self->{pdf}, $fam, $wt);
      $self->{font}[VERSE] = $fp;
      $self->{Lfam} = $fam;
      $self->{Lwt} = $wt;
    } else {
      $fp = $self->{font}[VERSE];
    }
    $self->{Lsz} = $sz;
    $self->{Ldc} = abs(ceil(($fp->descender * $sz) / 1000));
    $self->{Las} = $sz - $self->{Ldc};
    $self->{Ldc} += 2;
  } else {
    error("Lyric", $fam, $wt);
  }
}

sub tabSize {
  my($self,$size) = @_;

  if (!defined $size || $size eq '') {
    $size = $Media->{Tab}{size};
  }
  my $fp = $self->{font}[TAB]; 
  $self->{TBsz} = $size;
  $self->{TBdc} = abs(ceil(($fp->descender * $size) / 1000));
  $self->{TBas} = $size - $self->{TBdc};
  $self->{TBdc} += 2;
}

# Called in response to a {textfont} directive.
sub tabFont {
  my($self,$font) = @_;

  if (!defined $font || $font eq '') {
    my $fp = $Media->{Tab};
    $font = "\{$fp->{family}\} $fp->{size} $fp->{weight} $fp->{slant}";
  }
  my($fam,$sz,$wt) = fontAttr($self->{TBwt},$font);

  if (defined $FontList{"$fam"}) {
    my $fp;
    if ($self->{TBfam} ne $fam || $self->{TBwt} ne $wt) {
      $fp = getFont($self->{pdf}, $fam, $wt);
      $self->{font}[TAB] = $fp;
      $self->{TBfam} = $fam;
      $self->{TBwt} = $wt;
    } else {
      $fp = $self->{font}[TAB];
    }
    $self->{TBsz} = $sz;
    $self->{TBdc} = abs(ceil(($fp->descender * $sz) / 1000));
    $self->{TBas} = $sz - $self->{TBdc};
    $self->{TBdc} += 2;
  } else {
    error("Tab", $fam, $wt);
  }
}

sub fontAttr {
  my($pwt,$str) = @_;

  my $owt = ($pwt =~ /bold/i) ? 'bold' : '';
  my $osl = ($pwt =~ /italic/i) ? 'italic' : '';
  my ($fam,$sz,$nwt,$nsl);
  if ($str =~ /^\s*\{([^\}]+)\}\s*(\d*)\s*(\S*)\s*(\S*)/) {
    $fam = $1;
    $sz = $2;
    $nwt = $3;
    $nsl = $4;
  }
  else {
    ($fam,$sz,$nwt,$nsl) = split(' ',$str);
    $sz = '' if (!defined $sz);
    $nwt = '' if (!defined $nwt);
    $nsl = '' if (!defined $nsl);
  }
  $nwt = $owt if ($nwt eq '');
  $nsl = $osl if ($nsl eq '');
  ($fam,$sz,pdfWeight($nwt, $nsl));
}

sub pdfWeight {
  my($wt,$sl) = @_;

  my $nwt = ($wt eq 'bold') ? 'Bold' : '';
  $nwt .= 'Italic' if ($sl eq 'italic');
  $nwt = 'Regular' if ($nwt eq '');
  $nwt;
}

sub error {
  my($type,$fam,$wt) = @_;
  errorPrint("$type Font '$fam $wt' does not exist - reverting to original font.");
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
  my $hht = $self->{Tsz} + 3;
  if ($Media->{titleBG} ne WHITE) {
    _bg($Media->{titleBG}, 0, $h - $hht, $w, $hht);
  }
  _textCenter($w/2, $h - ($hht - $self->{Tdc} - 1),
	      $pro->{title}, $self->{font}[TITLE], $self->{Tsz}, $Media->{Title}{color});

  $h -= $hht;
  _hline(0, $h + 0.5, $w, 1, DBLUE);

  my $offset = 0;
  my $tht = $h + $self->{Tdc} + 2;
  my $th = $self->{Tsz} * KEYMUL;
  my $dc = $self->{Tdc} * KEYMUL;
  my $cc = $Media->{Chord}{color};

  if ($pro->{key} ne '') {
    my $tw = _textAdd(INDENT, $tht, "Key: ", $self->{font}[TITLE], $th, BLACK);
    my($ch,$cname) = CP::Chord->new($pro->{key});
    $ch = $ch->trans2obj($pro) if ($Opt->{Transpose} ne 'No');
    chordAdd($self, INDENT + $tw, $tht, $ch, $cc, $th);
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
	$offset = _textAdd(INDENT, $h, "Tempo: ", $self->{font}[TITLE], $th, BLACK);
	_textAdd(INDENT + $offset, $h, "$pro->{tempo}", $self->{font}[TITLE], $th, $cc);
	$h -= $dc;
      }
      if ($pro->{note} ne '') {
	$h -= ($th - $dc);
	my $tw = _textAdd(INDENT, $h, "Note: ", $self->{font}[TITLE], $th, BLACK) + INDENT;
	$offset = $tw if ($offset == 0);
	_textAdd(INDENT + $offset, $h, $pro->{note}, $self->{font}[TITLE], $th, $cc);
	$h -= $dc;
      }
      if ($pro->{capo} ne 0 && $Opt->{LyricOnly} == 0) {
	$h -= ($th - $dc);
	my $tw = _textAdd(INDENT, $h, "Capo: ", $self->{font}[TITLE], $th, BLACK);
	$offset = $tw if ($offset == 0);
	$tw = _textAdd(INDENT + $offset, $h, "$pro->{capo}", $self->{font}[TITLE], $th, $cc);
	if ($Opt->{IgnCapo}) {
	  $offset += $tw;
	  $tw = int(($th / 4) * 3);
	  _textAdd(INDENT + $offset, $h, "  (ignored)", $self->{font}[TITLE], $tw, $cc);
	}
	$h -= $dc;
      }
      $h -= 1;
    }
  }
  if ($offset) {
    _hline(0, $h, $w, 0.5, DBLUE);
  }

  if ($Opt->{Grid} != NONE && ($pn == 1 || $Opt->{Grid} == ALLP)) {
    $h -= INDENT;
    $FFSIZE = _measure("10", $self->{font}[CHORD], $self->{Csz} * $SUPHT) if ($FFSIZE == 0);
    my($cnt,$xinc) = fingersWidth();
    my $margin = INDENT * 2;
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
#  $h -= INDENT;
  $h;
}

sub pageNum {
  my($self,$npage) = @_;

  my $h = $Media->{height} - $self->{Tsz} + $self->{Tdc};
  my $npg = 0 - $npage;
  my $pn = 1;
  my $ptext = $TextPtr;
  while ($npg) {
    my $pp = $self->{page}[$npg++];
    my $page = "Page ".$pn++." of $npage ";
    $TextPtr = $pp->text();
    _textRight($Media->{width} - INDENT, $h,
	       $page, $self->{font}[TITLE], ceil($self->{Tsz} * PAGEMUL), BROWN);
    $TextPtr->textend;
  }
  $TextPtr = $ptext;
}

#
# Return the height (in points) of one chord finger display
#
sub fingerHeight {
  my($self,$name) = @_;

  my $tht = $self->{Csz} * $SUPHT;
  my $tdc = $self->{Cdc} * $SUPHT;
  my $ly = $self->{Csz} + $tht + $tdc;
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

  my($nc,$inc) = fingersWidth();
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
  my $w = $Media->{width} - (INDENT * 4);
  my $cw = (($Nstring - 1) * $XSIZE) + $FFSIZE + $SPACE; # min size of a chord diagram + spacer
  my $nc = int($w / $cw);                                # number of chords we can draw
  $cw += int(($w - ($nc * $cw) + $SPACE) / ($nc - 1));   # even out any leftover space
  ($nc,$cw);
}

sub drawFinger {
  my($self,$pro,$x,$y,$name) = @_;

  my ($ch,$cname) = CP::Chord->new($name);
  if ($KeyShift) {
    $cname = $ch->trans2str($pro);
    $ch = $ch->trans2obj($pro);
  }
  my $dx = chordLen($self, $ch) / 2;
  my $ns = $Nstring - 1;
  my $ly = $y;
  my $lmy = $y;
  my $mx = $x;
  my $fp = $self->{font}[CHORD];
  my $fc = $Media->{Chord}{color};
  my $tht = $self->{Csz} * $SUPHT;
  my $tdc = $self->{Cdc} * $SUPHT;
  my $vsz = $YSIZE/2;
  $ly -= $self->{Csz};  # minus Cdc?
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
  if (exists $pro->{finger}{"$cname"}{base}) {
    $fptr = \%{$pro->{finger}{$cname}};
  } elsif (exists $Fingers{"$cname"}{base}) {
    $fptr = \%{$Fingers{$cname}};
  }
  if (ref($fptr) ne "") {
    my $base = $fptr->{base};
    my $frptr = $fptr->{fret};
    my $max = 0;
    foreach (0..$ns) {
      my $fr = $frptr->[$_];
      if ($fr =~ /[-xX0]/) {
	_textCenter($mx, $ly, ($fr eq '0') ? 'o' : 'x', $fp, $tht, $fc);
      }
      $mx += $XSIZE;
      $max = $fr if ($fr =~ /\d+/ && $fr > $max);
    }
    $ly -= $tdc;
    # Draw Frets
    $GfxPtr->linewidth(1);
    $GfxPtr->linecap(0);
    $lmy = $ly;
    $mx = $ns * $XSIZE;
    for (0..$max) {
      my $dx = $x + $mx;
      $dx += 2 if ($_ == 1);
      $GfxPtr->move($x, $lmy);
      $GfxPtr->hline($dx);
      $GfxPtr->stroke();
      $lmy -= $YSIZE;
    }
    # Draw the base fret number to the right of the first fret
    # NOTE: the nut is NOT considered to be a fret.
    _textAdd($x + $mx + 3, $ly - $YSIZE - $tdc, "$base", $fp, $tht, $fc);
    my $bfw = $mx + 3 + $FFSIZE;
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
    $ly -= ($self->{Csz}*2);
    _textCenter($x+($XSIZE*$ns/2), $ly, 'X', $fp, $self->{Csz}*2, RED);
    $mx = (($XSIZE * $ns) + 3 + $FFSIZE);
    $lmy = $ly;
  }
  ($mx,$y-int($lmy + 1));
}

# A 'Chord' object is an array eg: C [#b] maj7 / G [#b] maj7 text
sub chordAdd {
  my($self,$x,$y,$ch,$clr,$ht) = @_;

  $ht = $self->{Csz} if (!defined $ht);
  my $fp = $self->{font}[CHORD];
  $x += _textAdd($x, $y, $ch->[0], $fp, $ht, $clr);
  if ($#$ch > 0) {
    my $sht = ceil($ht * $SUPHT);
    my $sy = $y + ceil($sht * $SUPHT);
    my $s = $ch->[1].$ch->[2];
    $x += _textAdd($x, $sy, $s, $fp, $sht, $clr) if ($s ne "");
    $x += _textAdd($x, $y, $ch->[3], $fp, $ht, $clr) if ($ch->[3] ne "");
    if ($#$ch > 3) {
      $x += _textAdd($x, $y, $ch->[4], $fp, $ht, $clr);
      $s = $ch->[5].$ch->[6];
      $x += _textAdd($x, $sy, $s, $fp, $sht, $clr) if ($s ne "");
      $x += _textAdd($x, $y, $ch->[7], $fp, $ht, $clr) if ($ch->[7] ne "");
    }
  }
}

sub chordLen {
  my($self, $ch) = @_;

  my $fp = $self->{font}[CHORD];
  my $nx = _measure($ch->[0], $fp, $self->{Csz});
  if ($#$ch > 0) {
    my $sht = ceil($self->{Csz} * $SUPHT);
    my $s = $ch->[1].$ch->[2];
    $nx += _measure($s, $fp, $sht) if ($s ne "");
    $nx += _measure($ch->[3], $fp, $self->{Csz}) if ($ch->[3] ne "");
    if ($#$ch > 3) {
      $nx += _measure($ch->[4], $fp, $self->{Csz});
      $s = $ch->[5].$ch->[6];
      $nx += _measure($s, $fp, $sht) if ($s ne "");
      $nx += _measure($ch->[7], $fp, $self->{Csz}) if ($ch->[7] ne "");
    }
  }
  $nx;
}

sub lyricAdd {
  my($self,$x,$y,$txt,$clr) = @_;
  _textAdd($x, $y, $txt, $self->{font}[VERSE], $self->{Lsz}, $clr);
}

sub lyricLen {
  my($self,$txt) = @_;
  _measure($txt, $self->{font}[VERSE], $self->{Lsz});
}

sub hline {
  my($self,$x,$y,$h,$w,$clr) = @_;

  if ($clr ne '') {
    $x = int(($Media->{width} - $w) / 2) if ($Opt->{Center});
    _bg($clr, $x, $y, $w, $h);
  }
}

#______________________________________
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
  my($self,$type,$y,$txt,$fg,$bg) = @_;

  my $dc = ($type == HLIGHT) ? $self->{Hdc}: $self->{CMdc};
  my $sz = ($type == HLIGHT) ? $self->{Hsz}: $self->{CMsz};
  my $tw = _measure($txt, $self->{font}[$type], $sz);
  my($bw,$x) = (0,0);
  if ($type == HLIGHT) {
    $bw = $Media->{width} if ($Opt->{FullLineHL});
  } else {
    $bw = $Media->{width} if ($Opt->{FullLineCM});
  }
  if ($bw == 0) {
    # Not a full width background
    $bw = $tw + (INDENT * 2);
    $x = int(($Media->{width} - $bw) / 2) if ($Opt->{Center});
  }
  $self->commentBG($x, $y, $type, $bg, $bw);
  $x = int(($Media->{width} - $tw) / 2) - INDENT if ($Opt->{Center});
  _textAdd($x + INDENT, $y + $dc, $txt, $self->{font}[$type], $sz, $fg);
}

sub commentBG {
  my($self,$x,$y,$type,$bg,$w) = @_;

  if ($bg eq "") {
    # These can be changed dynamically in "Background Colours".
    $bg = ($type == HLIGHT) ? $Media->{highlightBG} : $Media->{commentBG};
  }
  my $ht = ($type == HLIGHT) ? $self->{Hdc} + $self->{Has}: $self->{CMdc} + $self->{CMas};
  _bg($bg, $x, $y, $w, $ht);
  if ($type == CMMNTB) {
    $GfxPtr->linewidth(1);
    $GfxPtr->strokecolor(BLACK);
    $GfxPtr->rect($x + 0.5, $y, $w - 1, $ht);
    $GfxPtr->stroke();
  }
}

sub _hline {
  my($x,$y,$xx,$t,$clr) = @_;

  $GfxPtr->linewidth($t);
  $GfxPtr->strokecolor($clr);
  $GfxPtr->fillcolor($clr);
  $GfxPtr->move($x, $y);
  $GfxPtr->hline($xx);
  $GfxPtr->stroke();
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

sub _textCenter {
  my($x,$y,$txt,$font,$sz,$fg) = @_;

  $TextPtr->font($font, $sz);
  $TextPtr->fillcolor($fg);

  $TextPtr->translate($x, $y);
  $TextPtr->text_center($txt);
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
