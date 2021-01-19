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

use CP::Cconst qw/:OS :PDF :FONT :MUSIC :TEXT :SHFL :INDEX :SMILIE/;
use CP::Global qw/:FUNC :OPT :WIN :PRO :SCALE :MEDIA/;
use CP::PDFfont;
use CP::CPpdf;
use CP::Cmsg;
use CP::Line;
use CP::Chord;
use CP::Editor;
use POSIX qw/ceil/;
use Exporter;

our @ISA = qw/Exporter/;

our($MyPDF, $PdfFileName);

sub new {
  my($proto,$fn,$elem) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;
  decompose($self, $Path->{Pro}, $fn, $elem);
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
#   key    => "-",
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
  my($self,$path,$fn,$elem) = @_;

  $self->{path} = $path;
  $self->{name} = $fn;
  $self->{tempo} = 0;
  $self->{capo} = 0;
  $self->{key} = '-';
  $self->{note} = '';
  $self->{instrument} = $Opt->{Instrument};
  $self->{chords} = {}; # a hash of all chords used in this .pro
  $self->{finger} = {}; # local (to this .pro) chord fingering from a {define: }
  unless (open IFH, "$self->{path}/$self->{name}") {
    message(SAD, "Could not access\n   \"$self->{path}/$self->{name}\"");
    return(0);
  }
  @{$self->{lines}} = ();
  my %verseLines = ();
  my %chorusLines = ();
  my %bridgeLines = ();
  my %tabLines = ();
  my $gridlref;
  my $tablref;
  my $lvcb = LYRIC;
  my($vidx,$cidx,$bidx,$tidx,$blk_no) = qw/dflt dflt dflt dflt 0/;
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
	$txt = '' if (! defined $txt);
	$cmd =~ s/^x_//;
	if ($txt ne '') {
	  my $pat = "";
	  if ($txt =~ /(\d+),(\d+),(\d+)$/) {
	    $pat = $1.",".$2.",".$3;
	    $bg = sprint("#%02x%02x%02x", $1, $2, $3);
	  } elsif ($txt =~ /(#[\da-fA-F]{6})$/) {
	    $bg = $pat = $1;
	  }
	  $txt =~ s/$pat$//;
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
	  $lref->segment($self);
	}
	elsif ($cmd =~ /^ci$|^comment_italic$/i) {
	  $lref = CP::Line->new(CMMNTI, $txt, $blk_no, $bg); $bg = '';
	  $lref->segment($self);
	}
	elsif ($cmd =~ /^cb$|^comment_box$/i) {
	  $lref = CP::Line->new(CMMNTB, $txt, $blk_no, $bg); $bg = '';
	  $lref->segment($self);
	}
	elsif ($cmd =~ /^h$|^highlight$/i) {
	  $lref = CP::Line->new(HLIGHT, $txt, $blk_no, $bg); $bg = '';
	  $lref->segment($self);
	}
	elsif ($cmd =~ /^(sov|start_of_verse)$/i) {
	  $lvcb = VERSE;
	  $vidx = $txt if ($txt ne '');
	  @{$verseLines{$vidx}} = ();
	  if ($txt ne '') {
	    $lref = CP::Line->new($lvcb, $txt, $blk_no, $bg);
	    $lref->{label} = 1;
	  }
	}
	elsif ($cmd =~ /^(soc|start_of_chorus)$/i) {
	  $lvcb = CHORUS;
	  $cidx = $txt if ($txt ne '');
	  @{$chorusLines{$cidx}} = ();
	  if ($txt ne '') {
	    $lref = CP::Line->new($lvcb, $txt, $blk_no, $bg);
	    $lref->{label} = 1;
	  }
	}
	elsif ($cmd =~ /^(sob|start_of_bridge)$/i) {
	  $lvcb = BRIDGE;
	  $bidx = $txt if ($txt ne '');
	  @{$bridgeLines{$bidx}} = ();
	  if ($txt ne '') {
	    $lref = CP::Line->new($lvcb, $txt, $blk_no, $bg);
	    $lref->{label} = 1;
	  }
	}
	elsif ($cmd =~ /^(sog|start_of_grid)$/i) {
	  $lvcb = GRID;
	  $gridlref = CP::Line->new($lvcb, $txt, $blk_no, $bg);
	}
	elsif ($cmd =~ /^(sot|start_of_tab)$/i) {
	  $lvcb = TAB;
	  $tidx = $txt if ($txt ne '');
	  @{$tabLines{$tidx}} = ();
	  if ($txt ne '') {
	    $tablref = CP::Line->new($lvcb, '', $blk_no, $bg);
	    $lref = CP::Line->new($lvcb, $txt, $blk_no, $bg);
	    $lref->{label} = 1;
	  }
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
	  $vidx = $cidx = $bidx = $tidx = 'dflt';
	  $bg = '';
	  $blk_no++;
	}
	elsif ($cmd =~ /^np$|^npp$|^new_page$|^new_physical_page$/i) {
	  $lref = CP::Line->new(NP, "", $blk_no++, "");
	  $bg = '';
	}
	elsif ($cmd =~ /^(verse|chorus|bridge|tab)$/i) {
	  # Chorus backgrounds stay in effect until changed by another colour directive.
	  my $lp = ($cmd =~ /^v/i) ? \%verseLines :
	           ($cmd =~ /^c/i) ? \%chorusLines :
	           ($cmd =~ /^b/i) ? \%bridgeLines : \%tabLines;
	  if ($txt eq '') {
	    $txt = ($cmd =~ /^v/i) ? $vidx :
	           ($cmd =~ /^c/i) ? $cidx :
		   ($cmd =~ /^b/i) ? $bidx : $tidx;
	  }
	  if (! defined $lp->{$txt}) {
	    $lp = \@{$lp->{dflt}};
	  } else {
	    $lp = \@{$lp->{$txt}};
	  }
	  my $idx = 0;
	  foreach my $cl (@{$lp}) {
	    my $cln = $cl->clone($blk_no);
	    if ($idx == 0 && $txt ne 'dflt') {
	      if ($cln->{label} == 0) {
		my $ref = CP::Line->new($cln->{type}, $txt, $blk_no, $bg);
		$ref->{label} = 1;
		$ref->{bg} = ($bg ne '') ? $bg : $cl->{bg};
		push(@{$self->{lines}}, $ref);
	      } else {
		$cln->{text} = $txt;
	      }
	      $idx++;
	    }
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
	  $bg = '';
	}
	elsif ($cmd =~ /^vs$|^vspace$/i) {
	  $lref = CP::Line->new(VSPACE, $txt, $blk_no++, $bg);
	  $bg = '';
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
	  $lref = CP::Line->new($lvcb, $_, $blk_no, $bg);
	  $lref->segment($self);
	}
      }
    }
    if (defined $lref) {
      $lref->{num} = $lineNum;
      push(@{$self->{lines}}, $lref);
      if ($lvcb == VERSE) {
	push(@{$verseLines{$vidx}}, $lref);
      } elsif ($lvcb == CHORUS) {
	push(@{$chorusLines{$cidx}}, $lref);
      } elsif ($lvcb == BRIDGE) {
	push(@{$bridgeLines{$bidx}}, $lref);
      } elsif ($lvcb == TAB) {
	push(@{$tabLines{$tidx}}, $lref);
      }
    }
  }
  close(IFH);
  ($self->{title} = $fn) =~ s/\.pro(\.\d+)?$// if (! defined $self->{title});
  return(1);
}

sub makePDF {
  my($self,$myPDF) = @_;

  # We can't transpose if there is no 'key' directive.
  $KeyShift = 0;
  if ($self->{key} ne '') {
    if ($Opt->{Transpose} ne "-") {
      $KeyShift = setIdx("$self->{key}");
    }
    if ($Opt->{IgnCapo} == 0 && $self->{capo} != 0) {
      $KeyShift -= $self->{capo};
      $KeyShift %= 12;
    }
  }

  my $lengthErr = 0;

  my $linespc = $Opt->{LineSpace};
  my $halfspc = int($linespc / 2);

  my $lyfp    = $myPDF->{fonts}[VERSE];
  my $lyricdc = $lyfp->{dc};
  my $lyricht = $lyfp->{as} + $lyricdc;
  my $lyr_clr = $lyfp->{clr};

  my $chfp    = $myPDF->{fonts}[CHORD];
  my $chorddc = $chfp->{dc} / 2;
  my $chordht = $chfp->{as} + $chorddc;
  my $chd_clr = $chfp->{clr};

  my $cmfp    = $myPDF->{fonts}[CMMNT];
  my $cmmntht = $cmfp->{dc} + $cmfp->{as} + 2;

  my $hlfp    = $myPDF->{fonts}[HLIGHT];
  my $highlht = $hlfp->{dc} + $hlfp->{as} + 2;

  my $lbfp    = $myPDF->{fonts}[LABEL];
  my $labeldc = $lbfp->{dc};
  my $labelht = $lbfp->{as} + $labeldc;
  my $lab_clr = $lbfp->{clr};

  my $tbfp    = $myPDF->{fonts}[TAB];
  my $tabdc   = $tbfp->{dc};
  my $tabht   = $tbfp->{as} + $tabdc;
  my $tab_clr = $tbfp->{clr};
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
  my $lyrOnly = $Opt->{LyricOnly};
  my $pageno = 1;
  my $lineX = $Opt->{LeftMargin};
  # $lineY is always where the last entry was placed so it's up to
  # the current entity to drop it down the page before placing itself.
  my $lineY = $myPDF->newPage($self, $pageno++);

  my $blk = -1;
  my $lref = \@{$self->{lines}};
  for(my $lnidx = 0; $lnidx < @{$self->{lines}}; $lnidx++) {
    my $ln = $lref->[$lnidx];
    my $type = $ln->{type};
    if ($type == NP || $lineY < $Opt->{BottomMargin}) {
      $lineY = $myPDF->newPage($self, $pageno++);
    }
    next if ($type == NP);

    #
    # Work out if it's the start of a new Block and if so,
    # will it fit on the current page.
    #
    if ($type == TAB) {
      # Tab block contents are ALWAYS kept together on one page.
      if ($lyrOnly == 0) {
	my $ht = 0;
	if ($ln->{label}) {
	  $ht += $linespc if ($ln->{text} ne '' && $Opt->{ShowLabels});
	}
	my @lns = split(/\n/, $ln->{text});
	$lineY = $myPDF->newPage($self, $pageno++) if ((($tabht * @lns) + $ht) > $lineY);
      }
    }
    elsif ($type < NL && $Opt->{Together} && $ln->{blk_no} != $blk) {
      $blk = $ln->{blk_no};
      # Start of a new Block. Work out it's height and see if it'll fit on this Page.
      my $ht = $Opt->{BottomMargin};
      for(my $i = $lnidx; $i <= $#{$lref} && $lref->[$i]->{blk_no} == $blk; $i++) {
	my $lrp = $lref->[$i];
	my $ty = $lrp->{type};
	if ($ty == HLINE || $ty == VSPACE) {
	  $ht += ($lrp->{text} =~ /([\.\d]+)\s?([\.\d]+)?/) ? $1 : 5;
	} elsif ($ty == GRID) {
	  $ht += ($chordht * $lrp->{ch_cnt}) if ($lyrOnly == 0);
	} elsif ($ty == LYRIC || $ty == VERSE || $ty == CHORUS || $ty == BRIDGE) {
	  if ($ln->{label}) {
	    $ht += ($linespc + $labelht) if ($ln->{text} ne '' && $Opt->{ShowLabels});
	  } else {
	    my $h = ($lrp->{ly_cnt}) ? $lyricht: 0;
	    $h += $chordht if ($lrp->{ch_cnt} && $lyrOnly == 0);
	    $ht += ($linespc + $h) if ($h);
	  }
	} elsif ($ty == CHRD) {
	  my @chords = split(' ', $lrp->{text});
	  while ($lref->[++$i]->{type} == CHRD) {
	    push(@chords, split(' ', $lref->[$i]->{text}));
	  }
	  $i--;
	  $ht += $myPDF->fingersHeight(@chords);
	} elsif ($ty == HLIGHT || $ty == CMMNT || $ty == CMMNTI || $ty == CMMNTB) {
	  my $dy = ($ty == HLIGHT) ? $highlht : $cmmntht;
	  if ($lrp->{ch_cnt} && $lyrOnly == 0) {
	    my $cht = ceil(($chfp->{as} + $chfp->{dc}) * SUPHT);
	    $cht += ceil($cht * SUPHT);
	    $dy = $cht if ($cht > $dy);
	  }
	  $ht += ($dy + 1);
	}
      }
      if ($ht > $lineY) {
	$lineY = $myPDF->newPage($self, $pageno++);
      }
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
      my $label = 0;
      my $wid = 0;
      if ($ln->{label}) {
	$label++ if ($ln->{text} ne '' && $Opt->{ShowLabels});
      } else {
	# Adjust the font size until the lyrics fit on the page.
	# Side effect of measure() sets the x offset for each segment.
	# As a side note - Tcl/Tk doesn't handle half point sizes for
	#   fonts but PDF::API2 can - so we do.
	my $max = $Media->{width} - $Opt->{LeftMargin};
	while (1) {
	  $wid = $ln->measure($self,$myPDF);
	  last if ($wid < $max || $lyfp->{sz} < 5); # Sanity check!
	  $lyfp->{sz} -= 0.5;
	  $chfp->{sz} -= 0.5;
	  $heightAdj += 0.5;
	  $lengthErr++;
	}
	if ($heightAdj != 0) {
	  my $str = "";
	  if ($ln->{ly_cnt}) {
	    foreach my $s (@{$ln->{segs}}) {
	      $str .= "$s->{lyric}";
	    }
	  } else {
	    foreach my $s (@{$ln->{segs}}) {
	      if (@{$s->{chord}}) {
		$str .= join("", @{$s->{chord}});
	      }
	    }
	  }
	  print localtime."\n";
	  printf "  LINE $ln->{num} TOO LONG by %.1fmm: %s/%s\n  -->%s\n\n",
	      ($wid - $max) * (25.4 / 72), $self->{path}, $self->{name}, $str;
	}
      }
      my $off = 0;
      if ($Opt->{Center} && $ln->{label} == 0) {
	$off = int(($Media->{width} - $wid) / 2) - $Opt->{LeftMargin};
      }
      $off += $Opt->{LeftMargin};
      #
      # Now go through the segments on this line and insert into the PDF
      # Do the BackGrounds first so that chord descenders can go down
      # into the lyric space (even if only marginally).
      #
      my($lineht,$chordY,$lyricY) = (0,0,0);
      if ($label) {
	$lineht = $labelht;
	$lyricY = $lineY - $halfspc - $lineht + $labeldc;
      } else {
	if ($ln->{ch_cnt} && $lyrOnly == 0) {
	  $lineht = $chordht;
	  $chordY = $lineY - $halfspc - $lineht + $chorddc;
	}
	if ($ln->{ly_cnt}) {
	  $lineht += $lyricht;
	  $lyricY = $lineY - $halfspc - $lineht + $lyricdc;
	}
      }
      if ($lineht) {
	$lineY -= ($lineht + $linespc);
	if ($lineY < $Opt->{BottomMargin}) {
	  my $cdiff = $chordY - $lineY;
	  my $ldiff = $lyricY - $lineY;
	  $lineY = $myPDF->newPage($self, $pageno++) - $lineht - $linespc;
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
	  $bg = CP::FgBgEd::darken($bg, 7) if ($label);
	  CP::CPpdf::_bg($bg, 0, $lineY, $Media->{width}, $lineht + $linespc);
	}
	#
	# Now the actual text
	#
	if ($label) {
	  $myPDF->labelAdd($off, $lyricY, $ln->{text}, $lab_clr);
	} else {
	  foreach my $s (@{$ln->{segs}}) {
	    $lineX = $s->{x} + $off;
	    # Chords
	    if ($lyrOnly == 0 && defined $s->{chord}) {
	      $myPDF->chordAdd($lineX, $chordY, $s->{chord}->trans2obj($self), $chd_clr);
	    }
	    # Lyrics
	    if ($s->{lyric} ne "") {
	      $myPDF->lyricAdd($lineX, $lyricY, $s->{lyric}, $lyr_clr);
	    }
	  }
	}
      }
      if ($heightAdj) {
	# Reset the Chord/Lyric font heights
	$lyfp->{sz} += $heightAdj;
	$chfp->{sz} += $heightAdj;
      }
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
	  CP::CPpdf::_textAdd($Opt->{LeftMargin}, $lineY,
			      $line, $tbfp->{font}, $tbfp->{sz}, $tbfp->{clr});
	}
      }
      $lineY -= $tabdc;
    }
    elsif ($type == GRID) {
      $lineY = drawGrid($myPDF,$ln,$lineY,$lyfp,$chordht,$chd_clr);
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
	$lineX = $Opt->{LeftMargin};
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
      my ($h,$w,$x) = (1,$Media->{width},0);
      if ($ln->{text} =~ /([\.\d]+)\s?([\.\d]+)?/) {
	$h = $1;
	$w = $2 if (defined $2 && $2 ne '');
	if (int($w) != $w) {
	  # We'll assume it's a fractional number and
	  # treat it as a percentage of the Media width.
	  $w *= $Media->{width};
	}
      }
      $x = ($Media->{width} - $w) / 2;
      $lineY -= $h;
      $myPDF->hline($x, $lineY, $h, $w, $ln->{bg});
    } elsif ($type == VSPACE) {
      $lineY -= ($ln->{text} =~ /(\d+)/) ? $1 : 5;
    } elsif ($type == NL) {
      my $dy = ($lyricht + $linespc);
      $dy /= 2 if ($Opt->{HHBL});
      $lineY -= $dy;
    } elsif ($type == CFONT) {
      $chfp->chordFont($myPDF, $ln->{text});
    } elsif ($type == CFSIZ) {
      $chfp->chordSize($myPDF, $ln->{text});
    } elsif ($type == CFCLR) {
      $chd_clr = ($ln->{text} eq '') ? $Media->{Chord}{color} : $ln->{text};
    } elsif ($type == LFONT) {
      $lyfp->lyricFont($myPDF, $ln->{text});
    } elsif ($type == LFSIZ) {
      $lyfp->lyricSize($ln->{text});
    } elsif ($type == LFCLR) {
      $lyr_clr = ($ln->{text} eq '') ? $Media->{Lyric}{color} : $ln->{text};
    } elsif ($type == TFONT) {
      $tbfp->tabFont($myPDF, $ln->{text});
    } elsif ($type == TFSIZ) {
      $tbfp->tabSize($ln->{text});
    } elsif ($type == TFCLR) {
      $tab_clr = ($ln->{text} eq '') ? $Media->{Tab}{color} : $ln->{text};
    } elsif ($type == HLIGHT || $type == CMMNT || $type == CMMNTI || $type == CMMNTB) {
      #
      # A Comment or Highlight directive
      #
      my $dy = ($type == HLIGHT) ? $highlht : $cmmntht;
      if ($ln->{ch_cnt} && $lyrOnly == 0) {
	my $cht = ceil(($chfp->{as} + $chfp->{dc}) * SUPHT);
	$cht += ceil($cht * SUPHT);
	$dy = $cht if ($cht > $dy);
      }
      $lineY -= ($dy + 1);
      if ($lineY < 0) {
	$lineY = $myPDF->newPage($self, $pageno++);
      }
      $myPDF->commentAdd($self, $ln, $type, $lineY, $dy);
    }
  }
  #
  # Restore the modifiable fonts
  #
  $lyfp->lyricSize();
  $lyfp->lyricFont($myPDF);
  $chfp->chordSize();
  $chfp->chordFont($myPDF);
  $tbfp->tabSize();
  $tbfp->tabFont($myPDF);
  #
  # Just need to go back and add in the Page numbers
  #
  $myPDF->pageNum(--$pageno);
  $lengthErr;
}

sub drawGrid {
  my($myPDF,$ln,$lineY,$lyfp,$chordht,$chd_clr) = @_;

  my $grid = {
    lmargw => 1,
    rmargw => 1,
    measures => 4,
    beats => 4,
    label => '',
      };
  my @gr = split(/\n/, $ln->{text});
  gridDef($grid, shift(@gr));
  my $idx = my $maxl = my $maxr = 0;
  foreach my $line (@gr) {
    # Looking for (in order)   :|:  ||  :|  |:  |. |
    my @c = split(/(:\|:|\|\||:\||\|:|\|\.|\|)/, $line);
    if ($c[0] !~ /\|/) {
      my $len = CP::CPpdf::_measure($c[0], $lyfp->{font}, $lyfp->{sz});
      $maxl = $len if ($len > $maxl);
    }
    if ($c[-1] !~ /\|/) {
      my $len = CP::CPpdf::_measure($c[-1], $lyfp->{font}, $lyfp->{sz});
      $maxr = $len if ($len > $maxr);
    }
    $grid->{lines}[$idx++] = \@c;
  }
  if ($grid->{label} ne '') {
    my $cmfp = $myPDF->{fonts}[LABEL];
    $lineY -= ($cmfp->{dc} + $cmfp->{as});
    $myPDF->labelAdd($Opt->{LeftMargin}, $lineY, $grid->{label}, $cmfp->{clr});
  }
  my $grfp = $myPDF->{fonts}[GRID];
  my $div = CP::CPpdf::_measure('4', $grfp->{font}, $grfp->{sz});
  my $cells = $grid->{measures} * $grid->{beats};
  $cells += $grid->{lmargw} if ($maxl == 0);
  $cells += $grid->{rmargw} if ($maxr == 0);
  my $cellw = $Media->{width} - $Opt->{LeftMargin} - ($maxl + $maxr) - ($div * ($grid->{measures} + 1)) - $Opt->{RightMargin};
  $cellw /= $cells;
  $maxl = $cellw * $grid->{lmargw} if ($maxl == 0);
  foreach my $gl (@{$grid->{lines}}) {
    my $x = $Opt->{LeftMargin};
    $lineY -= $chordht;
    my $idx = 0;
    while (scalar @$gl) {
      my $meas = shift(@{$gl});
      if ($meas =~ /\|/) {
	my $d = ($meas eq '|') ? '0' : ($meas eq '||') ? '1' : ($meas eq '|:') ? '2' : ($meas eq ':|') ? '3' : ($meas eq ':|:') ? '4' : '5';
	CP::CPpdf::_textAdd($x, $lineY, $d, $grfp->{font}, $grfp->{sz}, $chd_clr);
	$x += $div;
      } else {
	if ($idx == 0 || (scalar @$gl) == 0) {
	  $myPDF->lyricAdd($x, $lineY, $meas, $lyfp->{clr});
	  $x += $maxl;
	} else {
	  my $mw = $cellw * $grid->{beats};
	  if ($meas =~ /%%/) {
	    $x += $mw;
	    CP::CPpdf::_textAdd($x, $lineY,
				'6', $grfp->{font}, $Media->{Chord}{size}, $chd_clr);
	    $x += $div;
	    # This takes the liberty that the following Measure MUST be empty!
	    shift(@{$gl});shift(@{$gl});
	  } elsif ($meas =~ /%/) {
	    CP::CPpdf::_textAdd($x + ($mw / 2), $lineY,
				'6', $grfp->{font}, $grfp->{sz}, $chd_clr);
	  } else {
	    my $mx = $x;
	    foreach my $cell (split(' ', $meas)) {
	      if ($cell eq '.' || $cell eq '/') {
		CP::CPpdf::_textAdd($mx, $lineY, $cell, $grfp->{font}, $grfp->{sz}, $chd_clr);
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
  $lineY;
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
  if ($orgKey eq '-') {
    my $resp = msgYesNoCan("There is no Key defined for this file.\nIf you edit the file - add a {key:X} directive.", "Guess the key", "Edit File");
    return(0) if ($resp eq 'Cancel');
    if ($resp eq 'No') { # == Edit File
      $self->edit($idx);
      goto AGAIN;
    }
  }
  $KeyShift = setIdx($orgKey) if ($orgKey ne '-');
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
	if ($orgKey eq '-' && @$chrd > 1) {
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

  $Opt->add2recent($self->{name},'RecentPro',\&CP::CPmenu::refreshRcnt);
  my $fileName = "$self->{path}/$self->{name}";
  my $tempfn = CP::Editor::Edit($fileName);
  if ($tempfn eq $self->{name}) {
    # It's possible all sorts of "stuff" has changed so ....
    $self->decompose($Path->{Pro}, $self->{name});
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
