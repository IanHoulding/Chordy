package CP::Chordy;

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
use CP::Cconst qw/:OS :LENGTH :TEXT :SHFL :INDEX :PDF :BROWSE :SMILIE :COLOUR/;
use CP::Global qw(:FUNC :VERS :PATH :OPT :PRO :SETL :XPM :WIN :MEDIA);
use CP::Pop qw /:MENU/;
use CP::CHedit;
use CP::FgBgEd;
use CP::List;
use CP::Opt;
use CP::Cmsg;
use CP::Fonts;
use CP::SetList;
use CP::Browser;
use CP::HelpCh;

our $Chordy = {};

sub new {
  my($proto) = @_;
  my $class = ref($proto) || $proto;
  bless $Chordy, $class;

  # The main window is composed of 2 areas:
  # 1) A top NoteBook with 3 tabs.
  # 2) A bottom Frame that contains the Help & Exit buttons.

  $Chordy->{nb} = my $NB = $MW->new_ttk__notebook();
  $NB->g_pack(qw/-side top -expand 1 -fill both/);

  my $butf = $MW->new_ttk__frame(-padding => [0,8,0,8]);
  $butf->g_pack(qw/-side bottom -fill x/);

  my $chordy = $NB->new_ttk__frame(-padding => [4,4,4,4]);
  $Chordy->{setLst} = my $setLst = $NB->new_ttk__frame(-padding => [4,4,4,4]);
  $Chordy->{opts}   = my $opts   = $NB->new_ttk__frame(-padding => [4,4,4,4]);
  $Chordy->{misc}   = my $misc   = $NB->new_ttk__frame(-padding => [4,4,4,4]);
#  $Chordy->{made0nb} = 0; # Always made - see below.
  $Chordy->{made1nb} = 0;
  $Chordy->{made2nb} = 0;
  $Chordy->{made3nb} = 0;
  $NB->add($chordy, -text => '  Chordy PDF Generator  ');
  $NB->add($setLst, -text => '  Setlists  ');
  $NB->add($opts,   -text => '  Configuration Options  ');

  $NB->g_bind('<<NotebookTabChanged>>', [\&notebookTabSelect, $Chordy]);

  #### Bottom Button Frame
  my $about = $butf->new_ttk__button(
    -text => 'About',
    -style => 'Green.TButton',
    -command => sub{message(SMILE, "Version $Version\nian\@houlding.me.uk");});

  my $help = $butf->new_ttk__button(
    -text => 'Help',
    -style => 'Green.TButton',
    -command => [\&CP::HelpCh::help] );

  my $ext = $butf->new_ttk__button(
    -text => 'Exit',
    -style => 'Red.TButton',
    -command => sub{$MW->g_destroy();exit(0)});

  $about->g_pack(qw/-side left -padx/ => [60,0]);
  $help->g_pack(qw/-side left -padx 20/);
  $ext->g_pack(qw/-side right -padx 60/);

#### This is NoteBook Tab 0 and is always made and displayed first.
#### Chordy PDF Generator Tab
  $Chordy->{currentColl} = '';
  $Chordy->{collectionPath} = '';
  my $ctf = $chordy->new_ttk__labelframe(-text => " ChordPro Files ", -padding => [4,4,4,4]);
  filesWin($ctf);

  my $cmf = $chordy->new_ttk__labelframe(-text => " PDF Options ", -padding => [4,4,4,4]);
  optWin($cmf);

  $ctf->g_pack(qw/-side top -anchor n -expand 0 -fill x -pady 4/);
  $cmf->g_pack(qw/-side top -anchor n -expand 0 -fill x -pady 4/);

  $NB->select(0);
  $chordy->g_focus();
}

sub notebookTabSelect {
  my($Chordy) = shift;

  my $idx = $Chordy->{nb}->m_index('current');
  if ($idx == 1) {
    if ($Chordy->{made1nb} == 0) {
      setLists();
      $Chordy->{made1nb} = 1;
    }
  } elsif ($idx == 2) {
    if ($Chordy->{made2nb} == 0) {
      confOpts();
      $Chordy->{made2nb} = 1;
    } else {
      fontWin();
    }
  }
#  elsif ($idx == 3) {
#    if ($Chordy->{made3nb} == 0) {
#      miscOpts();
#      $Chordy->{made3nb} = 1;
#    }
#  }
}

##
## Configuration Options NoteBook Tab
##
sub confOpts {
  my $opts = $Chordy->{opts};

  my $tf = $opts->new_ttk__frame();
  my $col = $tf->new_ttk__labelframe(-text => " Collection ", -padding => [4,0,4,4]);
  my $sz = $tf->new_ttk__labelframe(-text => " PDF Page Size ", -padding => [4,0,4,4]);
  collectionWin($col);
  mediaWin($sz);

  $Chordy->{fontFr} = $opts->new_ttk__labelframe(-text => " PDF Fonts - Colour and Size ",
						 -padding => [4,0,4,8]);
  fontWin();

  my $bgf = $opts->new_ttk__labelframe(-text => " PDF Background Colours ",
				       -padding => [4,0,4,0]);
  bgWin($bgf);

  my $cf = $opts->new_ttk__labelframe(-text => " Chordy Appearance ");
  lookFrm($cf);

#  my $cmd = $opts->new_ttk__labelframe(-text => " Commands ", -padding => [4,4,4,4]);
#  commandWin($cmd);

#  my $bf = $opts->new_ttk__frame(); #-padding => [0,16,0,0]);
#  CP::Win::defButtons($bf, 'Media', \&main::saveMed, \&main::loadMed, \&main::resetMed);

  my $fw = $Chordy->{fontFr};
  $tf->g_pack( qw/-side top -fill x/, -pady => [4,0]);
  $col->g_pack(qw/-side left -anchor n -expand 1 -fill both/, -padx => [0,8]);
  $sz->g_pack( qw/-side right -anchor n /);

  $fw->g_pack( qw/-side top -anchor n -expand 1 -fill both/, -pady => [12,0]);
  $bgf->g_pack(qw/-side top -anchor n -expand 1 -fill both/, -pady => [12,0]);

  $cf->g_pack(qw/-side top -fill x/, -pady => [12,0]);
#  $cmd->g_pack(qw/-side top -fill x/, -pady => [12,0]);
 # $bf->g_pack( qw/-side bottom -pady 4 -fill x/);
}

##
## Misc Options Tab
##
#sub miscOpts {
#  my $misc = $Chordy->{misc};
#  my $ff = $misc->new_ttk__labelframe(-text => " File ");
#  $ff->g_pack(qw/-side top -fill x/, -pady => [8,0]);
#
#  my $of = $misc->new_ttk__labelframe(-text => " Options ");
#  $of->g_pack(qw/-side top -fill x/, -pady => [16,0]);
#
#  my $cf = $misc->new_ttk__labelframe(-text => " Appearance ");
#  $cf->g_pack(qw/-side top -fill x/, -pady => [16,0]);
#
#  my $cmd = $misc->new_ttk__labelframe(-text => " Commands ", -padding => [4,4,4,4]);
#  $cmd->g_pack(qw/-side top -fill x/, -pady => [16,0]);
#
#  fileFrm($ff);
#  optFrm($of);
#  lookFrm($cf);
#  commandWin($cmd);
#}

###############################
# Now all the various windows #
###############################

##########
##
## CHORDY
##
##########

sub filesWin {
  my($Fff) = @_;

  my $tFl = $Fff->new_ttk__frame();
  my $tFm = $Fff->new_ttk__frame();
  my $tFr = $Fff->new_ttk__labelframe(-text => ' Single File ');
  my $tFb = $Chordy->{ProgFrm} = $Fff->new_ttk__frame(-style => 'Pop.TFrame',
						      -relief => 'raised',
						      -borderwidth => 2,
						      -padding => [4,0,4,4]);

#  $Fff->g_grid_columnconfigure(0, -weight => 1);
#  $Fff->g_grid_columnconfigure(2, -weight => 1);
  $tFl->g_grid(qw/-row 0 -column 0 -sticky nsw -padx 16/);
  $tFm->g_grid(qw/-row 0 -column 1 -sticky nsw -padx 16/);
  $tFr->g_grid(qw/-row 0 -column 2 -sticky nsw -padx 16/, -pady => [0,8]);
  $tFb->g_grid(qw/-row 1 -column 0 -columnspan 3 -sticky ew -padx 16/, -pady => [4,0]);

###
  my $onee = $tFr->new_ttk__button(
    -text => "Edit",
    -width => 8,
    -command => \&main::editPro);
  my $oner = $tFr->new_ttk__button(
    -text => "Rename",
    -width => 8,
    -command => \&main::renamePro);
  my $onec = $tFr->new_ttk__button(
    -text => "Clone",
    -width => 8,
    -command => \&main::clonePro);
  my $oned = $tFr->new_ttk__button(
    -text => "Delete",
    -width => 8,
    -style => 'Red.TButton',
    -command => \&main::deletePro);
  Tkx::ttk__style_configure("Tr.Menu.TButton", -background => '#FFD0D0');
  my $onet = $tFr->new_ttk__button(
    -text => "Transpose",
    -width => 10,
    -style => 'Tr.Menu.TButton',
    -command => sub{$main::PDFtrans = 1;main::transposeOne(SINGLE);});
  no warnings; # stops perl bleating about '#' in array definition.
  my $onek = $tFr->new_ttk__button(
    -textvariable => \$Opt->{Transpose},
    -width => 3,
    -style => 'Tr.Menu.TButton',
    -command => sub{popMenu(
		      \$Opt->{Transpose},
		      undef,
		      [qw/No Ab A A# Bb B C C# Db D D# Eb E F F# Gb G G#/])
    });
  use warnings;

### Now pack everything
  # Single Selected File --- has to be packed first.
  $onee->g_pack(qw/-side top -padx 6 -pady 4/);
  $oner->g_pack(qw/-side top -padx 6 -pady 4/);
  $onec->g_pack(qw/-side top -padx 6 -pady 4/);
  $oned->g_pack(qw/-side top -padx 6 -pady 16/);
  $onek->g_pack(qw/-side bottom -padx 6/, -pady => [0,4]);
  $onet->g_pack(qw/-side bottom -padx 6/, -pady => [0,4]);

### Key/Files

  $KeyLB = CP::List->new($tFl, '', qw/-height 18 -width 4/);
  $FileLB = CP::List->new($tFl, 'e', qw/-height 18 -selectmode browse -takefocus 1/, -width => (SLWID + 4));

  $FileLB->{lb}->configure(-yscrollcommand => [sub{scroll_filelb($FileLB->{yscrbar}, @_)}]);
  $FileLB->{yscrbar}->m_configure(-command => sub {$KeyLB->{lb}->yview(@_);$FileLB->{lb}->yview(@_);});

  $KeyLB->{frame}->g_pack (qw/-side left -fill y -ipadx 1 -padx 1/);
  $FileLB->{frame}->g_pack(qw/-side left -fill y -ipadx 1/);

###
  my $brw = $tFm->new_ttk__button(
    -text => "Browse ...",
    -command => sub{main::selectFiles(FILE)} );

  my $fsl = $tFm->new_ttk__button(
    -text => "From Setlist",
    -command => sub{$Chordy->{nb}->m_select(1)});

  my $act = $tFm->new_ttk__labelframe(
    -text => " PDFs ",
    -labelanchor => 'n',
      );
  actWin($act);

  my $cob = $tFm->new_ttk__button(
    -text => "Collection",
    -command => sub{$Chordy->{currentColl} = $Collection->name();
		    popMenu(\$Chordy->{currentColl}, undef, [sort keys %{$Collection}]);
		    $Collection->change($Chordy->{currentColl});
		    collItems($Chordy);} );

  ## Browse/From Setlist/PDFs
  $brw->g_pack(qw/-side top -pady 4/);
  $fsl->g_pack(qw/-side top -pady 4/);
  $act->g_pack(qw/-side top -pady 8/);  # LabelFrame
  $cob->g_pack(qw/-side top -pady 8/);

  my $progl = $tFb->new_ttk__label(-text => "Please Wait .... PDF'ing: ", -style => 'Pop.TLabel');
  Tkx::ttk__style_configure('Prog.Pop.TLabel', -font => "BTkDefaultFont");

  my $proge = $Chordy->{ProgLab} = $tFb->new_ttk__label(-text => '',
							-width => SLWID + 4,
							-style => 'Prog.Pop.TLabel');
  $Chordy->{ProgCan} = 0;
  my $progc = $tFb->new_ttk__button(-text => ' Cancel ',
				    -style => 'Red.TButton',
				    -command => sub{$Chordy->{ProgCan} = 1; Tkx::update();});

  $progl->g_pack(qw/-side left/);
  $proge->g_pack(qw/-side left/);
  $progc->g_pack(qw/-side left -padx 8/, -pady => [4,0]);
  $tFb->g_grid_forget();
}

# This method is called when one Listbox is scrolled with the keyboard
# It makes the Scrollbar reflect the change, and scrolls the other lists
sub scroll_filelb {
  my($sb, @args) = @_;
  $sb->set(@args); # tell the Scrollbar what to display
  my($top,$bot) = split(' ', $FileLB->{lb}->yview());
  $KeyLB->{lb}->yview_moveto($top);
}

sub fromSetlist {
  $Chordy->{nb}->m_select(1);
}

sub actWin {
  my($act) = shift;

  ####
  my $view = $act->new_ttk__checkbutton(-text => "View",
					-variable => \$Opt->{PDFview},
					-command => sub{$Opt->saveOne('PDFview')});
  my $cret = $act->new_ttk__checkbutton(-text => "Create",
					-variable => \$Opt->{PDFmake},
					-command => sub{$Opt->saveOne('PDFmake')});
  my $prnt = $act->new_ttk__checkbutton(-text => "Print",
					-variable => \$Opt->{PDFprint},
					-command => sub{$Opt->saveOne('PDFprint')});

  ####
  my $sepa = $act->new_ttk__separator(qw/-orient horizontal/);
  my $ones = $act->new_ttk__button(-text => "Single Song", -command => sub{main::Main($Chordy,SINGLE);});
  my $sepb = $act->new_ttk__separator(qw/-orient horizontal/);
  my $alls = $act->new_ttk__button(
    -text => "All Songs",
    -width => 8,
    -command => sub{main::Main($Chordy,MULTIPLE);});
  my $onep = $act->new_ttk__checkbutton(
    -text => "Single PDF",
    -offvalue => MULTIPLE,
    -onvalue => SINGLE,
    -variable => \$Opt->{OnePDFfile});

  $view->g_pack(qw/-side top -anchor w -padx 8/);
  $cret->g_pack(qw/-side top -anchor w -padx 8/);
  $prnt->g_pack(qw/-side top -anchor w -padx 8/);

  $sepa->g_pack(qw/-side top -fill x/, -pady => [4,0]);
  $ones->g_pack(qw/-side top -padx 4 -pady 8/);

  $sepb->g_pack(qw/-side top -fill x/);
  $alls->g_pack(qw/-side top -padx 4/, -pady => [8,4]);
  $onep->g_pack(qw/-side top -anchor w/);
}

sub optWin {
  my($frm) = shift;

  my $wid = $frm->new_ttk__frame();
  $wid->g_pack(qw/-side left -anchor n/);

  my($a,$b,$c,$d,$e,$f,$g,$h,$z);
  #########################

  $a = $wid->new_ttk__checkbutton(-text => 'Center Lyrics',
				  -variable => \$Opt->{Center},
				  -command => sub{$Opt->saveOne('Center')});
  $b = $wid->new_ttk__checkbutton(-text => 'Lyrics Only',
				  -variable => \$Opt->{LyricOnly},
				  -command => sub{$Opt->saveOne('LyricOnly')});
  $c = $wid->new_ttk__checkbutton(-text => 'Group Lines',
				  -offvalue => MULTIPLE,
				  -onvalue => SINGLE,
				  -variable => \$Opt->{Together},
				  -command => sub{$Opt->saveOne('Together')});
  $d = $wid->new_ttk__checkbutton(-text => '1/2 Height Blank Lines',
				  -variable => \$Opt->{HHBL},
				  -command => sub{$Opt->saveOne('HHBL')});
  $z = $wid->new_ttk__button(
    -text => ' PDF Background ',
    -style => 'PDF.TButton',
    -command => sub{
      CP::FgBgEd->new('PDF Background');
      my($fg,$bg) = $ColourEd->Show(BLACK, $Opt->{PageBG}, BACKGRND);
      if ($bg ne '') {
	$Opt->{PageBG} = $bg;
	$Opt->saveOne('PageBG');
	Tkx::ttk__style_configure("PDF.TButton", -background => $bg);
      }
    });
  $e = $wid->new_ttk__checkbutton(-text => "No Long Line warnings",
				  -variable => \$Opt->{NoWarn},
				  -command => sub{$Opt->saveOne('NoWarn')});
  $f = $wid->new_ttk__checkbutton(-text => "Ignore Capo Directives",
				  -variable => \$Opt->{IgnCapo},
				  -command => sub{$Opt->saveOne('IgnCapo')});
  $g = $wid->new_ttk__checkbutton(-text => "Highlight full line",
				  -variable => \$Opt->{FullLineHL},
				  -command => sub{$Opt->saveOne('FullLineHL')});
  $h = $wid->new_ttk__checkbutton(-text => "Comment full line",
				  -variable => \$Opt->{FullLineCM},
				  -command => sub{$Opt->saveOne('FullLineCM')});

  $a->g_grid(qw/-row 0 -column 0 -sticky w -pady 1/, -padx => [0,12]);
  $b->g_grid(qw/-row 1 -column 0 -sticky w -pady 1/, -padx => [0,12]);
  $c->g_grid(qw/-row 2 -column 0 -sticky w -pady 1/, -padx => [0,12]);
  $d->g_grid(qw/-row 3 -column 0 -sticky w -pady 1/, -padx => [0,12]);
  $z->g_grid(qw/-row 4 -column 0 -sticky w -pady 6/, -padx => [0,12]);

  $e->g_grid(qw/-row 0 -column 1 -sticky w -pady 1/, -padx => [0,12]);
  $f->g_grid(qw/-row 1 -column 1 -sticky w -pady 1/, -padx => [0,12]);
  $g->g_grid(qw/-row 2 -column 1 -sticky w -pady 1/, -padx => [0,12]);
  $h->g_grid(qw/-row 3 -column 1 -sticky w -pady 1/, -padx => [0,12]);
  ################
  
  $a = $wid->new_ttk__label(-text => "Line Spacing:");
  $b = $wid->new_ttk__button(
    -textvariable => \$Opt->{LineSpace},
    -style => 'Menu.TButton',
    -width => 3,
    -command => sub{popMenu(\$Opt->{LineSpace},undef,[qw/1 2 3 4 5 6 7 8 9 10 12 14 16 18 20/]);
		    $Opt->saveOne('LineSpace');});

  $Opt->{Capo} = "No";
  $c = $wid->new_ttk__label(-text => "Capo On:");
  $d = $wid->new_ttk__button(
    -textvariable => \$Opt->{Capo},
    -style => 'Menu.TButton',
    -width => 3,
    -command => sub{popMenu(\$Opt->{Capo}, sub{$Opt->{Capo} = 'No' if ($Opt->{Capo} == 0)}, [0..12])});

  $Opt->{Transpose} = "No";
  $e = $wid->new_ttk__label(-text => "Transpose To:");
  no warnings; # stops perl bleating about '#' in array definition.
  $f = $wid->new_ttk__button(
    -textvariable => \$Opt->{Transpose},
    -width => 3,
    -style => 'Menu.TButton',
    -command => sub{popMenu(
		      \$Opt->{Transpose},
		      undef,
		      [qw/No Ab A A# Bb B C C# Db D D# Eb E F F# Gb G G#/])
    });
  use warnings;

  $g = $wid->new_ttk__radiobutton(-text => "Force Sharp",
				  -variable => \$Opt->{SharpFlat}, -value => SHARP);
  $h = $wid->new_ttk__radiobutton(-text => "Force Flat",
				  -variable => \$Opt->{SharpFlat}, -value => FLAT);

  $a->g_grid(qw/-row 0 -column 2 -sticky e/, -padx => [4,0]);
  $b->g_grid(qw/-row 0 -column 3 -sticky w/, -padx => [2,4]);

  $c->g_grid(qw/-row 1 -column 2 -sticky e/, -padx => [4,0]);
  $d->g_grid(qw/-row 1 -column 3 -sticky w/, -padx => [2,4]);

  $e->g_grid(qw/-row 2 -column 2 -sticky e/, -padx => [4,0]);
  $f->g_grid(qw/-row 2 -column 3 -sticky w/, -padx => [2,4]);

  $g->g_grid(qw/-row 3 -column 2 -columnspan 2 -sticky w/, -padx => [14,0]);
  $h->g_grid(qw/-row 4 -column 2 -columnspan 2 -sticky nw/, -padx => [14,0]);

  ################
  my $mrgn = $wid->new_ttk__labelframe(-text => " Margins ", -padding => [4,2,0,4]);
  $mrgn->g_grid(qw/-row 5 -column 0 -columnspan 4 -sticky we/);

  Tkx::ttk__style_configure("TSpinbox",
			    -foreground => $Opt->{MenuFG},
			    -arrowcolor => BLACK,
			    -fieldbackground => $Opt->{MenuBG},
			    -background => $Opt->{MenuBG});
  my $col = 0;
  foreach my $m (qw/Left Right Top Bottom/) {
    $a = $mrgn->new_ttk__label(-text => "$m", -anchor => 'e');

    $b = $mrgn->new_ttk__spinbox(
      -textvariable => \$Opt->{"${m}Margin"},
      -style => 'TSpinbox',
      -from => 0,
      -to => 72,
      -wrap => 1,
      -width => 2,
      -command => sub{$Opt->saveOne("${m}Margin");});
    $a->g_grid(qw/-row 0 -sticky e/, -column => $col++);
    $b->g_grid(qw/-row 0 -sticky w/, -column => $col++, -padx => [2,16]);
  }

  ################
  my $fcd = $frm->new_ttk__labelframe(
    -text => " Chord Diagrams ",
    -labelanchor => 'n');
  $fcd->g_pack(qw/-side right -anchor n/, -padx => [2,4]);
  $a = $fcd->new_ttk__label(-text => "Instrument");
  $b = $fcd->new_ttk__button(
    -textvariable => \$Opt->{Instrument},
    -width => 9,
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$Opt->{Instrument},sub{readChords();},$Opt->{Instruments});
      $Opt->saveOne('Instrument');
    });

  $c = $fcd->new_ttk__radiobutton(-text => "None",
				  -variable => \$Opt->{Grid}, -value => NONE,
				  -command => sub{$Opt->saveOne('Grid')});
  $d = $fcd->new_ttk__radiobutton(-text => "First Page",
				  -variable => \$Opt->{Grid}, -value => FIRSTP,
				  -command => sub{$Opt->saveOne('Grid')});
  $e = $fcd->new_ttk__radiobutton(-text => "All Pages",
				  -variable => \$Opt->{Grid}, -value => ALLP,
				  -command => sub{$Opt->saveOne('Grid')});

  $a->g_grid(qw/-row 0 -column 0 -sticky e/, -pady => [4,0]);
  $b->g_grid(qw/-row 0 -column 1 -sticky w -padx 4/, -pady => [4,0]);
  $c->g_grid(qw/-row 1 -column 0 -columnspan 2 -sticky w -padx 4/);
  $d->g_grid(qw/-row 2 -column 0 -columnspan 2 -sticky w -padx 4/);
  $e->g_grid(qw/-row 3 -column 0 -columnspan 2 -sticky w -padx 4/);
}

##############
##
## Setlists
##
##############

sub setLists {
  my $frame = $Chordy->{setLst};
  my $slFt = $frame->new_ttk__frame(qw/-relief raised -borderwidth 2 -style Wh.TFrame/);
  my $slFb = $frame->new_ttk__frame();

  $AllSets = CP::SetList->new();
  my $browser = $AllSets->{browser} = browser($slFb, $Chordy->{nb});

  my $sltL = $slFt->new_ttk__labelframe(
    -text => ' Setlists ',
    -style => 'Wh.TLabelframe',
    -labelanchor => 'n',
    -padding => [4,0,4,4]);
  my $sltM = $slFt->new_ttk__frame(qw/-style Wh.TFrame/);
  my $sltCS = $slFt->new_ttk__labelframe(
    -text => ' Current Setlist ',
    -style => 'Wh.TLabelframe',
    -labelanchor => 'n',
    -padding => [4,0,4,4]);
  my $sltR = $slFt->new_ttk__frame(qw/-style Wh.TFrame/);

  my $setsLB;
  my $sltr = $sltM->new_ttk__checkbutton(-variable => \$Opt->{SLrev},
					 -style => 'Wh.TCheckbutton',
					 -command => sub{$Opt->saveOne('SLrev');
							 $AllSets->listSets();
					 });
  # This is a bit OTT but the only apparent way to get rotated text.
  my $can = $sltM->new_tk__canvas(-bg => WHITE,
				  -highlightthickness => 0,
				  -relief => 'solid',
				  -borderwidth => 0);
  my $rtxt = $can->create_text(0,0,
			       -text => 'Reverse Sort',
			       -font => 'BTkDefaultFont',
			       -justify => 'left',
			       -angle => 270);
  my($x1,$y1,$x2,$y2) = split(/ /, $can->bbox($rtxt));
  $can->configure(-width => abs($x1) + $x2, -height => abs($y1) + $y2);
  $can->move($rtxt, abs($x1), abs($y1));

  $setsLB = $AllSets->{setsLB} = CP::List->new($sltL, 'e',
					       -height => 12, -width => SLWID,
					       -selectmode => '');
  $setsLB->{frame}->g_grid(qw/-row 0 -column 0 -sticky nsew/);
  $setsLB->bind('<ButtonRelease-1>' => sub{$AllSets->showSet()});
  $AllSets->listSets();

  CORE::state $DT;
  if (! defined $DT) {
    $DT = CP::Date->new();
  }

  my $dsub = sub{
    my($key) = shift;
    my $kp = \%{$AllSets->{meta}};
    if ($DT->newDate($kp->{$key})) {
      $kp->{$key} = $AllSets->{sets}{$CurSet}{$key} = sprintf "%d %s %d", $DT->{day}, $DT->{months}, $DT->{year};
    }
  };
  my $tsub = sub{
    my($key) = shift;
    my $kp = \%{$AllSets->{meta}};
    $kp->{$key} = $AllSets->{sets}{$CurSet}{$key} = $DT->{time} if ($DT->newTime($kp->{$key}));
  };

  my($row,$st) = (0,'YNb.TLabel');
  foreach my $l (['Name',        '',     25],
		 ['Date',        'date', 18],
		 ['Setup',       'setup', 5]) {
    my($n,$v,$w) = @{$l};
    my $ent;
    my $lab = $sltCS->new_ttk__label(-text => $n, -background => WHITE);
    $lab->g_grid(-row => $row, -column => 0, -sticky => 'e', -pady => 3);
    if ($row == 0) {
      $ent = $sltCS->new_ttk__label(-textvariable => \$CurSet,
				    -style => 'YNb.TLabel',
				    -width => $w);
      $st = 'YNnf.TLabel';
    } else {
      $ent = $sltCS->new_ttk__button(-textvariable => \$AllSets->{meta}{$v},
				     -style => $st,
				     -width => $w,
				     -command => ($row == 1) ? [$dsub, $v] : [$tsub, $v] );
    }
    $ent->g_grid(-row => $row, -column => 1, -sticky => 'w', -padx => [4,0], -pady => 3);
    $row++;
  }

  my $labs = $sltCS->new_ttk__label(-text => 'Sound', -background => WHITE);
  my $scFr = $sltCS->new_ttk__frame(qw/-style Wh.TFrame/);
  my $buts = $scFr->new_ttk__button(-textvariable => \$AllSets->{meta}{'soundcheck'},
				    -style => $st,
				    -width => 5,
				    -command => [$tsub, 'soundcheck'] );
  my $labc = $scFr->new_ttk__label(-text => 'Check', -background => WHITE);
  $labs->g_grid(-row => $row, -column => 0, -sticky => 'e', -pady => 3);
  $scFr->g_grid(-row => $row, -column => 1, -sticky => 'w', -pady => 3);
  $buts->g_grid(-row => 0,    -column => 0, -padx => 4);
  $labc->g_grid(-row => 0,    -column => 1);
  $row++;

  makeImage('hyphen', \%XPM);
  my %list = (Tkx::SplitList(Tkx::font_actual("BTkDefaultFont")));
  $list{'-size'} += 10;
  Tkx::font_create("HyphenFont", %list);

  foreach my $set (1..2) {
    my $lab = $sltCS->new_ttk__label(-text => "Set $set", -background => WHITE);
    my $sFr = $sltCS->new_ttk__frame(qw/-style Wh.TFrame/);

    my $buts = $sFr->new_ttk__button(-textvariable => \$AllSets->{meta}{"s${set}start"},
				       -style => $st,
				       -width => 5,
				       -command => [$tsub, "s${set}start"] );
    my $h = $sFr->new_ttk__label(qw/-image hyphen -font HyphenFont/, -background => WHITE);
    my $bute = $sFr->new_ttk__button(-textvariable => \$AllSets->{meta}{"s${set}end"},
				       -style => $st,
				       -width => 5,
				       -command => [$tsub, "s${set}end"] );
    $lab->g_grid( -row => $row, -column => 0, -sticky => 'e', -pady => 3);
    $sFr->g_grid( -row => $row, -column => 1, -sticky => 'w', -pady => 3);
    $buts->g_grid(-row => 0,    -column => 0, -padx => 4);
    $h->g_grid(   -row => 0,    -column => 1);
    $bute->g_grid(-row => 0,    -column => 2, -padx => 4);
    $row++;
  }
  
  my $butNew = $sltR->new_ttk__button(
    -text => "New",
    -width => 8,
    -command => sub{slAct(SLNEW)});
  my $butRen = $sltR->new_ttk__button(
    -text => "Rename",
    -width => 8,
    -command => sub{slAct(SLREN)});
  my $butCln = $sltR->new_ttk__button(
    -text => "Clone",
    -width => 8,
    -command => sub{slAct(SLCLN)});
  my $butClr = $sltR->new_ttk__button(
    -text => "Clear",
    -width => 8,
    -style => 'Green.TButton',
    -command => sub{$browser->reset();$AllSets->select('')});
  my $butSav = $sltR->new_ttk__button(
    -text => "Save",
    -width => 8,
    -style => 'Green.TButton',
    -command => sub{saveSet($browser)});
  my $butDel = $sltR->new_ttk__button(
    -text => "Delete",
    -width => 8,
    -style => 'Red.TButton',
    -command => sub{slAct(SLDEL)} );

  my $butPrt = $slFt->new_ttk__button(
    -text => "Print",
    -width => 8,
    -style => 'Green.TButton',
    -command => \&CP::CPpdf::printSL);
  my $butInp = $slFt->new_ttk__button(
    -text => "Import",
    -width => 8,
    -style => 'Green.TButton',
    -command => sub{$AllSets->importSet()});
  my $butExp = $slFt->new_ttk__button(
    -text => "Export",
    -width => 8,
    -style => 'Green.TButton',
    -command => sub{$AllSets->export()});

  ## Now pack everything
  # Setlists
  $slFt->g_pack(qw/-side top -fill x/, -pady => [0,4]);
  # Browser
  $slFb->g_pack(qw/-side top -fill x/, -pady => [4,0]);

  $sltL->g_grid(qw/-row 0 -column 0 -rowspan 2 -sticky n/, -padx => [4,0], -pady => [0,4]);

  $sltM->g_grid(qw/-row 0 -column 1 -sticky n/, -padx => [4,0], -pady => [0,4]);
  $sltr->g_pack(qw/-side top -fill x/, -pady => [12,0]);
  $can->g_pack(qw/-side top -fill x -pady 0/);

  $sltCS->g_grid(qw/-row 0 -column 2 -columnspan 3 -sticky n/, -padx => [12,0]);

  # Print/Export/Save/Delete
  $butPrt->g_grid(qw/-row 1 -column 2/, -pady => [0,4]);
  $butInp->g_grid(qw/-row 1 -column 3/, -pady => [0,4]);
  $butExp->g_grid(qw/-row 1 -column 4/, -pady => [0,4]);

  $sltR->g_grid(qw/-row 0 -column 5 -padx 6 -pady 4/);
  # New/Rename/Clone/Delete buttons
  $butNew->g_pack(qw/-side top -padx 4 -pady 4/);
  $butRen->g_pack(qw/-side top -padx 4 -pady 4/);
  $butCln->g_pack(qw/-side top -padx 4 -pady 4/);
  $butClr->g_pack(qw/-side top -padx 4 -pady 4/);
  $butSav->g_pack(qw/-side top -padx 4 -pady 4/);
  $butDel->g_pack(qw/-side top -padx 4/, -pady => [12,0]);
}

sub browser {
  my($frame,$NB) = @_;

  my $browse = CP::Browser->new($frame, SLNEW, $Path->{Pro}, '.pro');
  my $a = $browse->{frame}->new_ttk__button(
    -text => "Clear",
    -width => 8,
    -style => 'Red.TButton',
    -command => sub{
      $AllSets->{sets}{$CurSet} = [];
      $browse->reset();
    });
  my $b = $browse->{frame}->new_ttk__button(
    -text => "Select for Editing",
    -width => 20,
    -style => 'Green.TButton',
    -command => sub{$NB->select(0);main::showSelection($browse->{selLB}{array});});
  $a->g_grid(qw/-row 1 -column 0 -padx 4/, -pady => [8,4]);
  $b->g_grid(qw/-row 1 -column 1 -padx 4/, -pady => [8,4]);
  return($browse);
}

sub saveSet {
  my($browse) = shift;

  if ($CurSet eq '') {
    message(QUIZ, "No 'Current Set Name' selected to save to.\nIf you want this to be a new Set then enter a name into the\n    'New, Rename or Clone Set Name'\nbox and click on the 'New' button.");
  } else {
    $AllSets->{sets}{$CurSet}{songs} = $browse->{selLB}{array};
    $AllSets->save();
  }
}

sub slAct {
  my($what) = @_;

  if ($what == SLDEL) {
    $AllSets->delete();
    $AllSets->{browser}->reset();
    $AllSets->save();
  } else {
    my $new = $CurSet;
    if ($what == SLNEW || $new ne '') {
      my $ans = msgSet("Enter a new Setlist name:", \$new);
      return if ($ans eq "Cancel" || $new eq '');
      
      # setNRC() will only adjust the SetList object {sets}.
      # It's up to us to make everything (ie. Browser object) up to date.
      $AllSets->setNRC($what,$new);
      saveSet($AllSets->{browser});
      my $i;
      for($i = 0; $i < @{$AllSets->{setsLB}{array}}; $i++) {
	last if ($AllSets->{setsLB}{array}[$i] eq $CurSet);
      }
      $i = 0 if ($i == @{$AllSets->{setsLB}{array}});
      $AllSets->{setsLB}->set($i);
      $AllSets->showSet();
    }
  }
}

################
##
## Collections
##
################

sub collectionWin {
  my($wid) = @_;

  $Chordy->{currentColl} = $Collection->name();
  $Chordy->{collectionPath} = $Collection->{$Chordy->{currentColl}}.'/'.$Chordy->{currentColl};
  my $ccsub = sub{
    my @lst = (sort keys %{$Collection});
    popMenu(\$Chordy->{currentColl}, sub{}, \@lst);
    if ($Collection->name() ne $Chordy->{currentColl}) {
      $Collection->change($Chordy->{currentColl});
      collItems($Chordy);
      showSize();
      fontWin();
    }	    
  };
  my($a,$b,$c,$d,$e);

  $a = $wid->new_ttk__button(-textvariable => \$Chordy->{currentColl}, -width => 10,
			     -style => 'Menu.TButton',    -command => $ccsub);
  $b = $wid->new_ttk__label(-text => "Path: ");
  $c = $wid->new_ttk__label(-textvariable => \$Chordy->{collectionPath});

  $d = $wid->new_ttk__label(-text => "Common PDF Path: ");
  $e = $wid->new_ttk__label(-textvariable => \$Opt->{PDFpath});

  $a->g_grid(qw/-row 0 -column 0 -sticky w -padx 4/, -pady => [4,0]);
  $b->g_grid(qw/-row 1 -column 0 -sticky e/, -pady => [8,0]);
  $c->g_grid(qw/-row 1 -column 1 -sticky w/, -pady => [8,0]);

  $d->g_grid(qw/-row 2 -column 0 -sticky e/);
  $e->g_grid(qw/-row 2 -column 1 -sticky w/);
}

sub collEdit {
  if ($Collection->edit() eq 'OK' && $Collection->name() ne $Chordy->{currentColl}) {
    $Chordy->{currentColl} = $Collection->name();
    collItems($Chordy);
  } else {
    showSize();
#    fontWin();
  }
}

sub collItems {
  my($Chordy) = shift;

  my @del = ();
  foreach my $idx (0..$#ProFiles) {
    if (! -e "$Path->{Pro}/$ProFiles[$idx]->{name}") {
      push(@del, $idx);
    } else {
      # Becuase this Collections version of the file may be different.
      $ProFiles[$idx] = CP::Pro->new($ProFiles[$idx]->{name});
    }
  }
  while (@del) {
    my $idx = pop(@del);
    splice(@ProFiles, $idx, 1);
    $KeyLB->remove($idx);
    $FileLB->remove($idx);
  }
  my $cc = $Collection->name();
  $Chordy->{currentColl} = $cc;
  $Chordy->{collectionPath} = $Collection->{$cc}.'/'.$cc;
  main::title();
}

#################################
##
## Page Size, Fonts & Backgrounds
##
##################################

our($Wstr,$Hstr);

sub mediaWin {
  my($wid) = @_;

  my($a,$b,$c,$d,$e,$f,$g,$h,$i,$j,$k,$l);
  showSize();

  $a = $wid->new_ttk__label(-width => 8, -anchor => 'e', -text => "Media:");
  $b = $wid->new_ttk__button(
    -textvariable => \$Opt->{Media},
    -width => 15,
    -style => 'Menu.TButton',
    -command => sub{
      my @lst = $Media->list();
      my($pop,$fr) = popMenu(\$Opt->{Media}, \&newMedia, \@lst);
    });

  my $st = 'Media.TLabel';
  Tkx::ttk__style_configure($st,
			    -background => $Opt->{MenuBG},
			    -borderwidth => 0,
  			    -relief  => 'solid',
			    -padding => [0,0,0,0]);
  my $stb = 'MediaB.TLabel';
  Tkx::ttk__style_configure($stb,
			    -background => $Opt->{MenuBG},
			    -font => "BTkDefaultFont",
			    -borderwidth => 0,
  			    -relief  => 'solid',
			    -padding => [0,0,0,0]);

  Tkx::ttk__style_configure("Win.TButton", -background => MWBG);
  $c = $wid->new_ttk__label(-text => "Print Media:");
  $d = $wid->new_ttk__button(
    -textvariable => \$Opt->{PrintMedia},
    -width => 15,
    -style => 'Win.TButton',
    -command => sub{
      my @lst = $Media->list();
      popMenu(\$Opt->{PrintMedia}, undef, \@lst);
      # Need to delay the save otherwise Opt->{PrintMedia} = 0
      Tkx::after_idle(sub{$Opt->save()});
    });

  Tkx::ttk__style_configure('Menu.TFrame',
			    -background => $Opt->{MenuBG});
  my $sizeFr = $wid->new_ttk__frame(-relief => 'raised',
				    -style => 'Menu.TFrame',
				    -borderwidth => 2);

  $e = $sizeFr->new_ttk__label(-style => $stb, -anchor => 'e', -text => "Width");
  $f = $sizeFr->new_ttk__separator(-orient => 'vertical');
  $g = $sizeFr->new_ttk__label(-style => $stb, -anchor => 'e', -text => "Height");
  $h = $sizeFr->new_ttk__separator(-orient => 'horizontal');

  $i = $sizeFr->new_ttk__label(-style => $st, -justify => 'right', -textvariable => \$Wstr);
  $j = $sizeFr->new_ttk__label(-style => $st, -justify => 'left',  -text => "in\nmm\npt");
  $k = $sizeFr->new_ttk__label(-style => $st, -justify => 'right', -textvariable => \$Hstr);
  $l = $sizeFr->new_ttk__label(-style => $st, -justify => 'left',  -text => "in\nmm\npt");

  $a->g_grid(qw/-row 0 -column 0 -sticky e/, -padx => [0,2], -pady => 0);
  $b->g_grid(qw/-row 0 -column 1 -sticky w/, -pady => 0);
  $sizeFr->g_grid(qw/-row 0 -column 2 -rowspan 2/, -padx => [12,4]);
  $c->g_grid(qw/-row 1 -column 0 -sticky e/, -padx => [0,2], -pady => 0);
  $d->g_grid(qw/-row 1 -column 1 -sticky w/, -pady => 0);

  # Now grid the widgets within the sizeFr
  $e->g_grid(qw/-row 0 -column 0 -columnspan 2/, -pady => 0);
  $f->g_grid(qw/-row 0 -column 2 -rowspan 3 -sticky ns/, -padx => 2, -pady => 0);
  $g->g_grid(qw/-row 0 -column 3 -columnspan 2/, -pady => 0);
  $h->g_grid(qw/-row 1 -column 0 -columnspan 5 -sticky ew/, -pady => 2);

  $i->g_grid(qw/-row 2 -column 0/, -pady => [0,2]);
  $j->g_grid(qw/-row 2 -column 1/, -padx => 2,  -pady => [0,2]);
  $k->g_grid(qw/-row 2 -column 3/, -pady => [0,2]);
  $l->g_grid(qw/-row 2 -column 4/, -padx => 2, -pady => [0,2]);
}

sub newMedia {
#  $Opt->changeOne('Media');
  $Media->change(\$Opt->{Media});
  showSize();
  fontWin();
}

sub showSize {
  my $w = $Media->{width};
  my $h = $Media->{height};
  $Wstr = sprintf(INF."\n".MMF."\n".PTF, $w * IN, $w * MM, $w * PT);
  $Hstr = sprintf(INF."\n".MMF."\n".PTF, $h * IN, $h * MM, $h * PT);
}

sub fontWin {
  if (defined $Chordy->{fontFr}) {
    foreach my $c (Tkx::SplitList(Tkx::winfo_children($Chordy->{fontFr}))) {
      Tkx::destroy($c);
    }
    CP::Fonts::fonts($Chordy->{fontFr}, [qw/Title Chord Lyric Tab Comment Highlight Editor/]);
    Tkx::update();
  }
}

sub bgWin {
  my($bgf) = shift;

  BGcS($bgf, 0, 'Comment',   \%{$Media->{Comment}},   \$Media->{commentBG});
  BGcS($bgf, 1, 'Highlight', \%{$Media->{Highlight}}, \$Media->{highlightBG});
  BGcS($bgf, 2, 'Title',     \%{$Media->{Title}},     \$Media->{titleBG});
  BGcS($bgf, 3, 'Verse',     \%{$Media->{Lyric}},     \$Media->{verseBG});
  BGcS($bgf, 4, 'Chorus',    \%{$Media->{Chord}},     \$Media->{chorusBG});
  BGcS($bgf, 5, 'Bridge',    \%{$Media->{Lyric}},     \$Media->{bridgeBG});
  BGcS($bgf, 6, 'Tab',       \%{$Media->{Tab}},       \$Media->{tabBG});
}

# $fntp is used to get the Foreground Colour.
sub BGcS {
  my($bgf,$col,$title,$fntp,$var) = @_;

  my $but;
  my $w = length($title) + 2;
  $but = $bgf->new_ttk__button(
    -text => $title,
    -width => $w,
    -style => "$title.BG.TButton",
    -command => sub{pickBG($title, $fntp, $but, $var)});
  $but->g_grid(-row => 0, -padx => 4, -pady => 4, -column => $col);
}

sub pickBG {
  my($title,$fntp,$but,$var) = @_;

  CP::FgBgEd->new("$title Background Colour");
  my($fg,$bg) = $ColourEd->Show($fntp->{color}, $$var, BACKGRND);
  if ($bg ne '') {
    $$var = $bg;
    Tkx::ttk__style_configure("$title.BG.TButton", -background => $bg);
    # Note: if $title is Bridge this has no effect - it just
    #       creates a new style which isn't used anywhere.
    # Otherwise, the Font example background should change.
    if ($title eq 'Verse') {
      Tkx::ttk__style_configure("Chord.Font.TLabel", -background => $bg);
      Tkx::ttk__style_configure("Lyric.Font.TLabel", -background => $bg);
    } else {
      Tkx::ttk__style_configure("$title.Font.TLabel", -background => $bg);
    }
    $Media->save();
  }
}

#############
##
## Commands
##
#############

sub commandWin {
  my $Done = '';
  my $sz = (OS eq 'win32') ? 56 : 42;

  my $pop = CP::Pop->new(0, '.cw', 'PDF Commands');
  return if ($pop eq '');
  my($top,$fr) = ($pop->{top}, $pop->{frame});
  $fr->m_configure(-padding => [0,0,0,0]);

  my $cmd = $fr->new_ttk__frame(-padding => [4,4,4,4]);
  $cmd->g_pack(qw/-side top -fill x/);

  CmdS($cmd, 0, $sz, "View PDF", \$Cmnd->{Acro});
  CmdS($cmd, 1, $sz, "Print PDF", \$Cmnd->{Print});

  my $hl = $fr->new_ttk__separator(-orient => 'horizontal');
  $hl->g_pack(qw/-side top -fill x/);

  my $bf = $fr->new_ttk__frame(-padding => [0,8,0,8]);
  $bf->g_pack(qw/-side top -fill x/);

  my $cancel = $bf->new_ttk__button(
    -text => "Cancel",
    -command => sub{$Done = "Cancel";});
  $cancel->g_pack(qw/-side left -padx 60/);

  my $ok = $bf->new_ttk__button(
    -text => "OK",
    -command => sub{$Done = "OK";});
  $ok->g_pack(qw/-side right -padx 60/);

  Tkx::vwait(\$Done);
  if ($Done eq "OK") {
    main::saveCmnd();
  }
  $pop->destroy();
}

sub CmdS {
  my($wid,$r,$sz,$title,$cmd) = @_;

  my $ctypes;
  if (OS eq 'win32') {
    $ctypes = [['Programs', '.exe'],
	       ['All Files', '*'],];
  } else {
    $ctypes = [['All Files', '*'],];
  }

  my $cl = $wid->new_ttk__label(-text => "${title}:");
  $cl->g_grid(-row => $r, qw/-column 0 -sticky e -padx 2 -pady 4/);
  my $ent = $wid->new_ttk__entry(
    -width => $sz,
    -textvariable => $cmd,
    -state => 'disabled');
  $ent->g_grid(-row => $r, qw/-column 1 -sticky w -padx 2 -pady 4/);
  $ent->g_bind('<FocusOut>' => sub{$ent->m_configure(-state => 'disabled');});
  $ent->g_bind('<Return>' => sub{$ent->m_configure(-state => 'disabled');$wid->g_focus();});
  $ent->g_bind('<Tab>' => sub{$ent->m_configure(-state => 'disabled');$wid->g_focus();});
  my $cbe = $wid->new_ttk__button(
    -text => "Edit",
    -width => 5,
    -command => sub{
      $ent->m_configure(-state => 'normal');
      $ent->g_focus();
      $ent->icursor('end');
    });
  $cbe->g_grid(-row => $r, qw/-column 2 -sticky w -padx 4 -pady 4/);
  my $ip = (OS eq 'win32') ? 'C:/' : "/";
  my $cbb = $wid->new_ttk__button(
    -text => "Browse",
    -width => 7,
    -command => sub{
      my $c = Tkx::tk___getOpenFile(
	-multiple => 0,
	-initialdir => "$ip",
	-filetypes => $ctypes);
      if (defined $c && $c ne "") {
	$$cmd = ($c =~ /\s/) ? "\"$c\"" : $c;
      }
      $wid->g_focus();
    });
  $cbb->g_grid(-row => $r, qw/-column 3 -sticky w -padx 4 -pady 4/);
}

sub lookFrm {
  my($frm) = shift;

  my($a,$b,$c,$d,$e,$f,$g,$h,$i,$j,$k,$m);
  $a = $frm->new_ttk__label(-text => "Colours:");
  $b = $frm->new_ttk__button(
    -text => "Push Button",
    -command => \&CP::Win::PBclr );
  $c = $frm->new_ttk__button(
    -text => "Menu Button",
    -style => 'Menu.TButton',
    -command => \&CP::Win::MBclr );
  $d = $frm->new_ttk__button(
    -text => "Lists",
    -width => 8,
    -style => 'List.TButton',
    -command => sub{CP::List::background(1)} );
  $e = $frm->new_ttk__button(
    -text => "Entry",
    -width => 8,
    -style => 'Ent.TButton',
    -command => \&CP::Win::ENTclr );
  $f = $frm->new_ttk__button(
    -text => "Window",
    -width => 8,
    -style => 'Win.TButton',
    -command => \&CP::Win::BGclr );
  $g = $frm->new_ttk__button(
    -text => "Message",
    -width => 8,
    -style => 'Msg.TButton',
    -command => \&CP::Win::MSGclr );

  $h = $frm->new_ttk__button(
    -text => "Defaults",
    -style => 'Green.TButton',
    -command => \&CP::Win::defLook );

  $i = $frm->new_ttk__label(-text => "Fonts:");
  $j = $frm->new_ttk__button(-text => "Normal/Bold", -command => \&main::useBold );
  $k = $frm->new_ttk__button(
    -text => "Save",
    -style => 'Green.TButton',
    -command => sub{$Opt->save()} );
  $m = $frm->new_ttk__button(
    -text => "Copy To All Collections",
    -style => 'Green.TButton',
    -command => sub{$Opt->saveClr2all()} );


  $a->g_grid(qw/-row 0 -column 0 -sticky e/, -padx => [4,0], -pady => [0,8]);
  $b->g_grid(qw/-row 0 -column 1 -padx 4/, -pady => [0,8]);
  $c->g_grid(qw/-row 0 -column 2 -padx 4/, -pady => [0,8]);
  $d->g_grid(qw/-row 0 -column 3 -padx 4/, -pady => [0,8]);
  $e->g_grid(qw/-row 0 -column 4 -padx 4/, -pady => [0,8]);
  $f->g_grid(qw/-row 0 -column 5 -padx 4/, -pady => [0,8]);
  $g->g_grid(qw/-row 0 -column 6 -padx 4/, -pady => [0,8]);
  $i->g_grid(qw/-row 1 -column 0 -sticky e/, -pady => [0,8]);
  $j->g_grid(qw/-row 1 -column 1 -sticky ew -padx 4/, -pady => [0,8]);

  $k->g_grid(qw/-row 2 -column 2 /, -padx => [0,4], -pady => [0,8]);
  $h->g_grid(qw/-row 2 -column 3 /, -padx => [0,4], -pady => [0,8]);
  $m->g_grid(qw/-row 2 -column 4 -columnspan 3 -sticky w/, -padx => [4,8], -pady => [0,8]);
}

1;
