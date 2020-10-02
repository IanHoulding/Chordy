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
use CP::Global qw/:FUNC :WIN :VERS :PATH :OPT/;
use CP::Tab;
use CP::TabPDF;
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
    $MW->configure(-menu => $menu);
  }
  my $file = $menu->new_menu();
  my $edit = $menu->new_menu();
  my $PDF  = $menu->new_menu();
  my $opt  = $menu->new_menu();
  my $misc = $menu->new_menu();
  my $help = $menu->new_menu();

  $menu->add_cascade(-menu => $file, -label => "File");
  $menu->add_cascade(-menu => $edit, -label => "Edit");
  $menu->add_cascade(-menu => $PDF,  -label => "PDF");
  $menu->add_cascade(-menu => $opt,  -label => "Options");
  $menu->add_cascade(-menu => $misc, -label => "Misc");
  $menu->add_cascade(-menu => $help, -label => "Help");

  $file->add_command(-label => "Open Tab",   -command => \&openTab);
  $file->add_command(-label => "New Tab",    -command => \&newTab);
  $file->add_command(-label => "Close Tab",  -command => \&closeTab);
  $file->add_command(-label => "Delete Tab", -command => \&delTab);
  $file->add_separator;  #########
  $file->add_command(-label => "Save Tab",   -command => sub{$Tab->save()});
  $file->add_command(-label => "Save As",    -command => sub{$Tab->saveAs()});
  $file->add_command(-label => "Rename Tab", -command => \&renameTab);
  $file->add_command(-label => "Export Tab", -command => \&exportTab);
  $file->add_separator;  #########
  $file->add_command(-label => "Exit",       -command => \&exitTab);

  $edit->add_command(-label => "Collection", -command => sub{$Collection->edit()});
  $edit->add_command(-label => "Media",      -command => \&mediaEdit);
  $edit->add_command(-label => "Fonts",      -command => \&fontEdit);
  
  $PDF->add_command(-label => "View",       -command => [\&CP::TabPDF::make, 'V']);
  $PDF->add_command(-label => 'Make',       -command => [\&CP::TabPDF::make, 'M']);
  $PDF->add_command(-label => 'Batch Make', -command =>  \&CP::TabPDF::batch);
  $PDF->add_command(-label => 'Print',      -command => [\&CP::TabPDF::make, 'P']);
  $PDF->add_separator;  #########
  $PDF->add_command(-label => 'Save, Make & Close',  -command => \&saveCloseTab);
  $PDF->add_command(-label => 'Save As Text',        -command => sub{$Tab->saveAsText()});

  my $inst = $opt->new_menu;
  $opt->add_cascade(-menu => $inst, -label => 'Instrument'." - $Opt->{Instrument}");
  foreach (@{$Opt->{Instruments}}) {
    $inst->add_radiobutton(-label => $_,
			   -variable => \$Opt->{Instrument},
			   -command =>
			   sub{$Tab->drawPageWin();
			       main::setEdited(1);
			       config($opt, 0, 'Instrument', $Opt->{Instrument});
			   });
  }
  my $tim = $opt->new_menu;
  $opt->add_cascade(-menu => $tim, -label => 'Timing'." - $Tab->{Timing}");
  foreach (qw{2/4 3/4 4/4}) {
    $tim->add_radiobutton(-label => $_,
			  -variable => \$Tab->{Timing},
			  -command => sub{my($t,$_t) = split('/', $Tab->{Timing});
					  $Tab->{BarEnd} = $t * 8;
					  $Tab->drawPageWin();
					  editWindow();
					  main::setEdited(1);
					  config($opt, 1, 'Timing', $Tab->{Timing});
			  });
  }
  my $key = $opt->new_menu;
  $opt->add_cascade(-menu => $key, -label => 'Set Key'." - $Tab->{key}");
  no warnings; # stops perl bleating about '#' in array definition.
  foreach (qw/- Ab Abm A Am A# A#m Bb Bbm B Bm C Cm C# C#m Db Dbm D Dm D# D#m Eb Ebm E Em F Fm F# F#m Gb Gbm G Gm G# G#m/) {
    $key->add_radiobutton(-label => $_,
			  -variable => \$Tab->{key},
			  -command => sub{$Tab->pageKey();
					  main::setEdited(1);
					  config($opt, 2, 'Set Key', $Tab->{key});
			  });
  }
  use warnings;
  my $bps = $opt->new_menu;
  $opt->add_cascade(-menu => $bps, -label => 'Bars/Stave'." - $Opt->{Nbar}");
  foreach (qw/3 4 5 6 7 8 9 10/) {
    $bps->add_radiobutton(-label => $_,
			  -variable => \$Opt->{Nbar},
			  -command => sub{$Tab->drawPageWin();
					  main::setEdited(1);
					  config($opt, 3, 'Bars/Stave', $Opt->{Nbar});
			  });
  }
  my $ss = $opt->new_menu;
  $opt->add_cascade(-menu => $ss, -label => 'String Spacing'." - $Opt->{StaffSpace}");
  foreach (qw/6 7 8 9 10 11 12 13 14 15 16/) {
    $ss->add_radiobutton(-label => $_,
			 -variable => \$Opt->{StaffSpace},
			 -command => sub{$Tab->drawPageWin();
					 CP::TabWin::editWindow();
					 main::setEdited(1);
					 config($opt, 4, 'String Spacing', $Opt->{StaffSpace});
			 });
  }
  my $sg = $opt->new_menu;
  $opt->add_cascade(-menu => $sg, -label => 'Stave Gap'." - $Tab->{staveGap}");
  foreach (qw/0 1 2 3 4 5 6 8 9 10 11 12 13 14 16 18 20/) {
    $sg->add_radiobutton(-label => $_,
			 -variable => \$Tab->{staveGap},
			 -command => sub{$Tab->drawPageWin();
					 main::setEdited(1);
					 config($opt, 5, 'Stave Gap', $Tab->{staveGap});
			 });
  }
  my $es = $opt->new_menu;
  $opt->add_cascade(-menu => $es, -label => 'Edit Scale'." - $Opt->{EditScale}");
  foreach (qw/3 3.5 4 4.5 5 5.5 6/) {
    $es->add_radiobutton(-label => $_,
			 -variable => \$Opt->{EditScale},
			 -command => sub{CP::TabWin::editWindow();
					 config($opt, 6, 'Edit Scale', $Opt->{EditScale});
			 });
  }
  my $ll = $opt->new_menu;
  $opt->add_cascade(-menu => $ll, -label => 'Lyric Lines'." - $Opt->{LyricLines}");
  my $lln = $Opt->{LyricLines};
  foreach (qw/0 1 2 3/) {
    $ll->add_radiobutton(-label => $_,
			 -variable => \$lln,
			 -command => sub{$Tab->{lyrics}->adjust($lln);
					 $Tab->drawPageWin();
					 main::setEdited(1);
					 config($opt, 7, 'Lyric Lines', $Opt->{LyricLines});
			 });
  }
  my $ls = $opt->new_menu;
  $opt->add_cascade(-menu => $ls, -label => 'Lyric Spacing'." - $Tab->{lyricSpace}");
  foreach (qw/0 2 4 6 8 10 12 14 16 18 20/) {
    $ls->add_radiobutton(-label => $_,
			 -variable => \$Tab->{lyricSpace},
			 -command => sub{$Tab->drawPageWin();
					 main::setEdited(1);
					 config($opt, 8, 'Lyric Spacing', $Tab->{lyricSpace});
			 });
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

sub config {
  my($menu,$idx,$opt,$val) = @_;

  $menu->entryconfigure($idx, -label => "$opt - $val");
}

sub openTab {
  my $fn = (CP::Browser->new($MW, TABBR, $Path->{Tab}, '.tab'))[0];
  if ($fn ne '') {
    CP::Tab->new("$Path->{Tab}/$fn");
    $Tab->drawPageWin();
  }
}

sub newTab {
  if ($Tab->checkSave() ne 'Cancel') {
    if ($Tab->{fileName} eq '') {
      my $fn = "";
      my $ans = msgSet("Enter a name for the new file", \$fn);
      return(0) if ($ans eq "Cancel");
      if ($fn eq "") {
	message(QUIZ, "How about a file name then?");
	return(0);
      }
      (my $title = $fn) =~ s/.tab$//i;
      $fn = $title.'.tab';
      if (-e "$Path->{Tab}/$fn") {
	$ans = msgYesNo("$fn already exists.\nDo you want to overwrite it?");
	return(0) if ($ans eq "No");
      }
      open OFH, ">", "$Path->{Tab}/$fn" or die "failed open '$Path->{Tab}/$fn' : $!\n";
      print OFH "{title:$title}\n";
      close OFH;
      $Tab->{fileName} = $fn;
    }
    CP::Tab->new("$Path->{Tab}/$Tab->{fileName}");
    $Tab->drawPageWin();
    tabTitle($Tab->{fileName});
  }
}

sub closeTab {
  if ($Tab->checkSave() ne 'Cancel') {
    CP::Tab->new('');
    $Tab->drawPageWin();
  }
}

sub delTab {
  if ($Tab->{fileName} ne '') {
    my $ans = msgYesNo("Do you really want to delete\n  $Tab->{fileName}");
    return if ($ans eq "No");
    unlink("$Path->{Tab}/$Tab->{fileName}");
    CP::Tab->new('');
    $Tab->drawPageWin();
  }
}

sub renameTab {
  if ($Tab->{fileName} ne '') {
    my $ofn = $Tab->{fileName};
    my $newfn = $ofn;
    my $ans = msgSet("Enter a new name for the file:", \$newfn);
    return if ($ans eq 'Cancel');
    $newfn =~ s/\.tab$//i;
    $newfn .= '.tab';
    if (-e "$Path->{Tab}/$newfn") {
      $ans = msgYesNo("$Path->{Tab}/$newfn\nFile already exists.\nDo you want to replace it?");
      return if ($ans eq "No");
    }
    rename("$Path->{Tab}/$ofn", "$Path->{Tab}/$newfn");
    $Tab->{fileName} = $newfn;
    tabTitle("$newfn");
  } else {
    Tkx::bell();
  }
}

sub exportTab {
  if ($Tab->{loaded} == 0) {
    Tkx::bell();
    return;
  }
  my $dest = Tkx::tk___chooseDirectory(
    -title => "Choose Destination Folder",
    -initialdir => "$Home",);
  $dest =~ s/\/$//;
  if ($dest ne '') {
    if ($dest eq $Path->{Tab}) {
      message(QUIZ, "Destination Folder cannot be:\n    \"$dest\"\nPlease try again!");
      return;
    }
    if (! -e $dest) {
      make_path($dest, {chmod => 0777});
    }
    if ($Tab->save($dest, 0) == 1) {
      # We now have the current Tab in a temporary file: "$Path->{Temp}/$Tab->{fileName}"
      my $tmp = "$Path->{Temp}/$Tab->{fileName}";
      my $txt = read_file($tmp);
      if (write_file("$dest/$Tab->{fileName}", $txt) == 1) {
	unlink($tmp);
      } else {
	message(SAD, "Failed to write \"$Tab->{fileName}\" to \"$dest\"\nOriginal is in: \"$tmp\"");
	return;
      }
      message(SMILE, "\"$Tab->{fileName}\" Exported", -1);
    }
  }
}

sub exitTab {
  if ($Tab->checkSave() ne 'Cancel') {
    $MW->g_destroy();
    exit(0);
  }
}

sub saveCloseTab {
  $Tab->save();
  CP::TabPDF::make('M');
  $Tab->new('');
}

sub mediaEdit {
  if ($Media->edit() eq "OK") {
    $Tab->drawPageWin();
  }
}

sub fontEdit {
  my $pop = CP::Pop->new(0, '.fo', 'Font Selector', -1, -1);
  return if ($pop eq '');
  my($top,$wt) = ($pop->{top}, $pop->{frame});

  my $Done;
  my $mcopy = {};
  $Media->copy($mcopy);

  $wt->m_configure(qw/-relief raised -borderwidth 2/);

  my $tf = $wt->new_ttk__frame(qw/-borderwidth 2 -relief ridge/, -padding => [4,4,4,4]);
  $tf->g_pack(qw/-side top/);

  my $ff = $tf->new_ttk__frame();
  $ff->g_pack(qw/-side top -expand 1 -fill x/);

  my $df = $tf->new_ttk__frame();
  $df->g_pack(qw/-side bottom -expand 1 -fill x/, -pady => [12,4]);
  CP::Win::defButtons($df, 'Fonts', \&main::mediaSave, \&main::mediaLoad, \&main::mediaDefault);

  my $bf = $wt->new_ttk__frame();
  $bf->g_pack(qw/-side top -expand 1 -fill x/);

  CP::Fonts::fonts($ff, [qw/Title Header Notes SNotes Words/]);

  ($bf->new_ttk__button(-text => "Cancel", -command => sub{$Done = "Cancel";})
  )->g_grid(qw/-row 0 -column 0 -padx 60/, -pady => [4,0]);
  ($bf->new_ttk__button(-text => "OK", -command => sub{$Done = "OK";})
  )->g_grid(qw/-row 0 -column 1 -sticky e -padx 60/, -pady => [4,0]);

  Tkx::vwait(\$Done);
  if ($Done eq "OK") {
    $Tab->drawPageWin();
  } else {
    $mcopy->copy($Media);
  }
  $pop->popDestroy();
}

1;
