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
  my($proto,$tab) = @_;

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
  $file->add_command(-label => "New",    -font => 'TkMenuFont', -command => [\&newTab, $tab]);
  {
    $Recent = $file->new_menu;
    $file->add_cascade(-menu => $Recent, -font => 'TkMenuFont', -label => 'Recent');
    foreach my $i (0..9) {
      my $fn = (defined $Opt->{RecentTab}[$i]) ? $Opt->{RecentTab}[$i] : '. . .';
      $Recent->add_command(-label => $fn,
			   -font => 'TkMenuFont',
			   -command => sub{
			     if ($fn ne '. . .') {
			       CP::Tab->new("$Path->{Tab}/$fn");
			       $tab->drawPageWin();
			       $Opt->add2recent($fn, 'RecentTab', \&refresh);
			     }
			   });
    }
  }
  $file->add_command(-label => "Close",  -font => 'TkMenuFont', -command => [\&closeTab, $tab]);
  $file->add_command(-label => "Delete", -font => 'TkMenuFont', -command => [\&delTab, $tab]);
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
		     -command => sub{$tab->save()});
  $file->add_command(-label => "Save As",
		     -font => 'TkMenuFont',
		     -command => sub{$tab->saveAs()});
  $file->add_command(-label => 'Save, Make & Close',
		     -font => 'TkMenuFont',
		     -command => [\&saveCloseTab, $tab]);
  $file->add_command(-label => "Rename",
		     -font => 'TkMenuFont',
		     -command => [\&renameTab, $tab]);
  $file->add_command(-label => "Export",
		     -font => 'TkMenuFont',
		     -command => [\&exportTab, $tab]);
  $file->add_separator;  #########
  $file->add_command(-label => "Exit",
		     -font => 'TkMenuFont',
		     -command => \&exitTab);

  $edit->add_command(-label => "Collection",
		     -font => 'TkMenuFont',
		     -command => sub{$Collection->edit()});
  $edit->add_command(-label => "Media",
		     -font => 'TkMenuFont',
		     -command => [\&mediaEdit, $tab]);
  $edit->add_command(-label => "Fonts",
		     -font => 'TkMenuFont',
		     -command => [\&fontEdit, $tab]);
  
  $PDF->add_command(-label => "View",
		    -font => 'TkMenuFont',
		    -command => [\&CP::TabPDF::make, $tab, 'V']);
  $PDF->add_command(-label => 'Make',
		    -font => 'TkMenuFont',
		    -command => [\&CP::TabPDF::make, $tab, 'M']);
  $PDF->add_command(-label => 'Batch Make',
		    -font => 'TkMenuFont',
		    -command => [\&CP::TabPDF::batch, $tab]);
  $PDF->add_command(-label => 'Print',
		    -font => 'TkMenuFont',
		    -command => [\&CP::TabPDF::make, $tab, 'P']);
  $PDF->add_separator;  #########
  $PDF->add_command(-label => 'Save, Make & Close',
		    -font => 'TkMenuFont',
		    -command => [\&saveCloseTab, $tab]);
  $PDF->add_command(-label => 'Save As Text',
		    -font => 'TkMenuFont',
		    -command => sub{$tab->saveAsText()});

  $Opts{menu} = $opt;
  my $oidx = 0;
  $Opts{ent}[$oidx] = {text => 'Bars/Stave', var => \$Opt->{Nbar}};
  my $bps = $opt->new_menu;
  $opt->add_cascade(-menu => $bps,
		    -font => 'TkMenuFont',
		    -label => 'Bars/Stave'." - $Opt->{Nbar}");
  foreach (qw/3 4 5 6 7 8 9 10/) {
    $bps->add_radiobutton(-label => $_,
			  -variable => \$Opt->{Nbar},
			  -font => 'TkMenuFont',
			  -command => sub{$tab->drawPageWin();
					  main::setEdited(1);
					  config($opt, $oidx, 'Bars/Stave', $Opt->{Nbar});
					  $Opt->saveOne('Nbar');
			  });
  }
  $Opts{ent}[++$oidx] = {text => 'Edit Scale', var => \$Opt->{EditScale}};
  my $es = $opt->new_menu;
  $opt->add_cascade(-menu => $es,
		    -font => 'TkMenuFont',
		    -label => 'Edit Scale'." - $Opt->{EditScale}");
  foreach (qw/3 3.5 4 4.5 5 5.5 6/) {
    $es->add_radiobutton(-label => $_,
			 -variable => \$Opt->{EditScale},
			 -font => 'TkMenuFont',
			 -command => sub{CP::TabWin::editWindow($tab);
					 config($opt, $oidx, 'Edit Scale', $Opt->{EditScale});
					 $Opt->saveOne('EditScale');
			 });
  }
  $Opts{ent}[++$oidx] = {text => 'Instrument', var => \$Opt->{Instrument}};
  my $inst = $opt->new_menu;
  $opt->add_cascade(-menu => $inst,
		    -font => 'TkMenuFont',
		    -label => 'Instrument'." - $Opt->{Instrument}");
  foreach (@{$Opt->{Instruments}}) {
    $inst->add_radiobutton(-label => $_,
			   -variable => \$Opt->{Instrument},
			   -font => 'TkMenuFont',
			   -command =>
			   sub{$tab->drawPageWin();
			       main::setEdited(1);
			       config($opt, $oidx, 'Instrument', $Opt->{Instrument});
			       $Opt->saveOne('Instrument');
			   });
  }
  $Opts{ent}[++$oidx] = {text => 'Lyric Lines', var => \$Opt->{LyricLines}};
  my $ll = $opt->new_menu;
  $opt->add_cascade(-menu => $ll,
		    -font => 'TkMenuFont',
		    -label => 'Lyric Lines'." - $Opt->{LyricLines}");
  foreach (qw/0 1 2 3/) {
    $ll->add_radiobutton(-label => $_,
			 -variable => \$Opt->{LyricLines},
			 -font => 'TkMenuFont',
			 -command => sub{$tab->{lyrics}->adjust($Opt->{LyricLines});
					 $tab->drawPageWin();
					 main::setEdited(1);
					 config($opt, $oidx, 'Lyric Lines', $Opt->{LyricLines});
					 $Opt->saveOne('LyricLines');
			 });
  }
  $Opts{ent}[++$oidx] = {text => 'Lyric Spacing', var => \$tab->{lyricSpace}};
  my $ls = $opt->new_menu;
  $opt->add_cascade(-menu => $ls,
		    -font => 'TkMenuFont',
		    -label => 'Lyric Spacing'." - $tab->{lyricSpace}");
  foreach (qw/0 2 4 6 8 10 12 14 16 18 20/) {
    $ls->add_radiobutton(-label => $_,
			 -variable => \$tab->{lyricSpace},
			 -font => 'TkMenuFont',
			 -command => sub{$tab->drawPageWin();
					 main::setEdited(1);
					 config($opt, $oidx, 'Lyric Spacing', $tab->{lyricSpace});
			 });
  }
  $Opts{ent}[++$oidx] = {text => '', var => \$Opt->{SaveFonts}};
  $opt->add_checkbutton(-label => "Save Fonts",
			-variable => \$Opt->{SaveFonts},
			-font => 'TkMenuFont');
  $Opts{ent}[++$oidx] = {text => 'Set Key', var => \$tab->{key}};
  my $key = $opt->new_menu;
  $opt->add_cascade(-menu => $key,
		    -font => 'TkMenuFont',
		    -label => 'Set Key'." - $tab->{key}");
  no warnings; # stops perl bleating about '#' in array definition.
  foreach (qw/- Ab Abm A Am A# A#m Bb Bbm B Bm C Cm C# C#m Db Dbm D Dm D# D#m Eb Ebm E Em F Fm F# F#m Gb Gbm G Gm G# G#m/) {
    $key->add_radiobutton(-label => $_,
			  -variable => \$tab->{key},
			  -font => 'TkMenuFont',
			  -command => sub{$tab->pageKey();
					  main::setEdited(1);
					  config($opt, $oidx, 'Set Key', $tab->{key});
			  });
  }
  use warnings;
  $Opts{ent}[++$oidx] = {text => 'Stave Gap', var => \$tab->{staveGap}};
  my $sg = $opt->new_menu;
  $opt->add_cascade(-menu => $sg,
		    -font => 'TkMenuFont',
		    -label => 'Stave Gap'." - $tab->{staveGap}");
  foreach (qw/0 1 2 3 4 5 6 8 9 10 11 12 13 14 16 18 20/) {
    $sg->add_radiobutton(-label => $_,
			 -variable => \$tab->{staveGap},
			 -font => 'TkMenuFont',
			 -command => sub{$tab->drawPageWin();
					 main::setEdited(1);
					 config($opt, $oidx, 'Stave Gap', $tab->{staveGap});
			 });
  }
  $Opts{ent}[++$oidx] = {text => 'String Spacing', var => \$Opt->{StaffSpace}};
  my $ss = $opt->new_menu;
  $opt->add_cascade(-menu => $ss,
		    -font => 'TkMenuFont',
		    -label => 'String Spacing'." - $Opt->{StaffSpace}");
  foreach (qw/6 7 8 9 10 11 12 13 14 15 16/) {
    $ss->add_radiobutton(-label => $_,
			 -variable => \$Opt->{StaffSpace},
			 -font => 'TkMenuFont',
			 -command => sub{$tab->drawPageWin();
					 CP::TabWin::editWindow($tab);
					 main::setEdited(1);
					 config($opt, $oidx, 'String Spacing', $Opt->{StaffSpace});
					 $Opt->saveOne('StaffSpace');
			 });
  }
  $Opts{ent}[++$oidx] = {text => 'Timing', var => \$tab->{Timing}};
  my $tim = $opt->new_menu;
  $opt->add_cascade(-menu => $tim,
		    -font => 'TkMenuFont',
		    -label => 'Timing'." - $tab->{Timing}");
  foreach (qw{2/4 3/4 4/4}) {
    $tim->add_radiobutton(-label => $_,
			  -variable => \$tab->{Timing},
			  -font => 'TkMenuFont',
			  -command => sub{my($t,$_t) = split('/', $tab->{Timing});
					  $tab->{BarEnd} = $t * 8;
					  $tab->drawPageWin();
					  CP::TabWin::editWindow($tab);
					  main::setEdited(1);
					  config($opt, $oidx, 'Timing', $tab->{Timing});
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
    if ($ep->{text} ne '') {
      $menu->entryconfigure($idx, -label => "$ep->{text} - ${$ep->{var}}");
    }
    $idx++;
  }
  foreach my $i (0..9) {
    my $fn = (defined $Opt->{RecentTab}[$i]) ? $Opt->{RecentTab}[$i] : '. . .';
    $Recent->entryconfigure($i,
			    -label => $fn,
			    -command => sub{
			      if ($fn ne '. . .') {
				my $tab = CP::Tab->new("$Path->{Tab}/$fn");
				$tab->drawPageWin();
				$Opt->add2recent($fn, 'RecentTab', \&refresh);
			      }
			    }
	);
  }
}

sub config {
  my($menu,$idx,$opt,$val) = @_;

  $menu->entryconfigure($idx, -label => "$opt - $val");
}

sub openTab {
  my $fn = (CP::Browser->new($MW, TABBR, $Path->{Tab}, '.tab'))[0];
  if ($fn ne '') {
    my $tab = CP::Tab->new("$Path->{Tab}/$fn");
    $tab->drawPageWin();
    $Opt->add2recent($fn, 'RecentTab', \&refresh);
  }
}

sub newTab {
  my($tab) = shift;

  if ($tab->checkSave() ne 'Cancel') {
    if ($tab->{fileName} eq '') {
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
      $tab->{fileName} = $fn;
    }
    $tab = CP::Tab->new("$Path->{Tab}/$tab->{fileName}");
    $tab->drawPageWin();
    main::tabTitle($tab, $tab->{fileName});
    $Opt->add2recent($tab->{fileName}, 'RecentTab', \&refresh);
  }
}

sub closeTab {
  my($tab) = shift;

  if ($tab->checkSave() ne 'Cancel') {
    $tab = CP::Tab->new('');
    $tab->drawPageWin();
  }
}

sub delTab {
  my($tab) = shift;

  if ($tab->{fileName} ne '') {
    my $ans = msgYesNo("Do you really want to delete\n  $tab->{fileName}");
    return if ($ans eq "No");
    unlink("$Path->{Tab}/$tab->{fileName}");
    $tab = CP::Tab->new('');
    $tab->drawPageWin();
  }
}

sub renameTab {
  my($tab) = shift;

  if ($tab->{fileName} ne '') {
    my $ofn = $tab->{fileName};
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
    $tab->{fileName} = $newfn;
    main::tabTitle($tab, "$newfn");
    $Opt->add2recent($newfn, 'RecentTab', \&refresh);
  } else {
    Tkx::bell();
  }
}

sub exportTab {
  my($tab) = shift;

  if ($tab->{loaded} == 0) {
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
    if ($tab->save($dest, 0) == 1) {
      # We now have the current Tab in a temporary file: "$Path->{Temp}/$tab->{fileName}"
      my $tmp = "$Path->{Temp}/$tab->{fileName}";
      my $txt = read_file($tmp);
      if (write_file("$dest/$tab->{fileName}", $txt) == 1) {
	unlink($tmp);
      } else {
	message(SAD, "Failed to write \"$tab->{fileName}\" to \"$dest\"\nOriginal is in: \"$tmp\"");
	return;
      }
      message(SMILE, "\"$tab->{fileName}\" Exported", -1);
    }
  }
}

sub exitTab {
  my($tab) = CP::Tab::getTab();  # We need the current definition of $Tab
  if ($tab->checkSave() ne 'Cancel') {
    $MW->g_destroy();
    exit(0);
  }
}

sub saveCloseTab {
  my($tab) = shift;

  $tab->save();
  CP::TabPDF::make($tab, 'M');
  $tab = $tab->new('');
  $tab->drawPageWin();
}

sub mediaEdit {
  my($tab) = shift;

  if ($Media->edit() eq "OK") {
    $tab->drawPageWin();
  }
}

sub fontEdit {
  my($tab) = shift;

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
    $tab->drawPageWin();
  } else {
    $mcopy->copy($Media);
    $Media->save();
  }
  $pop->popDestroy();
}

1;
