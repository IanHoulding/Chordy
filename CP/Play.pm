package CP::Play;

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

use CP::Cconst qw/:OS :COLOUR :TAB :PLAY/;
use CP::Global qw/:FUNC :WIN :OPT/;

BEGIN {
  my $os = Tkx::tk_windowingsystem();
  if ($os eq 'win32') {
    require Win32::Sound;
  } elsif ($os eq 'aqua') {
  }
}

use CP::Pop qw/:MENU/;
use CP::Tab;
use CP::Bar;

use Time::HiRes qw(usleep);

my $Damp = 0;
my $Crate = '1/64';
my @Bars = ();
my %PrePack = ();
my %Note = ();
my $WAV = undef;

my $Tick = '';
foreach my $tick (qw/-0.02573 0.09296 -0.14412 -0.10788 0.41505 0.14239 -0.78552 -0.16894 1.00000
		  0.23279 -0.94127 -0.34776 0.88395 0.06776 -0.44626 0.18490 -0.05709 0.25090
		  0.12904 0.41834 -0.12845 -0.28892 0.12337 -0.05322 -0.10887 0.08143 0.28843
		  0.00267 -0.35518 -0.03203 0.22992 0.01731 -0.02241 -0.09759 -0.13836 0.25675
		  0.15917 -0.29398 -0.19234 0.31417 0.16480 -0.17135 -0.17291 -0.03234 0.05648
		  0.22214 0.08178 -0.24230 -0.07503 0.14135 0.00356 -0.20740 0.16615 0.14745
		  -0.11161/) {
  $Tick .= pack("s", $tick);
}

my $baseNotes = {
  Banjo    => [],
  Bass4    => [qw/41.203 55 73.416 97.999/],
  Bass5    => [qw/30.868 41.203 55 73.416 97.999/],
  Guitar   => [qw/82.406 110 146.832 195.998 246.944 329.624/],
  Mandolin => [],
  Ukelele  => [],  
};

my $BarIdx = 0;
my $Beat = 0;

my $BpChan = 16;
my $Nchan = 1;
my $Two12 = 2 ** (1/12);

my $Paused = 0;

my $AfterID = 0;

sub play {
  my($tab) = shift;

  return if (OS ne 'win32');
  if (! $Paused && ! defined $WAV) {
    newWav();
    my $fst = ($tab->{select1}) ? $tab->{select1} : $tab->{bars};
    my $lst = ($tab->{select2}) ? $tab->{select2} : $tab->{lastBar};
    @Bars = ();
    %Note = ();
    makeNotes($tab, $fst, $lst);
    $BarIdx = 0;
    $Beat = 0;
    note($tab);
  }
}

sub newWav {
  $WAV = new Win32::Sound::WaveOut(RATE, $BpChan, $Nchan);
}

sub pause {
  $WAV->Pause();
}

sub resetWav {
  $WAV->Pause();
  $WAV->Reset();
}

sub load {
  my($idx) = shift;

  $WAV->Load($idx);
  $WAV->Write();
}

sub unload {
  $WAV->Unload();
  $WAV->CloseDevice();
}

sub setRate {
  ($Damp) ? (RATE / ($Damp * 2)) : RATE;
}

sub note {
  my($tab) = shift;

  $AfterID = Tkx::after(int(7500/$tab->{tempo}), [\&note, $tab]); # Same as: 600000/($tab->{tempo}*8)
  if ($tab->{play} == PLAY || $tab->{play} == LOOP || $tab->{play} == MET) {
    my $ticks = eval($tab->{Timing}) * 32;
    $Paused = 0 if ($Paused);
    if ($BarIdx == @Bars) {
      if ($tab->{play} == LOOP) {
	$BarIdx = 0;
      } else {
	stop($tab);
	return;
      }
    }
    my $iv = $Bars[$BarIdx];
    if (defined $iv->{pos}[$Beat] && $tab->{play} != MET) {
      resetWav();
      my $idx = $iv->{pos}[$Beat][0];
      if (defined $idx && $idx ne 'REST') {
	load($idx);
      }
    }
    if (($Beat % 8) == 0) {
      #
      # Draw the vertical red "beat" bar.
      #
      my $bar = $iv->{bar};
      if ($bar->{pnum} != $tab->{pageNum}) {
	$tab->newPage($bar->{pnum});
      }
      my($can,$X,$Y,$off) = ($bar->{canvas},$bar->{x},$bar->{y},$bar->{offset});
      my $ly = $Y + $off->{staffY} - 4;
      my $y2 = $Y + $off->{staff0} + 4;
      my $lx = $X + $off->{pos0} + ($off->{interval} * $Beat);
      $can->delete('beat');
      $can->create_line($lx, $ly, $lx, $y2,
			-width => 2, -fill => RED, -tags => 'beat');
      if ($tab->{play} == MET) {
	resetWav();
	load($Tick);
      }
    }
    if (++$Beat == $ticks) {
      $Beat = 0;
      $BarIdx++;
    }
  } elsif ($tab->{play} == STOP) {
    stop($tab);
    return;
  } elsif ($tab->{play} == PAUSE) {
    pause() if ($Paused == 0);
    $Paused++;
  }
}

sub stop {
  my($tab) = shift;

  Tkx::after_cancel($AfterID) if ($AfterID);
  my $can = $Bars[0]->{bar}{canvas};
  $can->delete('beat') if (defined $can);
  $tab->ClearSel();
  if (OS eq 'win32') {
    resetWav();
    unload();
  } elsif (OS eq 'aqua') {
  }
  $WAV = undef;
  @Bars = ();
  %Note = ();
}

sub makeNotes {
  my($tab,$first,$last) = @_;

  my $time = setRate() * 2;  # how long we want a note to last
  #
  # First pass creates all the individual notes
  #
  for(my $bar = $first; $bar != 0; $bar = $bar->{next}) {
    my $iv = {};
    $iv->{pos} = [];
    $iv->{bar} = $bar;
    foreach my $nt (@{$bar->{notes}}) {
      my $str = $nt->{string};
      my $pos = $nt->{pos};
      my $frt = $nt->{fret};
      next if ($frt eq 'X');
      if ($str == REST) {
	$iv->{pos}[$pos][0] = 'REST';
      } else {
	my $n = "$str.$frt";
	push(@{$iv->{pos}[$pos]}, "$n");
	if (!defined $Note{$n}) {
	  my $note = oneNote($str, $frt, $time);
	  $PrePack{$n} = $note;
	  $Note{$n} = pack('s'.@{$note}, @{$note});
	}
      }
    }
    push(@Bars, $iv);
    last if ($bar == $last);
  }
  #
  # Second pass detects any multiple notes and
  # amalgamates them into a single chord
  #
  my $ticks = (eval($tab->{Timing}) * 32) - 1;
  foreach my $iv (@Bars) {
    my $pos = $iv->{pos};
    foreach my $t (0..$ticks) {
      if (defined $pos->[$t]) {
	if (@{$pos->[$t]} > 1) {
	  my @n = ();
	  my $off = 12;
	  foreach my $strfrt (@{$pos->[$t]}) {
	    my($str,$frt) = split(/\./, $strfrt);
	    $off = $str if ($str < $off);
	  }
	  # Sample rate is RATE samples/second.
	  # Each beat duration is (60 / $tab->{tempo}) seconds.
	  # Each 'tick' is 1/8 of this (there are 8 ticks per beat).
	  # So each tick is:  60 / ($tab->{tempo} * 8) seconds long.
	  # Multiple RATE by this and we get the samples/tick.
	  my $delay = RATE * (60 / $tab->{tempo}) * eval($Crate);
	  foreach my $strfrt (@{$pos->[$t]}) {
	    my($str,$frt) = split(/\./, $strfrt);
	    $str -= $off;
	    my $idx = $str * $delay;
	    foreach my $pp (@{$PrePack{$strfrt}}) {
	      $n[$idx++] += $pp;
	    }
	  }
	  my $cnt = @{$pos->[$t]};
	  foreach (0..$#n) {
	    $n[$_] = int($n[$_] / $cnt) if (defined $n[$_]);
	  }
	  $pos->[$t][0] = pack('s'.@n, @n);
	} else {
	  $pos->[$t][0] = $Note{$pos->[$t][0]};
	}
      }
    }
  }
}

sub oneNote {
  my($str,$frt,$time) = @_;

  my $note = [];
  my($c1,$c2,$c3) = (0,0,0);
  # formula for any given note is:
  #   fn = f0 * (a)^n
  # where:
  #   fn = the frequency of the note n frets away from f0.
  #   f0 = the frequency of one fixed note (usually the open sting).
  #   a = (2)^1/12 = the twelth root of 2 = 1.059463094359...
  #   n  = the number of frets away from the fixed note you are.
  my $f0 = $baseNotes->{$Opt->{Instrument}}[$str];
  my $fn = ($frt > 0) ? ($f0 * ($Two12 ** $frt)) : $f0 ;
  my $i1 = $fn / RATE;
  my $i2 = $i1 * 2;     # 2nd harmonic
  my $i3 = $i1 * 3;     # 3rd harmonic
  my $vol = 32766;
  for my $i (reverse 1..$time) { # Generate $time samples
    # Calculate the pitch
    # (range 0..255 for 8 bits)
#    my $v1 = sin($c1 * 6.28) * $vol;
#    my $v2 = sin($c2 * 6.28) * $vol;     # 2nd harmonic
    my $v1 = (sin($c1 * 6.28) + sin($c2 * 6.28)) * $vol;
    my $v3 = sin($c3 * 6.28) * ($vol/2); # 3rd harmonic
    push(@{$note}, int(($v1 + $v3) * 0.4)); # 0.4 = 1 / (1 + 1 + 0.5)
    $c1 += $i1;
    $c2 += $i2;
    $c3 += $i3;
    $vol -= ($vol * (1.5 / $i));
  }
  $note;
}

my %CNTRL;

$CNTRL{'play'} = <<'EOXPM';
/* XPM */
static char *play[] = {
"18 18 3 1",
"  c None",
"x c #600060",
"c c #90c0c0",
"                  ",
"  c               ",
"  xc              ",
"  xxxc            ",
"  xxxxxc          ",
"  xxxxxxxc        ",
"  xxxxxxxxxc      ",
"  xxxxxxxxxxxc    ",
"  xxxxxxxxxxxxxc  ",
"  xxxxxxxxxxxxxc  ",
"  xxxxxxxxxxxc    ",
"  xxxxxxxxxc      ",
"  xxxxxxxc        ",
"  xxxxxc          ",
"  xxxc            ",
"  xc              ",
"  c               ",
"                  "};
EOXPM

$CNTRL{'pause'} = <<'EOXPM';
/* XPM */
static char *pause[] = {
"18 18 2 1",
"  c None",
"x c #600060",
"                  ",
"                  ",
"   xxxx    xxxx   ",
"   xxxx    xxxx   ",
"   xxxx    xxxx   ",
"   xxxx    xxxx   ",
"   xxxx    xxxx   ",
"   xxxx    xxxx   ",
"   xxxx    xxxx   ",
"   xxxx    xxxx   ",
"   xxxx    xxxx   ",
"   xxxx    xxxx   ",
"   xxxx    xxxx   ",
"   xxxx    xxxx   ",
"   xxxx    xxxx   ",
"   xxxx    xxxx   ",
"                  ",
"                  "};
EOXPM

$CNTRL{'stop'} = <<'EOXPM';
/* XPM */
static char *stop[] = {
"18 18 2 1",
"  c None",
"x c #600060",
"                  ",
"                  ",
"                  ",
"   xxxxxxxxxxxx   ",
"   xxxxxxxxxxxx   ",
"   xxxxxxxxxxxx   ",
"   xxxxxxxxxxxx   ",
"   xxxxxxxxxxxx   ",
"   xxxxxxxxxxxx   ",
"   xxxxxxxxxxxx   ",
"   xxxxxxxxxxxx   ",
"   xxxxxxxxxxxx   ",
"   xxxxxxxxxxxx   ",
"   xxxxxxxxxxxx   ",
"   xxxxxxxxxxxx   ",
"                  ",
"                  ",
"                  "};
EOXPM

$CNTRL{'loop'} = <<'EOXPM';
/* XPM */
static char *loop[] = {
"18 18 3 1",
"  c None",
"x c #600060",
"c c #90c0c0",
"             c    ",
"             xc   ",
"             xxc  ",
"   cxxxxxxxxxxxxc ",
"  cxxxxxxxxxxxxxxc",
"  xxxxxxxxxxxxxxc ",
"  xxxc       xxc  ",
"  xxxc       xc   ",
"              c   ",
"    c             ",
"   cx       cxxx  ",
"  cxx       cxxx  ",
" cxxxxxxxxxxxxxx  ",
"cxxxxxxxxxxxxxxc  ",
" cxxxxxxxxxxxxc   ",
"  cxx             ",
"   cx             ",
"    c             "};
EOXPM

$CNTRL{'metronome'} = <<'EOXPM';
/* XPM */
static char * metronome_xpm[] = {
"18 18 17 1",
"  c None",
". c #090C08",
"+ c #2B332F",
"@ c #4E5652",
"# c #74653B",
"$ c #8E6327",
"% c #6C7572",
"& c #98712C",
"* c #83775B",
"= c #a09050",
"- c #D8A860",
"; c #859190",
"> c #F97913",
", c #FF7C10",
"' c #9EA8A7",
") c #FFAA11",
"! c #E4C649",
"     -&&&&&-      ",
"     =======      ",
"    ;;%@@@%%      ",
"    ;;%...%%%     ",
"    ';%+++%%%  =- ",
"    ';%+++%%% =-  ",
"    ';%+++%%%,,   ",
"    ';%+++%%=,,   ",
"   '';%+++%=-=    ",
"   ';;%+++=-@%    ",
"   ';;%++=-%%%    ",
"   ';;%+=-%;;%%   ",
"  '';;%=-+%;;;%   ",
"  $$$$=-$$$$$$=   ",
"  =-&&&&&&&&&$$   ",
"  --&&&&&&&&&$$   ",
"  --&&&&&&&&&&$   ",
"   @+++++++++@    "};
EOXPM

sub pagePlay {
  my($tab,$fr) = @_;

  my $frt = $fr->new_ttk__frame();
  $frt->g_pack(qw/-side top/);

  my $frb = $fr->new_ttk__frame();
  $frb->g_pack(qw/-side top/);

  my $lb = $frt->new_ttk__label(-text => 'Tempo: ');
  $lb->g_grid(qw/-row 0 -column 0 -sticky e/);

  my $sc;
  my $trc = sprintf("#%02x0000", $tab->{tempo} + 55);
  $sc = $frt->new_tk__scale(
    -variable => \$tab->{tempo},
    -fg => DRED,
    -from => 40,
    -to => 200,
    -tickinterval => 40,
    -borderwidth => 0,
    -resolution => 1,
    -showvalue => 1,
    -length  => '6c',
    -orient  => 'horizontal',
    -bg => MWBG,
    -troughcolor => $trc,
    -command => sub {
      $trc = sprintf("#%02x0000", $tab->{tempo} + 55);
      $sc->m_configure(-troughcolor => $trc);
      $tab->pageTempo();
      $tab->setEdited(1) if ($tab->{loaded});});
  $sc->g_grid(qw/-row 0 -column 1/);

  makeImage("stop", \%CNTRL);
  my $st = $frb->new_ttk__button(
    -image => 'stop',
    -command => sub{$tab->{play} = STOP});
  $st->g_grid(qw/-row 0 -column 0 -padx 4 -pady 4/);

  makeImage("play", \%CNTRL);
  my $pl = $frb->new_ttk__button(
    -image => 'play',
    -command => sub{$tab->{play} = PLAY; play($tab);});
  $pl->g_grid(qw/-row 0 -column 1 -padx 4 -pady 4/);

  makeImage("pause", \%CNTRL);
  my $pa = $frb->new_ttk__button(
    -image => 'pause',
    -command => sub{$tab->{play} = PAUSE});
  $pa->g_grid(qw/-row 0 -column 2 -padx 4 -pady 4/);

  makeImage("loop", \%CNTRL);
  my $pp = $frb->new_ttk__button(
    -image => 'loop',
    -command => sub{$tab->{play} = LOOP; play($tab);});
  $pp->g_grid(qw/-row 0 -column 3 -padx 4 -pady 4/);

  makeImage("metronome", \%CNTRL);
  my $pm = $frb->new_ttk__button(
    -image => 'metronome',
    -command => sub{$tab->{play} = MET; play($tab);});
  $pm->g_grid(qw/-row 0 -column 4 -padx 5 -pady 4/);

  my $bsl = $frb->new_ttk__label(-text => "Damping:");
  my $bsm = popButton($frb,
		      \$Damp,
		      sub{},
		      [qw/0 1 2 3 4/],
		      -width => 3,
		      -style => 'Menu.TButton',
      );
  $bsl->g_grid(qw/-row 0 -column 5 -padx 4 -pady 4/);
  $bsm->g_grid(qw/-row 0 -column 6 -padx 0 -pady 4/);

  my $crl = $frb->new_ttk__label(-text => "Chord Rate:");
  my $bcr = popButton($frb,
		      \$Crate,
		      sub{},
		      ['1', '1/2', '1/4', '1/8', '1/16', '1/32', '1/64', '0'],
		      -width => 4,
		      -style => 'Menu.TButton',
      );
  $crl->g_grid(qw/-row 1 -column 5 -padx 4 -pady 4/);
  $bcr->g_grid(qw/-row 1 -column 6 -padx 0 -pady 4/);
}

1;
