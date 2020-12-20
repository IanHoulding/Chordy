package CP::Bar;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

# These are fixed distances and are common to all Bars:
#   header        space above the top Staff line
#   height        total y distance allocated to a Bar
#   interval      distance from one Note to the next
#   scale         1 for the page view, 3 - 5 for edit view
#   staffHeight   distance between the top and bottom Staff lines
#   staffSpace    distance between each Staff Line
#   width         total x distance allocated to a Bar
#
# These are absolute screen positions on the overall Canvas
#   x             left position of the Bar rectangle
#   y             top position of the Bar rectangle
#   staffX        same as x screen position
#   staffY        position of the top Staff line
#   staff0        position of the bottom Staff line (staffY + staffHeight)
#   pos0          x position of the first Note (x + (interval * 2))

# tab     back pointer to the containing Tab
# pidx    page index for the Bar
# bg      Bar background colour
# volta   type of header bar - left, right or just horizontal bar
# header  Text to show above the bar
# justify where to position the header text
# rep     repeat indicator - Left, Right or None
# lyric   array of lyrics to display below the Bar
# sid     used for Slide/Hammer
# eid      ""
# notes   array of Notes/Rests to be displayed in this Bar

use strict;
use warnings;

use Tkx;
use Math::Trig;
use CP::Cconst qw/:TEXT :SMILIE :COLOUR :TAB/;
use CP::Global qw/:OPT :WIN :CHORD/;
use CP::Cmsg;
use CP::FgBgEd;
use CP::Tab;
use CP::Note;

sub new {
  my($proto,$tab) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;

  $self->{tab} = $tab;
  $self->{prev} = 0;
  $self->{next} = 0;
  $self->{canvas} = $tab->{pCan};    # This is the majority - only
  $self->{offset} = $tab->{pOffset}; # changed once for the EditBars.
  $self->{pnum} = 0;
  $self->{pidx} = 0;
  $self->{bidx} = 0;
  $self->blank();

  return($self);
}

# Reset all displayable elements.
sub blank {
  my($self) = shift;

  $self->{notes} = [];
  $self->{header} = '';
  $self->{rep} = $self->{volta} = 'None';
  $self->{justify} = 'Left';
  $self->{newline} = $self->{newpage} = 0;
  $self->{bg} = BLANK;
}

sub isblank {
  my($self) = shift;

  return(0) if (@{$self->{notes}} ||
		$self->{header} ne '' ||
		$self->{volta} ne 'None' ||
		$self->{rep} ne 'None' ||
		$self->{newline} ||
		$self->{newpage});
  return(1);
}

# Remove all Heading, Notes, Background, etc from a displayed Bar.
# Does nothing to the actual Bar object.
sub unMap {
  my($self) = shift;

  my $pidx = $self->{pidx};
  my $can = $self->{canvas};
  if ($pidx < 0) {
    if ($pidx == -1) {
      $can->delete('barn');
      $self->{topEnt}->delete(0, 'end');
    }
    $can->delete('edit');
    foreach my $n (@{$self->{notes}}) {
      if ($n->{shbr} =~ /^[shbrv]{1}$/) {
	$can->delete("$n->{shbr}$n->{id}");
      }
      $n->{id} = '';
    }
  } else {
    $can->delete("bar$pidx");
  }
  $can->itemconfigure("bg$pidx", -fill => BLANK);
}

sub Clear {
  my($self) = shift;

  $self->unMap();
  $self->blank();
}
  
sub ClearEbar {
  my($tab) = shift;

  $EditBar->Clear();
  $EditBar->{pbar} = 0;
  $EditBar1->Clear();
  $EditBar1->{pbar} = 0;
  $tab->ClearSel();
}

sub ClearAndRedraw {
  my($tab) = shift;

  $tab->{eWin}->g_wm_withdraw();
  ClearEbar($tab);
  $tab->indexBars();
  $tab->newPage($tab->{pageNum});
}

# Clears the Edit Bars and redraws them.
# Usually done after a change to one of the size/distance parameters.
#sub remap {
#  my $sel = CP::Tab->get()->{select1};
#  ClearEbar();
#  $sel->select();
#  $sel->Edit();
#}

sub comp {
  my($self,$b) = @_;

  return(1) if ($b == 0);
  foreach my $i (qw/volta header rep justify/) {
    return(2) if ($self->{$i} ne $b->{$i});
  }
  foreach my $i (qw/newline newpage/) {
    return(3) if ($self->{$i} != $b->{$i});
  }
  return(4) if (@{$self->{notes}} != @{$b->{notes}});
  my $idx = 0;
  foreach my $n (@{$self->{notes}}) {
    return(5) if ($n->comp($b->{notes}[$idx++]));
  }
  0;
}
# This sub can be called in 2 ways:
# 1) Where we pass in a bar object that we want to display.
#    In this case we only pass in the bar object.
#    Currently ONLY for the EditBar.
# 2) Where we don't have a bar object but still want the bar outline.
#    In this case we pass in the tab object, page index and x/y values.
#    Currently ONLY for Page bar outlines.
#
sub outline {
  my($self) = shift;

  my($tab,$pidx,$X,$Y,$off,$tt,$thick,$thin,$can);
  if (ref($self) eq 'CP::Bar') {
    $tab = $self->{tab};
    ($pidx,$X,$Y,$off) = ($self->{pidx},$self->{x},$self->{y},$self->{offset});
    $can = $self->{canvas};
  } else {
    $tab = $self;
    $pidx = shift;
    $X = shift;
    $Y = shift;
    $off = $tab->{pOffset};
    $can = $tab->{pCan};
  }
  ($thick,$thin) = ($off->{thick},$off->{thin});
  my $w = $off->{width};
  my $ht = $thin / 2;
  my $x1 = my $x2 = $X;
  $x2 += $w;
  my $y1 = my $y2 = $Y;
  $y2 += ($off->{height} - $off->{lyricHeight});
  # Background rectangle for bg colour.
  if (($pidx % $Opt->{Nbar}) == 0 || $pidx == -1) {
    $x1 -= $thick;
    $x2 += $thick;
  } elsif (($pidx % $Opt->{Nbar}) == ($Opt->{Nbar} - 1)) {
    $x2 += $thick;
  }
  $can->create_rectangle($x1, $y1, $x2, $y2, -width => 0, -tags => "bg$pidx");

  my $fill = ($pidx == -1) ? BLACK : LGREY;
  my $tag = "b$pidx";
  # Staff Lines
  my $ss = $off->{staffSpace};
  $y1 = $Y + $off->{staffY};
  $x1 = $X + $thin;
  $x2 = $X + $w;
  foreach (1..$Nstring) {
    $can->create_line($x1, $y1, $x2, $y1, -width => $thin, -fill => $fill, -tags => $tag);
    $y1 += $ss;
  }
  # Bar Lines
  $x1 = $X + $off->{pos0};
  $y1 = $Y + $off->{staffY};
  $y2 = $Y + $off->{staff0};
  my $un = $off->{interval} * 8;
  my($t,$_t) = split('/', $tab->{Timing});
  foreach (1..$t) {
    vline($can, $x1, $y1, $y2, $ht, $fill, $tag);
    $x1 += $un;
  }

  $x1 = $X + ($thick / 2);
  # First thick vertical line at beginning of a row
  my @ft = ('-width', 0, '-fill', $fill, '-tags', $tag);
  if (($pidx % $Opt->{Nbar}) == 0 || $pidx == -1) {
    vline($can, $x1, $y1-$ht, $y2+$ht, $thick, $fill, $tag);
  }
  $x1 += ($w - $thick);
  # Thick line at the end of a bar
  vline($can, $x1, $y1-$ht, $y2+$ht, $thick, $fill, $tag);

  if ($pidx < 0) {
    markers($self);
  } else {
    # Detection rectangle to edit a Bar
    $can->create_rectangle(
      $X, $Y, $X + $w, $Y + $off->{lyricY},
      -width => 0,
      -fill => BLANK,
      -tags => "det$pidx", );
  }
}

#
# This should ONLY be called on the Edit Bars.
#
sub markers {
  my($self) = shift;

  #
  # Make tick marks at every (visible) demi-semi-quaver
  # position and detection rectangles at each position.
  #
  my($X,$Y,$off) = ($self->{x},$self->{y},$self->{offset});
  my $ns = $Nstring - 1;
  my $y = $Y + $off->{staff0};
  my $u = $off->{interval};
  my $hu = $u / 2;
  my $ss = $off->{staffSpace};
  my $hss = $ss / 2;
  my($t,$_t) = split('/', $self->{tab}{Timing});
  my $hsq = ($t * 8) - 1;
  my $can = $self->{canvas};
  my $fill = ($self->{pidx} == -1) ? BLACK : LGREY;
  my $tag = "b$self->{pidx}";
  my $det = "det$self->{pidx}";
  foreach my $str (0..$ns) {
    my $len = ($str == $ns) ? +5 : -5;
    my $x = $X + $off->{pos0};
    my $y1 = $y - $hss;
    my $y2 = $y + $hss;
    foreach my $pos (0..$hsq) {
      if (($pos % 8) != 0) {
	my $l = (($pos % 2) == 0) ? $len * 2 : $len;
	$can->create_line($x,$y, $x,$y+$l, -width => 1, -fill => $fill, -tags => $tag);
      }
      # Create and bind the detection rectangles
      $pos += $self->{tab}{BarEnd} if ($self->{pidx} == -2);
      my $a = $can->create_rectangle($x-$hu, $y1, $x+$hu, $y2, -width => 0, -tags => $det);
      $can->bind($a, "<Button-1>", sub{posSelect($self, $str, $pos)});
      $x += $u;
    }
    $y -= $ss;
  }
}

sub EditPrev { _pn('prev', @_) }
sub EditNext { _pn('next', @_) }

sub _pn {
  my($pn,$tab,$save) = @_;

  my $bar = $tab->{select1};
  if ($save) {
    Update();
    $tab->indexBars();
    $tab->newPage($tab->{pageNum});
  } else {
    if (($bar && comp($EditBar, $bar)) || ($bar == 0 && ! isblank($EditBar))) {
      my $ans = CP::Cmsg::msgYesNoCan("Save current Bar?");
      return if ($ans eq 'Cancel');
      Save() if ($ans eq 'Yes');
    }
  }
  if ($bar) {
    $bar = $bar->{$pn};
    if ($bar == 0 && $pn eq 'prev') {
      CP::Cmsg::message(SAD, "This is the first Bar.", 1);
      return;
    }
  }
  ClearEbar($tab);
  $bar->select() if ($bar);
  Edit($bar);
}

# This is ONLY called for the EditBar.
sub Background {
  my($self) = @_;

  if ((my $bg = bgGet($self)) ne '') {
    $self->{bg} = $bg;
    $self->{canvas}->itemconfigure("bg-1", -fill => $bg);
  }
}

sub bgGet {
  my($self) = shift;

  $self->{bg} = WHITE if ($self->{bg} eq '');
  CP::FgBgEd->new("Background Colour");
  my($fg,$bg) = $ColourEd->Show($self->{tab}{noteColor}, $self->{bg}, BACKGRND);
  $bg;
}

sub getNote {
  my($self,$id) = @_;

  foreach my $n (@{$self->{notes}}) {
    return($n) if ($n->{id} == $id);
  }
  return(0);
}

#
# Come here when one of the Edit Bar detection rectangles is clicked.
#
sub posSelect {
  my($self,$string,$pos) = @_;

  my $tab = $self->{tab};
  my $id = $tab->{selected};
  my $can = $self->{canvas};
  if ($id != 0) {
    my $n = getNote($self, $id);
    if ($n->{string} eq 'r') {
      $can->itemconfigure($id, -fill => BLACK);
      $n->move($string, $pos);
    }
    else {
      # We've already selected a fret so:
      #   End a BendRelease.
      # or
      #   Move a selected note to this position.
      if ($tab->{shbr} eq 'r') {
	if ($pos <= $n->{pos}) {
	  message(SAD, "Second point must be AFTER the original note position.",);
	}
	else {
	  $n->{shbr} = 'r';
	  $n->{bend} = 1;
	  if ($n->{bar} == $self) {
	    $n->{hold} = $pos - $n->{pos};
	  } else {
	    my $barEnd = (eval($tab->{Timing}) * 32) + 1;
	    $n->{hold} = ($barEnd - $n->{pos}) + ($pos - $barEnd);
	  }
	  $n->show('F');
	}
      }
      else {
	$can->itemconfigure($id, -fill => $tab->{noteColor});
	# {fret} stays the same ...
	$n->move($string, $pos);
      }
    }
    $self->deselect();
  } elsif ($tab->{fret} ne '') {
    # Place a fret number or rest on a string.
    my $n = CP::Note->new($EditBar, 1, '');
    if ($tab->{fret} =~ /r(\d+)/) {
      $n->{string} = 'r';
      $n->{fret} = $1;
      # Remove all frets from this position.
      my $idx = 0;
      while ($idx <= $#{$self->{notes}}) {
	if ($self->{notes}[$idx]{pos} == $pos) {
	  $self->{notes}[$idx]{id}->unmap();
	  splice(@{$self->{notes}}, $idx, 1);
	} else {
	  $idx++;
	}
      }
      $n->{pos} = $pos;
    } else {
      $n->{string} = $string;
      $n->{fret} = $tab->{fret};
      $n->{pos} = $pos;
      $n->{font} = $tab->{noteFsize};
    }
    $n->show('F');
    $self->noteSort($n);
  }
}

sub Edit {
  my($tab) = shift;

  my $bar = $tab->{select1};
  if ($bar) {
    if ($tab->{eWin}->g_wm_state() eq 'normal') {
      # We have a Bar being Edited and someone's selected a new Bar for editing.
      my $pbar = $EditBar->{pbar};
      if (($pbar && comp($EditBar, $pbar)) || ($pbar == 0 && ! isblank($EditBar))) {
	my $ans = CP::Cmsg::msgYesNoCan("Save current Bar?");
	if ($ans eq 'Cancel') {
	  $tab->ClearSel();
	  $pbar->select();
	  $tab->{select1} = $pbar;
	  return;
	}
	Save() if ($ans eq 'Yes');
      }
      $EditBar->Clear();
      $EditBar1->Clear();
    }
    copy($bar, $EditBar, ALLB);
    $EditBar->{pbar} = $bar;
    $EditBar->{prev} = $bar->{prev};
    if ($bar->{next} != 0) {
      $EditBar1->{pbar} = $bar->{next};
      copy($bar->{next}, $EditBar1, ALLB);
      $EditBar1->{next} = $bar->{next}{next};
    } else {
      $EditBar1->{next} = $EditBar1->{pbar} = 0;
    }
    $EditBar->{bidx} = $bar->{bidx};
  } else {
    $EditBar->{bidx} = ($tab->{bars}) ? $tab->{lastBar}{bidx} + 1 : 1;
  }
  $tab->{eWin}->g_wm_deiconify() if (Tkx::winfo_ismapped($tab->{eWin}) == 0);
  $tab->{eWin}->g_raise();
  show($EditBar);
  show($EditBar1);
}

sub InsertBefore { insert(shift,BEFORE); }
sub InsertAfter  { insert(shift,AFTER); }

# $self is actually $EditBar
sub insert {
  my($self,$where) = @_;

  my $tab = $self->{tab};
  if ($tab->{select1}) {
    $self->{pbar} = $tab->{select1};
    $self->save_bar($where);
    ClearAndRedraw($tab);
  } else {
    message(SAD, "No Bar selected - don't know where to put this one!", 1);
  }
}

sub Save {
  $EditBar1->save_bar(REPLACE) if ($EditBar1->{pbar} && comp($EditBar1, $EditBar1->{pbar}));
  $EditBar->save_bar(REPLACE) if (comp($EditBar, $EditBar->{pbar}));
  ClearAndRedraw($EditBar->{tab});
}

sub Update {
  if ($EditBar->{pbar}) {
    $EditBar1->save_bar(UPDATE) if ($EditBar1->{pbar} && comp($EditBar1, $EditBar1->{pbar}));
    $EditBar->save_bar(UPDATE) if (comp($EditBar, $EditBar->{pbar}));
  } else {
    # Editing a bar to tack on the end.
    $EditBar->save_bar(UPDATE);
#    message(SAD, "No Bar selected - don't know which bar to update!", 1);
  }
}

sub save_bar {
  my($self,$insert) = @_;

  my $tab = $self->{tab};
  my($bar);
  if ($self->{pbar} == 0) {
    # We've edited a (new) blank Bar.
    $bar = CP::Bar->new($tab);
    if ($tab->{bars} == 0) {
      $tab->{bars} = $bar;
    } else {
      $tab->{lastBar}{next} = $bar;
      $bar->{prev} = $tab->{lastBar};
    }
    $insert = REPLACE;
  } else {
    my $dest = $self->{pbar};
    if ($insert == BEFORE || $insert == AFTER) {
      $bar = CP::Bar->new($tab);
      if ($insert == AFTER) {
	$bar->{prev} = $dest;
	$bar->{next} = $dest->{next};
	$dest->{next}{prev} = $bar;
	$dest->{next} = $bar;
      } else {
	if ($dest->{prev} == 0) {
	  $bar->{next} = $dest;
	  $dest->{prev} = $bar;
	  $tab->{bars} = $bar;
	} else {
	  $bar->{prev} = $dest->{prev};
	  $bar->{next} = $dest;
	  $dest->{prev}{next} = $bar;
	  $dest->{prev} = $bar;
	}
      }
    } else {
      $bar = $dest;
    }
  }
  $tab->{lastBar} = $bar if ($bar->{next} == 0);
  foreach my $v (qw/newline newpage volta header justify rep bg/) {
    $bar->{$v} = $self->{$v};
  }
  $bar->{notes} = [];
  foreach my $n (noteSort($self)) {
    $n->{bar} = $bar;
    push(@{$bar->{notes}}, $n);
  }
  if ($insert == UPDATE) {
    $bar->unMap();
    $bar->show();
  }
  $tab->setEdited(1);
}

# ONLY called on the EditBar
sub RemoveBG {
  my($self) = shift;

  $self->{canvas}->itemconfigure("bg$self->{pidx}", -fill => BLANK);
  $self->{bg} = BLANK;
}

# ONLY called on the Page Bars
sub select {
  my($self) = shift;

  my $tab = $self->{tab};
  my $bg = $self->{bg};
  my $tag = "bg$self->{pidx}";
  my $can = $tab->{pCan};
  $can->g_bind('<KeyRelease>', sub{});
  if ($tab->{select1} == $self) {
    $can->itemconfigure($tag, -fill => $bg);
    $tab->{select1} = 0;
  } else {
    if ($tab->{select2} != 0) {
      $tab->ClearSel();
    }
    if ($tab->{select1} != 0) {
      $can->itemconfigure("bg$tab->{select1}{pidx}", -fill => $bg);
    }
    $can->itemconfigure($tag, -fill => SELECT);
    $MW->g_bind('<Key-Delete>', [\&checkDel, $tab]);
    $tab->{select1} = $self;
  }
  $tab->{select2} = 0;
}

sub deselect {
  my($self) = shift;

  my $tab = $self->{tab};
  my $id = $tab->{selected};
  if ($id != 0) {
    my $t = $tab->{eCan}->type($id);
    if ($t eq 'image') {
      my $rst = "r".getNote($self, $id)->{fret};
      $tab->{eCan}->itemconfigure($id, -image => "edit$rst");
    } else {
      $tab->{eCan}->itemconfigure($id, -fill => $tab->{noteColor});
    }
    $tab->{selected} = 0;
  }
}

sub checkDel {
  my($tab) = shift;

  if ($tab->{select1}) {
    $tab->DeleteBars();
  }
}

sub rangeSelect {
  my($self) = shift;

  my $tab = $self->{tab};
  $tab->{select2} = $self;
  my($a,$b) = $tab->diff();
  if ($a != 0) {
    my $can = $tab->{pCan};
    do {
      $can->itemconfigure("bg$a->{pidx}", -fill => SELECT);
      $a = $a->{next};
    } while ($a && $a->{prev} != $b);
  }
}

# Copy the visible components from one bar to another.
sub copy {
  my($self,$dst,$what) = @_;

  # VOLTA REPEAT HEAD JUST BBG NEWLP NOTE ALLB
  my @content = (qw/volta rep header justify bg newlp/);
  my $idx = 0;
  for(my $i = VOLTA; $i <= NEWLP; $i <<= 1) {
    if ($what & $i) {
      if ($i == NEWLP) {
	$dst->{newline} = $self->{newline};
	$dst->{newpage} = $self->{newpage};
      } else {
	my $c = $content[$idx];
	$dst->{$c} = $self->{$c};
      }
    }
    $idx++;
  }
  if ($what & NOTE) {
    $dst->{notes} = [];
    foreach my $n (noteSort($self)) {
      push(@{$dst->{notes}}, $n->copy($dst));
    }
  }
}

sub Cancel {
  my($self) = shift;

  my $tab = $self->{tab};
  ClearEbar($tab);
  $tab->ClearSel();
  $tab->{eWin}->g_wm_withdraw();
}

sub show {
  my($self) = shift;

  my $tab = $self->{tab};
  my $pidx = $self->{pidx};
  my $can = $self->{canvas};
  $can->itemconfigure("bg$pidx", -fill => $self->{bg});
  $can->lower("bg$pidx");
  volta($self);
  repeat($self);
  if ($pidx < 0) {
    if ($pidx == -1) {
      # Edit Bar.
      $can->delete('barn');
      $can->create_text(
	$tab->{editX} + 10, $tab->{editY} + 1,
	-text => "Bar #: $self->{bidx}",
	-font => $tab->{barnFont},
	-anchor => 'sw',
	-tags => 'barn');
      if ($self->{header} ne '') {
	entryUpdate($self->{topEnt}, $self->{header});
      }
      # Need to find if there's a Slide/Hammer/BendRelease at the end of the previous Bar.
      if (my $prev = $self->{prev}) {
	my $pn = $prev->{notes}[-1];
 	if (defined $pn) {
	  if ($pn->{shbr} =~ /s|h/) {
	    my $fn = $self->{notes}[0];
	    my $u = $self->{offset}{interval};
	    my $xlft = ($tab->{BarEnd} - $pn->{pos}) * $u;
	    my $xrht = (2 + $fn->{pos}) * $u;
	    my $xaxis = $xlft + $xrht;
	    if ($pn->{shbr} eq 's') {
	      my $ymid = ($xlft / $xaxis) * ($self->{offset}{staffSpace} * 0.4);
	      $fn->slideTail($fn->{fret}, $ymid, $tab->{headColor}, 'edit');
	    }
	    elsif ($pn->{shbr} eq 'h') {
	      $xaxis /= 2;
	      my $arc = $xaxis - $xrht;
	      my $mid = int(rad2deg(acos($arc/$xaxis)));
	      $fn->hammerTail($xaxis, $mid, $tab->{headColor}, 'edit');
	    }
	  }
	  elsif ($pn->{shbr} eq 'r' && ($pn->{pos} + $pn->{hold}) >= $tab->{BarEnd}) {
	    my $hold = $pn->{hold} - ($tab->{BarEnd} - 1 - $pn->{pos}) + 2;
	    my $arc = ($hold >= 3) ? 3 : 2;
	    $hold -= $arc;
	    my($x,$y) = $pn->noteXY();
	    $y -= ($prev->{offset}{staffSpace} * 1.2);
	    $y -= $prev->{y};
	    $pn->bendRelTail($self, $hold, $arc, $self->{x}, $y * $Opt->{EditScale}, 'edit');
	  }
	}
      }
    }
    else {
      topText($self);
    }
    foreach my $n (@{$self->{notes}}) {
      $n->show('F');
    }
  } else {
    my $tag = "det$pidx";
    if ($can->bind($tag) eq '') {
      my $sub = sub{$tab->ClearSel();$self->select();Edit($tab);};
      $can->itemconfigure("b$pidx", -fill => BLACK);
      $can->bind($tag, '<Button-1>', sub{$self->select()});
      $can->bind($tag, '<Shift-Button-1>', sub{$self->rangeSelect()});
      $can->bind($tag, '<Button-3>', $sub);
      # For Macs
      $can->bind($tag, '<Control-Button-1>', $sub);
    }
    # View Page.
    topText($self);
    my $btag = "bar$pidx";
    foreach my $n (@{$self->{notes}}) {
      $n->show($btag);
    }
    $can->raise($tag, $btag) if (@{$self->{notes}});
  }
}

sub entryUpdate {
  my($ent,$txt) = @_;

  $ent->delete(0, 'end');
  if ($txt ne '') {
    # Side effect is the text is displayed in the bar
    # because of the "validate" routine but we have to
    # do it one character at a time.
    foreach (split('', $txt)) {
      $ent->insert('end', "$_");
    }
  }
}

sub repeat {
  my($self) = shift;

  my $pidx = $self->{pidx};
  my $tag = [(($pidx < 0) ? 'topr' : 'bar').$pidx];
  my $can = $self->{canvas};
  $can->delete($tag) if ($pidx < 0);
  push(@{$tag}, 'edit') if ($pidx < 0);
  if ($self->{rep} ne 'None') {
    my $off = $self->{offset};

    my($X,$Y) = ($self->{x},$self->{y});
    my($thin,$thick,$fat) = ($off->{thin},$off->{thick},$off->{fat});
    # See outline() for x/y spacing.
    my $x = $X + $off->{staffX};
    my $ht = $thin / 2;
    my $y = $Y + $off->{staffY} - $ht;
    my $y2 = $Y + $off->{staff0} + $ht;

    my $clr = $self->{tab}{headColor};
    $clr = CP::FgBgEd::lighten($clr, PALE) if ($self->{pidx} == -2);

    my $dia = $fat * 2;
    my $dy = $fat * 0.75;
    my @ft = ('-width', 0, '-fill', $clr, '-tags', $tag);
    if ($self->{rep} eq 'Start') {
      vline($can, $x, $y, $y2, $fat+$thick+$thin, $clr, $tag);
      $x += $ht;
      vline($can, $x, $y+$thick, $y2-$thick, $thin, WHITE, $tag);

      $x += $thick;
      $y += ($off->{staffHeight} / 2);
      $can->create_oval($x, $y-$dy, $x+$dia, $y-$dy-$dia, @ft);
      $can->create_oval($x, $y+$dy, $x+$dia, $y+$dy+$dia, @ft);
    }
    elsif ($self->{rep} eq 'End') {
      $x += $off->{width};
      vline($can, $x, $y, $y2, $fat+$thick+$thin, $clr, $tag);
      $x -= $ht;
      vline($can, $x, $y+$thick, $y2-$thick, $thin, WHITE, $tag);
  
      $x -= ($thick + $ht);
      $y += ($off->{staffHeight} / 2);
      $can->create_oval($x, $y-$dy, $x-$dia, $y-$dy-$dia, @ft);
      $can->create_oval($x, $y+$dy, $x-$dia, $y+$dy+$dia, @ft);
    }
  }
}

sub vline {
  my($can,$x,$y1,$y2,$wid,$clr,$tag) = @_;

  $can->create_line($x, $y1, $x, $y2, -width => $wid, -fill => $clr, -tags => $tag);
}

sub topText {
  my($self) = shift;

  my $tab = $self->{tab};
  my $off = $self->{offset};
  my $pidx = $self->{pidx};
  my $can = $self->{canvas};
  my $tag = [(($pidx < 0) ? 'topt' : 'bar').$pidx];
  $can->delete($tag) if ($pidx < 0);
  push(@{$tag}, 'edit') if ($pidx < 0);
  if ($self->{header} ne '') {
    my $fnt = ($pidx >= 0) ? $tab->{headFont} : $tab->{eheadFont};
    my $x = $self->{x};
    my $clr = $tab->{headColor};
    $clr = CP::FgBgEd::lighten($clr, PALE) if ($pidx == -2);
    my $wid = $can->create_text(
      0,0,
      -text => $self->{header},
      -anchor => 'sw',
      -fill => $clr,
      -font => $fnt,
      -tags => $tag);
    if ($self->{justify} eq 'Right') {
      my($lx,$ly,$rx,$ry) = split(/ /, $can->bbox($wid));
      $x += ($off->{width} - ($rx + $off->{thick}));
    } else {
      $x += $off->{thick};
    }
    my $fh = ($pidx >= 0) ? $tab->{headSize} : $tab->{eheadSize};
    $can->coords($wid, $x, $self->{y} + $off->{headY});
  }
}

sub volta {
  my($self) = @_;

  my $can = $self->{canvas};
  my $off = $self->{offset};
  my $pidx = $self->{pidx};
  my $tag = [(($pidx < 0) ? 'topv' : 'bar').$pidx];
  $can->delete($tag) if ($pidx < 0);
  push(@{$tag}, 'edit') if ($pidx < 0);
  if ($self->{volta} ne 'None') {
    my $clr = $self->{tab}{headColor};
    $clr = CP::FgBgEd::lighten($clr, PALE) if ($pidx == -2);
    my $linew = $off->{fat};
    my $w = $off->{width};
    my $x = $self->{x} + $off->{staffX};
    my $y = $self->{y};
    my @ft = ('-width', 0, '-fill', $clr, '-tags', $tag);
    my $id = $can->create_rectangle($x, $y, $x+$w, $y+$linew, @ft);
    if ($self->{volta} ne 'Center') {
      my $y1 = $y + $off->{staffY} - ($off->{scale} * 3);
      if ($self->{volta} =~ /Left|Both/) {
	$id = $can->create_rectangle($x, $y, $x+$linew, $y1, @ft);
      }
      if ($self->{volta} =~ /Right|Both/) {
	$x += $w;
	$id = $can->create_rectangle($x, $y, $x-$linew, $y1, @ft);
      }
    }
  }
}

# Sort a {notes} array into position order. If more than 1
# note occupy the same position then sort by string number.
sub noteSort {
  my($self) = shift;

  push(@{$self->{notes}}, @_) if (@_);
  $self->{notes} = [sort {($a->{pos} == $b->{pos})? $a->{string} <=> $b->{string} : $a->{pos} <=> $b->{pos}} @{$self->{notes}}];
  @{$self->{notes}};
}

1;
