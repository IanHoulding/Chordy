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
use POSIX;
use Math::Trig;

our($GfxPtr,$TextPtr);

sub new {
  my($proto) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  $self->{page} = [];
  $self->{bars} = [];
  if ($Tab->{PDFname} eq '') {
    if ($Tab->{fileName} eq '') {
      return '' if (main::checkSave() eq 'Cancel' || $Tab->{fileName} eq '');
    } else {
      ($Tab->{PDFname} = $Tab->{fileName}) =~ s/.tab$/.pdf/i;
    }
  }
  $self->{tmpFile} = "$Path->{Temp}/$Tab->{PDFname}";
  unlink($self->{tmpFile}) if (-e $self->{tmpFile});
  my $pdf = $self->{pdf} = PDF::API2->new(-file => "$self->{tmpFile}");
  #
  # Do all the font jiggery-pokery ...
  #
  foreach my $m (['Title',  TITLE],
		 ['Header', HEADER],
		 ['Notes',  NOTES],
		 ['SNotes', SNOTES],
		 ['Words',  WORDS],
                 ['',       RESTS]) {
    my($media,$idx) = @{$m};
    my $pfp;
    if ($idx ne RESTS) {
      my $cap = substr($media, 0, 1);
      my $fp = $Media->{"$media"};
      my $fam = $fp->{family};
      my $size = ceil($fp->{size});
      my $wt = pdfWeight($fp->{weight}, $fp->{slant});
      $pfp = getFont($pdf, $fam, $wt);
      $self->{"${cap}dc"} = ceil((abs($pfp->descender) * $size) / 1000);
      $self->{"${cap}cap"} = $size - $self->{"${cap}dc"};
      $self->{"${cap}mid"} = $self->{"${cap}cap"} / 2;
      $self->{"${cap}sz"} = $size;
      $self->{"${cap}clr"} = $fp->{color};
    } else {
      $pfp = getFont($pdf, RESTFONT, 'Regular');
    }
    $self->{hscale}[$idx] = 100;
    $self->{font}[$idx] = $pfp;
  }

  bless $self, $class;
  return($self);
}

sub pdfWeight {
  my($wt,$sl) = @_;

  my $nwt = ($wt eq 'bold') ? 'Bold' : '';
  $nwt .= 'Italic' if ($sl eq 'italic');
  $nwt = 'Regular' if ($nwt eq '');
  $nwt;
}

# We need this sub because PDF::API2 needs a PATH to a specific
# font file unlike Windows which handles it automagically.
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
    my $tmp = $pdf->ttfont($path."/".$FontList{"$fam"}{Regular});
    $pfp = $pdf->synfont($tmp, %opts);
  } else {
    $pfp = $pdf->ttfont($path."/".$file);
  }
  $pfp;
}

sub newTextGfx {
  my($self,$pp) = @_;

  $GfxPtr = $pp->gfx();
  $GfxPtr->linecap(1);
  $TextPtr->textend() if (defined $TextPtr);
  $TextPtr = $pp->text();
}

sub batch {
  my $done = '';
  my $x = Tkx::winfo_pointerx($MW);
  my $y = Tkx::winfo_pointery($MW);
  my @files = CP::Browser->new($MW, FILE, $Path->{Tab}, '.tab');
  return if (@files == 0);
  my $pl = (@files > 1) ? 's' : '';
  my($top,$frm) = popWin(0, 'Batch DPF', $x, $y);
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
      $Tab->new("$Path->{Tab}/$fn");
      CP::Cmsg::position($x,$y);
      make('M');
      textConf($text, $idx++, 'green');
    }
    $Tab->new('');
    CP::Cmsg::position($x,$y);
    message(SMILE, " Done ", -1);
  }
  $top->g_destroy();
}

sub textConf {
  my($text,$idx,$clr) = @_;

  $text->configure(-state => 'normal');
  $text->tag_add($clr, "$idx.0", "$idx.end");
  $text->configure(-state => 'disabled');
  Tkx::update();
}

sub make {
  my($what) = @_;

  $Tab->{lyrics}->collect() if ($Opt->{LyricLines});
  return if ((my $pdf = CP::TabPDF->new()) eq '');
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
  my($x,$y) = (INDENT,$pageht);
  my $off = $Tab->{bars}{offset};
  my $h = $off->{height};
  my $w = $off->{width};
  my $u = $off->{interval};
  my $ss = $off->{staffSpace};
  my $oldlb = $Tab->{lastBar};
  my $lbnext = 0;
  # Find the last non-blank bar and make it the last.
  for(my $bar = $Tab->{lastBar}; $bar != 0; $bar = $bar->{prev}) {
    if ($bar->isblank() == 0) {
      $Tab->{lastBar} = $bar;
      $lbnext = $bar->{next};
      $bar->{next} = 0;
      last;
    }
  }
  for(my $bar = $Tab->{bars}; $bar != 0; $bar = $bar->{next}) {
    if ($bar->{newpage}) {
      $x = INDENT;
      $y = $pageht;
    }
    elsif ($bar->{newline} && $x > INDENT) {
      $x = INDENT;
      $y -= $h;
      $y = $pageht if (($y - $h) < 0);
    }
    if ($y == $pageht) {
      $y = $pdf->newPage();
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
      my $offset = $pdf->{Nmid};
      $offset *= 0.8 if ($n->{fret} eq 'X');
      $n->{x} = $x + ($u * ($n->{pos} + 2));
      $n->{y} = $xy->{staff0} + ($ss * $n->{string}) - $offset if ($n->{string} ne 'r');
    }

    _bg($bar->{bg}, $x-2, $y - $off->{height}, $w+4, $off->{height});

    $x += $w;
    if (($x + $w) > $Media->{width}) {
      $x = INDENT;
      $y -= $h;
      $y = $pageht if (($y - $h) < 0);
    }
  }

  # PASS 2
  #
  my $lidx = my $pn = 0;
  for(my $bar = $Tab->{bars}; $bar != 0; $bar = $bar->{next}) {
    if ($bar->{pageNum} != $pn) {
      $pdf->newTextGfx($pdf->{page}[$pn]);
      $lidx = $pn * $Tab->{rowsPP};
      $pdf->pageNum(++$pn);
    }

    $pdf->bar($bar);

    if ($bar->{xy}{x} == INDENT && $Opt->{LyricLines}) {
      $pdf->lyrics($lidx++, $bar->{xy}{x}, $bar->{xy}{y});
    }
  }
  $pdf->close();
  $Tab->{lastBar}{next} = $lbnext;
  $Tab->{lastBar} = $oldlb;
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
    my $PDFname = "$Path->{PDF}/$Tab->{PDFname}";
    unlink("$PDFname") if (-e "$PDFname");
    write_file("$PDFname", $txt);
    if ($Opt->{PDFpath} ne '' && $Opt->{PDFpath} ne $Path->{PDF}) {
      my $copyName = "$Opt->{PDFpath}/$Tab->{PDFname}";
      unlink("$copyName") if (-e "$copyName");
      write_file("$copyName", $txt);
    }
    unlink("$pdf->{tmpFile}");
    message(SMILE, "Made", 1);
  }
}

sub newPage {
  my($self) = shift;

  my $w = $Media->{width};
  my $h = $Media->{height};
  my $pp = $self->{pdf}->page;
  push(@{$self->{page}}, $pp);
  $pp->mediabox($w, $h);
  $pp->cropbox(0, 0, $w, $h);
  newTextGfx($self, $pp);

  $h -= $Tab->{pageHeader};

  if ($Media->{titleBG} ne WHITE) {
    _bg($Media->{titleBG}, 0, $h, $w, $Tab->{pageHeader});
  }
  _textCenter($self, $w/2, $h + $self->{Tdc} + 2, $Tab->{title}, TITLE, $self->{Tsz}, $self->{Tclr});

  _hline(0, $h, $h + $w, 0.75, DBLUE);

  my $tht = ($Media->{height} - $h) / 2;
  my $th = int($self->{Tsz} * KEYMUL);
  my $dc = int($self->{Tdc} * KEYMUL);
  if ($Tab->{key} ne '') {
    my $tw = _textAdd($self, INDENT, $h + $self->{Tdc} + 2, "Key: ", TITLE, $th, bFG);
    my $ch = [split('',$Tab->{key})];
    chordAdd($self, INDENT + $tw, $h + $self->{Tdc} + 2, $ch, $Media->{Chord}{color}, $th);
  }
  if ($Tab->{note} ne '') {
    _textRight($self, $Media->{width} - INDENT, $h - $th, "Note: $Tab->{note}", TITLE, $th, DGREEN);
  }

  if (defined $Tab->{tempo} && @{$self->{page}} == 1) {
    my $ht = $Tab->{symSize} * 0.6;
    my $x = ($Media->{width} / 2) - $ht;
    my $wid = _textAdd($self, $x, $h - $ht + 2, 'O', RESTS, $ht, BLACK);
    _textAdd($self, $x + $wid, $h - $ht, " = ".$Tab->{tempo}, TITLE, $ht, BLACK);
  }
  $h -= INDENT;
}

sub pageNum {
  my($self,$pn) = @_;

  my $fntht = POSIX::ceil($self->{Tsz} * PAGEMUL);
  my $y = $Media->{height} - $Tab->{pageHeader} + (($Tab->{pageHeader} - $fntht) / 2);
  my $npg = @{$self->{page}} + 0;
  _textRight($self, $Media->{width} - INDENT, $y, "Page $pn of $npg ", TITLE, $fntht, BROWN);
}

sub chordAdd {
  my($self,$x,$y,$ch,$clr,$ht) = @_;

  my $sht = int($ht * 0.8);
  $ht = $self->{Csz} if (!defined $ht);
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
  (my $t = $Opt->{Timing}) =~ s/(\d).*/$1/;
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
  if ($x == INDENT || ($bar->{prev}{rep} ne 'End')) {
    _vline($x, $ly, $ly + $h - THIN, THICK, BLACK);
  }
  _vline($x + $w, $ly, $ly + $h - THIN, THICK, BLACK);

  #
  # Handle anything that needs to go above the Bar.
  #
  $ly = $y - (FAT / 2);
  my $txt = '';
  if ($bar->{volta} ne 'None') {
    _hline($x, $ly, $x + $off->{width}, FAT, $self->{Hclr});
    if ($bar->{volta} ne 'Center') {
      if ($bar->{volta} =~ /Left|Both/) {
	_vline($x, $ly, $xy->{staffY} + INDENT, FAT, $self->{Hclr});
      }
      if ($bar->{volta} =~ /Right|Both/) {
	_vline($x+$w, $ly, $xy->{staffY} + INDENT, FAT, $self->{Hclr});
      }
    }
  }
  if ($bar->{header} ne '') {
    if ($bar->{justify} eq 'Right') {
      $lx = $x + $w - _measure($self, $bar->{header}, HEADER, $self->{Hsz},
			       $self->{hscale}[HEADER]) - (THICK * 2);
    } else {
      $lx = $x;
    }
    _adjTextAdd($self, $lx, $ly - $self->{Hcap} - FAT,
		$bar->{header}, $Tab->{headFont}, HEADER, $self->{Hsz}, $self->{Hclr});
  }
  #
  # Handle start of repeat and/or repeat count.
  #
  if ($bar->{rep} eq 'Start') {
    repStart($x, $xy->{staffY}, $off->{staffHeight}, $self->{Hclr});
  }
  if ($bar->{rep} eq 'End') {
    repEnd($x + $w, $xy->{staffY}, $off->{staffHeight}, $self->{Hclr});
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
    if ($n->{string} eq 'r') {
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
		    RESTS, $Tab->{symSize}, BLACK);
      }
    } else {
      my $y = $xy->{staff0};
      my($fidx,$fh,$offset,$clr);
      if ($n->{font} eq 'Normal') {
	$fidx = NOTES;
	$fh = $self->{Nsz};
	$offset = $self->{Ncap};
	$clr = $self->{Nclr};
      } else {
	$fidx = SNOTES;
	$fh = $self->{Ssz};
	$offset = $self->{Scap};
	$clr = $self->{Sclr};
      }
      $offset /= 2;
      my $adj = 1.0;
      $n->{x} = $x + ($u * $n->{pos});
      my $ht = $fh;
      $ht *= ($adj = 0.8) if ($n->{fret} eq 'X');
      $n->{y} = $y + ($ss * $n->{string}) - ($offset * $adj);
      my $hs = $self->{hscale}[$fidx];
      if ($n->{fret} eq 'X') {
	$clr = BLACK;
      } elsif ($n->{fret} > 9) {
	$self->{hscale}[$fidx] = 65;
      }
      _textCenter($self, $n->{x}, $n->{y}, $n->{fret}, $fidx, $ht, $clr);
      $self->{hscale}[$fidx] = $hs;
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
  my $can = $bar->{canvas};
  my $off = $bar->{offset};
  my $fat = $off->{fat};
  my $ss = $off->{staffSpace};
  my $u = $off->{interval};
  my($x,$y) = my($x1,$y1) = $self->selfXY();
  my $pos = $self->{pos};
  my $topos = $nn->{pos};

  my $clr = $Tab->{headColor};
  $clr = CP::FgBgEd::lighten($clr, 80) if ($bar->{pidx} == -2);

  my $xaxis = ($nn->{bar} != $bar) ? $Opt->{BarEnd} - $pos + 3 + $topos : $topos - $pos;
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
      $can->create_line($x, $y, $x1, $y1, -fill  => $clr, -width => $fat, -tags => $tag);
    }
    else {
      # Crosses a Bar boundary.
      my $xlen = ($Opt->{BarEnd} + 1 - $pos) * $u;
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
	$clr = CP::FgBgEd::lighten($clr, 80) if ($self->{bar} == $EditBar);
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
	$clr = CP::FgBgEd::lighten($clr, 80) if ($bar == $EditBar);
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
  my($fidx,$fh,$clr,$hu,$npn);
  if ($note->{font} eq 'Normal') {
    $fidx = NOTES;
    $fh = $self->{Nsz};
    $clr = $self->{Nclr};
  } else {
    $fidx = SNOTES;
    $fh = $self->{Ssz};
    $clr = $self->{Sclr};
  }

  my $x = $note->{x};
  my $y = $note->{y};
  my($x1,$y1);
  my $pos = $note->{pos};
  my $topos = $nn->{pos};
  my $xaxis = ($nn->{bar} != $bar) ? $Opt->{BarEnd} - $pos + 3 + $topos : $topos - $pos;
  $xaxis *= $u;
  $hu = $u / 2;

  $GfxPtr->strokecolor($self->{Hclr});

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
      my $xlen = ($Opt->{BarEnd} + 1 - $pos) * $u;
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
  my $off = $bar->{offset};
  my $x = $note->{x};
  my $y = $note->{y};
  my $yr = ($ss * 0.6);
  my $pos = $note->{pos};
  my $hu = $u / 2;
  $GfxPtr->linewidth($off->{fat});
  $GfxPtr->strokecolor($self->{Hclr});
  if ($note->{shbr} eq 'b') {
    $y += ($ss * 1.6);
    $GfxPtr->arc($x, $y, 2 * $u, $yr, 270, 360, 1);
  } else {
    # We always do this as two halves, even when the Release
    # is in the same Bar as the Bend - makes the logic easier.
    my $hold = $note->{hold};
    my $arc1 = my $arc2 = ($hold > 8) ? 4 : $hold / 2;
    if ($pos == ($Opt->{BarEnd} - 1)) {
      $arc1 = 2;
    }
    if (($pos + $hold) >= $Opt->{BarEnd}) {
      $arc2 = 2 if (($pos + $hold) == $Opt->{BarEnd});
      $hold += 3;
    }
    $arc1 *= $u;
    $arc2 *= $u;
    my $line = ($hold * $u) - ($arc1 + $arc2);
    $y += ($ss * 1.6);
    $GfxPtr->arc($x, $y, $arc1, $yr, 270, 360, 1);

    $x += $arc1;
    my $x1;
    if (($pos + $hold) >= $Opt->{BarEnd}) {
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

      my $clr = $Tab->{noteColor};
      _textCenter($self, $x, $y - ($ss * 1.4), $note->{fret}, SNOTES, $self->{Ssz}, $clr);
    }
  }
  $GfxPtr->stroke();
}

sub lyrics {
  my($self,$lidx,$x,$y) = @_;

  my $text = $Tab->{lyrics}{text};
  $lidx *= $Opt->{LyricLines};
  #
  # Lyrics - This is REAL messy (see _adjTextAdd) because the same font
  # displays differently (length-wise) on a screen and on a PDF page :-(.
  #
  $y -= ($Tab->{pOffset}{lyricY} - 3);
  foreach my $idx (0..($Opt->{LyricLines} - 1)) {
    if ($text->[$lidx] ne '') {
      $y -= ($self->{Wsz} + 0.5);
      _adjTextAdd($self, $x, $y,
		  $text->[$lidx],
		  $Tab->{wordFont},
		  WORDS, $self->{Wsz},
		  $self->{Wclr});
    }
    $y -= $Tab->{lyricSpace};
    $lidx++;
  }
}

sub _adjTextAdd {
  my($self,$x,$y,$txt,$fnt,$fidx,$sz,$bg) = @_;

  my $can = $Tab->{pCan};
  my $id = $can->create_text(0,0, -text => $txt, -anchor => 'nw', -font => $fnt);
  my($x1,$y1,$len,$y2) = split(/ /, $can->bbox($id));
  $can->delete($id);
  my $plen = _measure($self, $txt, $fidx, $sz, 100);
  $len /= $plen;
  $self->{hscale}[$fidx] = int(($len * 100) + 0.5);
  _textAdd($self, $x, $y, $txt, $fidx, $sz, $bg);
  $self->{hscale}[$fidx] = 100;
}

sub _textAdd {
  my($self,$x,$y,$txt,$fidx,$sz,$bg) = @_;

  $TextPtr->hscale($self->{hscale}[$fidx]);
  $TextPtr->font($self->{font}[$fidx], $sz);
  $TextPtr->fillcolor($bg);
  $TextPtr->translate($x, $y);
  # Returns the width of the text added
  int($TextPtr->text($txt) + 0.5);
}

sub _textRight {
  my($self,$x,$y,$txt,$fidx,$sz,$bg) = @_;

  $TextPtr->hscale($self->{hscale}[$fidx]);
  $TextPtr->font($self->{font}[$fidx], $sz);
  $TextPtr->fillcolor($bg);
  $TextPtr->translate($x, $y);
  # Returns the width of the text added
  int($TextPtr->text_right($txt) + 0.5);
}

sub _textCenter {
  my($self,$x,$y,$txt,$fidx,$sz,$bg) = @_;

  $TextPtr->hscale($self->{hscale}[$fidx]);
  $TextPtr->font($self->{font}[$fidx], $sz);
  $TextPtr->fillcolor($bg);

  $TextPtr->translate($x, $y);
  $TextPtr->text_center($txt);
}

sub _measure {
  my($self,$txt,$fidx,$sz,$scale) = @_;

  $TextPtr->hscale($scale);
  $TextPtr->font($self->{font}[$fidx], $sz);
  my $tx = $TextPtr->advancewidth($txt);
  int($tx + 0.5);
}

sub _hline {
  my($x,$y,$x1,$t,$clr) = @_;

  $GfxPtr->linewidth($t);
  $GfxPtr->strokecolor($clr);
  $GfxPtr->fillcolor($clr);
  $GfxPtr->move($x, $y);
  $GfxPtr->hline($x1);
  $GfxPtr->stroke();
}

sub _vline {
  my($x,$y,$y1,$t,$clr) = @_;

  $GfxPtr->linewidth($t);
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
