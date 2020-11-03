package CP::LyricEd;

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
use CP::Cconst qw(:OS :PDF :TEXT :INDEX :SMILIE :COLOUR);
use CP::Global qw/:FUNC :OPT :WIN :MEDIA :XPM/;
#use CP::Pop qw/:MENU :POP/;
use CP::Win;
use CP::Cmsg;
use CP::Tab;

our $Ed = {};

sub Edit {
  my($class,$lyrics) = @_;

  my $done = '';
  my $txtWin = '';

  if (ref($Ed) eq 'HASH') {
    bless $Ed, $class;

    $Ed->{Top} = $MW->new_toplevel();
    $Ed->{Top}->g_wm_withdraw();
    $Ed->{Top}->g_wm_protocol('WM_DELETE_WINDOW' => sub{$Ed->{Top}->g_wm_withdraw()});
    $Ed->{Top}->g_wm_title("Lyric Editor");

    makeImage("Eicon", \%XPM);
    $Ed->{Top}->g_wm_iconphoto("Eicon");

    ##############################################
    ## set up 2 frames to put everything into.
    ##    Top: Editor frame
    ## Bottom: Buttons
    ##############################################

    my $mainFrame = $Ed->{Top}->new_ttk__frame(qw/-relief raised -borderwidth 2/);
    $mainFrame->g_pack(qw/-expand 1 -fill both/);

    my $topF = $Ed->{leftFrame} = $mainFrame->new_ttk__frame();
    $topF->g_pack(qw/-side top -expand 1 -fill both/);

    my $botF = $mainFrame->new_ttk__frame(-padding => [0,4,0,4]);
    $botF->g_pack(qw/-side bottom -expand 0 -fill x/);

    ##############################################
    ## now set up text window with contents.
    ##############################################
    ## autosizing is set up such that when the outside window is
    ## resized, the text box adjusts to fill everything else in.
    ## the text frame and the text window in the frame are both
    ## set up for autosizing.

    my $fp = $Media->{Words};
    my $sz = int($EditFont{size} * $Tab->{scaling});
    $txtWin = $Ed->{TxtWin} = $topF->new_tk__text(
      -width => 80,
      -height => 24,
      -insertwidth => 2,
      -font => "\{$fp->{family}\} $sz $fp->{weight} $fp->{slant}",
      -relief => 'raised',
      -foreground => $fp->{color},
      -background => WHITE,  # $EditFont{background},
      -borderwidth => 2,
      -highlightthickness => 0,
      -selectborderwidth => 0,
      -exportselection => 'true',
      -selectbackground => SELECT,
      -selectforeground => BLACK,
      -wrap=> 'none',
      -spacing1 => 3,
      -spacing3 => 3,
      -undo => 1,
      -setgrid => 'true'); # use this for autosizing
#    $txtWin->g_pack(qw/-expand 1 -fill both/);
    $txtWin->g_bind("<KeyRelease>",  sub{Tkx::after(20, sub{drawBlinds($txtWin)} )});

    my $sv = $topF->new_ttk__scrollbar(-orient => "vertical",   -command => [$txtWin, "yview"]);
    my $sh = $topF->new_ttk__scrollbar(-orient => "horizontal", -command => [$txtWin, "xview"]);

    $txtWin->configure(-yscrollcommand => [$sv, 'set']);
    $txtWin->configure(-xscrollcommand => [$sh, 'set']);

    $topF->g_grid_rowconfigure(0, -weight => 1);
    $topF->g_grid_columnconfigure(0, -weight => 1);

    $txtWin->g_grid(qw/-row 0 -column 0 -sticky nsew/);
    $sv->g_grid(qw/-row 0 -column 1 -sticky nsw/);
    $sh->g_grid(qw/-row 1 -column 0 -sticky new/);

    Tkx::clipboard_clear();

    $botF->g_grid_columnconfigure(0, -weight => 1);
    $botF->g_grid_columnconfigure(1, -weight => 1);
    $botF->g_grid_columnconfigure(2, -weight => 1);
    my $can = $botF->new_ttk__button(
      -text => 'Cancel',
      -style => "Red.TButton",
      -command => sub{$done = 'Cancel'});
    $can->g_grid(qw/-row 0 -column 0 -sticky w -padx 16/);
    my $updt = $botF->new_ttk__button(
      -text => 'Update',
      -style => "Green.TButton",
      -command => sub{update($txtWin, $lyrics)});
    $updt->g_grid(qw/-row 0 -column 1/);
    my $save = $botF->new_ttk__button(
      -text => 'Save',
      -style => "Green.TButton",
      -command => sub{$done = 'Save'});
    $save->g_grid(qw/-row 0 -column 2 -sticky e -padx 16/);

    Tkx::update();
  } else {
    $txtWin = $Ed->{TxtWin};
  }
  $txtWin->delete('1.0', 'end');

  my $edited = $Tab->{edited};
  $lyrics->collect();
  my @org = @{$lyrics->{text}};
  return('') if (@org == 0);
  $txtWin->insert('1.0', join("\n", @org));
  drawBlinds($txtWin);

  $Ed->{Top}->g_wm_deiconify();
  $Ed->{Top}->g_raise();
  $txtWin->mark_set('insert', '1.0');
  $txtWin->g_focus();

  Tkx::tkwait_variable(\$done);

  if ($done eq 'Cancel') {
    @{$lyrics->{text}} = @org;
    $Tab->newPage($Tab->{pageNum});
    main::setEdited($edited);
  } else {
    update($txtWin, $lyrics);
  }
  $Ed->{Top}->g_wm_withdraw();
  Tkx::update_idletasks();
  return($done);
}

###################
###################
##               ##
##  SUBROUTINES  ##
##               ##
###################
###################

sub drawBlinds {
  my($txtWin) = shift;

  print "Blinds\n";
  $txtWin->tag_delete('B');
  my $nlines = $txtWin->count(-lines, '1.0', 'end');
  my $ll = $Opt->{LyricLines} * 2;
  for(my $i = 1; $i <= $nlines; $i += $ll) {
    $txtWin->tag_add('B', "$i.0", ($i+$Opt->{LyricLines}).".0");
  }
  $txtWin->tag_configure('B', -background => "#F0F0F0", -selectbackground => SELECT);
}

sub update {
  my($txtWin, $lyrics) = @_;

  my $nlines = $txtWin->count(-lines, '1.0', 'end');
  my $text = $lyrics->{text};
  my $idx = 0;
  for(my $i = 1; $i <= $nlines; $i++) {
    last if (! defined $text->[$idx]);
    my $txt = $txtWin->get("$i.0", "$i.end");
    if ($txt ne $text->[$idx]) {
      $text->[$idx] = $txt;
      main::setEdited(1);
    }
    $idx++;
  }
  $Tab->newPage($Tab->{pageNum});
}

1;
