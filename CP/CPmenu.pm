package CP::CPmenu;

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
use CP::Global qw/:FUNC :WIN :VERS :OPT :PRO/;
use CP::CHedit qw(&CHedit);
use CP::Cmsg;

our $Recent;

#
# Not really a module in the strictest sense
# but a way to keep all the menu code together.
#
sub new {
  my($m,$menu,$file,$edit,$opt,$media,$setl,$misc,$help);
  if (OS eq 'aqua') {
    $m = $MW->new_menu();
    $menu = Tkx::widget->new(Tkx::menu($m->_mpath . ".apple"));
    $m->add_cascade(-menu => $menu);
  } else {
    $menu = $MW->new_menu();
    $MW->configure(-menu => $menu);
  }
  $file  = $menu->new_menu();
  $edit  = $menu->new_menu();
  $opt   = $menu->new_menu();
  $misc  = $menu->new_menu();
  $help  = $menu->new_menu();

  $menu->add_cascade(-menu => $file, -label => "File");
  $menu->add_cascade(-menu => $edit, -label => "Edit");
  $menu->add_cascade(-menu => $opt,  -label => "Options");
  $menu->add_cascade(-menu => $misc, -label => "Misc");
  $menu->add_cascade(-menu => $help, -label => "Help");

  $file->add_command(-label => "New ChordPro", -command => \&main::newProFile);
  $file->add_command(-label => "Open File(s)", -command => [\&main::selectFiles, FILE]);
  $file->add_command(-label => "From Setlist", -command => \&CP::Chordy::fromSetlist);
  {
    $Recent = $file->new_menu;
    $file->add_cascade(-menu => $Recent, -label => 'Recent');
    foreach my $i (0..9) {
      my $fn = (defined $Opt->{RecentPro}[$i]) ? $Opt->{RecentPro}[$i] : '. . .';
      $Recent->add_command(-label => $fn,
			   -command => sub{
			     if ($fn ne '. . .') {
			       main::showSelection([$fn]);
			     }
			   });
    }
  }
  $file->add_command(-label => "Revert",
		     -command => sub{
		       my $fn = (CP::Browser->new($MW, FILE, $Path->{Pro}, '.pro'))[0];
		       if ($fn eq '') {
			 message(SAD, "You don't appear to have selected a ChordPro file.");
			 return;
		       }
		       RevertTo(undef, $fn);
		     });
  $file->add_separator;
  $file->add_command(-label => "Import ChordPro", -command => \&main::impProFile);
  {
    my $exp = $file->new_menu();
    $file->add_cascade(-menu => $exp, -label => 'Export');
    $exp->add_command(-label => 'One ChordPro',
		      -command => sub{main::expFile($Path->{Pro}, '.pro', 1)});
    $exp->add_command(-label => 'All ChordPros',
		      -command => sub{main::expFile($Path->{Pro}, '.pro')});
    $exp->add_separator;
    $exp->add_command(-label => 'One PDF',
		      -command => sub{main::expFile($Path->{PDF}, '.pdf', 1)});
    $exp->add_command(-label => 'All PDFs',
		      -command => sub{main::expFile($Path->{PDF}, '.pdf')});
  }
  {
    my $mail = $file->new_menu();
    $file->add_cascade(-menu => $mail, -label => 'Mail');
    $mail->add_command(-label => 'One ChordPro',
		       -command => sub{main::mailFile($Path->{Pro}, '.pro', 1)});
    $mail->add_command(-label => 'All ChordPros',
		       -command => sub{main::mailFile($Path->{Pro}, '.pro')});
    $mail->add_separator;
    $mail->add_command(-label => 'One PDF',
		       -command => sub{main::mailFile($Path->{PDF}, '.pdf', 1)});
    $mail->add_command(-label => 'All PDFs',
		       -command => sub{main::mailFile($Path->{PDF}, '.pdf')});
  }
  $file->add_command(-label => "Sync Collection", -command => [\&CP::Chordy::syncFiles, $Path->{Pro}, 'pro']);
  $file->add_separator;
  $file->add_command(-label => "Exit", -command => sub{exit(0)});

  $edit->add_command(-label => "Chord Editor",  -command => sub{CHedit('Save');});
  $edit->add_separator;
  $edit->add_command(-label => 'Collections',   -command => \&CP::Chordy::collEdit);
  $edit->add_command(-label => 'PDF Page Size', -command => sub{CP::Chordy::newMedia() if ($Media->edit() eq "OK");});
  $edit->add_command(-label => 'Sort Articles', -command => \&main::editArticles);
  $edit->add_command(-label => 'Options File',  -command => [\&CP::Editor::Edit, $Path->{Option}, 1]);

  my @cbopts = (
    -compound => 'left',
    -indicatoron => 0,
    -image => 'xtick',
    -selectimage => 'tick'
  );
  {
    my $op = $opt->new_menu;
    $opt->add_cascade(-menu => $op, -label => 'PDFs');
    $op->add_checkbutton(-label => " View",
			 -variable => \$Opt->{PDFview},
			 -command => sub{$Opt->saveOne('PDFview')},
			 @cbopts );
    $op->add_checkbutton(-label => " Create",
			 -variable => \$Opt->{PDFmake},
			 -command => sub{$Opt->saveOne('PDFmake')},
			 @cbopts );
    $op->add_checkbutton(-label => " Print",
			 -variable => \$Opt->{PDFprint},
			 -command => sub{$Opt->saveOne('PDFprint')},
			 @cbopts );
  }
  {
    my $ol = $opt->new_menu;
    $opt->add_cascade(-menu => $ol, -label => 'Lyrics');
    $ol->add_checkbutton(-label => " Center Lyrics",
			 -variable => \$Opt->{Center},
			 -command => sub{$Opt->saveOne('Center')},
			 @cbopts);
    $ol->add_checkbutton(-label => " Lyrics Only",
			 -variable => \$Opt->{LyricOnly},
			 -command => sub{$Opt->saveOne('LyricOnly')},
			 @cbopts );
    $ol->add_checkbutton(-label => " Group Lines",
			 -variable => \$Opt->{Together},
			 -command => sub{$Opt->saveOne('Together')},
			 @cbopts );
    $ol->add_checkbutton(-label => " 1/2 Ht Blank Lines",
			 -variable => \$Opt->{HHBL},
			 -command => sub{$Opt->saveOne('HHBL')},
			 @cbopts );
    {
      my $ls = $opt->new_menu;
      $opt->add_cascade(-menu => $ls, -label => 'Line Spacing');
      foreach (qw{0 1 2 3 4 5 6 7 8 9 10 12 14 16 18 20}) {
	$ls->add_radiobutton(-label => $_,
			     -variable => \$Opt->{LineSpace},
			     -command => sub{$Opt->saveOne('LineSpace')} );
      }
    }
  }
  $opt->add_separator;
  $opt->add_checkbutton(-label => " Highlight full line",
			-variable => \$Opt->{FullLineHL},
			-command => sub{$Opt->saveOne('FullLineHL')},
			 @cbopts ); 
  $opt->add_checkbutton(-label => " Highlight Border",
			-variable => \$Opt->{BorderHL},
			-command => sub{$Opt->saveOne('BorderHL')},
			 @cbopts ); 
  $opt->add_checkbutton(-label => " Comment full line",
			-variable => \$Opt->{FullLineCM},
			-command => sub{$Opt->saveOne('FullLineCM')},
			 @cbopts );
  $opt->add_checkbutton(-label => " Comment Border",
			-variable => \$Opt->{BorderCM},
			-command => sub{$Opt->saveOne('BorderCM')},
			 @cbopts );
  $opt->add_separator;
  $opt->add_checkbutton(-label => " Ignore Capo Directives",
			-variable => \$Opt->{IgnCapo},
			-command => sub{$Opt->saveOne('IgnCapo')},
			 @cbopts ); 
  $opt->add_checkbutton(-label => " No Long Line warnings",
			-variable => \$Opt->{NoWarn},
			-command => sub{$Opt->saveOne('NoWarn')},
			 @cbopts );
  $opt->add_checkbutton(-label => " Show Labels",
			-variable => \$Opt->{ShowLabels},
			-command => sub{$Opt->saveOne('ShowLabels')},
			 @cbopts );
    {
      my $ls = $opt->new_menu;
      $opt->add_cascade(-menu => $ls, -label => 'Label Background %');
      foreach (-15..15) {
	$ls->add_radiobutton(-label => $_,
			     -variable => \$Opt->{LabelPC},
			     -command => sub{$Opt->saveOne('LabelPC')} );
      }
    }

  $opt->add_separator;
  $opt->add_command(-label => 'Defaults', -command => sub{$Opt->resetOpt()});
  
  $misc->add_command(-label => 'View Error Log',     -command => \&viewElog);
  $misc->add_command(-label => 'Clear Error Log',    -command => \&clearElog);
  $misc->add_command(-label => 'View Release Notes', -command => \&viewRelNt);
  $misc->add_separator;
  $misc->add_command(-label => "Delete ChordPro Backups", -command => [\&DeleteBackups, '.pro']);
  $misc->add_command(-label => "Delete Temporary PDFs",   -command => [\&DeleteBackups, '.pdf']);
  $misc->add_separator;
  $misc->add_command(-label => "Commands", -command => \&CP::Chordy::commandWin);

  $help->add_command(-label => 'Help',  -command => \&CP::HelpCh::help);
  $help->add_command(-label => 'About', -command => sub{message(SMILE, "Version $Version\nian\@houlding.me.uk");});
  if (OS eq 'aqua') {
    $MW->configure(-menu => $m);
  }
}

sub refreshRcnt {
  foreach my $i (0..9) {
    my $fn = (defined $Opt->{RecentPro}[$i]) ? $Opt->{RecentPro}[$i] : '. . .';
    $Recent->entryconfigure($i,
			    -label => $fn,
			    -command => sub{
			      if ($fn ne '. . .') {
				main::showSelection([$fn]);
			      }
			    }
	);
  }
}

1;
