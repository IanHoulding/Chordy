package CP::Pop;

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

use Tkx;
use CP::Global qw(:WIN :FUNC :OPT :XPM);

BEGIN {
  our @ISA = qw(Exporter);
  our @EXPORT_OK = qw/pop popExists popDestroy popButton popBmenu balloon/;
  our %EXPORT_TAGS = (
    POP  => [qw/pop popExists popDestroy/],
    MENU => [qw/popButton popBmenu balloon/]);
  require Exporter;
}

our %Pops;  # Keeps track of all active/available pop-ups
            # via their toplevel path names.

sub new {
  my($proto,$ov,$path,$title,$x,$y,$icon) = @_;
  my $class = ref($proto) || $proto;

  my $self = {};
  bless $self, $class;

  if (popExists($path)) {
    Tkx::bell();
    $Pops{$path}->{top}->g_focus();
    return('');
  }
  $Pops{$path} = $self;
  $self->{path} = $path;
  my $top = $self->{top} = $MW->new_toplevel(-name => $path);
  $top->g_wm_withdraw();
  if ($ov) {
    $top->g_wm_overrideredirect(1);
  } else {
    if (defined $icon) {
      makeImage($icon, \%XPM);
    } else {
      $icon = (defined $Images{Ticon}) ? 'Ticon' : (defined $Images{Cicon}) ? 'Cicon' : 'Eicon';
    }
    $top->g_wm_iconphoto($icon);
    $top->g_wm_title($title) if ($title ne '');
    $top->g_wm_protocol('WM_DELETE_WINDOW' => sub{$self->popDestroy()});
  }

  $self->{frame} = $top->new_ttk__frame(
    -relief => 'raised',
    -borderwidth => 2,
    -padding => [4,4,4,4]);
  $self->{frame}->g_pack(qw/-side top -expand 1 -fill both/);

  if (! defined $x) {
    $x = Tkx::winfo_pointerx($MW);
    $y = Tkx::winfo_pointery($MW);
  } elsif ($x < 0) {
    $x = Tkx::winfo_rootx($MW) + 10;
    $y = Tkx::winfo_rooty($MW) + 5;
  }
  $x = 0 if ($x < 0);
  $y = 0 if ($y < 0);
  Tkx::update_idletasks();
  $top->g_wm_geometry("+$x+$y");
  $top->g_wm_deiconify();
  $top->g_raise();
  $self;
}

sub pop {
  my($path) = shift;

  return((! defined $Pops{$path}) ? '' : $Pops{$path});
}

sub popDestroy {
  my($self) = shift;

  $self->{top}->g_destroy();
  $Pops{$self->{path}} = '';
}

sub popExists {
  my($path) = shift;

  return((! defined $Pops{$path} || $Pops{$path} eq '') ? 0 : $Pops{$path});
}

sub popButton {
  my($frm,$var,$subr,$list,@opts) = @_;

  my $func = sub{popBmenu($var,$subr,$list)};
  my $but = $frm->new_ttk__button(-textvariable => $var, -command => $func, @opts);
#  $but->g_bind('<Enter>', $func);
  return($but);
}

sub popBmenu {
  my($var,$subr,$listptr) = @_;
  
  Tkx::update();
  return if (Tkx::winfo_exists('.pb'));
  my($x,$y) = (Tkx::winfo_pointerx($MW), Tkx::winfo_pointery($MW));
  my $list = (ref($listptr) eq 'ARRAY') ? $listptr : &$listptr;
  
  my $pop = $MW->new_toplevel(-name => '.pb', -background => '');
  $pop->g_wm_withdraw(); 
  $pop->g_wm_overrideredirect(1);

  my $fr = $pop->new_ttk__frame(-style => 'PopMenu.TFrame',
				-relief => 'ridge',
				-borderwidth => 1,
				-padding => [1,2,1,2]);
  $fr->g_pack();

  my $len = 0;
  foreach my $l (@{$list}) {
    my $x = length($l);
    $len = $x if ($x > $len);
  }
  $len += 1;
  foreach my $l (@{$list}) {
    if ($l eq 'SeP') {
      my $hl = $fr->new_ttk__separator(-orient => 'horizontal');
      $hl->g_pack(qw/-fill x/);
    } else {
      my $but = $fr->new_ttk__button(-text => $l,
				     -width => $len,
				     -style => 'PopMenu.TButton',
				     -command => sub{$$var = $l;
						     &$subr;
						     $pop->g_destroy();});
      $but->g_pack();
    }
  }

  Tkx::update(); # So the winfo_req's work.
  my($w,$h) = (Tkx::winfo_reqwidth($fr), Tkx::winfo_reqheight($fr));

  my $bg = $pop->new_ttk__frame(-style => 'PopShad.TFrame', -width => $w - 2, -height => $h - 2);
  $fr->g_place(qw/-x 0 -y 0/);
  $bg->g_place(qw/-x 6 -y 6/);
  $fr->g_raise();

  $x -= int($w / 2);
  $y -= int($h / 3);
  $w += 4;
  $h += 4;
  $pop->g_wm_geometry($w."x$h+$x+$y"); 
  Tkx::after(100, sub{where($pop,$x,$y,$w,$h)});
  $pop->g_wm_deiconify(); 
  $pop->g_raise(); 
}

sub where {
  my($pop,$Px,$Py,$Pw,$Ph) = @_;

  if (Tkx::winfo_exists('.pb')) {
    my($x,$y) = (Tkx::winfo_pointerx($MW), Tkx::winfo_pointery($MW));
    if ($x < $Px || $x >= ($Px + $Pw) || $y < $Py || $y >= ($Py + $Ph)) {
      $pop->g_destroy();
    } else {
      Tkx::after(100, sub{where($pop,$Px,$Py,$Pw,$Ph)});
    }
  }
}

sub balloon {
  my($wid,$text) = @_;

  CORE::state $Ball = '';
  $wid->g_bind(
    '<Enter>',
    sub {
      if ($Ball eq '') {
	$Ball = $MW->new_toplevel();
	$Ball->g_wm_overrideredirect(1);
	my $x = Tkx::winfo_pointerx($MW) + 10;
	my $y = Tkx::winfo_pointery($MW) - 30;
	$Ball->g_wm_geometry("+$x+$y");
	($Ball->new_ttk__label(-text => $text, -style => 'YN.TLabel'))->g_pack();
	Tkx::update_idletasks();
	$Ball->g_raise();
	Tkx::after(1000, sub{$Ball = $Ball->g_destroy() if ($Ball ne '');});
      }
    });
  $wid->g_bind('<Leave>', sub {$Ball = $Ball->g_destroy() if ($Ball ne '');});
}

1;
