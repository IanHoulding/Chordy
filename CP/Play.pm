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
my @Bars = ();
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

# 5 String Bass tuning: B E A D G
my @baseNotes = (qw/30.868 41.203 55 73.416 97.999/);

my $BarIdx = 0;
my $Beat = 0;

my $BpChan = 16;
my $Nchan = 1;

my $Paused = 0;

my $AfterID = 0;

sub play {
  return if (OS ne 'win32');
  if (! $Paused && ! defined $WAV) {
    newWav();
    my $fst = ($Tab->{select1}) ? $Tab->{select1} : $Tab->{bars};
    my $lst = ($Tab->{select2}) ? $Tab->{select2} : $Tab->{lastBar};
    @Bars = ();
    %Note = ();
    makeNotes($fst, $lst);
    $BarIdx = 0;
    $Beat = 0;
    note();
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

  $WAV->Load($Note{$idx});
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
  $AfterID = Tkx::after(int(7500/$Tab->{tempo}), \&note); # Same as: 600000/($Tab->{tempo}*8)
  if ($Tab->{play} == PLAY || $Tab->{play} == LOOP || $Tab->{play} == MET) {
    my $ticks = eval($Tab->{Timing}) * 32;
    $Paused = 0 if ($Paused);
    if ($BarIdx == @Bars) {
      if ($Tab->{play} == LOOP) {
	$BarIdx = 0;
      } else {
	stop();
	return;
      }
    }
    my $iv = $Bars[$BarIdx];
    if (defined $iv->{$Beat} && $Tab->{play} != MET) {
      resetWav();
      my $idx = $iv->{$Beat};
      if ($idx ne 'r') {
	load($idx);
      }
    }
    if (($Beat % 8) == 0) {
      #
      # Draw the vertical red "beat" bar.
      #
      my $bar = $iv->{bar};
      if ($bar->{pnum} != $Tab->{pageNum}) {
	$Tab->newPage($bar->{pnum});
      }
      my($can,$X,$Y,$off) = ($bar->{canvas},$bar->{x},$bar->{y},$bar->{offset});
      my $ly = $Y + $off->{staffY} - 4;
      my $y2 = $Y + $off->{staff0} + 4;
      my $lx = $X + $off->{pos0} + ($off->{interval} * $Beat);
      $can->delete('beat');
      $can->create_line($lx, $ly, $lx, $y2,
			-width => 2, -fill => RED, -tags => 'beat');
      if ($Tab->{play} == MET) {
	resetWav();
	$WAV->Load($Tick);
	$WAV->Write();
      }
    }
    if (++$Beat == $ticks) {
      $Beat = 0;
      $BarIdx++;
    }
  } elsif ($Tab->{play} == STOP) {
    stop();
    return;
  } elsif ($Tab->{play} == PAUSE) {
    pause() if ($Paused == 0);
    $Paused++;
  }
}

sub stop {
  Tkx::after_cancel($AfterID) if ($AfterID);
  my $can = $Bars[0]->{bar}{canvas};
  $can->delete('beat') if (defined $can);
  $Tab->ClearSel();
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
  my($first,$last) = @_;

  my $time = setRate() * 2;  # how long we want a note to last
  my $two12 = 2 ** (1/12);
  for(my $bar = $first; $bar != 0; $bar = $bar->{next}) {
    my $IV = {};
    $IV->{bar} = $bar;
    foreach my $nt (@{$bar->{notes}}) {
      my $str = $nt->{string};
      my $int = $nt->{pos};
      my $frt = $nt->{fret};
      next if ($frt eq 'X');
      if ($str eq 'r') {
	$IV->{$int} = 'r';
      } else {
	#
	##### ONLY DONE FOR BASSes AT THE MO'
	#
	$str += 1 if ($Opt->{Instrument} eq 'Bass4');
SH:	my $n = "$str.$frt";
	$IV->{$int} = "$n";
	if (!defined $Note{$n}) {
	  $Note{$n} = '';
	  my($c1,$c2,$c3) = (0,0,0);
	  # formula for any given note is:
	  #   fn = f0 * (a)^n
	  # where:
	  #   fn = the frequency of the note n frets away from f0.
	  #   f0 = the frequency of one fixed note (usually the open sting).
	  #   a = (2)^1/12 = the twelth root of 2 = 1.059463094359...
	  #   n  = the number of frets away from the fixed note you are.
	  my $f0 = $baseNotes[$str];
	  my $fn = ($frt > 0) ? ($f0 * ($two12 ** $frt)) : $f0 ;
	  my $i1 = $fn / RATE;
	  my $i2 = $i1 * 2; #($fn * 2) / RATE;     # 2nd harmonic
	  my $i3 = $i1 * 3; #($fn * 3) / RATE;     # 3rd harmonic
	  my $vol = 32766;
	  for my $i (reverse 1..$time) { # Generate $time samples
	    # Calculate the pitch
	    # (range 0..255 for 8 bits)
	    my $v1 = sin($c1*6.28) * $vol;
	    my $v2 = sin($c2*6.28) * $vol; # 2nd harmonic
	    my $v3 = sin($c3*6.28) * ($vol/2); # 3rd harmonic
	    my $v = int(($v1 + $v2 + $v3) * 0.4); # 0.4 = 1 / (1 + 1 + 0.5)
	    # "pack" it
	    $Note{$n} .= pack("s", $v);
	    $c1 += $i1;
	    $c2 += $i2;
	    $c3 += $i3;
	    $vol -= ($vol * (1.5 / $i));
	  } # end for
	} # end if (!defined $Note{$n})
      } # end elsif ($frt ne 'X')
    }
    push(@Bars, $IV);
    last if ($bar == $last);
  }
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
  my($fr) = shift;

  my $frt = $fr->new_ttk__frame();
  $frt->g_pack(qw/-side top/);

  my $frb = $fr->new_ttk__frame();
  $frb->g_pack(qw/-side top/);

  my $lb = $frt->new_ttk__label(-text => 'Tempo: ');
  $lb->g_grid(qw/-row 0 -column 0 -sticky e/);

  my $sc;
  my $trc = sprintf("#%02x0000", $Tab->{tempo} + 55);
  $sc = $frt->new_tk__scale(
    -variable => \$Tab->{tempo},
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
      $trc = sprintf("#%02x0000", $Tab->{tempo} + 55);
      $sc->m_configure(-troughcolor => $trc);
      $Tab->pageTempo();
      main::setEdited(1) if ($Tab->{loaded});});
  $sc->g_grid(qw/-row 0 -column 1/);

  makeImage("stop", \%CNTRL);
  my $st = $frb->new_ttk__button(
    -image => 'stop',
    -command => sub{$Tab->{play} = STOP});
  $st->g_grid(qw/-row 0 -column 0 -padx 4 -pady 4/);

  makeImage("play", \%CNTRL);
  my $pl = $frb->new_ttk__button(
    -image => 'play',
    -command => sub{$Tab->{play} = PLAY; CP::Play::play();});
  $pl->g_grid(qw/-row 0 -column 1 -padx 4 -pady 4/);

  makeImage("pause", \%CNTRL);
  my $pa = $frb->new_ttk__button(
    -image => 'pause',
    -command => sub{$Tab->{play} = PAUSE});
  $pa->g_grid(qw/-row 0 -column 2 -padx 4 -pady 4/);

  makeImage("loop", \%CNTRL);
  my $pp = $frb->new_ttk__button(
    -image => 'loop',
    -command => sub{$Tab->{play} = LOOP; CP::Play::play();});
  $pp->g_grid(qw/-row 0 -column 3 -padx 4 -pady 4/);

  makeImage("metronome", \%CNTRL);
  my $pm = $frb->new_ttk__button(
    -image => 'metronome',
    -command => sub{$Tab->{play} = MET; CP::Play::play();});
  $pm->g_grid(qw/-row 0 -column 4 -padx 5 -pady 4/);

  my $bsl = $frb->new_ttk__label(-text => "Damping:");
  my $bsm = $frb->new_ttk__button(
    -textvariable => \$Damp,
    -style => 'Menu.TButton',
    -width => 3,
    -command => sub{popMenu(\$Damp, sub{}, [qw/0 1 2 3 4/]);
    });
  $bsl->g_grid(qw/-row 0 -column 5 -padx 4 -pady 4/);
  $bsm->g_grid(qw/-row 0 -column 6 -padx 0 -pady 4/);
}

1;
