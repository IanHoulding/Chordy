package CP::Path;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

use strict;

use File::Path qw(make_path);
use CP::Cconst qw/:OS :PATH/;
use CP::Global qw/:OPT :PATH :VERS :FUNC/;

sub new {
  my($proto) = @_;
  my $class = ref($proto) || $proto;

  #
  # The $Home paths change depending on the Collection being used.
  # The USER paths are fixed as they are global to all Collections.
  #
  my $self = {
    Temp    => "$Home/Temp",       #
    Pro     => "$Home/Pro",        #
    Tab     => "$Home/Tab",        # These are the defaults but can be
    PDF     => "$Home/PDF",        # changed on a per Collection basis
    Option  => "$Home/Option.cfg", #
    Swatch  => "$Home/Swatch.cfg", #
    SMTP    => USER."/SMTP.cfg",
    Command => USER."/Command.cfg",
    Media   => USER."/Media.cfg",
  };
  $self->{Font} = (OS eq "win32") ? "C:/Windows/Fonts" :
      (OS eq "aqua") ? "/Library/Fonts,/System/Library/Fonts/Supplemental" :
                       "/usr/share/fonts/truetype";
  bless $self, $class;
  check_dir($self);
  if (-e PROG."/Release Notes.txt") {
    my $txt = read_file(PROG."/Release Notes.txt");
    write_file(USER."/Release Notes.txt", $txt);
    unlink(PROG."/Release Notes.txt");
  }
  return($self);
}

sub change {
  my($self,$home) = @_;

  foreach (qw/Option Swatch/) {
    $self->{$_} = "$home/$_.cfg";
  }
  foreach (qw/Pro Tab PDF/) {
    $self->{$_} = "$home/$_";
  }
  check_dir($self);
}

sub check_dir {
  my($self) = shift;

  foreach my $col (@{$Collection->listAll()}) {
    my $home = $Collection->path($col)."/$col";
    foreach my $dir (qw/Pro PDF Tab Temp/) {
      if (! -d "$home/$dir") {
	make_path("$home/$dir", {chmod => 0644});
      }
    }
  }
}

1;
