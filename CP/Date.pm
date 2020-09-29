package CP::Date;

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

use CP::Cconst qw/:TEXT :COLOUR/;
use CP::Global qw/:FUNC :WIN :OPT :XPM/;
use Tkx;
use POSIX;

our @Months = qw/January February March April May June July
                 August September October November December/;
our @MDcnt = qw/31 28 31 30 31 30 31 31 30 31 30 31/;
our @Days  = qw/Mon Tue Wed Thu Fri Sat Sun/;

our($Day,$Month,$Year);
our $Pt = 8;

sub new {
  my($proto,) = @_;

  my $class = ref($proto) || $proto;
  my ($_s,$n,$h,$d,$m,$y,$_w,$_r,$_i) = localtime(time);
  my $self = {
    year   => $y + 1900,
    month  => $m,
    months => $Months[$m],
    day    => $d,
    hour   => $h,
    minute => $n,
    time   => '',
    hours  => 24,
  };
  bless $self, $class;
  spTime($self);
  $self;
}

sub newDate {
  my($self,$var) = @_;

  if (defined $var && $var ne '') {
    my $ms;
    ($Day,$ms,$Year) = split(' ', $var);
    foreach my $i (0..11) {
      $Month = $i, last if ($ms eq $Months[$i]);
    }
  } else {
    ($Day,$Month,$Year) = ($self->{day},$self->{month},$self->{year});
  }
  my $done = '';

  my $f = Tkx::font_names();
  if ($f !~ / CalFont/) {
    my %list = (Tkx::SplitList(Tkx::font_actual("TkDefaultFont")));
    $list{'-weight'} = 'normal';
    $list{'-size'} = $Pt;
    Tkx::font_create("CalFont", %list);
    $list{'-weight'} = 'bold';
    Tkx::font_create("BCalFont", %list);
    $list{'-size'} -= 1;
    Tkx::font_create("SCalFont", %list);
  }
  foreach my $i (qw/dated dateu/) {
    makeImage($i, \%XPM);
  }

  my $pop = CP::Pop->new(0, '.nd', ' ',
			 Tkx::winfo_pointerx($MW) + 10,
			 Tkx::winfo_pointery($MW) - 10);
  return if ($pop eq '');
  my($top,$topF) = ($pop->{top}, $pop->{frame});

  my $botF = $topF->new_ttk__frame(-padding => 0);
  $botF->g_pack(qw/-side bottom -expand 1 -fill both/);

  $self->{canvas} = my $can = $topF->new_tk__canvas(
    -background => OWHITE,
    -relief => 'flat',
    -borderwidth => 0,
    -highlightthickness => 0,
    -selectborderwidth => 0,
      );
  $can->g_pack(qw/-side top -expand 0 -fill both/);

  my $id = $can->create_text(0, 0, -text => "Wed", -font => 'SCalFont');
  my($x1,$y1,$x2,$y2) = split(/ /, $can->bbox($id));
  $self->{cellW} = $x2 - $x1;
  $can->delete($id);
  $can->configure(-width => (INDENT + ($self->{cellW} * 7) + INDENT));
  redraw($self);

  my $cancel = $botF->new_ttk__button(-text => "Cancel", -command => sub{$done = "Cancel";});
  $cancel->g_pack(qw/-side left -padx 8 -pady 4/);

  my $ok = $botF->new_ttk__button(-text => "OK", -command => sub{$done = "OK";});
  $ok->g_pack(qw/-side right -padx 8 -pady 4/);

  $top->g_wm_deiconify();
  $top->g_raise();
  Tkx::vwait(\$done);

  $pop->popDestroy();
  if ($done eq 'OK') {
    ($self->{day},$self->{month},$self->{months},$self->{year}) = ($Day,$Month,$Months[$Month],$Year);
    return(1);
  }
  return(0);
}

sub redraw {
  my($self) = shift;

  my $can = $self->{canvas};
  $can->delete('all');

  my $y = $Pt;
  my $cellW = $self->{cellW};
  my $width = INDENT + ($cellW * 7) + INDENT;
  my $halfW = $cellW / 2;

  my $id = $can->create_text(0, 0, -text => "September", -font => 'SCalFont');
  my($x1,$y1,$x2,$y2) = split(/ /, $can->bbox($id));
  $can->delete($id);
  my $butind = (($width - ($x2 - $x1)) / 2);

  my $byl = $can->create_image($butind - 13, $y, -image => 'dated');
  $can->bind($byl, '<Button-1>', sub{$Year--; redraw($self);});
  $can->create_text($width / 2, $y,
		    -text => $Year, -font => 'CalFont');
  my $byr = $can->create_image($width - $butind + 13, $y, -image => 'dateu');
  $can->bind($byr, '<Button-1>', sub{$Year++; redraw($self);});

  $y += ($Pt * 2);

  my $bml = $can->create_image($butind - 13, $y, -image => 'dated');
  $can->bind($bml, '<Button-1>', sub{$Month--;
				     $Year-- if ($Month < 0);
				     $Month %= 12;
				     redraw($self);});
  $can->create_text($width / 2, $y,
		    -text => $Months[$Month], -font => 'CalFont');
  my $bmr = $can->create_image($width - $butind + 13, $y, -image => 'dateu');
  $can->bind($bmr, '<Button-1>', sub{$Month++;
				     $Year++ if ($Month == 12);
				     $Month %= 12;
				     $Day = $MDcnt[$Month] if ($Day > $MDcnt[$Month]);
				     redraw($self);});
  $y += ($Pt * 2.5);

  my $x = INDENT + $halfW;
  foreach my $wd (@Days) {
    $can->create_text($x, $y, -text => $wd, -font => 'SCalFont');
    $x += $cellW;
  }

  $y += $Pt;

  my $dow = firstDay($Year);            # Day of the week.
  for(my $m = 0; $m != $Month; $m++) {
    $dow += $MDcnt[$m];
    $dow %= 7;
  }
  my $rows = POSIX::ceil(($dow + $MDcnt[$Month]) / 7);
  $y1 = $y + ($cellW * $rows);
  $can->create_rectangle(INDENT, $y, INDENT + ($cellW * 7), $y1);
  my $strtY = $y + $halfW;
  $x = 5 + $cellW;
  foreach my $vl (0..5) {
    $can->create_line($x, $y, $x, $y1);
    $x += $cellW;
  }
  $x = INDENT;
  $y += $cellW;
  foreach my $hl (2..$rows) {
    $can->create_line($x, $y, $x + ($cellW * 7), $y);
    $y += $cellW;
  }
  my $strtX = $x = INDENT + $halfW + ($dow * $cellW);
  $y = $strtY;
  $width -= INDENT;
  my $dw = $halfW - 2;
  foreach my $d (1..$MDcnt[$Month]) {
    $can->create_rectangle($x - $dw + 1, $y - $dw + 1, $x + $dw, $y + $dw,
			   -width => 0, -tags => "d$d");
    my $tid = $can->create_text($x, $y, -text => $d, -font => 'BCalFont');
    $can->bind($tid, '<Button-1>', sub{$can->itemconfigure("d$Day", -fill => LGREY);
				       $can->itemconfigure("d$d", -fill => SELECT);
				       $Day = $d});
    $x += $cellW;
    if ($x > $width && $d != $MDcnt[$Month]) {
      $x = INDENT + $halfW;
      $y += $cellW;
    }
  }
  $can->configure(-height => ($y + $halfW + INDENT));
  $can->itemconfigure("d$Day", -fill => SELECT);
}

# The computation assumes Saturday is day 0
# hence our adjustment to make Monday day 0
sub firstDay {
  my($year) = shift;

  $MDcnt[1] = 28;
  $year--;
  my $day = (35 + $year + int($year/4) - int($year/100) + int($year/400) + 2) % 7;
  $day -= 2;
  $day += 5 if ($day < 0);

  $year++;
  my $leap = ($year % 4) ? 0 : ($year % 100) ? 1 : ($year % 400) ? 0 : 1;
  $MDcnt[1]++ if ($leap);

  $day;
}

my $Pressed = 0;

sub newTime {
  my($self,$var) = @_;

  if (defined $var && $var ne '') {
    $self->{time} = $var;
    ($self->{hour},$self->{minute}) = split(':',$var);
  }
  my $done = '';
  spTime($self);
  my $f = Tkx::font_names();
  if ($f !~ / TimeFont/) {
    my %list = (Tkx::SplitList(Tkx::font_actual("TkDefaultFont")));
    $list{'-size'} -= 2;
    Tkx::font_create("STimeFont", %list);
    $list{'-weight'} = 'bold';
    $list{'-size'} = $Pt * 2;
    Tkx::font_create("TimeFont", %list);
  }
  foreach my $i (qw/timeu timed/) {
    makeImage($i, \%XPM);
  }

  Tkx::ttk__style_configure('NoBd.TButton',
			    -background => $Opt->{WinBG},
			    -relief => 'flat',
			    -borderwidth => 0,);

  my $pop = CP::Pop->new(0, '.nt', ' ',
			 Tkx::winfo_pointerx($MW) + 10,
			 Tkx::winfo_pointery($MW) - 10);
  return if ($pop eq '');
  my($top,$topF) = ($pop->{top}, $pop->{frame});

  my $hup = $topF->new_ttk__button(-image => "timeu",
				   -style => 'NoBd.TButton',
				   -command => [\&hourUD, $self, 1]);
  $hup->g_grid(qw/-row 0 -column 0 -sticky e -pady 0/, -padx => [4,0]);
      
  my $hdn = $topF->new_ttk__button(-image => "timed",
				   -style => 'NoBd.TButton',
				   -command => [\&hourUD, $self, -1]);
  $hdn->g_grid(qw/-row 1 -column 0 -sticky e -pady 0/, -padx => [4,0]);

  my $lab = $topF->new_ttk__label(-font => 'TimeFont',
				  -width => 5,
				  -anchor => 'center',
				  -textvariable => \$self->{time});
  $lab->g_grid(qw/-row 0 -column 1 -rowspan 2 -padx 8 -pady 4/);

  my $mup = $topF->new_ttk__button(-image => "timeu",
				   -style => 'NoBd.TButton');
  $mup->g_grid(qw/-row 0 -column 2 -sticky w -padx 0 -pady 0/);
  $mup->g_bind('<ButtonPress-1>', sub{$Pressed = 750; minUp($self)});
  $mup->g_bind('<ButtonRelease-1>', sub{$Pressed = 0;});

  my $mdn = $topF->new_ttk__button(-image => "timed",
				   -style => 'NoBd.TButton');
  $mdn->g_grid(qw/-row 1 -column 2 -sticky w -padx 0 -pady 0/);
  $mdn->g_bind('<ButtonPress-1>', sub{$Pressed = 750; minDown($self)});
  $mdn->g_bind('<ButtonRelease-1>', sub{$Pressed = 0;});

  my $hourF = $topF->new_ttk__frame(-padding => 0);
  $hourF->g_grid(qw/-row 2 -column 0 -columnspan 3/);
  my $a = $hourF->new_ttk__radiobutton(-text => "12hour",
				       -variable => \$self->{hours},
				       -value => 12,
				       -command => [\&hourUD, $self, 0]);
  $a->g_pack(qw/-side left/, -padx => [0,8]);
  my $b = $hourF->new_ttk__radiobutton(-text => "24hour",
				       -variable => \$self->{hours},
				       -value => 24);
  $b->g_pack(qw/-side right/);

  my $ok = $topF->new_ttk__button(-text => "OK",
				  -width => 5,
				  -command => sub{$done = "OK";});
  $ok->g_grid(qw/-row 0 -column 3 -rowspan 2 -pady 0/, -padx =>[16,4]);

  my $cancel = $topF->new_ttk__button(-text => "Cancel",
				      -width => 7,
				      -command => sub{$done = "Cancel";});
  $cancel->g_grid(qw/-row 2 -column 3 -pady 0/, -padx =>[16,4]);

  $top->g_wm_deiconify();
  $top->g_raise();
  Tkx::vwait(\$done);

  $pop->popDestroy();
  return(($done eq 'OK') ? 1 : 0);
}

sub hourUD {
  my($self,$incr) = @_;

  $self->{hour} += $incr;
  $self->{hour} %= $self->{hours};
  spTime($self);
}

sub minUp {
  my($self) = shift;

  if ($Pressed) {
    $self->{minute}++;
    if ($self->{minute} >= 60) {
      $self->{hour}++;
      $self->{hour} %= $self->{hours};
    }
    $self->{minute} %= 60;
    spTime($self);
    Tkx::after($Pressed, [\&minUp, $self]);
    $Pressed = 80 if ($Pressed);
  }
}

sub minDown {
  my($self) = shift;


  if ($Pressed) {
    $self->{minute}--;
    if ($self->{minute} < 0) {
      $self->{hour}--;
      $self->{hour} %= $self->{hours};
    }
    $self->{minute} %= 60;
    spTime($self);
    Tkx::after($Pressed, [\&minDown, $self]);
    $Pressed = 80 if ($Pressed);
  }
}

sub spTime {
  my($self) = shift;

  $self->{time} = sprintf "%02d:%02d", $self->{hour}, $self->{minute};
}

1;
