package CP::TabMenu;

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
use CP::Cconst qw/:OS :BROWSE :SMILIE/;
use CP::Global qw/:FUNC :WIN :VERS :OPT/;
use CP::Tab;
use CP::Cmsg;

#
# Not really a module in the strictest sense
# but a way to keep all the menu code together.
#
sub new {
  my($m,$menu);

  if (OS eq 'aqua') {
    $m = $MW->new_menu();
    $menu = Tkx::widget->new(Tkx::menu($m->_mpath . ".apple"));
    $m->add_cascade(-menu => $menu);
  } else {
    $menu = $MW->new_menu();
    my $c = $MW->configure(-menu => $menu);
    print "c=$c menu=$menu\n";
  }
  my $file = $menu->new_menu();
  my $PDF  = $menu->new_menu();
  my $opt  = $menu->new_menu();
  my $misc = $menu->new_menu();
  my $help = $menu->new_menu();

  $menu->add_cascade(-menu => $file, -label => "File");
  $menu->add_cascade(-menu => $PDF,  -label => "PDF");
  $menu->add_cascade(-menu => $opt,  -label => "Options");
  $menu->add_cascade(-menu => $misc, -label => "Misc");
  $menu->add_cascade(-menu => $help, -label => "Help");

  $file->add_command(-label => "Open Tab",   -command => \&main::openTab);
  $file->add_command(-label => "New Tab",    -command => \&main::newTab);
  $file->add_command(-label => "Close Tab",  -command => \&main::closeTab);
  $file->add_command(-label => "Delete Tab", -command => \&main::delTab);
  $file->add_separator;  #########
  $file->add_command(-label => "Save Tab",   -command => sub{$Tab->save()});
  $file->add_command(-label => "Save As",    -command => sub{$Tab->saveAs()});
  $file->add_command(-label => "Rename Tab", -command => \&main::renameTab);
  $file->add_command(-label => "Export Tab", -command => \&main::exportTab);
  $file->add_separator;  #########
  $file->add_command(-label => "Exit",       -command => \&main::exitTab);

  $PDF->add_command(-label => "View",       -command => [\&CP::TabPDF::make, 'V']);
  $PDF->add_command(-label => 'Make',       -command => [\&CP::TabPDF::make, 'M']);
  $PDF->add_command(-label => 'Batch Make', -command =>  \&CP::TabPDF::batch);
  $PDF->add_command(-label => 'Print',      -command => [\&CP::TabPDF::make, 'P']);
  $PDF->add_separator;  #########
  $PDF->add_command(-label => 'Save, Make & Close',  -command => \&saveCloseTab);
  $PDF->add_command(-label => 'Save As Text',        -command => sub{$Tab->saveAsText()});

  my $inst = $opt->new_menu;
  $opt->add_cascade(-menu => $inst, -label => 'Instrument');
  foreach (@{$Opt->{Instruments}}) {
    $inst->add_radiobutton(-label => $_,
			   -variable => \$Opt->{Instrument},
			   -command => sub{$Tab->drawPageWin();main::setEdited(1);});
  }
  my $tim = $opt->new_menu;
  $opt->add_cascade(-menu => $tim, -label => 'Timing');
  foreach (qw{2/4 3/4 4/4}) {
    $tim->add_radiobutton(-label => $_,
			  -variable => \$Tab->{Timing},
			  -command => sub{my($t,$_t) = split('/', $Tab->{Timing});
					  $Tab->{BarEnd} = $t * 8;
					  $Tab->drawPageWin();
					  editWindow();
					  main::setEdited(1);});
  }
  my $key = $opt->new_menu;
  $opt->add_cascade(-menu => $key, -label => 'Set Key');
  no warnings; # stops perl bleating about '#' in array definition.
  foreach (' ', qw/Ab Abm A Am A# A#m Bb Bbm B Bm C Cm C# C#m Db Dbm D Dm D# D#m Eb Ebm E Em F Fm F# F#m Gb Gbm G Gm G# G#m/) {
    $key->add_radiobutton(-label => $_,
			  -variable => \$Tab->{key},
			  -command => sub{$Tab->pageKey();main::setEdited(1);});
  }
  use warnings;
  my $bps = $opt->new_menu;
  $opt->add_cascade(-menu => $bps, -label => 'Bars/Stave');
  foreach (qw/3 4 5 6 7 8 9 10/) {
    $bps->add_radiobutton(-label => $_,
			  -variable => \$Opt->{Nbar},
			  -command => sub{$Tab->drawPageWin();main::setEdited(1);});
  }
  my $ss = $opt->new_menu;
  $opt->add_cascade(-menu => $ss, -label => 'String Spacing');
  foreach (qw/6 7 8 9 10 11 12 13 14 15 16/) {
    $ss->add_radiobutton(-label => $_,
			 -variable => \$Opt->{StaffSpace},
			 -command => sub{$Tab->drawPageWin();CP::TabWin::editWindow();main::setEdited(1);});
  }
  my $sg = $opt->new_menu;
  $opt->add_cascade(-menu => $sg, -label => 'Stave Gap');
  foreach (qw/0 1 2 3 4 5 6 8 9 10 11 12 13 14 16 18 20/) {
    $sg->add_radiobutton(-label => $_,
			 -variable => \$Tab->{staveGap},
			 -command => sub{$Tab->drawPageWin();main::setEdited(1);});
  }
  my $es = $opt->new_menu;
  $opt->add_cascade(-menu => $es, -label => 'Edit Scale');
  foreach (qw/3 3.5 4 4.5 5 5.5 6/) {
    $es->add_radiobutton(-label => $_,
			 -variable => \$Opt->{EditScale},
			 -command => \&CP::TabWin::editWindow);
  }
  my $ll = $opt->new_menu;
  $opt->add_cascade(-menu => $ll, -label => 'Lyric Lines');
  my $lln = $Opt->{LyricLines};
  foreach (qw/0 1 2 3/) {
    $ll->add_radiobutton(-label => $_,
			 -variable => \$lln,
			 -command => sub{$Tab->{lyrics}->adjust($lln);$Tab->drawPageWin();main::setEdited(1);});
  }
  my $ls = $opt->new_menu;
  $opt->add_cascade(-menu => $ls, -label => '');
  foreach (qw/0 2 4 6 8 10 12 14 16 18 20/) {
    $ls->add_radiobutton(-label => $_,
			 -variable => \$Tab->{lyricSpace},
			 -command => sub{$Tab->drawPageWin();main::setEdited(1);});
  }
  
  $misc->add_command(-label => 'View Error Log',     -command => \&viewElog);
  $misc->add_command(-label => 'Clear Error Log',    -command => \&clearElog);
  $misc->add_command(-label => 'View Release Notes', -command => \&viewRelNt);
  $misc->add_separator;
  $misc->add_command(-label => "Delete Tab Backups", -command => [\&DeleteBackups, '.tab', $Path->{Temp}]);
  
  $help->add_command(-label => 'Help',  -command => \&CP::HelpTab::help);
  $help->add_command(-label => 'About', -command => sub{message(SMILE, "Version $Version\nian\@houlding.me.uk");});
  if (OS eq 'aqua') {
    $MW->configure(-menu => $m);
  }
}

sub saveCloseTab {
  $Tab->save();
  CP::TabPDF::make('M');
  $Tab->new('');
}

1;
