package CP::TabWin;

# List of tags used for various elements within the display
# where a # indicates the bar's page index.
#
#  EDIT PAGE
#  barn       Bar # header for edit display
#       b#    Lines which create bars on the page display
#  ebl        Lines which create the edit display bar
#       bg#   Bar background rectangle (always below b#/ebl)
#       det#  Detection rectangle (for page view) that is raised to the top
#
#  rep           Repeat start/end indicator
#  rep           Repeat end indicator
#       lyr#     Lyric lines
#  fret bar#     All notes/rests in a bar
#       bar#     All bar headers and repeats
#
#  pcnt     Bar numbers down the side of the page display
#  phdr     Everything in the page header - Title, Key, etc.

use strict;
use warnings;

use Tkx;
use CP::Cconst qw/:OS :SHFL :TEXT :SMILIE :COLOUR :TAB :PLAY/;
use CP::Global qw/:FUNC :VERS :OPT :WIN :XPM :CHORD :SCALE/;
use CP::Pop qw/:POP :MENU/;
use CP::Tab;
use CP::Offset;
use CP::Cmsg;
use CP::Bar;
use CP::HelpTab;
use CP::Play;
use CP::LyricEd;

my $helpWin = '';

#
# This whole module relies on the external global $Tab object being initialised.
#
sub pageWindow {
  my($tab) = shift;

  if ($tab->{pFrm} eq '') {
    my $outer = $MW->new_ttk__frame(qw/-relief raised -borderwidth 2/, -padding => [0,0,0,4]);
    $outer->g_pack(qw//);
    $tab->{pFrm} = $outer;

    my $leftF = $outer->new_ttk__frame(qw/-borderwidth 0/);
    $leftF->g_pack(qw/-side left -anchor nw/, -padx => [8,0]);

    my $leftFt = $leftF->new_ttk__frame();
    $leftFt->g_grid(qw/-row 0 -column 1 -sticky we -pady 4/);
    $leftFt->g_grid_columnconfigure(0, -weight => 1);
    $leftFt->g_grid_columnconfigure(1, -weight => 1);
    $leftFt->g_grid_columnconfigure(2, -weight => 1);

    my $bup = $leftFt->new_ttk__button(
      -text => '<<< Prev Page ',
      -style => "Blue.TButton",
      -command => sub{$tab->PrevPage});
    $bup->g_grid(qw/-row 0 -column 0 -sticky w -padx 16/);
    my $bue = $leftFt->new_ttk__button(
      -text => 'Edit Lyrics',
      -style => "Blue.TButton",
      -command => sub{CP::LyricEd->Edit($tab);});
    $bue->g_grid(qw/-row 0 -column 1/);
    my $bun = $leftFt->new_ttk__button(
      -text => ' Next Page >>>',
      -style => "Blue.TButton",
      -command => sub{$tab->NextPage});
    $bun->g_grid(qw/-row 0 -column 2 -sticky e -padx 16/);

    $tab->{nCan} = $leftF->new_tk__canvas(
      -bg => MWBG,
      -relief => 'solid',
      -borderwidth => 0,
      -highlightthickness => 0,
      -selectborderwidth => 0,
      -width => BNUMW,
      -height => $Media->{height});
    $tab->{nCan}->g_grid(qw/-row 1 -column 0 -sticky n/);

    $tab->{pCan} = $leftF->new_tk__canvas(
      -bg => WHITE,
      -width => $Media->{width} - 1,
      -height => $Media->{height},
      -relief => 'solid',
      -borderwidth => 1,
      -selectborderwidth => 0,
      -highlightthickness => 0);
    $tab->{pCan}->g_grid(qw/-row 1 -column 1 -sticky n/);

    pageCanvas($tab);

    my $rightF = $outer->new_ttk__frame(qw/-borderwidth 0/);
    $rightF->g_pack(qw/-side right -fill y/, -padx => [8,4]);

    pageButtons($tab,$rightF);

    if (OS eq 'win32') {
      my $rightFb = $rightF->new_ttk__frame(qw/-borderwidth 0/);
      $rightFb->g_pack(qw/-side bottom/, -pady => [0,4]);
      CP::Play::pagePlay($tab, $rightFb);
    }
  } else {
    pageCanvas($tab);
  }
}

sub shiftOpt {
  my($tab,$frm,$pe) = @_;

  my $lb1 = $frm->new_ttk__label(-text => 'Semi-tones');

  my $me1 = $frm->new_ttk__button(
    -textvariable => \$tab->{trans},
    -width => 4,
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$tab->{trans},
	      sub {},
	      [qw/+12 +11 +10 +9 +8 +7 +6 +5 +4 +3 +2 +1 0
	       -1 -2 -3 -4 -5 -6 -7 -8 -9 -10 -11 -12/]);
    });

  my $bu1 = $frm->new_ttk__button(
    -text    => ' Go ',
    -width   => 4,
    -command => sub{transCmnd($tab, 'transpose', $pe)});

  my $lb2 = $frm->new_ttk__label(-text => 'One String');

  my $bu2 = $frm->new_ttk__button(
    -text    => ' Up ',
    -width   => 4,
    -command => sub{transCmnd($tab, 'ud1string', $pe, +5)});

  my $bu3 = $frm->new_ttk__button(
    -text    => ' Down ',
    -width   => 6,
    -command => sub{transCmnd($tab, 'ud1string', $pe, -5)});

  my $cb4 = $frm->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				       -compound => 'left',
				       -text => 'Adjust Strings',
				       -variable => \$Opt->{Refret},
				       -image => ['xtick', 'selected', 'tick']
      );
  $lb1->g_grid(qw/-row 0 -column 0 -columnspan 2/, -pady => [0,4]);
  $me1->g_grid(qw/-row 1 -column 0 /,              -padx => [8,4], -pady => [0,4]);
  $bu1->g_grid(qw/-row 1 -column 1 /,              -padx => [4,8], -pady => [0,4]);

  $lb2->g_grid(qw/-row 0 -column 2 -columnspan 2/, -pady => [0,4]);
  $bu2->g_grid(qw/-row 1 -column 2 /,              -padx => [16,4], -pady => [0,4]);
  $bu3->g_grid(qw/-row 1 -column 3 /,              -padx => [4,8],  -pady => [0,4]);

  $cb4->g_grid(qw/-row 1 -column 4 -sticky w/, -padx => [16,0], -pady => [0,4]);
}

sub transCmnd {
  my($tab,$func,$pe,$cnt) = @_;

  my($sel1,$sel2);
  if ($pe == EDIT) {
    $sel1 = $tab->{select1};
    $sel2 = $tab->{select2};
    $tab->{select1} = $tab->{select2} = $EditBar;
  }
  $tab->$func($pe, $cnt);
  if ($pe == EDIT) {
    $tab->{select1} = $sel1;
    $tab->{select2} = $sel2;
  }
}

#############################
#############################
##
## Page Frame (right) Section
##
#############################
#############################

sub pageButtons {
  my($tab,$frm) = @_;

  my $sel = $frm->new_ttk__labelframe(-text => ' Select ');
  $sel->g_pack(qw/-side top -fill x -padx 4 -pady 4/);

  my $coll = $sel->new_ttk__label(-text => 'Collection');
  my $colb = $sel->new_ttk__button(
    -textvariable => \$Collection->{name},
    -style => 'Menu.TButton',
    -command => sub{ my $cc = $Collection->{name};
		     $Collection->select();
		     if ($cc ne $Collection->{name}) {
		       if ((my $fn = $tab->{fileName}) ne '') {
			 $fn = (-e "$Path->{Tab}/$fn") ? "$Path->{Tab}/$fn" : '';
			 $tab->new($fn);
		       }
		       $tab->drawPageWin();
		       CP::TabMenu::refresh();
		     }
                   }
    );
  my $medl = $sel->new_ttk__label(-text => 'Media');
  my $medb = $sel->new_ttk__button(
    -textvariable => \$Opt->{Media},
    -style => 'Menu.TButton',
    -command => [\&newMedia, $tab],
    );

  $coll->g_grid(qw/-row 0 -column 0 -sticky e/, -padx => [4,0], -pady => [0,4]);
  $colb->g_grid(qw/-row 0 -column 1 -sticky w/, -padx => [2,0], -pady => [0,4]);
  $medl->g_grid(qw/-row 0 -column 2 -sticky e/, -padx => [20,0], -pady => [0,4]);
  $medb->g_grid(qw/-row 0 -column 3 -sticky w/, -padx => [2,0], -pady => [0,4]);
######

  my $frt = $frm->new_ttk__frame(qw/-relief raised -borderwidth 2/);
  $frt->g_pack(qw/-side top -fill x -padx 4 -pady 4/);

  my $lb2 = $frt->new_ttk__label(-text => 'Tab File Name');
  my $en2 = $frt->new_ttk__entry(-textvariable => \$tab->{fileName}, -width => 38,
				 -state => 'disabled');
  my $lb3 = $frt->new_ttk__label(-text => 'PDF File Name');
  my $en3 = $frt->new_ttk__entry(-textvariable => \$tab->{PDFname}, -width => 38);
  my $lb4 = $frt->new_ttk__label(-text => 'Title');
  my $en4 = $frt->new_ttk__entry(-textvariable => \$tab->{title}, -width => 38);
  $en4->g_bind("<KeyRelease>" => sub{$tab->pageTitle();$tab->setEdited(1);});
  my $lb6 = $frt->new_ttk__label(-text => 'Heading Note');
  my $en6 = $frt->new_ttk__entry(
    -textvariable => \$tab->{note},
    -width        => 30);
  $en6->g_bind("<KeyRelease>" => sub{$tab->pageNote();$tab->setEdited(1);});

  $lb2->g_grid(qw/-row 0 -column 0 -sticky e/, -padx => [0,2], -pady => [4,4]);  # TFN
  $en2->g_grid(qw/-row 0 -column 1 -sticky w/, -padx => [0,4], -pady => [4,4]);
  $lb3->g_grid(qw/-row 1 -column 0 -sticky e/, -padx => [0,2], -pady => [0,4]);  # PDF FN
  $en3->g_grid(qw/-row 1 -column 1 -sticky w/, -padx => [0,4], -pady => [0,4]);
  $lb4->g_grid(qw/-row 2 -column 0 -sticky e/, -padx => [0,2], -pady => [0,4]);  # Title
  $en4->g_grid(qw/-row 2 -column 1 -sticky w/, -padx => [0,4], -pady => [0,4]);
  $lb6->g_grid(qw/-row 3 -column 0 -sticky e/, -padx => [0,2], -pady => [0,4]);  # HN
  $en6->g_grid(qw/-row 3 -column 1 -sticky w/, -padx => [0,0], -pady => [0,4]);

######

  my $edit = $frm->new_ttk__labelframe(-text => ' Edit ');
  $edit->g_pack(qw/-side top -fill x -padx 4 -pady 4/);
  my $bu1 = $edit->new_ttk__button(-text => 'Edit Bar',
				   -style => "Green.TButton",
				   -command => sub{$tab->editBar});
  $bu1->g_grid(qw/-row 0 -column 0 -padx 8/, -pady => [0,4]);
  my $bu2 = $edit->new_ttk__button(-text => 'Clone Bar(s)',
				   -style => "Green.TButton",
				   -command => sub{$tab->Clone});
  $bu2->g_grid(qw/-row 0 -column 1 -padx 8/, -pady => [0,4]);

  my $bu9 = $edit->new_ttk__button(-text => 'Clear Selection',
				   -style => "Red.TButton",
				   -command => sub{$tab->ClearSel});
  $bu9->g_grid(qw/-row 1 -column 0 -padx 8 -pady 4/);
  my $bu10 = $edit->new_ttk__button(-text => 'Clear Bar(s)',
				   -style => "Red.TButton",
				   -command => sub{$tab->ClearBars});
  $bu10->g_grid(qw/-row 1 -column 1 -padx 8 -pady 4/);
  my $bu11 = $edit->new_ttk__button(-text => 'Delete Bar(s)',
				   -style => "Red.TButton",
				   -command => sub{$tab->DeleteBars(1)});
  $bu11->g_grid(qw/-row 0 -rowspan 2 -column 2 -padx 8/, -pady => [0,4]);
######

  my $cp = $frm->new_ttk__labelframe(-text => ' Copy/Paste ');
  $cp->g_pack(qw/-side top -fill x -padx 4 -pady 4/);

  my $cb = $cp->new_ttk__label(-text => 'Copy Buffer:', -font => "BTkDefaultFont");
  $cb->g_grid(qw/-row 0 -column 1 -columnspan 2 -sticky e/, -pady => [0,4]);
  my $cbs = $cp->new_ttk__label(-textvariable => \$CP::Tab::CopyIdx);
  $cbs->g_grid(qw/-row 0 -column 3 -columnspan 4 -sticky w -padx 2/, -pady => [0,4]);

  my($volt,$rep,$hdg,$just,$bg,$newlp,$note) = (1,2,4,8,16,32,64);
  my $bu5 = $cp->new_ttk__button(-text => 'Copy',
				 -style => "Green.TButton",
				 -command => sub{$tab->Copy($volt|$rep|$hdg|$just|$bg|$newlp|$note)});
  $bu5->g_grid(qw/-row 1 -column 0 -sticky e/, -padx => [4,0]);

  $cp->g_grid_columnconfigure(1, -minsize => 16);
  $cp->g_grid_columnconfigure(3, -minsize => 10);
  $cp->g_grid_columnconfigure(5, -minsize => 10);
  my $ch1 = $cp->new_ttk__separator(-style => 'H.TSeparator', -orient => 'horizontal');
  $ch1->g_grid(qw/-row 1 -column 1 -sticky ew -padx 4/);

  my $cpf = $cp->new_ttk__frame();
  $cpf->g_grid(qw/-row 1 -column 2 -columnspan 6/);
  my @cmn = (-style => 'My.TCheckbutton',
	     -compound => 'left',
	     -image => ['xtick', 'selected', 'tick']);
  my $cpv = $cpf->new_ttk__checkbutton(@cmn,
				       -text => 'Volta',
				       -variable => \$volt, -onvalue => VOLTA);
  my $cpr = $cpf->new_ttk__checkbutton(@cmn,
				       -text => 'Repeat',
				       -variable => \$rep,  -onvalue => REPEAT);
  my $cph = $cpf->new_ttk__checkbutton(@cmn,
				       -text => 'Heading',
				       -variable => \$hdg,  -onvalue => HEAD);
  my $cpj = $cpf->new_ttk__checkbutton(@cmn,
				       -text => 'Justify',
				       -variable => \$just, -onvalue => JUST);
  my $cpb = $cpf->new_ttk__checkbutton(@cmn,
				       -text => 'BackGround',
				       -variable => \$bg,   -onvalue => BBG);
  my $cpp = $cpf->new_ttk__checkbutton(@cmn,
				       -text => 'New Line/Page',
				       -variable => \$newlp,-onvalue => NEWLP);
  my $cpn = $cpf->new_ttk__checkbutton(@cmn,
				       -text => 'Notes',
				       -variable => \$note, -onvalue => NOTE);

  $cpv->g_grid(qw/-row 0 -column 0 -sticky w/, -padx => [0,8]);
  $cpr->g_grid(qw/-row 1 -column 0 -sticky w/, -padx => [0,8]);
  $cph->g_grid(qw/-row 0 -column 1 -sticky w/, -padx => [0,8]);
  $cpj->g_grid(qw/-row 1 -column 1 -sticky w/, -padx => [0,8]);
  $cpb->g_grid(qw/-row 0 -column 2 -sticky w/, -padx => [0,8]);
  $cpp->g_grid(qw/-row 1 -column 2 -sticky w/, -padx => [0,8]);
  $cpn->g_grid(qw/-row 0 -column 3 -rowspan 2 -sticky w/, -padx => [0,8]);


  my $paste = $cp->new_ttk__label(-text => 'Paste', -font => "BTkDefaultFont");
  $paste->g_grid(qw/-row 2 -column 0 -sticky e -padx/ => [4,0]);
  my $ph1 = $cp->new_ttk__separator(-style => 'H.TSeparator', -orient => 'horizontal');
  $ph1->g_grid(qw/-row 2 -column 1 -sticky ew -padx 4/);
  my $bu6 = $cp->new_ttk__button(-text => 'Before',
				 -style => "Green.TButton",
				 -command => sub{$tab->PasteBefore});
  $bu6->g_grid(qw/-row 2 -column 2 -sticky we/, -pady => [4,0]);
  my $ph2 = $cp->new_ttk__separator(-style => 'H.TSeparator', -orient => 'horizontal');
  $ph2->g_grid(qw/-row 2 -column 3 -sticky ew -padx 4/);
  my $povar = 1;
  my $bu7 = $cp->new_ttk__button(-text => 'Over',
				 -style => "Green.TButton",
				 -command => sub{$tab->PasteOver($povar)});
  $bu7->g_grid(qw/-row 2 -column 4 -sticky we/, -pady => [4,0]);
  my $ph3 = $cp->new_ttk__separator(-style => 'H.TSeparator', -orient => 'horizontal');
  $ph3->g_grid(qw/-row 2 -column 5 -sticky ew -padx 4/);
  my $bu8 = $cp->new_ttk__button(-text => 'After',
				 -style => "Green.TButton",
				 -command => sub{$tab->PasteAfter});
  $bu8->g_grid(qw/-row 2 -column 6 -sticky we/, -pady => [4,0]);

  my $por = $cp->new_ttk__checkbutton(@cmn,
				      -text => 'Replace',
				      -variable => \$povar, -onvalue => 1);
  $por->g_grid(qw/-row 3 -column 4/, -pady => [0,4]);
######

  my $selbg = $frm->new_ttk__frame();
  $selbg->g_pack(qw/-side top -fill x/);

  my $bgnd = $selbg->new_ttk__labelframe(-text => ' Background ');
  $bgnd->g_pack(qw/-side left -fill x/, -padx => [4,0]);
  my $bu12 = $bgnd->new_ttk__button(-text => 'Set',
				    -width => 6,
				    -style => "Green.TButton",
				    -command => sub{$tab->setBG});
  $bu12->g_grid(qw/-row 0 -column 0 -sticky we -padx 8/, -pady => [0,4]);
  my $bu13 = $bgnd->new_ttk__button(-text => 'Clear',
				    -width => 6,
				    -style => "Red.TButton",
				    -command => sub{$tab->clearBG});
  $bu13->g_grid(qw/-row 0 -column 1 -sticky we -padx 8/, -pady => [0,4]);

  my $lyr = $selbg->new_ttk__labelframe(-text => ' Lyrics ');
  $lyr->g_pack(qw/-side right -fill x -padx 4 -pady 4/);
  my $bu14 = $lyr->new_ttk__button(-text => 'Shift Up 1 Line',
				   -style => "Green.TButton",
				   -command => sub{$tab->{lyrics}->shiftUp()});
  $bu14->g_grid(qw/-row 0 -column 0 -sticky we -padx 8/, -pady => [0,4]);
  my $bu15 = $lyr->new_ttk__button(-text => 'Shift Down 1 Line',
				   -style => "Green.TButton",
				   -command => sub{$tab->{lyrics}->shiftDown()});
  $bu15->g_grid(qw/-row 0 -column 1 -sticky we -padx 8/, -pady => [0,4]);
###
  my $frb = $frm->new_ttk__labelframe(-text => ' Transpose ');
  $frb->g_pack(qw/-side top -fill x -padx 4 -pady 4/);

  shiftOpt($tab, $frb, PAGE);
###
  my $mrgn = $frm->new_ttk__labelframe(-text => " Margins ", -padding => [6,0,0,0]);
  $mrgn->g_pack(qw/-side top -fill x -padx 4 -pady 4/);

  my $col = 0;
  foreach my $m (qw/Left Right Top Bottom/) {
    $a = $mrgn->new_ttk__label(-text => "$m", -anchor => 'e');

    $b = $mrgn->new_ttk__spinbox(
      -textvariable => \$Opt->{"${m}Margin"},
      -from => 0,
      -to => 72,
      -wrap => 1,
      -width => 2,
      -state => 'readonly',
      -command => sub{$Opt->saveOne("${m}Margin");$tab->drawPageWin();});
    $a->g_grid(-row => 0, -column => $col, -padx => [2,16], -pady => [0,4]);
    $b->g_grid(-row => 1, -column => $col, -padx => [2,16], -pady => [0,4]);
    $col++;
  }
}

sub newMedia {
  my($tab) = shift;

  popMenu(\$Opt->{Media}, undef, $Media->list());
  $Media = $Media->change($Opt->{Media});
  $tab->drawPageWin();
  CP::TabMenu::refresh();
}

sub pageCanvas {
  my($tab) = shift;

  my $can = $tab->{pCan};
  if ($Opt->{LyricLines}) {
    # We need to preserve lyrics across Canvas refreshes.
    $tab->{lyrics}->collect();
  }
  $can->delete('all');
  $can->configure(-width => $Media->{width} - 1, -height => $Media->{height});

  my $off = $tab->{pOffset};
  my $w = $off->{width};
  my $h = $off->{height};
  my $y = $tab->{pageHeader} + $Opt->{TopMargin};
  my $pidx = 0;
  foreach my $r (0..($tab->{rowsPP} - 1)) {
    my $x = $Opt->{LeftMargin};
    foreach (1..$Opt->{Nbar}) {
      CP::Bar::pageBarOutline(undef, $tab, $pidx++, $x, $y);
      $x += $w;
    }
    $y += $h;
  }
  $tab->{lyrics}->widgets();
}

1;
