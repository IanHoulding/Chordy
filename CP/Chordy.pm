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
use CP::CHedit qw(&CHedit);
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

#### This is NoteBook Tab 0 and is always made and displayed first.
#### Chordy PDF Generator Tab
  $Chordy->{currentColl} = '';
  my $ctf = $chordy->new_ttk__labelframe(-text => " ChordPro Files ", -padding => [4,4,4,4]);
  filesWin($ctf);

  my $cmf = $chordy->new_ttk__labelframe(-text => " PDF Options ", -padding => [4,4,4,4]);
  optWin($cmf);

  $ctf->g_pack(qw/-side top -anchor n -expand 0 -fill x -pady 4/);
  $cmf->g_pack(qw/-side top -anchor n -expand 0 -fill x -pady 4/);

  #### Bottom Button Frame
  my $butf = $chordy->new_ttk__frame(-padding => [4,4,4,4]);
  $butf->g_pack(qw/-side bottom -fill x/);

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
  $MW->g_focus();
}

##
## Configuration Options NoteBook Tab
##
sub confOpts {
  my $opts = $Chordy->{opts};

  my $col = $opts->new_ttk__labelframe(-text => " Collection ", -padding => [4,0,4,4]);
  $col->g_pack(qw/-side top -fill x -padx 4/);
  collectionWin($col);

  $Chordy->{fontFr} = $opts->new_ttk__labelframe(-text => " PDF Fonts - Colour and Size ",
						 -padding => [4,0,4,4]);
  $Chordy->{fontFr}->g_pack( qw/-side top -fill x -padx 4 -pady 6/);
  fontWin();

  my $bf = $opts->new_ttk__frame();
  $bf->g_pack( qw/-side top -fill x -padx 4/, -pady => [4,6]);
  my $bgf = $bf->new_ttk__labelframe(-text => " PDF Section Background Colours ",
				     -padding => [4,0,4,4]);
  $bgf->g_pack(qw/-side left -expand 1 -fill x/, -padx => [0,4]);
  bgWin($bgf);

  my $sz = $bf->new_ttk__labelframe(-text => " PDF Page Size ", -padding => [4,0,4,4]);
  $sz->g_pack( qw/-side right -expand 1 -fill x/, -padx => [4,0]);
  mediaWin($sz);
}

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

  my $tFsf  = $Fff->new_ttk__labelframe(-text => ' Single File ');
  my $tFlst = $Fff->new_ttk__frame();
  my $tFact = $Fff->new_ttk__frame();
  my $tFbot = $Chordy->{ProgFrm} = $Fff->new_ttk__frame(-style => 'Pop.TFrame',
						      -relief => 'raised',
						      -borderwidth => 2,
						      -padding => [4,0,4,4]);

  $tFsf->g_grid( qw/-row 0 -column 2 -sticky nsw -padx 16/, -pady => [0,8]);
  $tFlst->g_grid(qw/-row 0 -column 0 -sticky nsw -padx 16/);
  $tFact->g_grid(qw/-row 0 -column 1 -sticky nsw -padx 16/);
  $tFbot->g_grid(qw/-row 1 -column 0 -columnspan 3 -sticky ew -padx 16/, -pady => [4,0]);

###
  my $onee = $tFsf->new_ttk__button(
    -text => "Edit",
    -width => 8,
    -command => \&main::editPro);
  my $oner = $tFsf->new_ttk__button(
    -text => "Rename",
    -width => 8,
    -command => \&main::renamePro);
  my $onec = $tFsf->new_ttk__button(
    -text => "Clone",
    -width => 8,
    -command => \&main::clonePro);
  my $oned = $tFsf->new_ttk__button(
    -text => "Delete",
    -width => 8,
    -style => 'Red.TButton',
    -command => \&main::deletePro);
  Tkx::ttk__style_configure("Tr.Menu.TButton", -background => '#FFD0D0');
  my $onet = $tFsf->new_ttk__button(
    -text => "Transpose",
    -width => 10,
    -style => 'Tr.Menu.TButton',
    -command => sub{$main::PDFtrans = 1;main::transposeOne(SINGLE);});
  no warnings; # stops perl bleating about '#' in array definition.
  my $onek = popButton($tFsf,
		       \$Opt->{Transpose},
		       sub{},
		       [qw/- Ab A A# Bb B C C# Db D D# Eb E F F# Gb G G#/],
		       -width => 3,
		       -style => 'Tr.Menu.TButton',
      );
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

  $KeyLB = CP::List->new($tFlst, '', qw/-height 18 -width 4/);
  $FileLB = CP::List->new($tFlst, 'e', qw/-height 18 -selectmode browse -takefocus 1/, -width => (SLWID + 4));

  $FileLB->{lb}->configure(-yscrollcommand => [sub{scroll_filelb($FileLB->{yscrbar}, @_)}]);
  $FileLB->{yscrbar}->m_configure(-command => sub {$KeyLB->{lb}->yview(@_);$FileLB->{lb}->yview(@_);});

  $KeyLB->{frame}->g_pack (qw/-side left -fill y -ipadx 1 -padx 1/);
  $FileLB->{frame}->g_pack(qw/-side left -fill y -ipadx 1/);

###
  my $brw = $tFact->new_ttk__button(
    -text => "Browse ...",
    -command => sub{main::selectFiles(FILE)} );

  my $fsl = $tFact->new_ttk__button(
    -text => "From Setlist",
    -command => sub{$Chordy->{nb}->m_select(1)});

  my $act = $tFact->new_ttk__labelframe(
    -text => " PDFs ",
    -labelanchor => 'n',
      );
  actWin($act);

  my $cob = popButton($tFact,
		      \$Collection->{name},
		      sub{$Collection->change($Collection->{name});collItems($Chordy);},
		      sub{$Collection->list()},
		      -style => 'Menu.TButton',
      );
  my $cobl = $tFact->new_ttk__label(-text => 'Collection');

  ## Browse/From Setlist/PDFs
  $brw->g_pack(qw/-side top -pady 4/);
  $fsl->g_pack(qw/-side top -pady 4/);
  $act->g_pack(qw/-side top -pady 8/);  # LabelFrame
  $cob->g_pack(qw/-side bottom/, -pady => [0,8]);
  $cobl->g_pack(qw/-side bottom/);
  my $progl = $tFbot->new_ttk__label(-text => "Please Wait .... PDF'ing: ", -style => 'Pop.TLabel');
  Tkx::ttk__style_configure('Prog.Pop.TLabel', -font => "BTkDefaultFont");

  my $proge = $Chordy->{ProgLab} = $tFbot->new_ttk__label(-text => '',
							-width => SLWID + 4,
							-style => 'Prog.Pop.TLabel');
  $Chordy->{ProgCan} = 0;
  my $progc = $tFbot->new_ttk__button(-text => ' Cancel ',
				    -style => 'Red.TButton',
				    -command => sub{$Chordy->{ProgCan} = 1; Tkx::update();});

  $progl->g_pack(qw/-side left/);
  $proge->g_pack(qw/-side left/);
  $progc->g_pack(qw/-side left -padx 8/, -pady => [4,0]);
  $tFbot->g_grid_forget();
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
  my $view = $act->new_ttk__checkbutton(-style => 'My.TCheckbutton',
					-compound => 'left',
					-text => "View",
					-image => ['xtick', 'selected', 'tick'],
					-variable => \$Opt->{PDFview},
					-command => sub{$Opt->saveOne('PDFview')});
  my $cret = $act->new_ttk__checkbutton(-style => 'My.TCheckbutton',
					-compound => 'left',
					-text => "View",
					-image => ['xtick', 'selected', 'tick'],
					-text => "Create",
					-variable => \$Opt->{PDFmake},
					-command => sub{$Opt->saveOne('PDFmake')});
  my $prnt = $act->new_ttk__checkbutton(-style => 'My.TCheckbutton',
					-compound => 'left',
					-text => "View",
					-image => ['xtick', 'selected', 'tick'],
					-text => "Print",
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
  my $onep = $act->new_ttk__checkbutton(-style => 'My.TCheckbutton',
					-compound => 'left',
					-image => ['xtick', 'selected', 'tick'],
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
  $wid->g_grid(qw/-row 0 -column 0/);

  my($a,$b,$c,$d,$e,$f,$g,$h,$i);
  #########################

  $a = $wid->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				  -compound => 'left',
				  -image => ['xtick', 'selected', 'tick'],
				  -text => 'Center Lyrics',
				  -variable => \$Opt->{Center},
				  -command => sub{$Opt->saveOne('Center')});
  $b = $wid->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				  -compound => 'left',
				  -image => ['xtick', 'selected', 'tick'],
				  -text => 'Lyrics Only',
				  -variable => \$Opt->{LyricOnly},
				  -command => sub{$Opt->saveOne('LyricOnly')});
  $c = $wid->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				  -compound => 'left',
				  -image => ['xtick', 'selected', 'tick'],
				  -text => 'Group Lines',
				  -offvalue => MULTIPLE,
				  -onvalue => SINGLE,
				  -variable => \$Opt->{Together},
				  -command => sub{$Opt->saveOne('Together')});
  $d = $wid->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				  -compound => 'left',
				  -image => ['xtick', 'selected', 'tick'],
				  -text => '1/2 Height Blank Lines',
				  -variable => \$Opt->{HHBL},
				  -command => sub{$Opt->saveOne('HHBL')});
  $e = $wid->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				  -compound => 'left',
				  -image => ['xtick', 'selected', 'tick'],
				  -text => 'Show Labels',
				  -variable => \$Opt->{ShowLabels},
				  -command => sub{$Opt->saveOne('ShowLabels')});
  $f = $wid->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				  -compound => 'left',
				  -image => ['xtick', 'selected', 'tick'],
				  -text => "Highlight full line",
				  -variable => \$Opt->{FullLineHL},
				  -command => sub{$Opt->saveOne('FullLineHL')});
  $g = $wid->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				  -compound => 'left',
				  -image => ['xtick', 'selected', 'tick'],
				  -text => "Comment full line",
				  -variable => \$Opt->{FullLineCM},
				  -command => sub{$Opt->saveOne('FullLineCM')});
  $h = $wid->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				  -compound => 'left',
				  -image => ['xtick', 'selected', 'tick'],
				  -text => "Ignore Capo Directives",
				  -variable => \$Opt->{IgnCapo},
				  -command => sub{$Opt->saveOne('IgnCapo')});
  $i = $wid->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				  -compound => 'left',
				  -image => ['xtick', 'selected', 'tick'],
				  -text => "No Long Line warnings",
				  -variable => \$Opt->{NoWarn},
				  -command => sub{$Opt->saveOne('NoWarn')});

  $a->g_grid(qw/-row 0 -column 0 -sticky w -pady 1/, -padx => [0,12]);
  $b->g_grid(qw/-row 1 -column 0 -sticky w -pady 1/, -padx => [0,12]);
  $c->g_grid(qw/-row 2 -column 0 -sticky w -pady 1/, -padx => [0,12]);
  $d->g_grid(qw/-row 3 -column 0 -sticky w -pady 1/, -padx => [0,12]);

  $f->g_grid(qw/-row 0 -column 1 -sticky w -pady 1/, -padx => [0,12]);
  $g->g_grid(qw/-row 1 -column 1 -sticky w -pady 1/, -padx => [0,12]);
  $h->g_grid(qw/-row 2 -column 1 -sticky w -pady 1/, -padx => [0,12]);
  $i->g_grid(qw/-row 3 -column 1 -sticky w -pady 1/, -padx => [0,12]);
  $e->g_grid(qw/-row 4 -column 1 -sticky w -pady 1/, -padx => [0,12]);

  ################
  
  $a = $wid->new_ttk__label(-text => "Line Spacing:");
  $b = popButton($wid,
		 \$Opt->{LineSpace},
		 sub{$Opt->saveOne('LineSpace')},
		 [qw/1 2 3 4 5 6 7 8 9 10 12 14 16 18 20/],
		 -style => 'Menu.TButton',
		 -width => 3,
      );

  $Opt->{Capo} = "No";
  $c = $wid->new_ttk__label(-text => "Capo On:");
  $d = popButton($wid,
		 \$Opt->{Capo},
		 sub{$Opt->{Capo} = 'No' if ($Opt->{Capo} == 0)},
		 [0..12],
		 -style => 'Menu.TButton',
		 -width => 3,
      );

  $Opt->{Transpose} = "-";
  $e = $wid->new_ttk__label(-text => "Transpose To:");
  no warnings; # stops perl bleating about '#' in array definition.
  $f = popButton($wid,
		 \$Opt->{Transpose},
		 sub{},
		 [qw/- Ab A A# Bb B C C# Db D D# Eb E F F# Gb G G#/],
		 -style => 'Menu.TButton',
		 -width => 3,
      );
  use warnings;

  $g = $wid->new_ttk__radiobutton(-text => "Force Sharp",
				  -variable => \$Opt->{SharpFlat}, -value => SHARP);
  $h = $wid->new_ttk__radiobutton(-text => "Force Flat",
				  -variable => \$Opt->{SharpFlat}, -value => FLAT);

  $a->g_grid(qw/-row 0 -column 2 -sticky e/, -padx => [4,0]);
  $b->g_grid(qw/-row 0 -column 3 -sticky w -pady 2/, -padx => [2,4]);

  $c->g_grid(qw/-row 1 -column 2 -sticky e/, -padx => [4,0]);
  $d->g_grid(qw/-row 1 -column 3 -sticky w -pady 2/, -padx => [2,4]);

  $e->g_grid(qw/-row 2 -column 2 -sticky e/, -padx => [4,0]);
  $f->g_grid(qw/-row 2 -column 3 -sticky w -pady 2/, -padx => [2,4]);

  $g->g_grid(qw/-row 3 -column 2 -columnspan 2 -sticky w/, -padx => [14,0]);
  $h->g_grid(qw/-row 4 -column 2 -columnspan 2 -sticky w/, -padx => [14,0]);

  ################
  my $fcd = $frm->new_ttk__labelframe(
    -text => " Chord Diagrams ",
    -labelanchor => 'n');
  $fcd->g_grid(qw/-row 0 -column 1 -sticky n/, -padx => [8,4]);
  $a = $fcd->new_ttk__label(-text => "Instrument");
  $b = popButton($fcd,
		 \$Opt->{Instrument},
		 sub{readChords();$Opt->saveOne('Instrument');},
		 $Opt->{Instruments},
		 -style => 'Menu.TButton',
		 -width => 9,
      );

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

  ################
  my $mrgn = $frm->new_ttk__labelframe(-text => " Margins ", -padding => [4,2,0,4]);
  $mrgn->g_grid(qw/-row 1 -column 0 -sticky we/);

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
      -state => 'readonly',
      -command => sub{$Opt->saveOne("${m}Margin");});
    $a->g_grid(qw/-row 0 -sticky e/, -column => $col++);
    $b->g_grid(qw/-row 0 -sticky w/, -column => $col++, -padx => [2,16]);
  }

  ################
  $a = $frm->new_ttk__button(
    -text => ' PDF Background ',
    -style => 'PDF.TButton',
    -command => sub{
      CP::FgBgEd->new('PDF Background');
      my($fg,$bg) = $ColourEd->Show(BLACK, $Opt->{PageBG}, '', BACKGRND);
      if ($bg ne '') {
	$Opt->{PageBG} = $bg;
	$Opt->saveOne('PageBG');
	Tkx::ttk__style_configure("PDF.TButton", -background => $bg);
      }
    });
  $a->g_grid(qw/-row 1 -column 1 -pady 6/, -padx => [8,4]);
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

  my $sltr = $sltM->new_ttk__checkbutton(-style => 'Wh.My.TCheckbutton',
					 -variable => \$Opt->{SLrev},
					 -compound => 'right',
					 -image => ['xtick', 'selected', 'tick'],
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
  $can->bind($rtxt, '<Button-1>', sub{$sltr->invoke()});

  my $setsLB = $AllSets->{setsLB} = CP::List->new($sltL, 'e',
						  -height => 12, -width => SLWID,
						  -selectmode => 'single');
  $setsLB->{frame}->g_grid(qw/-row 0 -column 0 -sticky nsew/);
  # It would appear that if both <Button-1> and <Double-Button-1>
  # are bound then both subs are called in sequence.
  $setsLB->bind('<Button-1>' => sub{Tkx::after_idle(sub{$AllSets->showSet()})} );
  $setsLB->bind('<Double-Button-1>' => sub{
    Tkx::after_idle(sub{
      my $idx = $setsLB->curselection(0);
      $Chordy->{nb}->select(0);
      main::showSelection($browser->{selLB}{array});
      $setsLB->selection_set($idx);}
      )});
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

  foreach my $set (1..2) {
    my $lab = $sltCS->new_ttk__label(-text => "Set $set", -background => WHITE);
    my $sFr = $sltCS->new_ttk__frame(qw/-style Wh.TFrame/);
    $sFr->g_grid_columnconfigure(1, -minsize => 10);

    my $buts = $sFr->new_ttk__button(-textvariable => \$AllSets->{meta}{"s${set}start"},
				       -style => $st,
				       -width => 5,
				       -command => [$tsub, "s${set}start"] );
    my $h = $sFr->new_ttk__separator(-style => 'H.TSeparator', -orient => 'horizontal');
    my $bute = $sFr->new_ttk__button(-textvariable => \$AllSets->{meta}{"s${set}end"},
				       -style => $st,
				       -width => 5,
				       -command => [$tsub, "s${set}end"] );
    $lab->g_grid( -row => $row, -column => 0, -sticky => 'e', -pady => 3);
    $sFr->g_grid( -row => $row, -column => 1, -sticky => 'w', -pady => 3);
    $buts->g_grid(-row => 0,    -column => 0, -padx => 4);
    $h->g_grid(   -row => 0,    -column => 1, -sticky => 'ew');
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
    -command => [\&CP::CPpdf::printSL, $Chordy]);
  my $butInp = $slFt->new_ttk__button(
    -text => "Import",
    -width => 8,
    -style => 'Green.TButton',
    -command => sub{$AllSets->importSet()});
  my $butExp = $slFt->new_ttk__button(
    -text => "Export",
    -width => 8,
    -style => 'Green.TButton',
    -command => sub{if ($CurSet ne '') {
                      my $newC = $Collection->{name};
		      my $set = $AllSets->{sets}{$CurSet};
		      my $clst = $Collection->list();
		      my $lst = ['To all', 'SeP', @{$clst}, 'SeP', 'File'];
		      popBmenu(\$newC, sub{CP::SetList::export($set, $newC, $clst)}, $lst);
		    }
    });

  ## Now pack everything
  # Setlists
  $slFt->g_pack(qw/-side top -fill x/, -pady => [0,4]);
  # Browser
  $slFb->g_pack(qw/-side top -fill x/, -pady => [4,0]);

  $sltL->g_grid(qw/-row 0 -column 0 -rowspan 2 -sticky n/, -padx => [4,0], -pady => [0,4]);

  $sltM->g_grid(qw/-row 0 -column 1 -sticky n/, -padx => [4,0], -pady => [0,4]);
  $sltr->g_pack(qw/-side top -fill x/, -pady => [12,0]);
  $can->g_pack(qw/-side top -fill x -pady 0/, -padx => [4,0]);

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

  $Chordy->{currentColl} = $Collection->{name};
  my($a,$b,$c,$d,$e);

  $a = popButton($wid,
		 \$Collection->{name},
		 sub{$Collection->change($Collection->{name});showCollChange();},
		 sub{$Collection->list()},
		 -style => 'Menu.TButton',
		 -width => 10,
      );
  $b = $wid->new_ttk__label(-text => "Path: ");
  $c = $wid->new_ttk__label(-textvariable => \$Collection->{fullPath});

  $d = $wid->new_ttk__label(-text => "Common PDF Path: ");
  $e = $wid->new_ttk__label(-textvariable => \$Opt->{PDFpath});

  $a->g_grid(qw/-row 0 -column 0 -rowspan 2 -sticky w/, -padx => [4,16]);

  $b->g_grid(qw/-row 0 -column 1 -sticky e/);
  $c->g_grid(qw/-row 0 -column 2 -sticky w/);

  $d->g_grid(qw/-row 1 -column 1 -sticky e/);
  $e->g_grid(qw/-row 1 -column 2 -sticky w/);
}

sub showCollChange {
  collItems();
  if ($Chordy->{nb}->m_index('current') == 2) { # '2' is the Config Tab.
    showSize();
    fontWin();
  }
}

sub collItems {
  my @del = ();
  foreach my $idx (0..$#ProFiles) {
    if (! -e "$Path->{Pro}/$ProFiles[$idx]->{name}") {
      push(@del, $idx);
    } else {
      # Because this Collections version of the file may be different.
      $ProFiles[$idx] = CP::Pro->new($ProFiles[$idx]->{name});
    }
  }
  while (@del) {
    my $idx = pop(@del);
    splice(@ProFiles, $idx, 1);
    $KeyLB->remove($idx);
    $FileLB->remove($idx);
  }
  $Chordy->{currentColl} = $Collection->{name};
  CP::Win::title();
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
  $b = popButton($wid,
		 \$Opt->{Media},
		 sub{Tkx::after_idle(\&newMedia)},
		 sub{$Media->list()},
		 -style => 'Menu.TButton',
		 -width => 15,
      );

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
  $d = popButton($wid,
		 \$Opt->{PrintMedia},
		 sub{Tkx::after_idle(sub{$Opt->saveOne('PrintMedia')})},
		 sub{$Media->list()},
		 -style => 'Menu.TButton',
		 -width => 15,
      );

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
  $Media = $Media->change($Opt->{Media});
  $Opt->saveOne('Media');
  showSize();
  fontWin();
  CP::Win::title();
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
    CP::Fonts::fonts($Chordy->{fontFr}, [qw/Title Chord Lyric Tab Label Comment Highlight Editor/]);
    Tkx::update();
  }
}

sub bgWin {
  my($bgf) = shift;

  BGcS($bgf, 0, 'Verse');
  BGcS($bgf, 1, 'Chorus');
  BGcS($bgf, 2, 'Bridge');
  BGcS($bgf, 3, 'Tab');
}

sub BGcS {
  my($bgf,$col,$title,$tf) = @_;

  my $fg = ($title =~ /Ver|Cho|Bri/) ? $Opt->{FGLyric} : $Opt->{"FG$title"};
  my $bgptr = \$Opt->{"BG$title"};
  my $bdptr = (defined $tf) ? \$Opt->{$tf.'borderColour'} : undef;
  my $w = length($title) + 2;
  my $but = $bgf->new_ttk__button(
    -text    => $title,
    -width   => $w,
    -style   => "$title.BG.TButton",
    -command => sub{pickBG($title, $fg, $bgptr, $bdptr)});
  $but->g_grid(-row => 0, -padx => 4, -pady => 4, -column => $col);
}

sub pickBG {
  my($title,$fg,$bgptr,$bdptr) = @_;

  my($bg,$bd) = ($$bgptr,'');
  CP::FgBgEd->new("$title Background Colour");
  my $op = BACKGRND;
  if (defined $bdptr) {
    $bd = $$bdptr;
    $op |= BORDER;
  }
  ($fg,$bg,$bd) = $ColourEd->Show($fg, $bg, $bd, $op);
  if ($bg ne '') {
    $$bgptr = $bg;
    $$bdptr = $bd if (defined $bdptr);
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
    $Opt->save();
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
  $pop->popDestroy();
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

1;
