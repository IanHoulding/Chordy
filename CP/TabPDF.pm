package CP::TabPDF;

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

use CP::Cconst qw/:BROWSE :SMILIE :TEXT :MUSIC :COLOUR :FONT :TAB/;
use CP::Global qw/:FUNC :WIN :OPT :XPM :CHORD/;
use CP::Tab;
use CP::Cmsg;
use CP::Lyric;
use PDF::API2;
use PDF::API2::Resource::CIDFont::TrueType;
use CP::PDFfont;
use POSIX;
use Math::Trig;

our($GfxPtr,$TextPtr);

sub new {
  my($proto,$tab) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;

  $self->{page} = [];
  $self->{bars} = [];
  if ($tab->{PDFname} eq '') {
    if ($tab->{fileName} eq '') {
      return '' if ($tab->checkSave() eq 'Cancel' || $tab->{fileName} eq '');
    } else {
      ($tab->{PDFname} = $tab->{fileName}) =~ s/.tab$/.pdf/i;
    }
  }
  $self->{tmpFile} = "$Path->{Temp}/$tab->{PDFname}";
  unlink($self->{tmpFile}) if (-e $self->{tmpFile});
  my $pdf = $self->{pdf} = PDF::API2->new(-file => "$self->{tmpFile}");
  #
  # Do all the font jiggery-pokery ...
  #
  foreach my $m (['Title',  TITLE],
		 ['Header', HEADER],
		 ['Notes',  NOTES],
		 ['SNotes', SNOTES],
		 ['Words',  WORDS]) {
    my($media,$idx) = @{$m};
    my $pfp = $self->{fonts}[$idx] = CP::PDFfont->new($media, $idx, $pdf);
    my $size = $pfp->{sz};
    $pfp->{dc} = ceil((abs($pfp->{font}->descender) * $size) / 1000);
    $pfp->{cap} = $size - $pfp->{dc};
    $pfp->{mid} = $pfp->{cap} / 2;
    $pfp->{hscale} = 100;
  }
  my $copy = $self->{fonts}[RESTS] = $self->{fonts}[NOTES]->copy();
  $copy->{fam} = RESTFONT;
  $copy->{wt} = $copy->{sl} = 0;
  $self->{fonts}[RESTS]{font} = $copy->getFont($pdf, NOTES);

  return($self);
}

sub newTextGfx {
  my($pp) = shift;

  $GfxPtr = $pp->gfx();
  $GfxPtr->linecap(1);
  $TextPtr->textend() if (defined $TextPtr);
  $TextPtr = $pp->text();
}

sub batch {
  my($tab) = shift;

  my $pop = CP::Pop->new(0, '.bp', 'Batch PDF');
  return if ($pop eq '');
  my($top,$frm) = ($pop->{top}, $pop->{frame});

  my $done = '';
  my $x = Tkx::winfo_pointerx($MW);
  my $y = Tkx::winfo_pointery($MW);
  my @files = CP::Browser->new($MW, FILE, $Path->{Tab}, '.tab');
  return if ($files[0] eq '');
  my $pl = (@files > 1) ? 's' : '';

  my $lab = $frm->new_ttk__label(
    -text => "The following tab$pl will have a PDF created:",
    -font => 'BTkDefaultFont');
  my $text = $frm->new_tk__text(
    -width => 45,
    -height => 30,
    -font => 'TkDefaultFont',
    -spacing1 => 4,
    -relief => 'raised',
    -borderwidth => 2,
    -highlightthickness => 0,
    -selectborderwidth => 0,
    -wrap=> 'none');
  my $bfrm = $frm->new_frame();
  my $can = $bfrm->new_ttk__button(
    -text => 'Cancel',
    -style => 'Red.TButton',
    -command => sub{$done='Cancel';});
  my $con = $bfrm->new_ttk__button(
    -text => 'Continue',
    -style => 'Green.TButton',
    -command => sub{$done='Continue';});
  $lab->g_pack(qw/-side top -anchor w/);
  $text->g_pack(qw/-side top -pady 4/);
  $bfrm->g_pack(qw/-side top -fill x/);
  $can->g_pack(qw/-side left -padx 8/);
  $con->g_pack(qw/-side right -padx 8/);
  foreach my $fn (@files) {
    $text->insert('end', "$fn\n");
  }
  $text->configure(-state => 'disabled');
  $con->g_focus();
  Tkx::vwait(\$done);
  if ($done eq 'Continue') {
    $text->tag_configure('red',   -foreground => RFG, -font => 'BTkDefaultFont');
    $text->tag_configure('green', -foreground => DGREEN, -font => 'TkDefaultFont');
    # The minus 10 & 5 take away the default values added by CP::Cmsg::message()
    $x += (Tkx::winfo_reqwidth($frm) - 10);
    $y -= 5;
    my $idx = 1;
    foreach my $fn (@files) {
      textConf($text, $idx, 'red');
      $tab->new("$Path->{Tab}/$fn");
      $tab->drawPageWin();
      CP::Cmsg::position($x,$y);
      make('M');
      textConf($text, $idx++, 'green');
    }
    $tab->new('');
    $tab->drawPageWin();
    CP::Cmsg::position($x,$y);
    message(SMILE, " Done ", -1);
  }
  $pop->popDestroy();
}

sub textConf {
  my($text,$idx,$clr) = @_;

  $text->configure(-state => 'normal');
  $text->tag_add($clr, "$idx.0", "$idx.end");
  $text->configure(-state => 'disabled');
  Tkx::update();
}

sub make {
  my($tab,$what) = @_;

  return if ($tab->{bars} == 0);
  $tab->{lyrics}->collect() if ($Opt->{LyricLines});
  return if ((my $pdf = CP::TabPDF->new($tab)) eq '');
  # There doesn't seem to be an easy way round this -
  # we have to do 2 passes, one for the bar backgrounds
  # and then a second to paint the actual bars otherwise
  # the background of the following bar will paint over
  # the end of the current bar.

  # PASS 1
  # At the same time we'll transpose the Canvas XY co-ords
  # to PDF co-ords
  #
  my $pageht = $Media->{height};
  my $pageNum = 0;
  my($x,$y) = ($Opt->{LeftMargin},$pageht);
  my $off = $tab->{bars}{offset};
  my $h = $off->{height};
  my $w = $off->{width};
  my $u = $off->{interval};
  my $ss = $off->{staffSpace};
  my $oldlb = $tab->{lastBar};
  my $lbnext = 0;
  # Find the last non-blank bar and make it the last.
  for(my $bar = $tab->{lastBar}; $bar != 0; $bar = $bar->{prev}) {
    if ($bar->isblank() == 0) {
      $tab->{lastBar} = $bar;
      $lbnext = $bar->{next};
      $bar->{next} = 0;
      last;
    }
  }
  my $ntfp = $pdf->{fonts}[NOTES];
  for(my $bar = $tab->{bars}; $bar != 0; $bar = $bar->{next}) {
    if ($bar->{newpage}) {
      $x = $Opt->{LeftMargin};
      $y = $pageht;
    }
    elsif ($bar->{newline} && $x > $Opt->{LeftMargin}) {
      $x = $Opt->{LeftMargin};
      $y -= $h;
      $y = $pageht if (($y - $h) < $Opt->{BottomMargin});
    }
    if ($y == $pageht) {
      $y = $pdf->newPage($tab);
      $pageNum++;
    }

    my $xy = {};
    $xy->{x} = $xy->{staffX} = $x;
    $xy->{y} = $y;
    $xy->{pos0} = $x + $off->{pos0};
    $xy->{staffY} = $y - $off->{header};
    $xy->{staff0} = $xy->{staffY} - $off->{staffHeight};
    $bar->{xy} = $xy;
    $bar->{pageNum} = $pageNum;

    foreach my $n (@{$bar->{notes}}) {
      my $offset = $ntfp->{mid};
      $offset *= 0.8 if ($n->{fret} eq 'X');
      $n->{x} = $x + ($u * ($n->{pos} + 2));
      $n->{y} = $xy->{staff0} + ($ss * $n->{string}) - $offset if ($n->{string} != REST);
    }

    _bg($bar->{bg}, $x-2, $y - $off->{height}, $w+4, $off->{height});

    $x += $w;
    if (($x + $w) > $Media->{width}) {
      $x = $Opt->{LeftMargin};
      $y -= $h;
      $y = $pageht if (($y - $h) < $Opt->{BottomMargin});
    }
  }

  # PASS 2
  #
  my $lidx = my $pn = my $tn = 0;
  for(my $bar = $tab->{bars}; $bar != 0; $bar = $bar->{next}) {
    if ($bar->{pageNum} != $pn) {
      newTextGfx($pdf->{page}[$pn]);
      $lidx = $pn * $tab->{rowsPP};
      $pdf->pageNum(++$pn);
      $tn++ if ($pn == 1);
    }

    $pdf->bar($bar);

    if ($bar->{xy}{x} == $Opt->{LeftMargin} && $Opt->{LyricLines}) {
      $pdf->lyrics($lidx++, $bar);
    }
    if ($tn == 1) {
      $h = $pdf->{headerBase} - $Opt->{TopMargin};
      my $tifp = $pdf->{fonts}[TITLE];
      my $th = int($tifp->{sz} * KEYMUL);
      my $dc = int($tifp->{dc} * KEYMUL);
      if ($tab->{note} ne '') {
	my $txt = " $tab->{note} ";
	my $tw = _measure($pdf, $txt, TITLE, $th, 100);
	my $x = $Media->{width} - $Opt->{RightMargin} - $tw - 2;
	my $y = $h - $th - $dc;
	_bg('#FFFF80', $x, $y - 1, $tw, $th + 2);
	_textAdd($pdf, $x, $y + $dc, $txt, TITLE, $th, '#000060');
      }
      if (defined $tab->{tempo}) {
	my $ht = int($tab->{symSize} * (PAGEMUL - 0.1));
	my $y = $h - $ht;
	my $x = ($Media->{width} / 2) - $ht;
	my $wid = _textAdd($pdf, $x, $y + 2, 'O', RESTS, $ht, BLACK);
	$ht = $tab->{titleSize} * PAGEMUL;
	_textAdd($pdf, $x + $wid, $y + 1, " = ".$tab->{tempo}, TITLE, $ht, BLACK);
      }
      $tn++;
    }
  }
  $pdf->close();
  $tab->{lastBar}{next} = $lbnext;
  $tab->{lastBar} = $oldlb;
  #
  # At this point we have a file named tmpTab.pdf in the "Temp" folder.
  if ($what =~ /V|P/) {
    if ($what eq 'P') {
      jobSpawn("$Cmnd->{Print} \"$pdf->{tmpFile}\"");
    } else {
      jobSpawn("$Cmnd->{Acro} \"$pdf->{tmpFile}\"");
    }
  } elsif ($what eq 'M') {
    my $txt = read_file("$pdf->{tmpFile}");
    my $PDFname = "$Path->{PDF}/$tab->{PDFname}";
    unlink("$PDFname") if (-e "$PDFname");
    write_file("$PDFname", $txt);
    if ($Opt->{PDFpath} ne '' && $Opt->{PDFpath} ne $Path->{PDF}) {
      my $copyName = "$Opt->{PDFpath}/$tab->{PDFname}";
      unlink("$copyName") if (-e "$copyName");
      write_file("$copyName", $txt);
    }
    unlink("$pdf->{tmpFile}");
    message(SMILE, "Made", 1);
  }
}

sub newPage {
  my($self,$tab) = @_;

  my $tifp = $self->{fonts}[TITLE];
  my $tfp = $tifp->{font};

  my $w = $Media->{width};
  my $h = $Media->{height};
  my $pp = $self->{pdf}->page;
  push(@{$self->{page}}, $pp);
  $pp->mediabox($w, $h);
  $pp->cropbox(0, 0, $w, $h);
  newTextGfx($pp);

  $h -= ($tifp->{sz} + 3);
  $self->{headerBase} = $h + 1;

  if ($Media->{titleBG} ne WHITE) {
    _bg($Media->{titleBG}, 0, $h, $w, $tab->{pageHeader});
  }
  _textCenter($self, $w/2, $self->{headerBase} + $tifp->{dc},
	      $tab->{title}, TITLE, $tifp->{sz}, $tifp->{clr});

  $h -= 1;
  _bg(DBLUE, 0, $h, $w, 1);

  my $tbl = $self->{headerBase} + $tifp->{dc};
  my $th = int($tifp->{sz} * KEYMUL);
  my $dc = int($tifp->{dc} * KEYMUL);
  if ($tab->{key} ne '-') {
    my $tw = _textAdd($self, $Opt->{LeftMargin}, $tbl, "Key: ", TITLE, $th, bFG);
    my $ch = [split('',$tab->{key})];
    chordAdd($self, $Opt->{LeftMargin} + $tw, $tbl, $ch, $Media->{Chord}{color}, $th);
  }
  $h -= $Opt->{TopMargin};
}

sub pageNum {
  my($self,$pn) = @_;

  my $fp = $self->{fonts}[TITLE];
  my $fntht = $fp->{sz} * PAGEMUL;
  my $y = $self->{headerBase} + $fp->{dc};
  my $npg = @{$self->{page}} + 0;
  _textRight($self, $Media->{width} - $Opt->{RightMargin}, $y, "Page $pn of $npg ", TITLE, $fntht, BROWN);
}

sub chordAdd {
  my($self,$x,$y,$ch,$clr,$ht) = @_;

  my $sht = int($ht * 0.8);
  $ht = $self->{fonts}[NOTES]{sz} if (!defined $ht);
  $x += _textAdd($self, $x, $y, $ch->[0], NOTES, $ht, $clr);
  if (defined $ch->[1]) {
    # Make the base line for superscript 1/2 the height of a capital
    $x += _textAdd($self, $x, $y + int($ht / 2), $ch->[1], NOTES, $sht, $clr);
  }
  $x;
}

# All the absolute xy values are in the %{$xy} hash.
sub bar {
  my($self,$bar) = @_;

  my $xy = $bar->{xy};
  my $off = $bar->{offset};
  my($x,$y,$w,$h) = ($xy->{x},$xy->{y},$off->{width},$off->{staffHeight});
  # Staff Lines
  my $ly = $xy->{staffY};
  my $lx = $x;
  my $lw = $w + $lx;
  my $ss = $off->{staffSpace};
  foreach (1..$Nstring) {
    _hline($lx, $ly, $lw, THIN, BLACK);
    $ly -= $ss;
  }
  # Bar Lines
  $lx = $xy->{pos0};
  $ly += $ss;
  my $un = $off->{interval} * 8;
  (my $t = $bar->{tab}{Timing}) =~ s/(\d).*/$1/;
  foreach (1..$t) {
    _vline($lx, $ly, $ly + $h, (THIN / 2), BLACK);
    $lx += $un;
  }
  #
  # The bar start vline is a bit of a problem. If the previous
  # bar is physically just before this one AND it has a repeat
  # end marker, it would get overwritten.
  #
  $ly += (THIN / 2);
  if ($x == $Opt->{LeftMargin} || ($bar->{prev}{rep} ne 'End')) {
    _vline($x, $ly, $ly + $h - THIN, THICK, BLACK);
  }
  _vline($x + $w, $ly, $ly + $h - THIN, THICK, BLACK);

  #
  # Handle anything that needs to go above the Bar.
  #
  my $hdfp = $self->{fonts}[HEADER];
  $ly = $y - (FAT / 2);
  my $txt = '';
  if ($bar->{volta} ne 'None') {
    _hline($x, $ly, $x + $off->{width}, FAT, $hdfp->{clr});
    if ($bar->{volta} ne 'Center') {
      if ($bar->{volta} =~ /Left|Both/) {
	_vline($x, $ly, $xy->{staffY} + INDENT, FAT, $hdfp->{clr});
      }
      if ($bar->{volta} =~ /Right|Both/) {
	_vline($x+$w, $ly, $xy->{staffY} + INDENT, FAT, $hdfp->{clr});
      }
    }
  }
  if ($bar->{header} ne '') {
    if ($bar->{justify} eq 'Right') {
      $lx = $x + $w - _measure($self, $bar->{header}, HEADER, $hdfp->{sz},
			       $hdfp->{hscale}) - (THICK * 2);
    } else {
      $lx = $x;
    }
    _adjTextAdd($self, $bar->{tab}, $lx, $ly - $hdfp->{cap} - FAT,
		$bar->{header}, $bar->{tab}{headFont}, HEADER, $hdfp->{sz}, $hdfp->{clr});
  }
  #
  # Handle start of repeat and/or repeat count.
  #
  if ($bar->{rep} eq 'Start') {
    repStart($x, $xy->{staffY}, $off->{staffHeight}, $hdfp->{clr});
  }
  if ($bar->{rep} eq 'End') {
    repEnd($x + $w, $xy->{staffY}, $off->{staffHeight}, $hdfp->{clr});
  }
  notes($self, $bar);
}

sub repStart {
  my($x,$y,$h,$clr) = @_;

  $GfxPtr->linecap(0);
  $x -= FAT;
  $y -= $h;
  _vline($x, $y, $y + $h, FAT, $clr);
  $x += FAT;
  _vline($x, $y, $y + $h, THICK, $clr);
  $GfxPtr->linecap(1);
  $x += (FAT * 1.5);
  $y += ($h / 2);
  my $dy = FAT * 1.75;
  $GfxPtr->fillcolor($clr);
  $GfxPtr->circle($x, $y + $dy, FAT);
  $GfxPtr->fill();
  $GfxPtr->circle($x, $y - $dy, FAT);
  $GfxPtr->fill();
}

sub repEnd {
  my($x,$y,$h,$clr) = @_;

  $GfxPtr->linecap(0);
  $x += FAT;
  $y -= $h;
  _vline($x, $y, $y + $h, FAT, $clr);
  $x -= FAT;
  _vline($x, $y, $y + $h, THICK, $clr);
  $GfxPtr->linecap(1);
  $x -= (FAT * 1.5);
  $y += ($h / 2);
  my $dy = FAT * 1.75;
  $GfxPtr->fillcolor($clr);
  $GfxPtr->circle($x, $y + $dy, FAT);
  $GfxPtr->fill();
  $GfxPtr->circle($x, $y - $dy, FAT);
  $GfxPtr->fill();
}

sub notes {
  my($self,$bar) = @_;

  my $xy = $bar->{xy};
  my $off = $bar->{offset};
  my $x = $xy->{pos0};
  my $ss = $off->{staffSpace};
  my $u = $off->{interval};

  foreach my $n (@{$bar->{notes}}) {
    if ($n->{string} == REST) {
      my $y = $xy->{staff0} + $off->{staffHeight};
      my $num = $n->{fret};
      if ($num <= 2) {
	my $ht = $ss / 4;
        $y -= ($num == 1) ? ($ss + $ht) : $ss * 2;
        _bg(BLACK, $x + ($u * $n->{pos}) - $u, $y, ($u * 2), $ht);
      } else {
	_textCenter($self,
		    $x + ($u * $n->{pos}),
		    $y - ($off->{staffHeight} / 2),
		    chr(64 + $num),
		    RESTS, $bar->{tab}{symSize}, BLACK);
      }
    } else {
      my $y = $xy->{staff0};
      my($fp,$fidx,$fh,$offset,$clr);
      $fidx = ($n->{font} eq 'Normal') ? NOTES : SNOTES;
      $fp = $self->{fonts}[$fidx];
      $fh = $fp->{sz};
      $offset = $fp->{cap};
      $clr = $fp->{clr};


      $offset /= 2;
      my $adj = 1.0;
      $n->{x} = $x + ($u * $n->{pos});
      my $ht = $fh;
      $ht *= ($adj = 0.8) if ($n->{fret} eq 'X');
      $n->{y} = $y + ($ss * $n->{string}) - ($offset * $adj);
      my $hs = $fp->{hscale};
      if ($n->{fret} eq 'X') {
	$clr = BLACK;
      } elsif ($n->{fret} > 9) {
	$fp->{hscale} = 65;
      }
      _textCenter($self, $n->{x}, $n->{y}, $n->{fret}, $fidx, $ht, $clr);
      $fp->{hscale} = $hs;
      if ($n->{shbr} =~ /^[shbrv]{1}$/) {
	$n->{adj} = $adj;
	if ($n->{shbr} =~ /s|h/) {
	  slideHam($self,$n,$u,$ss);
	} elsif ($n->{shbr} =~ /b|r/) {
	  bendRel($self,$n,$u,$ss);
	}
      }
    }
  }
}

sub NoteSlideHam {
  my($self,$fnt,$tag) = @_;

  my $nn = $self->next();
  if (! defined $nn || $nn->{string} != $self->{string}) {
    $self->{shbr} = '';
    return;
  }
  $nn->{shbr} = $self;
  my $bar = $self->{bar};
  my $tab = $bar->{tab};
  my $can = $bar->{canvas};
  my $off = $bar->{offset};
  my $fat = $off->{fat};
  my $ss = $off->{staffSpace};
  my $u = $off->{interval};
  my($x,$y) = my($x1,$y1) = $self->selfXY();
  my $pos = $self->{pos};
  my $topos = $nn->{pos};

  my $clr = $tab->{headColor};
  $clr = CP::FgBgEd::lighten($clr, PALE) if ($bar->{pidx} == -2);

  my $xaxis = ($nn->{bar} != $bar) ? $tab->{BarEnd} - $pos + 3 + $topos : $topos - $pos;
  $xaxis *= $u;
  if ($self->{shbr} eq 's') {
    my $slht = $ss * 0.4;
    $y -= ($ss * 0.6);
    $y1 = $y;
    if ($nn->{fret} > $self->{fret}) {
      $y1 -= $slht;
    }
    else {
      $y -= $slht;
    }
    if ($nn->{bar} == $bar) {
      $x1 += $xaxis;
      $can->create_line($x, $y, $x1, $y1, -fill => $clr, -width => $fat, -tags => $tag);
    }
    else {
      # Crosses a Bar boundary.
      my $xlen = ($tab->{BarEnd} + 1 - $pos) * $u;
      $x1 = $x + $xlen;
      my $ymid = ($xlen / $xaxis) * $slht;
      if ($nn->{fret} > $self->{fret}) {
	$y1 = $y - $ymid;
      }
      else {
	$y1 = $y + $ymid;
      }
      $can->create_line($x, $y, $x1, $y1, -fill  => $clr, -width => $fat, -tags => $tag);
      if ($bar != $EditBar1) {
	$clr = CP::FgBgEd::lighten($clr, PALE) if ($self->{bar} == $EditBar);
	slideTail($nn, $self->{fret}, $ymid, $clr, $tag);
      }
    }
  } else {
    $x1 += $xaxis;
    $y1 = $y - ($ss * 1.2);
    if ($nn->{bar} == $bar) {
      $can->create_arc($x, $y, $x1, $y1,
		       -start => 0,     -extent  => 180,
		       -style => 'arc', -outline => $clr,
		       -width => $fat,  -tags    => $tag);
    }
    else {
      # Crosses a Bar boundary.
      # Using x = radx cos(t) - where t is in 0 to PI radians (we're only handling 180 deg)
      # t = acos(x / radx)
      $xaxis /= 2;
      my $arc = $xaxis - (($topos + 2) * $u);
      my $mid = int(rad2deg(acos($arc/$xaxis)));
      $can->create_arc($x, $y, $x1, $y1,
		       -start => $mid, -extent  => 180 - $mid,
		       -style => 'arc',  -outline => $clr,
		       -width => $fat,   -tags    => $tag);
      # If we've just drawn the start of an arc in EditBar1, that's it.
      if ($self->{bar} != $EditBar1) {
	$clr = CP::FgBgEd::lighten($clr, PALE) if ($bar == $EditBar);
	hammerTail($nn, $xaxis, $mid, $clr, $tag);
      }
    }
  }
}

sub slideHam {
  my($self,$note,$u,$ss) = @_;

  my $nn = $note->next();
  if (! defined $nn || $nn->{string} != $note->{string}) {
    return;
  }
  my $bar = $note->{bar};
  my $tab = $bar->{tab};
  my($fp,$fidx,$fh,$clr,$hu,$npn);
#  $fidx = ($note->{font} eq 'Normal') ? NOTES : SNOTES;
#  $fp = $self->{fonts}[$fidx];
#  $fh = $fp->{sz};
#  $clr = $fp->{clr};

  my $x = $note->{x};
  my $y = $note->{y};
  my($x1,$y1);
  my $pos = $note->{pos};
  my $topos = $nn->{pos};
  my $xaxis = ($nn->{bar} != $bar) ? $tab->{BarEnd} - $pos + 3 + $topos : $topos - $pos;
  $xaxis *= $u;
  $hu = $u / 2;

  $GfxPtr->strokecolor($tab->{headColor});

  $y += $ss;
  if ($note->{shbr} eq 's') {
    $GfxPtr->linewidth($bar->{offset}{fat});
    my $slht = $ss * 0.4;
    $y1 = $y;
    if ($nn->{fret} > $note->{fret}) {
      $y1 += $slht;
    }
    else {
      $y += $slht;
    }
    if ($nn->{bar} == $bar) {
      $GfxPtr->poly($x, $y, $x + $xaxis, $y1);
    }
    else {
      # Crosses a Bar boundary.
      my $xlen = ($tab->{BarEnd} + 1 - $pos) * $u;
      $x1 = $x + $xlen;
      my $ymid = ($xlen / $xaxis) * $slht;
      $y1 = ($nn->{fret} > $note->{fret}) ? $y + $ymid : $y - $ymid;
      $GfxPtr->poly($x, $y, $x1, $y1);

      $x = $nn->{bar}{x};
      $x1 = $nn->{x};
      $y1 = $nn->{y} + $ss;
      if ($nn->{fret} > $note->{fret}) { # Slide Up
	$y = $y1 + $ymid;
	$y1 += $slht;
      }
      else {                             # Slide Down
	$y = $y1 + $slht - $ymid;
      }
      $GfxPtr->poly($x, $y, $x1, $y1);
    }
  }
  else {
    $GfxPtr->linewidth($bar->{offset}{thick});
    $x1 = $x + $xaxis;
    my $hx = ($xaxis / 2) + 1;
    my $hss = $ss / 2;
    $y -= ($ss * 0.1);
    $x += ($hx - 1);
    if ($nn->{bar} == $bar) {
      $GfxPtr->arc($x, $y, $hx, $hss, 10, 170, 1);
      $GfxPtr->arc($x, $y, $hx, $hss-0.5, 10, 170, 1);
    }
    else {
      # Crosses a Bar boundary. Do this as 2 arcs then it doesn't matter
      # if the 2 Bars are on different lines.
      # Using x = radx cos(t) - where t is in 0 to PI radians (we're only handling 180 deg)
      # t = acos(x / radx)
      $xaxis /= 2;
      my $arc = $xaxis - (($topos + 2) * $u);
      my $mid = int(rad2deg(acos($arc/$xaxis)));
      $GfxPtr->arc($x, $y, $hx, $hss, $mid, 170, 1);
      $GfxPtr->arc($x, $y, $hx, $hss-0.5, $mid, 170, 1);

      $x = $nn->{x} - $xaxis;
      $y = $nn->{y} + ($ss * 0.9);
      $GfxPtr->arc($x, $y, $hx, $hss, 10, $mid, 1);
      $GfxPtr->arc($x, $y, $hx, $hss-0.5, 10, $mid, 1);
    }
  }
  $GfxPtr->stroke();
}

sub bendRel {
  my($self,$note,$u,$ss) = @_;

  my $bar = $note->{bar};
  my $tab = $bar->{tab};
  my $off = $bar->{offset};
  my $x = $note->{x};
  my $y = $note->{y};
  my $yr = ($ss * 0.6);
  my $pos = $note->{pos};
  my $hu = $u / 2;
  $GfxPtr->linewidth($off->{fat});
  $GfxPtr->strokecolor($tab->{headColor});
  if ($note->{shbr} eq 'b') {
    $y += ($ss * 1.6);
    $GfxPtr->arc($x, $y, 2 * $u, $yr, 270, 360, 1);
  } else {
    # We always do this as two halves, even when the Release
    # is in the same Bar as the Bend - makes the logic easier.
    my $hold = $note->{hold};
    my $arc1 = my $arc2 = ($hold > 8) ? 4 : $hold / 2;
    if ($pos == ($tab->{BarEnd} - 1)) {
      $arc1 = 2;
    }
    if (($pos + $hold) >= $tab->{BarEnd}) {
      $arc2 = 2 if (($pos + $hold) == $tab->{BarEnd});
      $hold += 3;
    }
    $arc1 *= $u;
    $arc2 *= $u;
    my $line = ($hold * $u) - ($arc1 + $arc2);
    $y += ($ss * 1.6);
    $GfxPtr->arc($x, $y, $arc1, $yr, 270, 360, 1);

    $x += $arc1;
    my $x1;
    if (($pos + $hold) >= $tab->{BarEnd}) {
      $x1 = $bar->{x} + $off->{width};
      $line -= ($x1 - $x);
    }
    else {
      $line /= 2;
      $x1 = $x + $line;
    }
    $GfxPtr->poly($x, $y, $x1, $y);

    if ($x1 == ($bar->{x} + $off->{width})) {
      my $ydif = $bar->{y} - $y;
      # Crosses a Bar boundary.
      if ($bar = $bar->{next}) {
	$x = $bar->{x};
	$y = $bar->{y} - $ydif;
      }
    }
    else {
      $x += $line;
    }
    if ($bar) {
      $x1 = $x + $line;
      if ($line) {
	$GfxPtr->poly($x, $y, $x1, $y);
      }
      $x = $x1 + $arc2;
      $GfxPtr->arc($x, $y, $arc2, $yr, 180, 270, 1);

      my $clr = $tab->{noteColor};
      my $tifp = $self->{fonts}[SNOTES];
      _textCenter($self, $x, $y - ($ss * 1.4), $note->{fret}, SNOTES, $tifp->{sz}, $clr);
    }
  }
  $GfxPtr->stroke();
}

sub lyrics {
  my($self,$lidx,$bar) = @_;

  my $tab = $bar->{tab};
  my($x,$y) = ($bar->{xy}{x}, $bar->{xy}{y});
  my $text = $tab->{lyrics}{text};
  $lidx *= $Opt->{LyricLines};
  #
  # Lyrics - This is REAL messy (see _adjTextAdd) because the same font
  # displays differently (length-wise) on a screen and on a PDF page :-(.
  #
  $y -= ($tab->{pOffset}{lyricY} - 3);
  my $wdfp = $self->{fonts}[WORDS];
  foreach my $idx (0..($Opt->{LyricLines} - 1)) {
    if (defined $text->[$lidx] && $text->[$lidx] ne '') {
      $y -= ($wdfp->{sz} + 0.5);
      _adjTextAdd($self, $tab, $x, $y,
		  $text->[$lidx],
		  $tab->{wordFont},
		  WORDS, $wdfp->{sz},
		  $wdfp->{clr});
    }
    $y -= $tab->{lyricSpace};
    $lidx++;
  }
}

sub _adjTextAdd {
  my($self,$tab,$x,$y,$txt,$fnt,$fidx,$sz,$clr) = @_;

  my $fp = $self->{fonts}[$fidx];
  my $can = $tab->{pCan};
  my $id = $can->create_text(0,0, -text => $txt, -anchor => 'nw', -font => $fnt);
  my($x1,$y1,$len,$y2) = split(/ /, $can->bbox($id));
  $can->delete($id);
  my $plen = _measure($self, $txt, $fidx, $sz, 100);
  $len /= $plen;
  $fp->{hscale} = int(($len * 100) + 0.5);
  _textAdd($self, $x, $y, $txt, $fidx, $sz, $clr);
  $fp->{hscale} = 100;
}

sub _textAdd {
  my($self,$x,$y,$txt,$fidx,$sz,$clr) = @_;

  my $fp = $self->{fonts}[$fidx];
  $TextPtr->hscale($fp->{hscale});
  $TextPtr->font($fp->{font}, $sz);
  $TextPtr->fillcolor($clr);
  $TextPtr->translate($x, $y);
  # Returns the width of the text added
  int($TextPtr->text($txt) + 0.5);
}

sub _textRight {
  my($self,$x,$y,$txt,$fidx,$sz,$clr) = @_;

  my $fp = $self->{fonts}[$fidx];
  $TextPtr->hscale($fp->{hscale});
  $TextPtr->font($fp->{font}, $sz);
  $TextPtr->fillcolor($clr);
  $TextPtr->translate($x, $y);
  # Returns the width of the text added
  int($TextPtr->text_right($txt) + 0.5);
}

sub _textCenter {
  my($self,$x,$y,$txt,$fidx,$sz,$bg) = @_;

  my $fp = $self->{fonts}[$fidx];
  $TextPtr->hscale($fp->{hscale});
  $TextPtr->font($fp->{font}, $sz);
  $TextPtr->fillcolor($bg);

  $TextPtr->translate($x, $y);
  $TextPtr->text_center($txt);
}

sub _measure {
  my($self,$txt,$fidx,$sz,$scale) = @_;

  my $fp = $self->{fonts}[$fidx];
  $TextPtr->hscale($scale);
  $TextPtr->font($fp->{font}, $sz);
  my $tx = $TextPtr->advancewidth($txt);
  int($tx + 0.5);
}

# hlines are specified left->right
sub _hline {
  my($x,$y,$x1,$ht,$clr) = @_;

  $GfxPtr->linewidth($ht);
  $GfxPtr->strokecolor($clr);
  $GfxPtr->fillcolor($clr);
  $GfxPtr->move($x, $y);
  $GfxPtr->hline($x1);
  $GfxPtr->stroke();
}

# vlines are specified from top->bottom
sub _vline {
  my($x,$y,$y1,$wt,$clr) = @_;

  $GfxPtr->linewidth($wt);
  $GfxPtr->strokecolor($clr);
  $GfxPtr->fillcolor($clr);
  $GfxPtr->move($x, $y);
  $GfxPtr->vline($y1);
  $GfxPtr->stroke();
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
