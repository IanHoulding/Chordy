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
use CP::Global qw/:WIN :XPM/;

BEGIN {
  our @ISA = qw(Exporter);
  our @EXPORT_OK = qw/pop popExists popDestroy popMenu balloon/;
  our %EXPORT_TAGS = (
    POP  => [qw/pop popExists popDestroy/],
    MENU => [qw/popMenu balloon/]);
  require Exporter;
}

our %Pops;  # Keeps track of all active/available pop-ups
            # via their toplevel path names.

sub new {
  my($proto,$ov,$path,$title,$x,$y) = @_;
  my $class = ref($proto) || $proto;

  my $self = {};
  bless $self, $class;

  if (CP::Pop::exists($path)) {
    Tkx::bell();
    $Pops{$path}->{top}->g_focus();
    return('');
  }
  $Pops{$path} = $self;
  $self->{path} = $path;
  my $top = $self->{top} = $MW->new_toplevel(-name => $path);
  if ($ov) {
    $top->g_wm_overrideredirect(1);
  } else {
    my $icon = (defined $Images{Ticon}) ? 'Ticon' : (defined $Images{Cicon}) ? 'Cicon' : 'Eicon';
    $top->g_wm_iconphoto($icon);
    $top->g_wm_title($title) if ($title ne '');
    $top->g_wm_protocol('WM_DELETE_WINDOW' => sub{$self->destroy()});
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

  $self;
}

sub pop {
  my($path) = shift;

  return((! defined $Pops{$path}) ? '' : $Pops{$path});
}

sub destroy {
  my($self) = shift;

  $self->{top}->g_destroy();
  $Pops{$self->{path}} = '';
}

sub exists {
  my($path) = shift;

  return((! defined $Pops{$path} || $Pops{$path} eq '') ? 0 : 1);
}

sub popMenu {
  my($var,$subr,$list) = @_;

  my $menu = $MW->new_menu();
  foreach my $e (@{$list}) {
    if ($e eq 'SeP') {
      $menu->add_separator();
    } else {
      $menu->add_radiobutton(
	-label => $e,
	-value => $e,
	-variable => $var,
	-command => $subr);
    }
  }
  $menu->g_tk___popup(Tkx::winfo_pointerx($MW), Tkx::winfo_pointery($MW));
  Tkx::update();
}

#my $Ball = '';
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
