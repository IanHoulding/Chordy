package CP::Lyric;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018, 2019, 2020 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

# This module is horribly complex due to the fact that a stave line can have more
# than one line of lyrics under it. These lines are then independent BUT if one
# of the lines exceeds the page width it has to wrap NOT to the line immediately
# below it but to the equivalent line under the next stave in order to keep a
# verse/chorus text consistent.
# Just figuring out if the line has wrapped and adjusting everything is a PITA!!

use strict;
use warnings;

BEGIN {
  our @ISA = qw(Exporter);
  our @EXPORT = qw//;
  require Exporter;
}

use CP::Cconst qw/:SMILIE :COLOUR :FONT :TEXT :TAB/;
use CP::Global qw/:OPT :WIN/;
use Tkx;
use POSIX;
use CP::Tab;

my $Ignore = 1;

sub new {
  my($proto) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;
  $self->{text} = [];    # Contains all the lyric lines as a linear array.
  $self->{widget} = [];  # Contains enough Text widgets for a page.
  $self;
}

sub widgets {
  my($self) = shift;

  if ((my $ll = $Opt->{LyricLines}) && $Tab->{rowsPP}) {
    my $can = $Tab->{pCan};
    my $off = $Tab->{pOffset};
    my $w = $Media->{width} - ($Opt->{LeftMargin} + $Opt->{RightMargin});
    my $h = $off->{lyricHeight};
    my $ht = $off->{height};
    my $y = $Tab->{pageHeader} + $Opt->{TopMargin} + $off->{lyricY};

    my $wid = $self->{widget};
    my $font = $Tab->{wordFont};
    my $fg = $Tab->{wordColor};
    my $rc = 0;
    foreach my $row (0..($Tab->{rowsPP} - 1)) {
      my $frm = $can->new_ttk__frame(-width => $Media->{width},
				     -height => $h * $ll,
				     -padding => [0,0,0,0]);
      foreach my $line (0..($ll - 1)) {
	my $wdgt = $frm->new_tk__text(
	  qw/-wrap none -borderwidth 0 -spacing1 0 -spacing2 0 -spacing3 0 -height 1/,
	  -font => $font,
	  -bg   => MWBG,
	  -fg   => $fg);
	$wdgt->g_pack(qw/-side top -anchor nw -fill x/);
	my $myrc = $rc;
	$wdgt->g_bind('<Key-Up>' => sub{moveWidget($wid, $myrc, -1)});
	$wdgt->g_bind('<Key-Down>' => sub{moveWidget($wid, $myrc, 1)});
	$wid->[$rc++] = $wdgt;
      }
      my $win = $can->create_window($Opt->{LeftMargin}, $y,
				    -window => $frm,
				    -width  => $w,
				    -height => $h,
				    -anchor => 'nw');
      $y += $ht;
    }
  }
}

# $wid is the pointer to the page list of text widgets.
# $idx is a valuee from 0 to # of text widgets (minus 1) on one page.
# $dir is either -1 or +1
sub moveWidget {
  my($wid,$idx,$dir) = @_;

  my $mark = $wid->[$idx]->index('insert');
  my $npage = $Tab->{nPage} - 1;
  my $pn = -1;
  if ($idx == 0 && $dir < 0) {
    $idx = $#{$wid};
    $pn = ($Tab->{pageNum} == 0) ? $npage : $Tab->{pageNum} - 1;
  } elsif ($idx == $#{$wid} && $dir > 0) {
    $idx = 0;
    $pn = ($Tab->{pageNum} == $npage) ? 0 : $Tab->{pageNum} + 1;
  } else {
    $idx += $dir;
  }
  if ($pn >= 0) {
    $Tab->newPage($pn);
  }
  $wid->[$idx]->g_focus();
  $wid->[$idx]->mark_set('insert', $mark);
}

sub linechk {
  my($self,$wid,$rc) = @_;

  return if ($Ignore);
  my ($package, $filename, $line) = caller;
  print "$filename  $line";
  my $w = $Media->{width} - ($Opt->{LeftMargin} + $Opt->{RightMargin});
  my $ln = $wid->get('1.0', 'end');
  if ($ln =~ /\n/) {
    $ln =~ s/\n.*//;
    $wid->replace('1.0', 'end', $ln);
  }
  my($x,$y,$lw,$lh,$bl) = Tkx::SplitList($wid->dlineinfo('1.0'));
  print "  rc=$rc  w=$w  lw=$lw\n";
  my $bg = ($lw > $w) ? '#FFD0D0' : MWBG;
  $wid->configure(-background => $bg);
#  $self->{modified}[$rc] = 1;
}

sub set {
  my($self,$stave,$line,$text) = @_;

  if (my $ll = $Opt->{LyricLines}) {
    my $idx = ($stave * $ll) + $line;
    $self->{text}[$idx] = $text;
  }
}

# Clear the visible Lyrics on the current page.
sub clear {
  my($self) = shift;

  if ($Opt->{LyricLines}) {
    $Ignore = 1;
    foreach my $wid (@{$self->{widget}}) {
      $wid->delete('1.0', 'end');
      $wid->edit_reset;
      $wid->edit_modified(0);
    }
  }
}

#
# These next 2 subs handle placing Lyrics into the Text widgets for displaying
# and retrieving any Lyrics from the Text widgets into the Tab->{lyrics} array.
#
# Display any lyrics on a page.
#
sub show {
  my($self) = shift;

  if (my $ll = $Opt->{LyricLines}) {
    my $lidx = $Tab->{pageNum} * $Tab->{rowsPP} * $ll;
    my $text = $self->{text};
#    my $mod = $self->{modified};
    my $rc = 0;
    foreach my $wid (@{$self->{widget}}) {
      $wid->replace('1.0', 'end', $text->[$lidx]);
#      $mod->[$lidx++] = 0;
      $wid->edit_reset();
      $wid->edit_modified(0);
      $lidx++;
    }
    $Ignore = 0;
  }
}

sub printArray {
  my($self,$ind) = @_;

  my $pidx = $Tab->{pageNum} * $Tab->{rowsPP} * $Opt->{LyricLines};
  my $text = $self->{text};
  my $idx = 0;
  foreach my $wid (@{$self->{widget}}) {
    print "$ind$idx - L$pidx - '".substr($text->[$pidx],0,40)."'\n";
    $idx++;
    $pidx++;
  }
  print "\n";
}

#
# Go through a page and collect any Lyrics.
#
sub collect {
  my($self) = shift;

  if (my $ll = $Opt->{LyricLines}) {
    my $lidx = $Tab->{pageNum} * $Tab->{rowsPP} * $ll;
    my $text = $self->{text};
    foreach my $wid (@{$self->{widget}}) {
      $text->[$lidx] = $wid->get('1.0', '1.end') if ($wid->edit_modified());
      $lidx++;
    }
  }
}

sub lprint {
  my($self,$ofh) = @_;

  my $si = 0;
  my $li = 0;
  foreach my $line (@{$self->{text}}) {
    print $ofh "{lyric:$si:$li:".$line."}\n" if ($line ne '');
    $li++;
    if ($li == $Opt->{LyricLines}) {
      $li = 0;
      $si++;
    }
  }
}

# Change the number of lyric lines per Stave.
# Increasing is no problem - we just splice in extra array elements.
# Decreasing causes layout issues - what do we do with any lyric lines
# that would be removed?
# Current policy is to have a stab at intelligently removing blank lines
# from the end of each stave IF we can do it to ALL staves otherwise we
# just redo the displayable text widgets and then distribute the existing
# lyrics into them.
# This will cause some wierd effects if for example you have one line
# of lyrics per stave and increase to two then decrease back to one after
# adding text to the second line of the first stave.
# You'll end up with every other lyric line blank.
#
# An exception is where $new == LyricLines - we use this to make sure
# that ALL the {text} array is initialised.
sub adjust {
  my($self,$new) = @_;

  if ($new) {
    my $ll = $Opt->{LyricLines};
    if ($new == $ll) {
      my $lidx = $Tab->{nPage} * $Tab->{rowsPP} * $ll;
      foreach my $idx (0..($lidx - 1)) {
	if (! defined $self->{text}[$idx]) {
	  $self->{text}[$idx] = '';
#	  $self->{modified}[$idx] = 0;
	}
      }
    } elsif ($new > $ll) {
      if ($new > 1) {
	collect($self);
	clear($self);
	my $segs = @{$self->{text}};
	while ($segs > 0) {
	  splice(@{$self->{text}}, $segs, 0, '');
	  $segs -= $ll;
	}
      }
    } else {
      collect($self);
      my @sn = ();
      for(my $segs = @{$self->{text}} - 1; $segs > 0; $segs -= $ll) {
	push(@sn, $segs) if ($self->{text}[$segs] eq '');
      }
      if (@sn == (@{$self->{text}} / $ll)) {
	foreach my $idx (@sn) {
	  splice(@{$self->{text}}, $idx, 1);
	}
      }
    }
  }
  $Opt->{LyricLines} = $new;
}

# Moving lyrics up/down one line (Note: NOT 1 Stave) is essentially a
# rotate left/right. Whatever moves off the first/last page is added
# to the end/begining of the Lyric array.
sub shiftUp {
  my($self) = shift;

  if ($Opt->{LyricLines}) {
    collect($self);
    my $ly = shift(@{$self->{text}});
    push(@{$self->{text}}, $ly);
    clear($self);
    show($self);
  }
}

sub shiftDown {
  my($self) = shift;

  if ($Opt->{LyricLines}) {
    collect($self);
    my $ly = pop(@{$self->{text}});
    unshift(@{$self->{text}}, $ly);
    clear($self);
    show($self);
  }
}

1;
