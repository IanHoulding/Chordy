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

my %Opts = ();
my $Recent;
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

  $file->add_command(-label => "Open",   -font => 'TkMenuFont', -command => \&openTab);
  $file->add_command(-label => "New",    -font => 'TkMenuFont', -command => \&newTab);
  {
    $Recent = $file->new_menu;
    $file->add_cascade(-menu => $Recent, -font => 'TkMenuFont', -label => 'Recent');
    foreach (0..9) {
      my $fn = (defined $Opt->{RecentTab}[$_]) ? $Opt->{RecentTab}[$_] : '. . .';
      $Recent->add_command(-label => $fn,
			   -font => 'TkMenuFont',
			   -command => sub{
			     if ($fn ne '. . .') {
			       CP::Tab->new("$Path->{Tab}/$fn");
			       $Tab->drawPageWin();
			       $Opt->add2recent($fn, 'RecentTab', \&refresh);
			     }
			   });
    }
  }
  $file->add_command(-label => "Close",  -font => 'TkMenuFont', -command => \&closeTab);
  $file->add_command(-label => "Delete", -font => 'TkMenuFont', -command => \&delTab);
  $file->add_command(-label => "Revert",
		     -font => 'TkMenuFont',
		     -command => sub{
		       my $fn = (CP::Browser->new($MW, TABBR, $Path->{Tab}, '.tab'))[0];
		       if ($fn eq '') {
			 message(SAD, "You don't appear to have selected a Tab file.");
			 return;
		       }
		       RevertTo($fn);
		     });
  $file->add_separator;  #########
  $file->add_command(-label => "Save",
		     -font => 'TkMenuFont',
		     -command => sub{$Tab->save()});
  $file->add_command(-label => "Save As",
		     -font => 'TkMenuFont',
		     -command => sub{$Tab->saveAs()});
  $file->add_command(-label => 'Save, Make & Close',
		     -font => 'TkMenuFont',
		     -command => \&saveCloseTab);
  $file->add_command(-label => "Rename",
		     -font => 'TkMenuFont',
		     -command => \&renameTab);
  $file->add_command(-label => "Export",
		     -font => 'TkMenuFont',
		     -command => \&exportTab);
  $file->add_separator;  #########
  $file->add_command(-label => "Exit",
		     -font => 'TkMenuFont',
		     -command => \&exitTab);

  $edit->add_command(-label => "Collection",
		     -font => 'TkMenuFont',
		     -command => sub{$Collection->edit()});
  $edit->add_command(-label => "Media",
		     -font => 'TkMenuFont',
		     -command => \&mediaEdit);
  $edit->add_command(-label => "Fonts",
		     -font => 'TkMenuFont',
		     -command => \&fontEdit);
  
  $PDF->add_command(-label => "View",
		    -font => 'TkMenuFont',
		    -command => [\&CP::TabPDF::make, 'V']);
  $PDF->add_command(-label => 'Make',
		    -font => 'TkMenuFont',
		    -command => [\&CP::TabPDF::make, 'M']);
  $PDF->add_command(-label => 'Batch Make',
		    -font => 'TkMenuFont',
		    -command =>  \&CP::TabPDF::batch);
  $PDF->add_command(-label => 'Print',
		    -font => 'TkMenuFont',
		    -command => [\&CP::TabPDF::make, 'P']);
  $PDF->add_separator;  #########
  $PDF->add_command(-label => 'Save, Make & Close',
		    -font => 'TkMenuFont',
		    -command => \&saveCloseTab);
  $PDF->add_command(-label => 'Save As Text',
		    -font => 'TkMenuFont',
		    -command => sub{$Tab->saveAsText()});

  $Opts{menu} = $opt;
  use warnings;
  $Opts{ent}[0] = {text => 'Bars/Stave', var => \$Opt->{Nbar}};
  my $bps = $opt->new_menu;
  $opt->add_cascade(-menu => $bps,
		    -font => 'TkMenuFont',
		    -label => 'Bars/Stave'." - $Opt->{Nbar}");
  foreach (qw/3 4 5 6 7 8 9 10/) {
    $bps->add_radiobutton(-label => $_,
			  -variable => \$Opt->{Nbar},
			  -font => 'TkMenuFont',
			  -command => sub{$Tab->drawPageWin();
					  main::setEdited(1);
					  config($opt, 0, 'Bars/Stave', $Opt->{Nbar});
					  $Opt->saveOne('Nbar');
			  });
  }
  $Opts{ent}[1] = {text => 'Edit Scale', var => \$Opt->{EditScale}};
  my $es = $opt->new_menu;
  $opt->add_cascade(-menu => $es,
		    -font => 'TkMenuFont',
		    -label => 'Edit Scale'." - $Opt->{EditScale}");
  foreach (qw/3 3.5 4 4.5 5 5.5 6/) {
    $es->add_radiobutton(-label => $_,
			 -variable => \$Opt->{EditScale},
			 -font => 'TkMenuFont',
			 -command => sub{CP::TabWin::editWindow();
					 config($opt, 1, 'Edit Scale', $Opt->{EditScale});
					 $Opt->saveOne('EditScale');
			 });
  }
  $Opts{ent}[2] = {text => 'Instrument', var => \$Opt->{Instrument}};
  my $inst = $opt->new_menu;
  $opt->add_cascade(-menu => $inst,
		    -font => 'TkMenuFont',
		    -label => 'Instrument'." - $Opt->{Instrument}");
  foreach (@{$Opt->{Instruments}}) {
    $inst->add_radiobutton(-label => $_,
			   -variable => \$Opt->{Instrument},
			   -font => 'TkMenuFont',
			   -command =>
			   sub{$Tab->drawPageWin();
			       main::setEdited(1);
			       config($opt, 2, 'Instrument', $Opt->{Instrument});
			       $Opt->saveOne('Instrument');
			   });
  }
  $Opts{ent}[3] = {text => 'Lyric Lines', var => \$Opt->{LyricLines}};
  my $ll = $opt->new_menu;
  $opt->add_cascade(-menu => $ll,
		    -font => 'TkMenuFont',
		    -label => 'Lyric Lines'." - $Opt->{LyricLines}");
  foreach (qw/0 1 2 3/) {
    $ll->add_radiobutton(-label => $_,
			 -variable => \$Opt->{LyricLines},
			 -font => 'TkMenuFont',
			 -command => sub{$Tab->{lyrics}->adjust($Opt->{LyricLines});
					 $Tab->drawPageWin();
					 main::setEdited(1);
					 config($opt, 3, 'Lyric Lines', $Opt->{LyricLines});
					 $Opt->saveOne('LyricLines');
			 });
  }
  $Opts{ent}[4] = {text => 'Lyric Spacing', var => \$Tab->{lyricSpace}};
  my $ls = $opt->new_menu;
  $opt->add_cascade(-menu => $ls,
		    -font => 'TkMenuFont',
		    -label => 'Lyric Spacing'." - $Tab->{lyricSpace}");
  foreach (qw/0 2 4 6 8 10 12 14 16 18 20/) {
    $ls->add_radiobutton(-label => $_,
			 -variable => \$Tab->{lyricSpace},
			 -font => 'TkMenuFont',
			 -command => sub{$Tab->drawPageWin();
					 main::setEdited(1);
					 config($opt, 4, 'Lyric Spacing', $Tab->{lyricSpace});
			 });
  }
  $Opts{ent}[5] = {text => 'Set Key', var => \$Tab->{key}};
  my $key = $opt->new_menu;
  $opt->add_cascade(-menu => $key,
		    -font => 'TkMenuFont',
		    -label => 'Set Key'." - $Tab->{key}");
  no warnings; # stops perl bleating about '#' in array definition.
  foreach (qw/- Ab Abm A Am A# A#m Bb Bbm B Bm C Cm C# C#m Db Dbm D Dm D# D#m Eb Ebm E Em F Fm F# F#m Gb Gbm G Gm G# G#m/) {
    $key->add_radiobutton(-label => $_,
			  -variable => \$Tab->{key},
			  -font => 'TkMenuFont',
			  -command => sub{$Tab->pageKey();
					  main::setEdited(1);
					  config($opt, 5, 'Set Key', $Tab->{key});
			  });
  }
  $Opts{ent}[6] = {text => 'Stave Gap', var => \$Tab->{staveGap}};
  my $sg = $opt->new_menu;
  $opt->add_cascade(-menu => $sg,
		    -font => 'TkMenuFont',
		    -label => 'Stave Gap'." - $Tab->{staveGap}");
  foreach (qw/0 1 2 3 4 5 6 8 9 10 11 12 13 14 16 18 20/) {
    $sg->add_radiobutton(-label => $_,
			 -variable => \$Tab->{staveGap},
			 -font => 'TkMenuFont',
			 -command => sub{$Tab->drawPageWin();
					 main::setEdited(1);
					 config($opt, 6, 'Stave Gap', $Tab->{staveGap});
			 });
  }
  $Opts{ent}[7] = {text => 'String Spacing', var => \$Opt->{StaffSpace}};
  my $ss = $opt->new_menu;
  $opt->add_cascade(-menu => $ss,
		    -font => 'TkMenuFont',
		    -label => 'String Spacing'." - $Opt->{StaffSpace}");
  foreach (qw/6 7 8 9 10 11 12 13 14 15 16/) {
    $ss->add_radiobutton(-label => $_,
			 -variable => \$Opt->{StaffSpace},
			 -font => 'TkMenuFont',
			 -command => sub{$Tab->drawPageWin();
					 CP::TabWin::editWindow();
					 main::setEdited(1);
					 config($opt, 7, 'String Spacing', $Opt->{StaffSpace});
					 $Opt->saveOne('StaffSpace');
			 });
  }
  $Opts{ent}[8] = {text => 'Timing', var => \$Tab->{Timing}};
  my $tim = $opt->new_menu;
  $opt->add_cascade(-menu => $tim,
		    -font => 'TkMenuFont',
		    -label => 'Timing'." - $Tab->{Timing}");
  foreach (qw{2/4 3/4 4/4}) {
    $tim->add_radiobutton(-label => $_,
			  -variable => \$Tab->{Timing},
			  -font => 'TkMenuFont',
			  -command => sub{my($t,$_t) = split('/', $Tab->{Timing});
					  $Tab->{BarEnd} = $t * 8;
					  $Tab->drawPageWin();
					  CP::TabWin::editWindow();
					  main::setEdited(1);
					  config($opt, 8, 'Timing', $Tab->{Timing});
			  });
  }
  
  $misc->add_command(-label => 'View Error Log',
		     -font => 'TkMenuFont',
		     -command => \&viewElog);
  $misc->add_command(-label => 'Clear Error Log',
		     -font => 'TkMenuFont',
		     -command => \&clearElog);
  $misc->add_command(-label => 'View Release Notes',
		     -font => 'TkMenuFont',
		     -command => \&viewRelNt);
  $misc->add_separator;
  $misc->add_command(-label => "Delete Tab Backups",
		     -font => 'TkMenuFont',
		     -command => [\&DeleteBackups, '.tab', $Path->{Temp}]);
  
  $help->add_command(-label => 'Help',
		     -font => 'TkMenuFont',
		     -command => \&CP::HelpTab::help);
  $help->add_command(-label => 'About',
		     -font => 'TkMenuFont',
		     -command => sub{message(SMILE, "Version $Version\nian\@houlding.me.uk");});
  if (OS eq 'aqua') {
    $MW->configure(-menu => $m);
  }
}

sub refresh {
  my $menu = $Opts{menu};
  my $idx = 0;
  foreach my $ep (@{$Opts{ent}}) {
    $menu->entryconfigure($idx++, -label => "$ep->{text} - ${$ep->{var}}");
  }
  foreach (0..9) {
    my $fn = (defined $Opt->{RecentTab}[$_]) ? $Opt->{RecentTab}[$_] : '. . .';
    $Recent->entryconfigure($_, -label => $fn);
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
    $Opt->add2recent($fn, 'RecentTab', \&refresh);
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
    main::tabTitle($Tab->{fileName});
    $Opt->add2recent($Tab->{fileName}, 'RecentTab', \&refresh);
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
    main::tabTitle("$newfn");
    $Opt->add2recent($newfn, 'RecentTab', \&refresh);
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
  $Tab->drawPageWin();
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
  $ff->g_pack(qw/-side top -expand 1 -fill x/, -pady => [0,4]);

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
    $Media->save();
  }
  $pop->popDestroy();
}

1;
