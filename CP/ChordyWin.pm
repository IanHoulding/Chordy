package CP::ChordyWin;

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
use Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/&chordyDisplay/;

#
# This is all the GUI stuff. Just kept in a separate file
# to make editing/managing easier.
#
my $FFrame = '';
my $CurCol;
my $Cpath;

sub chordyDisplay {
  $ColourEd = CP::FgBgEd->new() if (!defined $ColourEd);

  # The main window is composed of 2 areas:
  # 1) A top NoteBook with 3 tabs.
  # 2) A bottom Frame that contains the Help & Exit buttons.

  my $NB = $MW->new_ttk__notebook();
  my $butf = $MW->new_ttk__frame(-padding => [0,8,0,8]);

  $NB->g_pack(qw/-side top -expand 1 -fill both/);
  $butf->g_pack(qw/-side bottom -fill x/);

  my $chordy = $NB->new_ttk__frame(-padding => [4,4,4,4]);
  my $setLst = $NB->new_ttk__frame(-padding => [4,4,4,4]);
  my $opts = $NB->new_ttk__frame(-padding => [4,4,4,4]);
  my $misc = $NB->new_ttk__frame(-padding => [4,4,4,4]);

  $NB->add($chordy, -text => '  Chordy PDF Generator  ');
  $NB->add($setLst, -text => '  Setlists  ');
  $NB->add($opts,   -text => '  Configuration Options  ');
  $NB->add($misc,   -text => '  Miscellaneous  ');
  $NB->select(0);

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

#### Chordy PDF Generator Tab
  my $ctf = $chordy->new_ttk__labelframe(-text => " ChordPro Files ", -padding => [4,4,4,4]);
  filesWin($ctf, $NB);

  my $cmf = $chordy->new_ttk__labelframe(-text => " PDF Options ", -padding => [4,4,4,4]);
  optWin($cmf);

  $ctf->g_pack(qw/-side top -expand 1 -fill both/);
  $cmf->g_pack(qw/-side top -expand 1 -fill both/, -pady => [8,0]);

#### Setlists Tab
  setLists($setLst, $NB);

#### Configuration Options Tab
  my $fol = $opts->new_ttk__labelframe(-text => " Collections ", -padding => [4,4,4,4]);
  collectionWin($fol);

  my $sz = $opts->new_ttk__labelframe(-text => " PDF Page Size ", -padding => [4,4,4,0]);
  mediaWin($sz);

  $FFrame = $opts->new_ttk__labelframe(-text => " Fonts - Colour and Size ", -padding => [4,0,0,8]);
  $NB->g_bind('<<NotebookTabChanged>>', sub{fontWin() if ($NB->m_index('current') == 2)});

  my $bgf = $opts->new_ttk__labelframe(-text => " Background Colours ");
  bgWin($bgf);

  my $bf = $opts->new_ttk__frame(); #-padding => [0,16,0,0]);
  CP::Win::defButtons($bf, 'Media', \&main::saveMed, \&main::loadMed, \&main::resetMed);

  $fol->g_pack(qw/-side top -fill x/, -pady => [8,0]);
  $sz->g_pack(qw/-side top -fill x/, -pady => [16,0]);
  $FFrame->g_pack(qw/-side top -fill x/, -pady => [16,0]);
  $bgf->g_pack(qw/-side top -fill x/, -pady => [16,0]);
  $bf->g_pack(qw/-side bottom -pady 4 -fill x/);

#### Miscellaneous Tab
  my $ff = $misc->new_ttk__labelframe(-text => " File ");
  fileFrm($ff);

  my $of = $misc->new_ttk__labelframe(-text => " Options ");
  optFrm($of);

  my $cf = $misc->new_ttk__labelframe(-text => " Appearance ");
  lookFrm($cf);

  my $cmd = $misc->new_ttk__labelframe(-text => " Commands ", -padding => [4,4,4,4]);
  commandWin($cmd);

  $ff->g_pack(qw/-side top -fill x/, -pady => [8,0]);
  $of->g_pack(qw/-side top -fill x/, -pady => [16,0]);
  $cf->g_pack(qw/-side top -fill x/, -pady => [16,0]);
  $cmd->g_pack(qw/-side top -fill x/, -pady => [16,0]);

####
  $chordy->g_focus();
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
  my($Fff,$NB) = @_;

  # Has to be packed first.
  my $bLF = $Fff->new_ttk__labelframe(-text => ' Single Selected File ', -padding => [4,4,4,8]);
  $bLF->g_pack (qw/-side bottom -anchor w -fill x/);

  my $tFl = $Fff->new_ttk__frame();  $tFl->g_pack(qw/-side left -anchor n -expand 1 -fill x/);
  my $tFm = $Fff->new_ttk__frame();  $tFm->g_pack(qw/-side left -anchor n -fill y/);
  my $tFr = $Fff->new_ttk__frame();  $tFr->g_pack(qw/-side left -anchor n -expand 1 -fill x/);

###
  (my $bfrm = $tFl->new_ttk__frame())->g_pack();
  my $new = $bfrm->new_ttk__button(
    -text => 'New',    -command => \&main::newProFile );
  my $imp = $bfrm->new_ttk__button(
    -text => 'Import', -command => \&main::impProFile );
  my $syn = $bfrm->new_ttk__button(
    -text => 'Sync',   -command => sub{syncFiles($Path->{Pro}, 'pro')});

###
  my $cp = $bfrm->new_ttk__labelframe(
    -text => ' ChordPro ',
    -labelanchor => 'n',
    -padding => [4,0,4,6]);
  my $ecpl = $cp->new_ttk__label(-text => 'Export');
  my $econe = $cp->new_ttk__button(
    -text => "One",
    -width => 4,
    -style => 'Menu.TButton',
    -command => sub{main::expFile($Path->{Pro}, '.pro', 1)} );
  my $ecall = $cp->new_ttk__button(
    -text => "All",
    -width => 4,
    -style => 'Menu.TButton',
    -command => sub{main::expFile($Path->{Pro}, '.pro')} );
  my $mcpl = $cp->new_ttk__label(-text => 'Mail');
  my $mcone = $cp->new_ttk__button(
    -text => "One",
    -width => 4,
    -style => 'Menu.TButton',
    -command => sub{main::mailFile($Path->{Pro}, '.pro', 1)} );
  my $mcall = $cp->new_ttk__button(
    -text => "All",
    -width => 4,
    -style => 'Menu.TButton',
    -command => sub{main::mailFile($Path->{Pro}, '.pro')} );

  my $pdf = $bfrm->new_ttk__labelframe(
    -text => ' PDF ',
    -labelanchor => 'n',
    -padding => [4,0,4,6]);
  my $epdfl = $pdf->new_ttk__label(-text => 'Export');
  my $epone = $pdf->new_ttk__button(
    -text => "One",
    -width => 4,
    -command => sub{main::expFile($Path->{PDF}, '.pdf', 1)} );
  my $epall = $pdf->new_ttk__button(
    -text => "All",
    -width => 4,
    -command => sub{main::expFile($Path->{PDF}, '.pdf')} );
  my $mpdfl = $pdf->new_ttk__label(-text => 'Mail');
  my $mpone = $pdf->new_ttk__button(
    -text => "One",
    -width => 4,
    -command => sub{main::mailFile($Path->{PDF}, '.pdf', 1)} );
  my $mpall = $pdf->new_ttk__button(
    -text => "All",
    -width => 4,
    -command => sub{main::mailFile($Path->{PDF}, '.pdf')} );

###
  $KeyLB = CP::List->new($tFm, '', qw/-height 18 -width 4/);
  $FileLB = CP::List->new($tFm, 'e', qw/-height 18 -selectmode browse -takefocus 1/, -width => (SLWID + 4));

  $FileLB->{lb}->configure(-yscrollcommand => [sub{scroll_filelb($FileLB->{yscrbar}, @_)}]);
  $FileLB->{yscrbar}->m_configure(-command => sub {$KeyLB->{lb}->yview(@_);$FileLB->{lb}->yview(@_);});
###
  my $brw = $tFr->new_ttk__button(
    -text => "Browse ...",
    -command => sub{main::selectFiles(FILE)} );

  my $fsl = $tFr->new_ttk__button(
    -text => "From Setlist",
    -command => sub{$NB->m_select(1)});

  my $act = $tFr->new_ttk__labelframe(
    -text => " PDFs ",
    -labelanchor => 'n',
      );
  actWin($act);

  my $cob = $tFr->new_ttk__button(
    -text => "Collection",
    -command => sub{$CurCol = $Collection->name();
		    popMenu(\$CurCol, undef, [sort keys %{$Collection}]);
		    $Collection->change($CurCol);
		    collItems();} );

###
  my $onet = $bLF->new_ttk__button(
    -text => " Transpose (Use PDF Options) ",
    -command => sub{$main::PDFtrans = 1;main::transposeOne(SINGLE);});
  my $onee = $bLF->new_ttk__button(
    -text => "Edit",
    -width => 8,
    -command => \&main::editPro);
  my $oner = $bLF->new_ttk__button(
    -text => "Rename",
    -width => 8,
    -command => \&main::renamePro);
  my $onec = $bLF->new_ttk__button(
    -text => "Clone",
    -width => 8,
    -command => \&main::clonePro);
  my $oned = $bLF->new_ttk__button(
    -text => "Delete",
    -width => 8,
    -style => 'Red.TButton',
    -command => \&main::deletePro);

### Now pack everything
  # Single Selected File --- has to be packed first.
  $onet->g_pack(qw/-side left  -padx/ => [4,6]);
  $onee->g_pack(qw/-side left  -padx 6/);
  $oner->g_pack(qw/-side left  -padx 6/);
  $onec->g_pack(qw/-side left  -padx 6/);
  $oned->g_pack(qw/-side right -padx/ => [0,4]);

  ## New/Import/Sync
  $new->g_pack(qw/-side top -pady 4/);
  $imp->g_pack(qw/-side top -pady 4/);
  $syn->g_pack(qw/-side top -pady 4/);

  ## ChordPro/PDF Export/Mail
  $cp->g_pack   (qw/-side top -fill x -pady 4/);  # LabelFrame
  $ecpl->g_grid (qw/-row 0 -column 0 -sticky e/, -pady => [0,4]);
  $econe->g_grid(qw/-row 0 -column 1 -sticky w/, -padx => [4,8], -pady => [0,4]);
  $ecall->g_grid(qw/-row 0 -column 2 -sticky w/, -pady => [0,4]);

  $mcpl->g_grid (qw/-row 1 -column 0 -sticky e/);
  $mcone->g_grid(qw/-row 1 -column 1 -sticky w/, -padx => [4,8]);
  $mcall->g_grid(qw/-row 1 -column 2 -sticky w/);

  $pdf->g_pack  (qw/-side top -fill x -pady 4/);  # LabelFrame
  $epdfl->g_grid(qw/-row 0 -column 0 -sticky e/, -pady => [0,4]);
  $epone->g_grid(qw/-row 0 -column 1 -sticky w/, -padx => [4,8], -pady => [0,4]);
  $epall->g_grid(qw/-row 0 -column 2 -sticky w/, -pady => [0,4]);

  $mpdfl->g_grid(qw/-row 1 -column 0 -sticky e/);
  $mpone->g_grid(qw/-row 1 -column 1 -sticky w/, -padx => [4,8]);
  $mpall->g_grid(qw/-row 1 -column 2 -sticky w/);

  ## Key/Files
  $KeyLB->{frame}->g_pack (qw/-side left -fill y -ipadx 1 -padx 1/);
  $FileLB->{frame}->g_pack(qw/-side left -fill y -ipadx 1/);

  ## Browse/From Setlist/PDFs
  $brw->g_pack(qw/-side top -pady 4/);
  $fsl->g_pack(qw/-side top -pady 4/);
  $act->g_pack(qw/-side top -pady 8/);  # LabelFrame
  $cob->g_pack(qw/-side top -pady 8/);
}

# This method is called when one Listbox is scrolled with the keyboard
# It makes the Scrollbar reflect the change, and scrolls the other lists
sub scroll_filelb {
  my($sb, @args) = @_;
  $sb->set(@args); # tell the Scrollbar what to display
  my($top,$bot) = split(' ', $FileLB->{lb}->yview());
  $KeyLB->{lb}->yview_moveto($top);
}

sub actWin {
  my($act) = shift;

  ####
  my $view = $act->new_ttk__checkbutton(-text => "View",   -variable => \$Opt->{PDFview});
  my $cret = $act->new_ttk__checkbutton(-text => "Create", -variable => \$Opt->{PDFmake});
  my $prnt = $act->new_ttk__checkbutton(-text => "Print",  -variable => \$Opt->{PDFprint});

  ####
  my $sepa = $act->new_ttk__separator(qw/-orient horizontal/);
  my $ones = $act->new_ttk__button(-text => "Single Song", -command => sub{main::Main(SINGLE);});
  my $sepb = $act->new_ttk__separator(qw/-orient horizontal/);
  my $alls = $act->new_ttk__button(
    -text => "All Songs",
    -width => 8,
    -command => sub{main::Main(MULTIPLE);});
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
  my($frm) = @_;

  my $bf = $frm->new_ttk__frame(-padding => [0,16,0,0]);
  $bf->g_pack(qw/-side bottom -pady 4 -fill x/);

  CP::Win::defButtons($bf, 'Options', \&main::saveOpt, \&main::loadOpt, \&main::resetOpt);

  my $wid = $frm->new_ttk__frame();
  $wid->g_pack(qw/-side left -anchor n -expand 0/);

  my($a,$b,$c,$d,$e,$f,$g,$h,$z);
  #########################

  $a = $wid->new_ttk__checkbutton(-text => 'Center Lyrics',
				  -variable => \$Opt->{Center});
  $b = $wid->new_ttk__checkbutton(-text => 'Lyrics Only',
				  -variable => \$Opt->{LyricOnly});
  $c = $wid->new_ttk__checkbutton(-text => 'Group Lines',
				  -offvalue => MULTIPLE,
				  -onvalue => SINGLE,
				  -variable => \$Opt->{Together});
  $d = $wid->new_ttk__checkbutton(-text => '1/2 Height Blank Lines',
				  -variable => \$Opt->{HHBL});
  $z = $wid->new_ttk__button(
    -text => ' PDF Background ',
    -style => 'PDF.TButton',
    -command => sub{
      my($fg,$bg) = $ColourEd->Show(BLACK, $Opt->{PageBG}, BACKGRND);
      if ($bg ne '') {
	$Opt->{PageBG} = $bg;
	Tkx::ttk__style_configure("PDF.TButton", -background => $bg);
      }
    });
  $e = $wid->new_ttk__checkbutton(-text => "No Long Line warnings",
				  -variable => \$Opt->{NoWarn});
  $f = $wid->new_ttk__checkbutton(-text => "Ignore Capo Directives",
				  -variable => \$Opt->{IgnCapo});
  $g = $wid->new_ttk__checkbutton(-text => "Highlight full line",
				  -variable => \$Opt->{FullLineHL});
  $h = $wid->new_ttk__checkbutton(-text => "Comment full line",
				  -variable => \$Opt->{FullLineCM});

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
    -command => sub{popMenu(\$Opt->{LineSpace},undef,[qw/1 2 3 4 5 6 7 8 9 10 12 14 16 18 20/])});

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
  my $fcd = $frm->new_ttk__labelframe(
    -text => " Chord Diagrams ",
    -labelanchor => 'n');
  $fcd->g_pack(qw/-side right -anchor n/, -padx => [2,4]);
  $a = $fcd->new_ttk__label(-text => "Instrument:");
  $b = $fcd->new_ttk__button(
    -textvariable => \$Opt->{Instrument},
    -width => 8,
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$Opt->{Instrument},sub{readChords();},$Opt->{Instruments})
    });

  $c = $fcd->new_ttk__radiobutton(-text => "None",
				  -variable => \$Opt->{Grid}, -value => NONE);
  $d = $fcd->new_ttk__radiobutton(-text => "First Page",
				  -variable => \$Opt->{Grid}, -value => FIRSTP);
  $e = $fcd->new_ttk__radiobutton(-text => "All Pages",
				  -variable => \$Opt->{Grid}, -value => ALLP);
  $f = $fcd->new_ttk__button(-text => "Edit",
			     -width => 8,
			     -command => sub{CHedit('Save');});

  $a->g_grid(qw/-row 0 -column 0 -sticky e  -padx 2/, -pady => "4 0");
  $b->g_grid(qw/-row 0 -column 1 -sticky w -padx 4/, -pady => "4 0");
  $c->g_grid(qw/-row 1 -column 0 -sticky w  -padx 4/);
  $d->g_grid(qw/-row 2 -column 0 -sticky w  -padx 4/);
  $e->g_grid(qw/-row 3 -column 0 -sticky w  -padx 4/);
  $f->g_grid(qw/-row 2 -column 1 -sticky w -padx 4/);
}

##############
##
## Setlists
##
##############

sub setLists {
  my($frame,$NB) = @_;

  my $slFt = $frame->new_ttk__frame(qw/-relief raised -borderwidth 2 -style Wh.TFrame/);
  my $slFb = $frame->new_ttk__frame();

  $AllSets = CP::SetList->new();
  my $browser = $AllSets->{browser} = browser($slFb, $NB);

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
    -padding => [4,2,4,4]);
  my $sltR = $slFt->new_ttk__frame(qw/-style Wh.TFrame/);

  my $setsLB;
  my $rev = $Opt->{SLrev};
  my $sltr = $sltM->new_ttk__checkbutton(-variable => \$rev,
					 -style => 'Wh.TCheckbutton',
					 -command => sub{$Opt->change('SLrev', $rev);
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

  my($row,$w,$st,$cs) = (0,25,'YNb.TLabel',2);
  foreach my $l (['Name',        \$CurSet],
		 ['Date',        \$AllSets->{meta}{date}],
		 ['Setup',       \$AllSets->{meta}{setup}],
		 ['Sound Check', \$AllSets->{meta}{soundcheck}],
		 ['Set1 Start',  \$AllSets->{meta}{set1time}],
		 ['Set2 Start',  \$AllSets->{meta}{set2time}]) {
    my($n,$v) = @{$l};
    my $lab = $sltCS->new_ttk__label(-text => "$n: ", -background => WHITE);
    if ($row) {
      $w = ($row == 1) ? 18 : 8;
      $st = 'YNnf.TLabel';
      $cs = 1;
    }
    my $ent = $sltCS->new_ttk__label(-textvariable => $v, -style => $st, -width => $w);
    $lab->g_grid(-row => $row, -column => 0, -sticky => 'e', -pady => [0,6]);
    $ent->g_grid(-row => $row++, -column => 1, -columnspan => $cs, -sticky => 'w', -pady => [0,6]);
  }
  my $butEdt = $sltCS->new_ttk__button(
    -text => "Edit",
    -width => 6,
    -style => 'Green.TButton',
    -command => sub{if ($CurSet ne '') {$AllSets->edit()}});
  $butEdt->g_grid(-row => 2, -column => 2, -rowspan => 2, -sticky => 'w', -padx => 10, -pady => 4);
  my $butClr = $sltCS->new_ttk__button(
    -text => "Clear",
    -width => 6,
    -style => 'Green.TButton',
    -command => sub{$browser->reset();$AllSets->select('')});
  $butClr->g_grid(-row => 3, -column => 2, -rowspan => 2, -sticky => 'w', -padx => 10, -pady => 4);

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
  $can->g_pack(qw/-side top -fill x/, -pady => [0,0]);

  $sltCS->g_grid(qw/-row 0 -column 2 -columnspan 3 -sticky n/, -padx => [12,0]);

  # Print/Export/Save/Delete
  $butPrt->g_grid(qw/-row 1 -column 2 -pady 4/);
  $butInp->g_grid(qw/-row 1 -column 3 -pady 4/);
  $butExp->g_grid(qw/-row 1 -column 4 -pady 4/);

  $sltR->g_grid(qw/-row 0 -column 5 -padx 6 -pady 4/);
  # New/Rename/Clone/Delete buttons
  $slFt->g_grid_columnconfigure(6, -weight => 1);
  $butNew->g_pack(qw/-side top -padx 4 -pady 6/);
  $butRen->g_pack(qw/-side top -padx 4 -pady 6/);
  $butCln->g_pack(qw/-side top -padx 4 -pady 6/);
  $butSav->g_pack(qw/-side top -padx 4 -pady 6/);
  $butDel->g_pack(qw/-side top -padx 4 -pady 12/);
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
  my($wid) = shift;

  $CurCol = $Collection->name();
  $Cpath = $Collection->{$CurCol}.'/'.$CurCol;
  my $ccsub = sub{
    my @lst = (sort keys %{$Collection});
    popMenu(\$CurCol, sub{}, \@lst);
    if ($Collection->name() ne $CurCol) {
      $Collection->change($CurCol);
      collItems();
      showSize();
      fontWin();
    }	    
  };
  my $cedit = sub{
    if ($Collection->edit() eq 'OK' && $Collection->name() ne $CurCol) {
      $CurCol = $Collection->name();
      collItems();
    } else {
      showSize();
      fontWin();
    }
  };
  my($a,$b,$c,$d,$e,$f,$g);

  $a = $wid->new_ttk__label(-text => "Collection: ");
  $b = $wid->new_ttk__button(-textvariable => \$CurCol, -width => 10,
			     -style => 'Menu.TButton',    -command => $ccsub);
  $c = $wid->new_ttk__button(qw/-text Edit -command/ => $cedit);
  $d = $wid->new_ttk__label(-text => "Path: ");
  $e = $wid->new_ttk__label(-textvariable => \$Cpath);

  $f = $wid->new_ttk__label(-text => "Common PDF Path: ");
  $g = $wid->new_ttk__label(-textvariable => \$Opt->{PDFpath});

  $a->g_grid(qw/-row 0 -column 0 -sticky e/);
  $b->g_grid(qw/-row 0 -column 1 -sticky w/);
  $c->g_grid(qw/-row 0 -column 2 -sticky e/, -padx => [20,0]);
  $d->g_grid(qw/-row 0 -column 3 -sticky e/, -padx => [20,0]);
  $e->g_grid(qw/-row 0 -column 4 -sticky w/);

  $f->g_grid(qw/-row 1 -column 3 -sticky e/, -padx => [20,0], -pady => [0,4]);
  $g->g_grid(qw/-row 1 -column 4 -sticky w/, -pady => [0,4]);
}

sub collItems {
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
  $CurCol = $Collection->name();
  $Cpath = $Collection->{$CurCol}.'/'.$CurCol;
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

  my($a,$b,$c,$d,$e,$f,$g,$i,$j,$k,$m);
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

  $c = $wid->new_ttk__label(-width => 10, -anchor => 'e', -text => "Width:");
  $d = $wid->new_ttk__label(-width => 5, -justify => 'right', -textvariable => \$Wstr);
  $e = $wid->new_ttk__label(-width => 4, -justify => 'left', -text => "in\nmm\npt");

  $f = $wid->new_ttk__label(-width => 10, -anchor => 'e', -text => "Height:");
  $g = $wid->new_ttk__label(-width => 5, -justify => 'right', -textvariable => \$Hstr);
  $i = $wid->new_ttk__label(-width => 4, -justify => 'left', -text => "in\nmm\npt");

  $j = $wid->new_ttk__button(
    -text => "Edit Media",
    -command => sub{newMedia() if ($Media->edit() eq "OK");});

  $k = $wid->new_ttk__label(-text => "Print Media:");
  my $org = $Opt->{PrintMedia};
  $m = $wid->new_ttk__button(
    -textvariable => \$Opt->{PrintMedia},
    -width => 15,
    -style => 'Menu.TButton',
    -command => sub{
      my @lst = $Media->list();
      popMenu(\$Opt->{PrintMedia}, undef, \@lst);
      # Need to delay the save otherwise Opt->{PrintMedia} = 0
      Tkx::after_idle(sub{$Opt->save()});
    });

  $a->g_grid(qw/-row 0 -column 0 -sticky e/, -padx => [0,2], -pady => [0,8]);
  $b->g_grid(qw/-row 0 -column 1 -sticky w/, -pady => [0,8]);

  $c->g_grid(qw/-row 0 -column 2 -rowspan 2 -sticky w/, -pady => [0,8]);
  $d->g_grid(qw/-row 0 -column 3 -rowspan 2 -sticky e/, -pady => [0,8]);
  $e->g_grid(qw/-row 0 -column 4 -rowspan 2 -sticky w/, -pady => [0,8]);

  $f->g_grid(qw/-row 0 -column 5 -rowspan 2 -sticky w/, -pady => [0,8]);
  $g->g_grid(qw/-row 0 -column 6 -rowspan 2 -sticky e/, -pady => [0,8]);
  $i->g_grid(qw/-row 0 -column 7 -rowspan 2 -sticky w/, -pady => [0,8]);

  $j->g_grid(qw/-row 0 -column 8 -rowspan 2/, -padx => [10,0], -pady => [0,8]);

  $k->g_grid(qw/-row 1 -column 0 -sticky e/, -padx => [0,2], -pady => [0,8]);
  $m->g_grid(qw/-row 1 -column 1 -sticky w/, -pady => [0,8]);
}

sub newMedia {
#  $Opt->change('Media', $Opt->{Media});
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
  foreach my $c (Tkx::SplitList(Tkx::winfo_children($FFrame))) {
    Tkx::destroy($c);
  }
  CP::Fonts::fonts($FFrame, [qw/Title Chord Lyric Tab Comment Highlight Editor/]);

  Tkx::update();
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
  $but->g_grid(qw/-row 0 -padx 6/, -pady => [4,8], -column => $col);
}

sub pickBG {
  my($title,$fntp,$but,$var) = @_;

  $ColourEd->title("$title Background Colour");
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
  }
}

#############
##
## Commands
##
#############

sub commandWin {
  my($wid) = @_;
  my $sz = (OS eq 'win32') ? 56 : 42;

  CmdS($wid, 0, $sz, "View PDF", \$Cmnd->{Acro});
  CmdS($wid, 1, $sz, "Print PDF", \$Cmnd->{Print});

  my $blnk = $wid->new_ttk__frame();
  $blnk->g_grid(qw/-row 1 -column 4 -sticky nsew/);
  $wid->g_grid_columnconfigure(4, -weight => 1);

  my $bf = $wid->new_ttk__frame(-padding => [0,16,0,0]);
  $bf->g_grid(qw/-row 2 -column 0 -columnspan 5 -sticky nsew -pady 4/);

  CP::Win::defButtons($bf, 'Commands', \&main::saveCmnd, \&main::loadCmnd, \&main::resetCmnd);
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
    });
  $cbb->g_grid(-row => $r, qw/-column 3 -sticky w -padx 4 -pady 4/);
}

#############
##
## MISC Tab
##
#############

sub fileFrm {
  my($frm) = shift;

  my($a,$b,$c,$d);

  my $el = $frm->new_ttk__labelframe(
    -text => ' Error Log ',
    -labelanchor => 'n');
  $el->g_pack(qw/-side left/, -padx => [4,0], -pady => [0,8]);
  $a = $el->new_ttk__button(-text => "View",  -command => \&viewElog );
  $b = $el->new_ttk__button(-text => "Clear", -command => \&clearElog );
  $a->g_grid(qw/-row 0 -column 0 -sticky ew -padx 4/, -pady => [0,4]);
  $b->g_grid(qw/-row 0 -column 1 -sticky ew -padx 4/, -pady => [0,4]);

  my $del = $frm->new_ttk__labelframe(
    -text => ' Delete ',
    -labelanchor => 'n');
  $del->g_pack(qw/-side left/, -padx => [12,0], -pady => [0,8]);
  $c = $del->new_ttk__button(-text => "Pro Backups", -command => sub{DeleteBackups('.pro')} );
  $d = $del->new_ttk__button(-text => "Temp PDFs", -command => sub{DeleteBackups('.pdf')} );
  $c->g_grid(qw/-row 0 -column 0 -padx 4/, -pady => [0,4]);
  $d->g_grid(qw/-row 0 -column 1 -padx 4/, -pady => [0,4]);

  my $rn = $frm->new_ttk__button(-text => "View\n Release Notes ", -command => \&viewRelNt );
  $rn->g_pack(qw/-side left/, -padx => [12,0], -pady => 0);
}

sub optFrm {
  my($frm) = shift;

  my($a,$b);
  $a = $frm->new_ttk__button(-text => " Edit Sort Articles ", -command => \&main::editArticles );
  $b = $frm->new_ttk__button(-text => " Edit Options File ",  -command => \&main::editOpt );

  $a->g_grid(qw/-row 0 -column 0 -sticky ew -padx 4/, -pady => [0,8]);
  $b->g_grid(qw/-row 0 -column 1 -sticky ew -padx 4/, -pady => [0,8]);
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
    -text => "Copy To All\nCollections",
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

  $k->g_grid(qw/-row 2 -column 1 /, -padx => [0,4], -pady => [0,8]);
  $h->g_grid(qw/-row 2 -column 2 /, -padx => [0,4], -pady => [0,8]);
  $m->g_grid(qw/-row 2 -column 3 -columnspan 2 -sticky w/, -padx => [4,8], -pady => [0,8]);
}

1;
