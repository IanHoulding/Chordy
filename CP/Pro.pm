package CP::Pro;

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

use CP::Cconst qw/:OS :PDF :MUSIC :TEXT :SHFL :INDEX :SMILIE/;
use CP::Global qw/:FUNC :OPT :WIN :PRO :SCALE :MEDIA/;
use CP::CPpdf;
use CP::Cmsg;
use CP::Line;
use CP::Chord;
use CP::Editor;
use Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/$LenError/;

our($MyPDF, $PdfFileName, $LenError);

sub new {
  my($proto,$fn,$elem) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;
  decompose($self, $fn, $elem);
  return($self);
}

# Take the ChordPro file and break it down into lines
# and segments of lyric, lyric + chord or just chord
#
# Pro = {
#   path   => "",
#   name   => "",
#   title  => "",
#   capo   => 0,
#   tempo  => 0,
#   key    => "",
#   instrument => "",
#   chords => {},
#   finger => {},
#   Lines[0]->{     # Line.pm
#     blk_no => n,
#     ly_cnt => n,
#     ch_cnt => n,
#     type   => n,
#     text   => "",
#     bg     => "", # this is only set if a colour is defined within a directive.
#     segs   => [0]->{  # Seg.pm
#       x     => n,
#       chord => [],    # Chord.pm
#       lyric => "",
#     },
#   },
# },
#
sub decompose {
  my($self,$fn,$elem) = @_;

  $self->{path} = $Path->{Pro};
  $self->{name} = $fn;
  ($self->{title} = $fn) =~ s/\.pro$//;
  $self->{tempo} = 0;
  $self->{capo} = 0;
  $self->{key} = '';
  $self->{note} = '';
  $self->{instrument} = $Opt->{Instrument};
  $self->{chords} = {}; # a hash of all chords used in this .pro
  $self->{finger} = {}; # local (to this .pro) chord fingering from a {define: }
  unless (open IFH, "$self->{path}/$self->{name}") {
    message(SAD, "Could not access\n   \"$self->{path}/$self->{name}\"");
    return(0);
  }
  @{$self->{lines}} = ();
  my @verseLines;
  my @chorusLines;
  my @bridgeLines;
  my @tabLines;
  my $gridlref;
  my $tablref;
  my $lvcb = LYRIC;
  my($vidx,$cidx,$bidx,$tidx,$blk_no) = qw/0 0 0 0 0/;
  my $key = "";
  my $bg = '';
  my $lineNum = 0;
  while (<IFH>) {
    $lineNum++;
    next if (/^\#/);
    my $lref = undef;
    # Delete any trailing Cariage Return/New Line.
    $_ =~ s/\r|\n//g;
    if ($_ eq "" && $lvcb != TAB) {
      $lref = CP::Line->new(NL, "\n", $blk_no++, "");
      $bg = '';
    } else {
      if (/^{(.*)\}\s*$/) {
	# Handle any directives.
	my ($cmd, $txt) = split(/[:\s]/, $1, 2);
	$cmd =~ s/^x_//;
	if (defined $txt) {
	  my $pat = "";
	  if ($txt =~ /(\d+),(\d+),(\d+)$/) {
	    $pat = $1.",".$2.",".$3;
	    $bg = sprint("#%02x%02x%02x", $1, $2, $3);
	  } elsif ($txt =~ /(#[\da-fA-F]{6})$/) {
	    $bg = $pat = $1;
	  }
	  $txt =~ s/$pat$//;
	} else {
	  $txt = '';
	}
	if    ($cmd =~ /^key$/i)        {($self->{key} = $txt) =~ s/\s//g; $bg = '';}
	elsif ($cmd =~ /^t$|^title$/i)  {$self->{title} = $txt; $bg = '';}
	elsif ($cmd =~ /^note$/i)       {$self->{note} = $txt; $bg = '';}
	elsif ($cmd =~ /^capo$/i)       {$self->{capo} = $txt; $bg = '';}
	elsif ($cmd =~ /^tempo$/i)      {$self->{tempo} = $txt; $bg = '';}
	elsif ($cmd =~ /^instrument$/i) {($self->{instrument} = $txt) =~ s/\s//g; $bg = '';}
	elsif ($cmd =~ /^chord/i)  {
	  if ($cmd =~ /font/i)  {
	    $lref = CP::Line->new(CFONT, $txt, $blk_no, $bg); $bg = '';
	  }
	  elsif ($cmd =~ /size/i)  {
	    $lref = CP::Line->new(CFSIZ, $txt, $blk_no, $bg); $bg = '';
	  }
	  elsif ($cmd =~ /colour/i)  {
	    $lref = CP::Line->new(CFCLR, $bg, $blk_no, $bg); $bg = '';
	  }
	  elsif ($cmd =~ /^chord$/i) {
	    # This forces one or more Chords to be displayed
	    $txt =~ s/\[|\]/ /g;
	    $txt =~ s/\s+/ /g;
	    $txt =~ s/^\s+|\s+$//;
	    $lref = CP::Line->new(CHRD, $txt, $blk_no, "");
	    # Put them into this hash in case the Grid Index option is used.
	    foreach (split(' ', $txt)) {
	      $self->{chords}{$_} = 1;
	    }
	  }
	}
	elsif ($cmd =~ /^text/i)   {
	  if ($cmd =~ /font/i)   {
	    $lref = CP::Line->new(LFONT, $txt, $blk_no, $bg); $bg = '';
	  }
	  elsif ($cmd =~ /size/i)   {
	    $lref = CP::Line->new(LFSIZ, $txt, $blk_no, $bg); $bg = '';
	  }
	  elsif ($cmd =~ /colour/i)   {
	    $lref = CP::Line->new(LFCLR, $bg, $blk_no, $bg); $bg = '';
	  }
	}
	elsif ($cmd =~ /^tab/i)   {
	  if ($cmd =~ /font/i)   {
	    $lref = CP::Line->new(TFONT, $txt, $blk_no, $bg); $bg = '';
	  }
	  elsif ($cmd =~ /size/i)   {
	    $lref = CP::Line->new(TFSIZ, $txt, $blk_no, $bg); $bg = '';
	  }
	  elsif ($cmd =~ /colour/i)   {
	    $lref = CP::Line->new(TFCLR, $bg, $blk_no, $bg); $bg = '';
	  }
	}
	elsif ($cmd =~ /^c$|^comment$/i) {
	  $lref = CP::Line->new(CMMNT, $txt, $blk_no, $bg);  $bg = '';
	}
	elsif ($cmd =~ /^ci$|^comment_italic$/i) {
	  $lref = CP::Line->new(CMMNTI, $txt, $blk_no, $bg); $bg = '';
	}
	elsif ($cmd =~ /^cb$|^comment_box$/i) {
	  $lref = CP::Line->new(CMMNTB, $txt, $blk_no, $bg); $bg = '';
	}
	elsif ($cmd =~ /^h$|^highlight$/i) {
	  $lref = CP::Line->new(HLIGHT, $txt, $blk_no, $bg); $bg = '';
	}
	elsif ($cmd =~ /^(sov|start_of_verse)$/i) {
	  $lvcb = VERSE;
	  $vidx = $1 if ($txt =~ /(\d+)/);
	  @{$verseLines[$vidx]} = ();
	}
	elsif ($cmd =~ /^(soc|start_of_chorus)$/i) {
	  $lvcb = CHORUS;
	  $cidx = $1 if ($txt =~ /(\d+)/);
	  @{$chorusLines[$cidx]} = ();
	}
	elsif ($cmd =~ /^(sob|start_of_bridge)$/i) {
	  $lvcb = BRIDGE;
	  $bidx = $1 if ($txt =~ /(\d+)/);
	  @{$bridgeLines[$bidx]} = ();
	}
	elsif ($cmd =~ /^(sog|start_of_grid)$/i) {
	  $lvcb = GRID;
	  $gridlref = CP::Line->new($lvcb, $txt, $blk_no, $bg);
	}
	elsif ($cmd =~ /^(sot|start_of_tab)$/i) {
	  $lvcb = TAB;
	  $tidx = $1 if ($txt =~ /(\d+)/);
	  $tablref = CP::Line->new($lvcb, $txt, $blk_no, $bg);
	  @{$tabLines[$tidx]} = ();
	}
	elsif ($cmd =~ /^eo[vcbgt]$|^end_of_(verse|chorus|bridge|grid|tab)$/i) {
	  if ($lvcb == GRID) {
	    $gridlref->{num} = $lineNum;
	    push(@{$self->{lines}}, $gridlref);
	    $gridlref = undef;
	  } elsif ($lvcb == TAB) {
	    $tablref->{num} = $lineNum;
	    push(@{$self->{lines}}, $tablref);
	    $tablref = undef;
	  }
	  $lvcb = LYRIC;
	  $vidx = $cidx = $bidx = $tidx = 0;
	  $bg = '';
	  $blk_no++;
	}
	elsif ($cmd =~ /^np$|^npp$|^new_page$|^new_physical_page$/i) {
	  $lref = CP::Line->new(NP, "", $blk_no++, "");
	  $bg = '';
	}
	elsif ($cmd =~ /^(verse|chorus|bridge|tab)$/i) {
	  my $idx = ($txt =~ /(\d+)/) ? $1 : 0;
	  # Chorus backgrounds stay in effect until changed by another colour directive.
	  my $lp = ($cmd =~ /^v/i) ? \@{$verseLines[$idx]} :
	           ($cmd =~ /^c/i) ? \@{$chorusLines[$idx]} :
	           ($cmd =~ /^b/i) ? \@{$bridgeLines[$idx]} : \@{$tabLines[$idx]};
	  if ($idx && @{$lp} == 0) {
	    $lp = ($cmd =~ /^v/i) ? \@{$verseLines[0]} :
		  ($cmd =~ /^c/i) ? \@{$chorusLines[0]} :
		  ($cmd =~ /^b/i) ? \@{$bridgeLines[0]} : \@{$tabLines[0]};
	  }
	  foreach my $cl (@{$lp}) {
	    my $cln = $cl->clone($blk_no);
	    $cln->{bg} = ($bg ne '') ? $bg : $cl->{bg};
	    push(@{$self->{lines}}, $cln);
	  }
	  $blk_no++;
	  undef $lref;
	}
	elsif ($cmd =~ /^define$/i) {
	  $txt =~ /\s*([^\s]*)\s*base-fret\s*(\d+)\s*frets\s*([-\doOxX]+)\s*([-\doOxX]+)\s*([-\doOxX]+)\s*([-\doOxX]+)\s*([-\doOxX]*)\s*([-\doOxX]*)/;
	  my $n = $1;
	  my $ap = [];
	  $self->{finger}{$n} = ();
	  $self->{finger}{$n}{base} = $2;
	  push(@$ap, $3,$4,$5,$6);
	  push(@$ap, $7, $8) if ($7 ne '');
	  $self->{finger}{$n}{fret} = $ap;
	}
	elsif ($cmd =~ /^hl$|^horizontal_line$/i) {
	  $lref = CP::Line->new(HLINE, $txt, $blk_no++, $bg);
	}
	elsif ($cmd =~ /^vs$|^vspace$/i) {
	  $lref = CP::Line->new(VSPACE, $txt, $blk_no++, $bg);
	}
	elsif ($cmd =~ /^sbg$|^start_background$/i) { }
	elsif ($cmd =~ /^ebg$|^end_background$/i)   {$bg = '';}
	last if (defined $elem && defined $self->{$elem});
      }
      else {
	# Lyric line with (possibly) embedded chords
	# or it could just be a line of chords.
	if ($lvcb == GRID) {
	  $gridlref->{text} .= "\n$_";
	  $gridlref->{ch_cnt}++;
	  $lineNum++;
	} elsif ($lvcb == TAB) {
	  $tablref->{text} .= "$_\n";
	  $tablref->{ch_cnt}++;
	  $lineNum++;
	} else {
	  $lref = CP::Line->new($lvcb, "", $blk_no, $bg);
	  $lref->segment($self, $_);
	}
      }
    }
    if (defined $lref) {
      $lref->{num} = $lineNum;
      push(@{$self->{lines}}, $lref);
      if ($lvcb == VERSE) {
	push(@{$verseLines[$vidx]}, $lref);
      } elsif ($lvcb == CHORUS) {
	push(@{$chorusLines[$cidx]}, $lref);
      } elsif ($lvcb == BRIDGE) {
	push(@{$bridgeLines[$bidx]}, $lref);
      } elsif ($lvcb == TAB) {
	push(@{$tabLines[$tidx]}, $lref);
      }
    }
  }
  close(IFH);
  return(1);
}

sub makePDF {
  my($self,$myPDF) = @_;

  # We can't transpose if there is no 'key' directive.
  $KeyShift = 0;
  if ($self->{key} ne '') {
    if ($Opt->{Transpose} ne "No") {
      $KeyShift = setIdx("$self->{key}");
    }
    if ($Opt->{IgnCapo} == 0 && $self->{capo} != 0) {
      $KeyShift -= $self->{capo};
      $KeyShift %= 12;
    }
  }

  my $grid = {
    lmargw => 1,
    rmargw => 1,
    measures => 4,
    beats => 4,
    label => '',
      };

  my $linespc = $Opt->{LineSpace};
  my $halfspc = int($linespc / 2);

  my $lyricdc = $myPDF->{Ldc};
  my $lyricht = $myPDF->{Las} + $lyricdc;

  my $chorddc = $myPDF->{Cdc} / 2;
  my $chordht = $myPDF->{Cas} + $chorddc;
  my $superht = $myPDF->{Ssz};

  my $tabht   = $myPDF->{TBsz};
  my $tabdc   = $myPDF->{TBdc};
  #
  # Total height of a Chord:
  #--+------------------------------#----------+----
  #  |                              #          |
  #--|---+-------------------#------#          |
  #  |   |                  # #     ####      Sht (Cht * 0.6)
  #  |   |                 #   #    #   #      |
  #  |  Ccap              #     #   #   #      |
  #--|---|---------------#-------#--####--+----+
  # Cht  |              ###########       |
  #  |   |             #           #   (Ccap / 2)
  #  |   |            #             #     |
  #==|===+===========#===+===========#====+======= placing an 'A' at y is
  #  |                   |                         relative to this line
  #  |                  Cdc
  #--+-------------------+----------------+-------
  #
  my $cmmntht = $myPDF->{CMdc} + $myPDF->{CMas};
  my $highlht = $myPDF->{Hdc} + $myPDF->{Has};
  my $lyr_clr = $Media->{Lyric}{color};
  my $chd_clr = $Media->{Chord}{color};
  my $tab_clr = $Media->{Tab}{color};
  my $lyrOnly = $Opt->{LyricOnly};
  my $pageno = 1;
  my $lineX = INDENT;
  # $lineY is always where the last entry was placed so it's up to
  # the current entity to drop it down the page before placing itself.
  my $lineY = $myPDF->newPage($self, $pageno++);

  my $blk = -1;
  for(my $lnidx = 0; $lnidx < @{$self->{lines}}; $lnidx++) {
    my $ln = $self->{lines}[$lnidx];
    my $type = $ln->{type};
    my $lerr = 0;
    $lineY = $myPDF->newPage($self, $pageno++) if ($type == NP || $lineY < 0);
    next if ($type == NP);

    if ($type == TAB) {
      # Tab block contents are ALWAYS kept together on one page.
      if ($lyrOnly == 0) {
	my @lns = split(/\n/, $ln->{text});
	$lineY = $myPDF->newPage($self, $pageno++) if (($tabht * @lns) > $lineY);
      }
    }
    elsif ($type < NL && $Opt->{Together} && $ln->{blk_no} != $blk) {
      $blk = $ln->{blk_no};
      # Start of a new Block. Work out it's height and see if it'll fit on this Page.
      my $ht = 0;
      my $lref = \@{$self->{lines}};
      for(my $i = $lnidx; $i <= $#{$lref} && $lref->[$i]->{blk_no} == $blk; $i++) {
	my $sp = $lref->[$i];
	my $ty = $sp->{type};
	if ($ty == HLINE || $ty == VSPACE) {
	  $ht += ($sp->{text} =~ /([\.\d]+)\s?([\.\d]+)?/) ? $1 : 5;
	} elsif ($ty == GRID) {
	  $ht += ($chordht * $sp->{ch_cnt}) if ($lyrOnly == 0);
	} elsif ($ty == LYRIC || $ty == VERSE || $ty == CHORUS) {
	  my $h = ($sp->{ly_cnt}) ? $lyricht: 0;
	  $h += $chordht if ($sp->{ch_cnt} && $lyrOnly == 0);
	  $ht += ($linespc + $h) if ($h);
	} elsif ($ty == CHRD) {
	  my @chords = split(' ', $sp->{text});
	  while ($lref->[++$i]->{type} == CHRD) {
	    push(@chords, split(' ', $lref->[$i]->{text}));
	  }
	  $i--;
	  $ht += $myPDF->fingersHeight(@chords);
	} elsif ($ty == HLIGHT) {
	  $ht += $highlht;
	} elsif ($ty == CMMNT || $ty == CMMNTI || $ty == CMMNTB) {
	  $ht += $cmmntht;
	}
      }
      $lineY = $myPDF->newPage($self, $pageno++) if ($ht > $lineY);
    }
    if ($type == LYRIC || $type == VERSE || $type == CHORUS || $type == BRIDGE) {
      #
      # This is real messy because of the need to Center text on the page.
      # First need to get the length of the Lyrics and/or Chords so we can
      # make a note of the X position for each associated segment. Then we
      # can go ahead and put both lines on the page in the appropriate
      # position.
      #
      # First pass - sort out the Lyric offsets.
      #
      my $heightAdj = 0;
      # Adjust the font size until the lyrics fit on the page.
      # Side effect of measure() sets the x offset for each segment.
      # As a side note - Tcl/Tk doesn't handle half point sizes for
      #   fonts but PDF::API2 can - so we do.
      while (1) {
	$lineX = INDENT + $ln->measure($self,$myPDF);
	last if ($lineX < $Media->{width});
	$lerr = $lineX if ($lerr == 0);
	$myPDF->{Lsz} -= 0.5;
	$myPDF->{Csz} -= 0.5;
	$myPDF->{Ssz} -= 0.5;
	$heightAdj += 0.5;
	$LenError++;
	last if ($myPDF->{Lsz} < 6); # Sanity check!
      }
      if ($lerr) {
	my $str = "";
	if ($ln->{ly_cnt}) {
	  foreach my $s (@{$ln->{segs}}) {
	    $str .= "$s->{lyric}";
	  }
	} else {
	  foreach my $s (@{$ln->{segs}}) {
	    $str .= join("", @{$s->{chord}});
	  }
	}
	print localtime."\n";
	printf "  LINE $ln->{num} TOO LONG by %.1fmm: %s/%s\n  -->%s\n\n",
	    ($lerr - $Media->{width}) * (25.4 / 72), $self->{path}, $self->{name}, $str;
      }
      my $off = 0;
      if ($Opt->{Center}) {
	if ($ln->{ly_cnt} > 0) {
	  # Find the X offset to the first Lyric.
	  while ($ln->{segs}[$off]{lyric} eq "") { $off++; }
	}
	# Finally we can get the Line offset to Center the text.
	$off = int(($Media->{width} - $lineX - $ln->{segs}[$off]{x}) / 2);
      } else {
	$off = INDENT;
      }
      #
      # Now go through the segments on this line and insert into the PDF
      # Do the BackGrounds first so that chord descenders can go down
      # into the lyric space (even if only marginally).
      #
      my($lineht,$chordY,$lyricY) = (0,0,0);
      if ($ln->{ch_cnt} && $lyrOnly == 0) {
	$lineht = $chordht;
	$chordY = $lineY - $halfspc - $lineht + $chorddc;
      }
      if ($ln->{ly_cnt}) {
	$lineht += $lyricht;
	$lyricY = $lineY - $halfspc - $lineht + $lyricdc;
      }
      if ($lineht) {
	$lineY -= ($lineht + $linespc);
	if ($lineY < 0) {
	  my $cdiff = $chordY - $lineY;
	  my $ldiff = $lyricY - $lineY;
	  $lineY = $myPDF->newPage($self, $pageno++) - $lineht;
	  $chordY = $lineY + $cdiff;
	  $lyricY = $lineY + $ldiff;
	}
	my $bg = '';
	if ($type != LYRIC && $ln->{bg} eq '') {
	  if ($type == VERSE) {
	    $bg = $Media->{verseBG};
	  } elsif ($type == CHORUS) {
	    $bg = $Media->{chorusBG};
	  } elsif ($type == BRIDGE) {
	    $bg = $Media->{bridgeBG};
	  }
	} else {
	  $bg = $ln->{bg};
	}
	if ($bg ne '') {
	  CP::CPpdf::_bg($bg, 0, $lineY, $Media->{width}, $lineht + $linespc);
	}
	#
	# Now the actual text
	#
	foreach my $s (@{$ln->{segs}}) {
	  $lineX = $s->{x} + $off;
	  # Chords
	  if (@{$s->{chord}} && $lyrOnly == 0) {
	    $myPDF->chordAdd($lineX, $chordY, $s->{chord}->trans2obj($self), $chd_clr);
	  }
	  # Lyrics
	  if ($s->{lyric} ne "") {
	    $myPDF->lyricAdd($lineX, $lyricY, $s->{lyric}, $lyr_clr);
	  }
	}
      }
      #
      # Reset the Chord/Lyric font heights
      #
      $myPDF->{Lsz} += $heightAdj;
      $myPDF->{Csz} += $heightAdj;
      $myPDF->{Ssz} += $heightAdj;
    }
    elsif ($type == TAB) {
      # Tabs are always left justified so no need to do the centering garbage.
      if ($Media->{tabBG} !~ /\#FFFFFF/i) {
	my $bght = ($tabht * $ln->{ch_cnt}) + $tabdc;
	CP::CPpdf::_bg($Media->{tabBG}, 0, $lineY - $bght, $Media->{width}, $bght);
      }
      foreach my $line (split(/\n/, $ln->{text})) {
	$lineY -= $tabht;
	if ($line ne '') {
	  CP::CPpdf::_textAdd(INDENT, $lineY,
			      $line, $myPDF->{font}[TAB], $Media->{Tab}{size}, $tab_clr);
	}
      }
      $lineY -= $tabdc;
    }
    elsif ($type == GRID) {
      my @gr = split(/\n/, $ln->{text});
      gridDef($grid, shift(@gr));
      my $idx = my $maxl = my $maxr = 0;
      foreach my $line (@gr) {
	# Looking for (in order)   :|:  ||  :|  |:  |. |
	my @c = split(/(:\|:|\|\||:\||\|:|\|\.|\|)/, $line);
	if ($c[0] !~ /\|/) {
	  my $len = CP::CPpdf::_measure($c[0], $myPDF->{font}[VERSE], $Media->{Lyric}{size});
	  $maxl = $len if ($len > $maxl);
	}
	if ($c[-1] !~ /\|/) {
	  my $len = CP::CPpdf::_measure($c[-1], $myPDF->{font}[VERSE], $Media->{Lyric}{size});
	  $maxr = $len if ($len > $maxr);
	}
	$grid->{lines}[$idx++] = \@c;
      }
      if ($grid->{label} ne '') {
	$lineY -= $cmmntht;
	$myPDF->commentAdd(CMMNT, $lineY, $grid->{label}, $Media->{Comment}{color}, $ln->{bg});
      }
      my $div = CP::CPpdf::_measure('4', $myPDF->{font}[GRID], $Media->{Chord}{size});
      my $cells = $grid->{measures} * $grid->{beats};
      $cells += $grid->{lmargw} if ($maxl == 0);
      $cells += $grid->{rmargw} if ($maxr == 0);
      my $cellw = $Media->{width} - INDENT - ($maxl + $maxr) - ($div * ($grid->{measures} + 1)) - INDENT;
      $cellw /= $cells;
      $maxl = $cellw * $grid->{lmargw} if ($maxl == 0);
      foreach my $gl (@{$grid->{lines}}) {
	my $x = INDENT;
	$lineY -= $chordht;
	my $idx = 0;
	while (scalar @$gl) {
	  my $meas = shift(@{$gl});
	  if ($meas =~ /\|/) {
	    my $d = ($meas eq '|') ? '0' : ($meas eq '||') ? '1' : ($meas eq '|:') ? '2' : ($meas eq ':|') ? '3' : ($meas eq ':|:') ? '4' : '5';
	    CP::CPpdf::_textAdd($x, $lineY, $d, $myPDF->{font}[GRID], $Media->{Chord}{size}, $chd_clr);
	    $x += $div;
	  } else {
	    if ($idx == 0 || (scalar @$gl) == 0) {
	      $myPDF->lyricAdd($x, $lineY, $meas, $lyr_clr);
	      $x += $maxl;
	    } else {
	      my $mw = $cellw * $grid->{beats};
	      if ($meas =~ /%%/) {
		$x += $mw;
		CP::CPpdf::_textAdd($x, $lineY,
				    '6', $myPDF->{font}[GRID], $Media->{Chord}{size}, $chd_clr);
		$x += $div;
		# This takes the liberty that the following Measure MUST be empty!
		shift(@{$gl});shift(@{$gl});
	      } elsif ($meas =~ /%/) {
		CP::CPpdf::_textAdd($x + ($mw / 2), $lineY,
				    '6', $myPDF->{font}[GRID], $Media->{Chord}{size}, $chd_clr);
	      } else {
		my $mx = $x;
		foreach my $cell (split(' ', $meas)) {
		  if ($cell eq '.' || $cell eq '/') {
		    CP::CPpdf::_textAdd($mx, $lineY,
					$cell, $myPDF->{font}[GRID], $Media->{Chord}{size}, $chd_clr);
		  } else {
		    my($ch,$cn) = CP::Chord->new($cell);
		    $myPDF->chordAdd($mx, $lineY, $ch, $chd_clr);
		  }
		  $mx += $cellw;
		}
	      }
	      $x += $mw;
	    }
	  }
	  $idx++;
	}
      }
    }
    elsif ($type == CHRD) {
      #
      # A {chord:} directive ALWAYS displays the chord fingering
      # and does it independantly of the Index Grid option.
      #
      my($nc,$inc) = $myPDF->fingersWidth();
      my @chords = ();
      foreach my $c (split(' ', $ln->{text})) {
	push(@chords, $c) if ($c =~ /^[A-G]/);
      }
      while ($self->{lines}[++$lnidx]->{type} == CHRD) {
	foreach my $c (split(' ', $self->{lines}[$lnidx]->{text})) {
	  push(@chords, $c) if ($c =~ /^[A-G]/);
	}
      }
      $lnidx--;
      while (@chords) {
	$lineX = INDENT * 2;
	my $max = 0;
	foreach my $i (1..$nc) {
	  last if (@chords == 0);
	  my($dx,$dy) = $myPDF->drawFinger($self, $lineX, $lineY, shift(@chords));
	  $lineX += $inc;
	  $max = $dy if ($dy > $max);
	}
	$lineY -= ($max + 5);
      }
    } elsif ($type == HLINE) {
      my $h = 1;
      my $w = $Media->{width};
      if ($ln->{text} =~ /([\.\d]+)\s?([\d]+)?/) {
	$h = $1;
	$w = $2 if (defined $2 && $2 ne '');
      }
      $myPDF->hline(0, $lineY - $h, $h, $w, $ln->{bg});
      $lineY -= $h;
    } elsif ($type == VSPACE) {
      $lineY -= ($ln->{text} =~ /(\d+)/) ? $1 : 5;
    } elsif ($type == NL) {
      my $dy = ($lyricht + $linespc);
      $dy /= 2 if ($Opt->{HHBL});
      $lineY -= $dy;
    } elsif ($type == CFONT) {
      $myPDF->chordFont($ln->{text});
    } elsif ($type == CFSIZ) {
      $myPDF->chordSize($ln->{text});
    } elsif ($type == CFCLR) {
      $chd_clr = ($ln->{text} eq '') ? $Media->{Chord}{color} : $ln->{text};
    } elsif ($type == LFONT) {
      $myPDF->lyricFont($ln->{text});
    } elsif ($type == LFSIZ) {
      $myPDF->lyricSize($ln->{text});
    } elsif ($type == LFCLR) {
      $lyr_clr = ($ln->{text} eq '') ? $Media->{Lyric}{color} : $ln->{text};
    } elsif ($type == TFONT) {
      $myPDF->tabFont($ln->{text});
    } elsif ($type == TFSIZ) {
      $myPDF->tabSize($ln->{text});
    } elsif ($type == TFCLR) {
      $tab_clr = ($ln->{text} eq '') ? $Media->{Tab}{color} : $ln->{text};
    } elsif ($type == HLIGHT || $type == CMMNT || $type == CMMNTI || $type == CMMNTB) {
      #
      # A Comment or Highlight directive
      #
      my $dy = ($type == HLIGHT) ? $highlht : $cmmntht;
      my $clr = ($type == HLIGHT) ? $Media->{Highlight}{color} : $Media->{Comment}{color};
      $lineY = $myPDF->newPage($self, $pageno++) if (($lineY - $dy) < 0);
      $lineY -= $dy;
      $myPDF->commentAdd($type, $lineY, $ln->{text}, $clr, $ln->{bg});
    }
  }
  #
  # Restore the fonts
  #
  foreach my $f (qw/chordFont chordSize lyricFont lyricSize tabFont tabSize/) {
    $myPDF->$f();
  }
  #
  # Just need to go back and add in the Page numbers
  #
  $myPDF->pageNum(--$pageno);
}

sub gridDef {
  my($grid,$txt) = @_;

  my $cells = undef;
  if (defined $txt && $txt =~ /([\d\+x]+)*\s*(.*)/) {
    my $mc = (defined $1) ? $1 : '';
    $grid->{label} = (defined $2) ? $2 : '';
    if (defined $1) {
      (my $mc = $1) =~ s/\s//g;
      my @items = split(/[x+]/, $mc);
      if (@items == 1) {
        $cells = $items[0];
      }
      else {
        $grid->{lmargw} = shift(@items);
        if (@items == 1) {
          $cells = shift(@items);
        }
        else {
          if ($mc =~ /x/) {
            $grid->{measures} = shift(@items);
	    $grid->{beats} = shift(@items);
          }
          else {
            $cells = shift(@items);
          }
          $grid->{rmargw} = shift(@items) if (@items);
        }
      }
    }
  }
  if (defined $cells) {
    $grid->{measures} = $cells / 4;
    $grid->{beats} = 4;
  }
}

#
# This is a stripped down version of processOneFile() which
# just transposes the chords and writes the results back out
# to the original file.
#
sub transpose {
  my($self,$idx) = @_;

  if (!defined $self || $self->{name} eq "" || $self->{path} eq "") {
    message(SAD, "Couldn't determine the name of the file to transpose.");
    return(0);
  }
  my $orgKey;
 AGAIN:
  $orgKey = $self->{key};
  if ($orgKey eq '') {
    my $resp = msgYesNoCan("There is no Key defined for this file.\nIf you edit the file - add a {key:X} directive.", "Guess the key", "Edit File");
    return(0) if ($resp eq 'Cancel');
    if ($resp eq 'No') { # == Edit File
      $self->edit($idx);
      goto AGAIN;
    }
  }
  $KeyShift = setIdx($orgKey) if ($orgKey ne '');
  my $org = $self->{path}."/".$self->{name};
  my $new = $Path->{Temp}."/".$self->{name};

  unless (open IFH, "$org") {
    message(SAD, "Transpose could not access\n   \"$org\"");
    return(0);
  }
  unless (open OFH, ">$new") {
    close(IFH);
    message(SAD, "Transpose could not create\n   \"$new\"");
    return(0);
  }
  my $key = "";
  while (<IFH>) {
    # Delete any Cariage Returns.
    $_ =~ s/\r//g;
    my @ch = split('', $_);
    while (@ch) {
      my $c = shift(@ch);
      if ($c eq '[') {
        print OFH $c;
        my $chord = "";
        do {
          $c = shift(@ch);
          $chord .= $c if ($c ne ']');
        } while ($c ne ']' && @ch);
	my($chrd,$name) = CP::Chord->new($chord);
	if ($orgKey eq '' && @$chrd > 1) {
	  $orgKey = $chrd->[0].$chrd->[1];
	  $KeyShift = setIdx($orgKey);
	}
	print OFH $chrd->trans2str($self)."$c";
      }
      elsif ($key eq "" && $c eq '{') {
        print OFH $c;
        my $drct = "";
        do {
          $c = shift(@ch);
          $drct .= $c if ($c ne '}');
        } while ($c ne '}' && @ch);
	if ($drct =~ /key:(.*)/) {
	  ($key = $1) =~ s/\s//g;
	  my($chrd,$cname) = CP::Chord->new($key);
	  print OFH "key:".$chrd->trans2str($self);
	} else {
	  print OFH $drct;
	}
	print OFH $c;
      }
      else {
        print OFH $c;
      }
    }
  }
  close(IFH);
  close(OFH);

  backupFile($self->{path}, $self->{name}, $new, 1);
  return(1);
}

sub setIdx {
  my($key) = shift;

  $Scale = ($Opt->{SharpFlat} == FLAT) ? \@Fscale : \@Sscale;
  my $idx = idx($Opt->{Transpose}) - idx($key);
  # Just make sure it's positive and between 0 and 11.
  return($idx % 12);
}

sub idx {
  my($key) = shift;

  my $i = 0;
  my $k = substr($key, 0, 1);
  while ($i < 12) {
    last if ($k eq $Scale->[$i]);
    $i++;
  }
  if ($key =~ /\#/) {
    $i++;
  }
  elsif ($key =~ /b/) {
    $i--;
  }
  return($i % 12);
}

sub clone {
  my($self,$idx) = @_;

  my $nfn = $self->{title};
  my $ans = msgSet("Enter a name for the new file:\n  (No extension)", \$nfn);
  return if ($ans eq "Cancel");
  if ($nfn eq "") {
    message(QUIZ, "How about a new file name then?");
    return;
  }
  # Just to be on the safe side ...
  $nfn =~ s/\.pro$//i;
  if (-e "$Path->{Pro}/$nfn.pro") {
    message(SAD, "$nfn.pro already exists.\nYou can't Clone to an existing file.\nIf you want to do that, Delete the target file first.");
    return;
  } else {
    open IFH, "<", "$Path->{Pro}/$self->{name}";
    open OFH, ">", "$Path->{Pro}/$nfn.pro";
    while (<IFH>) {
      print OFH $_;
    }
    close IFH;
    close OFH;
    main::selectClear();
    $self = $ProFiles[0] = CP::Pro->new("$nfn.pro");
    $KeyLB->add2a($self->{key});
    $FileLB->add2a($self->{name});
    $FileLB->set(0);
  }
}

sub edit {
  my($self,$idx) = @_;

  my $fileName = "$self->{path}/$self->{name}";
  my $tempfn = CP::Editor::Edit($fileName);
  if ($tempfn eq $self->{name}) {
    # It's possible all sorts of "stuff" has changed so ....
    $self->decompose($self->{name});
    $KeyLB->{array}[$idx] = "$self->{key}";
    $KeyLB->a2tcl();
  } else {
    # They did a 'New' or 'Save As' and we get back the new file name
    # so we do nothing as we've now got a new chordpro file but it
    # won't be in the list from which we just edited.
  }
  # Not sure why but coming back from the Editor the file list has no selected item so:
  $FileLB->set($idx);
}

sub delete {
  my($self,$idx) = @_;

  my $ans = msgYesNo("Do you really want to delete\n  $self->{name}");
  return if ($ans eq "No");
  unlink("$self->{path}/$self->{name}");
  splice(@ProFiles, $idx, 1);
  $KeyLB->remove($idx);
  $FileLB->remove($idx);
}

sub rename {
  my($self,$idx) = @_;

  my $ofn = $self->{name};
  my $newfn = $ofn;
  my $ans = msgSet("Enter a new name for the file:", \$newfn);
  return if ($ans eq "Cancel");
  $newfn =~ s/\.pro$//i;
  $newfn .= '.pro';
  if (-e "$Path->{Pro}/$newfn") {
    $ans = msgYesNo("$Path->{Pro}/$newfn\nFile already exists.\nDo you want to replace it?");
    return if ($ans eq "No");
  }
  $self->{name} = $newfn;
  $self->{path} = $Path->{Pro};
  $FileLB->replace($idx, $newfn);
  rename("$self->{path}/$ofn", "$Path->{Pro}/$newfn");
}

1;
