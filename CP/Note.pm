package CP::Note;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

use strict;

use CP::Cconst qw/:COLOUR :TAB :SMILIE/;
use CP::Global qw/:WIN :OPT :CHORD/;
use CP::Tab;
use CP::Cmsg;
use Math::Trig;

##  s = Slide (up or down)   1(5,8s7,12)  fret at which interval to slide to
##  h = Hammer (up or down)  3(3,0h5,1)   fret at which interval to hammer/pull
##                                        If interval is >= 33 it's in the next Bar

# A Note is defined by the string that is played, the
# fret number and it's interval (timing) within the bar.
# A Note can be a single or compound entity defined by the {shbr} key.
# Compound entities include:
#
#  s = Slide (up or down)   1(5,8s)
#  h = Hammer (up or down)  3(3,0h)
#  - = End of Slide/Hammer  CP::Note     {shbr} contains a pointer to the start note
#                                        2nd/3rd parameters
#  b = Bend                 4(7,0b1)     ammount of bend in semitones
#  r = Bend/Release         4(7,0r1,8)   ammount of bend and length of hold
#-TBD-
#  v = Vibrato              2(5,12v24)   length of vibrato
#
# The fret number may be preceeded with an 'f' in which
# case it will be displayed in a smaller font.
#
# A note can also be a Rest in which case the "string" will be the letter 'r'.
# The values inside () become (duration,interval) where duration is one of:
# 1 1/2 1/4 1/8 1/16 or 1/32
#
# The text Tab file has strings starting at 1 (low E on a 6 string guitar) but
# internally, strings start at 0.
#
# How we handle Notes - specifically Slide/Hammer/Bend/Release:
#  **** THIS IS NOW WRONG ****
#  The second Note exists as a separate object but is linked into the starting Note.
#  If the starting Note tries a 'delete' operation,
#  the ending Note is made into a stand-alone object and the connecting bar/arc is
#  deleted. What are now 2 separate objects can now be manipulated individually.
#  When a Slide/Hammer is created, the end object is deleted and incorporated
#  into the start object.
#
sub new {
  my($proto,$bar,$string,$def) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;
  $self->{bar} = $bar;
  $self->{font} = 'Normal';
  $self->{fret} = $self->{pos} = $self->{to} = 0;
  $self->{shbr} = '';
  $self->{id} = '';           # Only used in the EditBars.
  if ($string =~ /r/i) {
    # Got a rest.
    $self->{string} = 'r';
    if ($def =~ /([\d\/]+),(\d+)/) {
      $self->{pos} = $2;
      ($self->{fret} = $1) =~ s/1\///;
    }
  } else {
    # This only happens where we are reading in a Tab file.
    $self->{string} = $string;
    if ($def =~ /(f)?([-]?[X\d]+),(\d+)([bhrsv])?(\d+)?,?([-]?\d+)?/) {
      $self->{font} = 'Small' if ($1 eq 'f');
      $self->{fret} = $2;
      $self->{pos} = ($3 % $Opt->{BarEnd});
      if (defined $4) {
	$self->{shbr} = lc($4);
	my $p5 = $5;
	my $p6 = $6;
	# Slide and Hammer depend on the following Note being on the same string.
	# If it's not, then it has the {shbr} reset - this is done at display time.
	if ($self->{shbr} eq 'b') {
	  $self->{bend} = (defined $p5) ? $p5 : 1;
	} elsif ($self->{shbr} =~ /r|v/) {
	  $self->{bend} = $p5;
	  $self->{hold} = $p6;
	}
      }
    }
  }
  return($self);
}

sub printnote {
  my($n,$str) = @_;

  print $str if (defined $str);
  printf "  pidx=%03d  ", $n->{bar}{pidx};
  if ($n->{string} =~ /r/i) {
    printf "  str=%s", $n->{string};
  } else {
    printf "  str=%d", $n->{string};
  }
  printf "  fret=%02d pos=%02d shbr=", $n->{fret}, $n->{pos};
  if (ref($n->{shbr}) eq 'CP::Note') {
    print "bar($n->{bar}{pidx})";
  } else {
    print "'$n->{shbr}'";
  }
  print "\n";
}

# Produce an exact copy of a Note.
sub clone {
  my($self) = shift;

  my $n = CP::Note->new(0, 0, '');
  foreach my $k (keys %{$self}) {
    $n->{$k} = $self->{$k};
  }
  $n;
}

# Copy everything except the canvas ID and adjust the {bar} entry.
sub copy {
  my($self,$bar) = @_;

  my $nn = clone($self);
  $nn->{bar} = $bar;
  $nn->{id} = '';
  $nn;
}

sub comp {
  my($self,$n) = @_;

  return(1) if ($self->{string} != $n->{string});
  return(2) if ($self->{fret} != $n->{fret});
  return(3) if ($self->{pos} != $n->{pos});
  if ($self->{shbr} ne $n->{shbr}) {
    # These won't be the same if they are the end of a
    # slide/hammer but they will both be a Note reference.
    return((ref($self->{shbr}) eq 'CP::Note' && ref($n->{shbr}) eq 'CP::Note') ? 0 : 1);
  }
  return(0);
}

# Come here when an existing Note is clicked.
sub select {
  my($self) = shift;

  my $id = $Tab->{selected};
  my $can = $self->{bar}{canvas};
  if ($id == 0) {
    if ($Tab->{shbr} =~ /b|s|h/) {
      if ($Tab->{shbr} eq 'b') {
	$self->{shbr} = 'b';
	$self->{bend} = 1;
	show($self, 'F');
      }
      else {
	my $nx = $self->next();
	if (defined $nx) {
	  if ($nx->{string} != $self->{string}) {
	    message(SAD, "Fret positions MUST be on the same string!");
	    $can->itemconfigure($id, -fill => $Tab->{noteColor});
	    $Tab->{selected} = 0;
	    $Tab->{shbr} = '';
	  }
	  else {
	    $self->unmap();
	    # This has to be AFTER the unmap.
	    $self->{shbr} = $Tab->{shbr};
	    show($self, 'F');
	  }
	}
	else {
	  message(SAD, "Could not find another Fret position\nin this or the following Bar.");
	}
      }
    }
    else {
      $can->itemconfigure($self->{id}, -fill => RED);
      $Tab->{selected} = $self->{id};
    }
  }
  else {
    my $clr = ($self->{string} eq 'r') ? BLACK : $Tab->{noteColor};
    $can->itemconfigure($id, -fill => $clr);
    $Tab->{selected} = 0;
    if ($id != $self->{id}) {
      $can->itemconfigure($self->{id}, -fill => RED);
      $Tab->{selected} = $self->{id};
    }
  }
}

# Does nothing to the note but removes
# all trace from the Canvas.
sub unmap {
  my($self) = shift;

  my $id = $self->{id};
  my $can = $self->{bar}{canvas};
  $can->delete("e$id");
  $self->{id} = '';
  $Tab->{selected} = 0;
}

sub delFromBar {
  my($self) = shift;

  my $idx = 0;
  foreach my $n (@{$self->{bar}{notes}}) {
    if ($n == $self) {
      return(splice(@{$self->{bar}{notes}}, $idx, 1));
    }
    $idx++;
  }
  return(undef);
}

sub remove {
  my($self) = shift;

  unmap($self);
  if ($self->{shbr} =~ /^[shbrv]{1}$/) {
    $self->next()->{shbr} = '' if ($self->{shbr} =~ /[sh]{1}/);
    $self->{shbr} = '';
    $self->{bend} = 0;
    show($self, 'F');
  } else {
    if (ref($self->{shbr}) eq 'CP::Note') {
      my $pn = $self->{shbr};
      $pn->{shbr} = '';
      $pn->{bend} = 0;
      show($pn, 'F');
    }
    delFromBar($self);
  }
}

sub move {
  my($self,$string,$pos) = @_;

  unmap($self);
  if ($self->{shbr} =~ /s|h/) {
    my $sdiff = $string - $self->{string};
    my $pdiff = $pos - $self->{pos};
    $self->{string} = $string;
    $self->{pos} = $pos;
    my $nn = $self->next();
    unmap($nn);
    $nn->{string} += $sdiff;
    $nn->{pos} += $pdiff;
    if ($self->{bar} == $nn->{bar} && $nn->{pos} >= $Opt->{BarEnd}) {
      # We've moved the end-point into the next Bar.
      $nn->{pos} -= $Opt->{BarEnd};
      $nn = delFromBar($nn);
      $nn->{bar} = $EditBar1;
      $EditBar1->noteSort($nn);
    } elsif ($self->{bar} != $nn->{bar} && $nn->{pos} < 0) {
      # We've moved the end-point into our Bar
      $nn->{pos} += $Opt->{BarEnd};
      $nn = delFromBar($nn);
      $nn->{bar} = $EditBar;
      $EditBar->noteSort($nn);
    }
    show($nn, 'F');
  } elsif (ref($self->{shbr}) eq 'CP::Note') {
    # This is the end note of a Slide/Hammer therefore
    # we force the move to stay on the same string.
    if ($pos >= $Opt->{BarEnd}) {
      $pos -= $Opt->{BarEnd};
      if ($self->{bar} == $EditBar) {
	$self->{bar} = $EditBar1;
	delFromBar($self);
      }
    }
    $self->{pos} = $pos;
    my $pn = $self->{shbr};
    unmap($pn);
    show($pn);
  } else {
    $self->{string} = $string if ($self->{string} ne 'r');
    $self->{pos} = $pos;
  }
  show($self, 'F');
}

#
# Show a fret position on the Page or Edit bar.
#
sub show {
  my($self,$tag) = @_;

  if ($self->{id} ne '') {
    $self->unmap();
  }
  my $bar  = $self->{bar};
  my $can  = $bar->{canvas};
  my $pidx = $bar->{pidx};
  my $off  = $bar->{offset};
  my($x,$y) = $self->noteXY();
  my($id,$fnt,$clr);
  my $hh = $off->{staffHeight} / 2;
  my $ss = $off->{staffSpace};
  if ($self->{string} eq 'r') {
    # Rest
    my $num = $self->{fret};
    my $yadd = ($num == 1) ? $ss : ($num == 2) ? $ss * 2 : $hh;
    $fnt = ($pidx < 0) ? $Tab->{esymFont} : $Tab->{symFont};
    $y = $bar->{y} + $off->{staffY} + $yadd;
    my $fill = ($pidx == -2) ? LGREY : BLACK;
    if ($pidx < 0) {
      $tag = [$tag, 'edit'];
    }
    $id = $can->create_text(
      $x,$y,
      -text => chr(64+$num),
      -font => $fnt,
      -fill => $fill,
      -tags => $tag);
  } else {
    $id = showFret($self, $x, $y, $self->{fret}, $tag);
  }
  if ($pidx < 0) {
    $tag = ["e$id", 'edit'];
    $can->itemconfigure($id, -tags => $tag);
  }
  if ($pidx < 0) {
    # {id} is only set for EditBar notes.
    $self->{id} = $id;
    if ($pidx == -1) {
      $can->bind($id, "<Button-1>", sub{$self->select()});
      $can->bind($id, "<Button-3>", sub{$self->remove()});
      # For Macs
      $can->bind($id, "<Control-Button-1>", sub{$self->remove()});
    }
  }
  if ($self->{shbr} =~ /^[shbrv]{1}$/) {
    if ($self->{shbr} =~ /s|h/) {
      slideHam($self, $fnt, $tag);
    } elsif ($self->{shbr} =~ /b|r/) {
      bendRel($self, $fnt, $tag);
    }
  }
  $Tab->{shbr} = '';
}

sub slideHam {
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
  my($x,$y) = my($x1,$y1) = $self->noteXY();
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

sub slideTail {
  my($self,$lfret,$ymid,$clr,$tag) = @_;

  my $off = $self->{bar}{offset};
  my($x1,$y1) = $self->noteXY();
  my $x = $self->{bar}{x};
  $y1 -= ($off->{staffSpace} * 0.6);
  my $y;
  if ($self->{fret} > $lfret) {
    $y = $y1 - $ymid;
    $y1 -= ($off->{staffSpace} * 0.4);
  }
  else {
    $y = $y1 - ($off->{staffSpace} * 0.4) + $ymid;
  }
  $self->{bar}{canvas}->create_line($x, $y, $x1, $y1,
				    -fill  => $clr, -width => $off->{fat},
				    -tags => $tag);
}

sub hammerTail {
  my($self,$xaxis,$mid,$clr,$tag) = @_;

  my $off = $self->{bar}{offset};
  my($x1,$y) = $self->noteXY();
  my $x = $x1 - ($xaxis * 2);
  my $y1 = $y - ($off->{staffSpace} * 1.2);
  $self->{bar}{canvas}->create_arc($x, $y, $x1, $y1,
				   -start => 0, -extent => $mid,
				   -style => 'arc', -outline => $clr,
				   -width => $off->{fat}, -tags => $tag);
}

sub bendRel {
  my($self,$fnt,$tag) = @_;

  my $bar = my $nb = $self->{bar};
  my $can = $bar->{canvas};
  my $off = $bar->{offset};
  my $fat = $off->{fat};
  my $u = $off->{interval};
  my $ss = $off->{staffSpace};
  my($x,$y) = $self->noteXY();
  my $clr = $Tab->{headColor};
  $clr = CP::FgBgEd::lighten($clr, 80) if ($bar->{pidx} == -2);

  if ($self->{shbr} eq 'b') {
    $can->create_arc($x - ($u * 2.5), $y - ($ss * 0.6), $x + ($u * 2), $y - ($ss * 1.8),
		     -start => 270,
		     -style => 'arc', -outline => $clr,
		     -width => $fat,  -tags    => $tag);
  }
  else {
    # We always do this as two halves, even when the Release
    # is in the same Bar as the Bend - makes the logic easier.
    my $hold = $self->{hold};
    my $arc1 = my $arc2 = ($hold > 6) ? 3 : $hold / 2;
    if ($self->{pos} == ($Opt->{BarEnd} - 1)) {
      $arc1 = 2;
    }
    if (($self->{pos} + $hold) >= $Opt->{BarEnd}) {
      if (($self->{pos} + $hold) == $Opt->{BarEnd}) {
	$arc2 = 2;
      }
      $hold += 4;
    }
    my $line = $hold - ($arc1 + $arc2);
    $y -= ($ss * 0.6);
    my $y1 = $y - ($ss * 1.2);
    my $x1 = $x + ($arc1 * $u);
    $x -= ($arc1 * $u);
    $can->create_arc($x, $y, $x1, $y1,
		     -start => 270,
		     -style => 'arc', -outline => $clr,
		     -width => $fat,  -tags    => $tag);
    $x = $x1;
    $y -= ($ss * 0.6);
    if (($self->{pos} + $hold) >= $Opt->{BarEnd}) {
      $line -= ($Opt->{BarEnd} - 1 - $self->{pos});
      $x1 = $bar->{x} + $off->{width};
    }
    else {
      $line /= 2;
      $x1 = $x + ($line * $u);
    }
    $can->create_rectangle($x, $y, $x1, $y + $fat,
			   -width => 0, -fill => $clr, -tags => $tag);

    $y1 = $y - $bar->{y};
    if ($x1 == ($bar->{x} + $off->{width})) {
      # Crosses a Bar boundary.
      return if ($bar == $EditBar1);
      $bar = $bar->{next};
      $x1 = $bar->{x};
    }
    if ($bar) {
      bendRelTail($self,$bar,$line,$arc2,$x1,$y1,$tag);
    }
  }
}

sub bendRelTail {
  my($self,$bar,$hold,$arc,$xoff,$yoff,$tag) = @_;

  my $clr = $Tab->{headColor};
  $clr = CP::FgBgEd::lighten($clr, 80) if ($bar->{pidx} == -2);
  my $off = $bar->{offset};
  my $fat = $off->{fat};
  $arc  *= $off->{interval};
  $hold *= $off->{interval};
  my $ss = $off->{staffSpace};
  my($x,$x1,$y);
  $x1 = $xoff + $hold;
  $y = $bar->{y} + $yoff;
  if ($hold) {
    $bar->{canvas}->create_rectangle($xoff, $y, $x1, $y + $fat,
				     -width => 0, -fill => $clr, -tags => $tag);
  }
  $xoff = $x1 - $arc;
  $x1 += $arc;
  $yoff = $y + ($ss * 1.2);
  $bar->{canvas}->create_arc($xoff, $y + ($fat / 2), $x1, $yoff,
			     -start => 0,     -extent  => 90,
			     -style => 'arc', -outline => $clr,
			     -width => $fat,  -tags    => $tag);
  $clr = $Tab->{noteColor};
  $clr = CP::FgBgEd::lighten($clr, 80) if ($bar->{pidx} == -2);
  my $fnt = ($bar->{pidx} >= 0) ? $Tab->{snoteFont} : $Tab->{esnoteFont};
  $bar->{canvas}->create_text($x1,$yoff,
			      -text => $self->{fret},  -font => $fnt,
			      -fill => $clr, -tags => $tag);
}

sub prev {
  my($self,$bar) = @_;

  $bar = $self->{bar} if (! defined $bar);
  my $n = undef;
  my $idx = 0;
  # Find ourself in the list.
  foreach my $sn (@{$bar->{notes}}) {
    $n = $sn, last if (comp($self, $sn) == 0);
    $idx++;
  }
  if ($idx == 0) {
    # Prev should be in the previous bar.
    my $pbar = $bar->{prev};
    if ($pbar != 0) {
      $n = $pbar->{notes}[-1];
    }
  }
  else {
    $n = $bar->{notes}[--$idx];
  }
  return($n);
}

sub next {
  my($self,$bar) = @_;

  $bar = $self->{bar} if (! defined $bar);
  my $n = undef;
  my $idx = 0;
  # Find our position in the array.
  foreach my $sn (@{$bar->{notes}}) {
    $n = $sn, last if (comp($self, $sn) == 0);
    $idx++;
  }
  if ($idx >= $#{$bar->{notes}}) {
    # Next should be in the next bar.
    my $nbar = $bar->{next};
    if ($nbar != 0) {
      $n = $nbar->{notes}[0];
    }
  }
  else {
    $idx++;
    $n = $bar->{notes}[$idx];
  }
  return($n);
}

# Just shows a fret number at the specified position.
sub showFret {
  my($self,$x,$y,$fr,$tag) = @_;

  my($fnt,$clr);
  my $bar = $self->{bar};
  if ($bar->{pidx} >= 0) {
    $fnt = ($self->{font} eq 'Normal' && $fr < 10) ? $Tab->{noteFont} : $Tab->{snoteFont};
#    $fnt = $Tab->{noteFont};
  } else {
    $fnt = ($self->{font} eq 'Normal' && $fr < 10) ? $Tab->{enoteFont} : $Tab->{esnoteFont};
#    $fnt = $Tab->{enoteFont};
  }
  if ($fr eq 'X') {
    $fnt = $Tab->newFont($fnt, 0.8);
    $clr = BLACK;
  } else {
    if ($fr < 0) {
      $clr = RED;
      $fr = abs($fr);
    } else {
      $clr = ($self->{font} eq 'Normal') ? $Tab->{noteColor} : $Tab->{snoteColor};
    }
  }
  $clr = CP::FgBgEd::lighten($clr, 80) if ($bar->{pidx} == -2);
  $tag = [$tag, 'edit'] if ($bar->{pidx} < 0);
#  if ($fr > 9) {
#    my $img = cNote($fr, $fnt, $clr, ($bar->{pidx} >= 0) ? 'n' : 'N');
#    $bar->{canvas}->create_image($x, $y, -image => $img, -tags => $tag); 
#  } else {
    $bar->{canvas}->create_text($x,$y, -text => $fr,  -font => $fnt,
				       -fill => $clr, -tags => $tag);
#  }
}

sub noteXY {
  my($self) = shift;

  my $bar = $self->{bar};
  my $off = $bar->{offset};
  my $y = $bar->{y} + $off->{staff0} - ($off->{staffSpace} * $self->{string});
  my $x = $bar->{x} + $off->{pos0} + ($off->{interval} * $self->{pos});
  ($x,$y);
}

#
# All this just to get a Condensed font!!!
# The PDF code does it in a single call!!
#
Tkx::package_require('img::window');
our $Nmw = 0;
our $Ncan;
our %Imgs;

sub cNote {
  my($fr,$fnt,$clr,$tag) = @_;

  my $nimg = "$tag$fr";
  if (! defined $Imgs{$nimg}) {
    my $h = ($fnt eq $Tab->{enoteFont}) ? $Tab->{enoteSize} : $Tab->{noteSize};
    my $w = Tkx::font_measure($fnt, $fr);
    if ($Nmw == 0) {
      $Nmw = $MW->new_toplevel();
      $Nmw->g_wm_overrideredirect(1);
      $Nmw->g_wm_geometry("$w"."x$h+0+0");
      $Ncan = $Nmw->new_tk__canvas(-height => $h, -width => $w,
				   -background => WHITE,
				   -highlightthickness => 0,
				   -borderwidth => 0,
				   -selectborderwidth => 0);
      $Ncan->g_pack(qw/-expand 0 -fill both/);
    } else {
      $Nmw->g_wm_geometry("$w"."x$h+0+0");
      $Ncan->delete('all');
      $Ncan->itemconfigure(-height => $h, -width => $w);
    }
    $Nmw->g_wm_deiconify();
    $Nmw->g_raise();
    $Ncan->g_focus();
    my $id = $Ncan->create_text($w / 2, $h / 2, -text => $fr,  -font => $fnt, -fill => $clr);
    Tkx::update_idletasks();

    my $img = Tkx::image_create_photo('tmp', -data => $Nmw, -format => 'WINDOW');
    $h = Tkx::image_height($img);
    $w = Tkx::image_width($img);

    no strict 'refs';
    my $subr = 'Tkx::'.$img.'_get';
    my $trans = 'Tkx::'.$img.'_transparency_set';
    for my $y (0..$h-1) {
      for my $x (0..$w-1) {
	my($r,$g,$b) = split(/ /, &$subr($x,$y));
	if ($r == 255 && $g == 255 && $b == 255) {
	  &$trans($x, $y, 1);
	}
      }
    }
    my $nimg = Tkx::image_create_photo($nimg, -height => $h, -width => $w / 2);
    $subr = 'Tkx::'.$nimg.'_copy';
    &$subr($img, -subsample => (2, 1));
    $subr = 'Tkx::'.$nimg.'_redither';
    &$subr();
    Tkx::image_delete('tmp');
    $Imgs{$nimg} = $nimg;
#    $Nmw->g_wm_withdraw();
  }
  $nimg;
}

1;
