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

use Tkx;
use CP::Cconst qw/:OS :SHFL :TEXT :SMILIE :COLOUR :TAB :PLAY/;
use CP::Global qw/:FUNC :VERS :OPT :WIN :XPM :CHORD :SCALE/;
use CP::Tab;
use CP::Offset;
use CP::Cmsg;
use CP::Bar;
use CP::HelpTab;
use CP::Play;

my $helpWin = '';

#
# This whole module relies on the external global $Tab object being initialised.
#
sub pageWindow {
  if ($Tab->{pFrm} eq '') {
    my $outer = $MW->new_ttk__frame(qw/-relief raised -borderwidth 2/, -padding => 0);
    $outer->g_pack(qw//);

    my $menuF = $outer->new_ttk__frame();
    $menuF->g_pack(qw/-side left -fill y -padx 4 -pady 4/);

    menu_buttons($menuF);

    my $sep = $outer->new_ttk__separator(qw/-orient vertical/);
    $sep->g_pack(qw/-side left -fill y/);

    my $leftF = $outer->new_ttk__frame(qw/-borderwidth 0/);
    $leftF->g_pack(qw/-side left -anchor nw/);

    my $midF = $outer->new_ttk__frame(qw/-borderwidth 0/);
    $midF->g_pack(qw/-side left -anchor nw/, -padx => [8,0]);

    my $rightF = $outer->new_ttk__frame(qw/-borderwidth 0/);
    $rightF->g_pack(qw/-side right -fill y/, -padx => [8,4]);

    my $rightFt = $rightF->new_ttk__frame(qw/-relief raised -borderwidth 2/,
					  -padding => [0,4,0,4]);
    $rightFt->g_pack(qw/-side top -fill x -pady 4/);

    my $rightFm = $rightF->new_ttk__frame(qw/-relief raised -borderwidth 2/);
    $rightFm->g_pack(qw/-side top -fill x -pady 4/);

    my $pfn = $Tab->{nFrm} = $midF->new_ttk__frame();
    $pfn->g_pack(qw/-side left -anchor nw -expand 1 -fill y/);

    $Tab->{nCan} = $pfn->new_tk__canvas(
      -bg => MWBG,
      -relief => 'solid',
      -borderwidth => 0,
      -highlightthickness => 0,
      -selectborderwidth => 0,
      -width => BNUMW,
      -height => $Media->{height});
    $Tab->{nCan}->g_pack(qw/-side top -expand 0 -fill y/);

    $Tab->{pFrm} = $midF;
    pageCanvas();

    pButtons($rightFt);
    pageOpts($rightFm);

    if (OS eq 'win32') {
      my $rightFb = $rightF->new_ttk__frame(qw/-borderwidth 0/);
      $rightFb->g_pack(qw/-side top/, -pady => [0,4]);
      CP::Play::pagePlay($rightFb);
    }
  } else {
    pageCanvas();
  }
}

#
# Called once at start-up
#
sub editWindow {
  if ($Tab->{eWin} eq '') {
    ($Tab->{eWin}, my $outer) = popWin(0, 'Bar Editor', 10, 10);
    $Tab->{eWin}->g_wm_protocol('WM_DELETE_WINDOW', sub{$EditBar->Cancel()});
    $outer->g_pack(qw//);
    $Tab->{eWin}->g_wm_withdraw();

    $EditBar = CP::Bar->new($Tab->{eOffset});
    $EditBar->{pidx} = -1;
    $EditBar->{pbar} = 0;
    $EditBar1 = CP::Bar->new($Tab->{eOffset});
    $EditBar1->{pidx} = -2;
    $EditBar1->{pbar} = 0;
    $EditBar->{next} = $EditBar1;
    $EditBar1->{prev} = $EditBar;

    my $efb = $outer->new_ttk__frame(qw/-borderwidth 0/, -padding => [8,0,4,4]);
    $efb->g_pack(qw/-side top -fill x/);
    eButtons($efb);

    my $eFrm = $Tab->{eFrm} = $outer->new_ttk__frame();
    $eFrm->g_pack(qw/-side top -expand 0/);
    editCanvas($eFrm);

    my $frnum = $outer->new_ttk__frame(qw/-borderwidth 0/);
    $frnum->g_pack(qw/-side top -expand 1 -fill x/, -padx => [4,0]);
    editBarFret($frnum);

    my $frb = $outer->new_ttk__frame(qw/-borderwidth 0/);
    $frb->g_pack(qw/-side top -expand 1 -fill x/, -padx => [4,0], -pady => [0,4]);

    my $baropt = $frb->new_ttk__labelframe(-text => ' Bar Options ', -padding => [0,0,4,4]);
    $baropt->g_pack(qw/-side left -anchor w/, -padx => 0, -pady => [8,0]);
    editBarOpts($baropt);

    my $shiftopt = $frb->new_ttk__labelframe(-text => ' Note Shift ', -padding => [4,0,4,4]);
    $shiftopt->g_pack(qw/-side left -anchor nw/, -padx => [16,0], -pady => [8,0]);
    shiftOpt($shiftopt, EDIT);

    my $frnp = $frb->new_ttk__frame(-padding => [4,0,4,4]);
    $frnp->g_pack(qw/-side left -anchor w/, -padx => [16,0], -pady => [8,0]);

    my $bp = $frnp->new_ttk__button(
      -text => '<<< Prev Bar ',
      -style => "Green.TButton",
      -command => [\&CP::Bar::EditPrev, 0]);
    $bp->g_grid(qw/-row 0 -column 0 -padx 10 -pady 4/);
    my $bn = $frnp->new_ttk__button(
      -text => ' Next Bar >>>',
      -style => "Green.TButton",
      -command => [\&CP::Bar::EditNext, 0]);
    $bn->g_grid(qw/-row 0 -column 1 -padx 10 -pady 4/);

    my $bp = $frnp->new_ttk__button(
      -text => '<<< Prev w/Save ',
      -style => "Green.TButton",
      -command => [\&CP::Bar::EditPrev, 1]);
    $bp->g_grid(qw/-row 1 -column 0 -padx 10 -pady 4/);
    my $bn = $frnp->new_ttk__button(
      -text => ' Next w/Save >>>',
      -style => "Green.TButton",
      -command => [\&CP::Bar::EditNext, 1]);
    $bn->g_grid(qw/-row 1 -column 1 -padx 10 -pady 4/);
  }
  else {
    editCanvas($Tab->{eFrm});
  }
}

sub menu_buttons {
  my($frame) = shift;

  my $topF = $frame->new_ttk__frame(qw/-relief raised -borderwidth 2/, -padding => 0);
  $topF->g_pack(qw/-side top/);

  #   Image       Balloon        Function           row,column,rowspan,columnspan
  my $items = [
    [['open',       'Open Tab',             sub{main::openTab()},       0,0,1,1],
     ['close',      'Close Tab',            sub{main::closeTab()},      0,1,1,1]],
    [['new',        'New Tab',              sub{main::newTab()},        1,0,1,1],
     ['delete',     'Delete Tab',           sub{main::delTab()},        1,1,1,1]],
    [['SEP',        '',            '',                                  2,0,1,2]],
    [['save',       'Save File',            sub{$Tab->save()},          3,0,1,1],
     ['saveAs',     'Save File As',         sub{$Tab->saveAs()},        3,1,1,1]],
    [['Rename Tab', 'Rename Current Tab',   sub{main::renameTab()},     4,0,1,2]],
    [['Export Tab', 'Export Current Tab',   sub{main::exportTab()},     5,0,1,2]],
    [['SEP',        '',            '',                                  6,0,1,2]],
    [['viewPDF',    'View PDF',             sub{CP::TabPDF::make('V')}, 7,0,1,1],
     ['saveclose',  'Save, Make and Close', sub{saveCloseTab()},        7,1,3,1]],
    [['makePDF',    'Make PDF',             sub{CP::TabPDF::make('M')}, 8,0,1,1]],
    [['batchPDF',   'Batch Make PDF',       sub{CP::TabPDF::batch()},   9,0,1,1]],
    [['printPDF',   'Print PDF',            sub{CP::TabPDF::make('P')},10,0,1,1],
     ['saveText',   'Save As Text',         sub{$Tab->saveAsText()},   10,1,1,1]],
    [['SEP',        '',            '',                                 11,0,1,2]],
    [['exit',       'Exit',                 sub{main::exitTab()},      12,0,1,2]],
    [['SEP',        '',            '',                                 13,0,1,2]],
    [['viewlog',    'View Error Log',       sub{viewElog()},           14,0,1,1],
     ['clearlog',   'Clear Error Log',      sub{clearElog()},          14,1,1,1]],
    [['Find',       'View Release Notes',   sub{viewRelNt()},          15,0,1,1],
     ['delete',     'Delete Tab Backups',   sub{DeleteBackups('.tab',$Path->{Temp})}, 15,1,1,1]],
      ];
  foreach my $r (@{$items}) {
    foreach my $c (@{$r}) {
      oneMbutton($topF, @{$c});
    }
  }

  my $midC = $frame->new_ttk__labelframe(-text => ' Collection ',
					 -labelanchor => 'n', -padding => 0);
  $midC->g_pack(qw/-side top -pady 4/);
  oneMbutton($midC, 'Select', '', sub{main::collectionSel()}, 0,0,1,1);
  oneMbutton($midC, 'Edit',   '', sub{$Collection->edit()},   1,0,1,1);

  my $midM = $frame->new_ttk__labelframe(-text => ' Media ',
					 -labelanchor => 'n', -padding => 0);
  $midM->g_pack(qw/-side top -pady 4/);
  oneMbutton($midM, 'Select', '', sub{main::mediaSel()}, 0,0,1,1);
  oneMbutton($midM, 'Edit',   '', sub{$Media->edit()},   1,0,1,1);

  my $midF = $frame->new_ttk__labelframe(-text => ' Fonts ',
					 -labelanchor => 'n', -padding => 0);
  $midF->g_pack(qw/-side top -pady 4/);
  oneMbutton($midF, 'Select', '', sub{main::fontEdit()}, 0,0,1,1);

  my $botF = $frame->new_ttk__frame(qw/-relief raised -borderwidth 2/, -padding => 0);
  $botF->g_pack(qw/-side bottom/);

  CORE::state $helpWin = '';
  foreach my $t (['About', 'Show Version', sub{showVersion()}, 0,0,1,1],
		 ['Help',  'Tab Help', sub{$helpWin=CP::HelpTab::help($helpWin)}, 1,0,1,1] ) {
    oneMbutton($botF, @{$t});
  }
}

sub saveCloseTab {
  $Tab->save();
  CP::TabPDF::make('M');
  $Tab->new('');
}

sub oneMbutton {
  my($frm,$img,$desc,$func,$row,$col,$rspn,$cspn) = @_;

  my $but;
  my @anc = ();
  if ($img eq 'SEP') {
    $but = $frm->new_ttk__separator(qw/-orient horizontal/);
    @anc = qw/-sticky we/;
  } else {
    if (makeImage("$img", \%XPM) ne '') {
      $but = $frm->new_ttk__button(-image => $img, -command => $func);
      balloon($but, $desc);
    } else {
      $but = $frm->new_ttk__button(-text => $img, -command => $func);
    }
    @anc = qw/-padx 4/;
  }
  $but->g_grid(-row => $row, -column => $col,
	       -rowspan => $rspn, -columnspan => $cspn,
	       -pady => 4, @anc);
}

sub showVersion{
  message(SMILE, "Version $Version\nian\@houlding.me.uk");
}

############################
############################
##
## Edit Frame (left) Section
##
############################
############################
sub eButtons {
  my($frm) = @_;

  foreach my $t (['Save',             'Save',         'Green'],
		 ['Update',           'Update',       'Green'],
		 ['Insert After',     'InsertAfter',  'Green'],
		 ['Insert Before',    'InsertBefore', 'Green'],
		 ['Clear Background', 'RemoveBG',     'Red'],
		 ['Set Background',   'Background',   'Green'],
		 ['Clear Bar',        'Clear',        'Red'],
		 ['>> Cancel <<',     'Cancel',       'Red']) {
    my($txt,$func,$fg) = @{$t};
    my $b = $frm->new_ttk__button(
      -text => $txt,
      -style => "$fg.TButton",
      -command => sub{$EditBar->$func()});
    $b->g_pack(qw/-side right -padx 10 -pady 2/);
  }
}

sub editCanvas {
  my($frame) = shift;

  my $ecan = $Tab->{eCan};
  my $off = $Tab->{eOffset};
  my $eh = $off->{height} + (INDENT * 2);
  my $ew = (INDENT * 2) + (POSIX::ceil($off->{width}) * 2) + INDENT;
  $frame->configure(-width => $ew, -height => $eh);
  if ($ecan ne '') {
    $ecan->delete('all');
    $ecan->configure(-width => $ew, -height => $eh);
  } else {
    $ecan = $Tab->{eCan} = $frame->new_tk__canvas(
      -width => $ew,
      -height => $eh,
      -bg => "WHITE",
      -relief => 'solid',
      -borderwidth => 1);
    $ecan->g_pack(qw//);
  }

  my $hd = int($Tab->{barnSize} * 1.4);
  # Green area at the top for the Bar number
  $ecan->create_rectangle(0, 0, $ew+3, $hd, -fill => DPOPBG, -width => 0);
  $ecan->create_line(0, $hd, $ew+3, $hd, -fill => BROWN, -width => 1);

  $Tab->{editX} = 0;
  $Tab->{editY} = $hd;
  $EditBar->{canvas} = $EditBar1->{canvas} = $ecan;

  $EditBar->{x} = INDENT * 2;
  $EditBar->{y} = $Tab->{editY} + INDENT;
  $EditBar->outline();

  $EditBar1->{x} = (INDENT * 2) + $off->{width};
  $EditBar1->{y} = $EditBar->{y};
  $EditBar1->outline();
}

sub editBarFret {
  my($frm) = shift;

  ####################
  # Fret Numbers .....
  ####################
  my $fr1 = $frm->new_ttk__labelframe(-text => ' Fret Number ', -padding => [4,0,4,4]);
  $fr1->g_grid(qw/-row 0 -column 0 -pady 4/, -padx => [0,4]);

  my $i = -1;
  foreach my $row (0..1) {
    foreach my $clm (0..12) {
      my $txt = ($row | $clm) ? $i : 'X';
      my $rb = $fr1->new_ttk__radiobutton(
	-text => "$txt",
	-width => 2,
	-variable => \$Tab->{fret},
	-value => $txt,
	-style => 'Toolbutton',
	);
      $rb->g_grid(-row => $row, -column => $clm, -padx => 3, -pady => 3);
      $i++;
    }
  }

  #############
  # Rests .....
  #############
  my $fr2 = $frm->new_ttk__labelframe(-text => ' Rest ', -padding => [0,0,4,4]);
  $fr2->g_grid(qw/-row 0 -column 1 -sticky new -padx 4 -pady 4/);

  foreach my $r (qw/1 2 4 8 16 32/) {
    my $val = "r$r";
    my $lbl = ($r > 1) ? "1/$r" : $r;
    my $but = "b$r";
    my $lb = $fr2->new_ttk__label(-text => $lbl, -width => length($lbl), -anchor => 'e', -padding => [4,0,0,0]);
    $lb->g_pack(qw/-side left/);
    makeImage("$but", \%XPM);
    my $rb = $fr2->new_ttk__radiobutton(
      -image => $but,
      -variable => \$Tab->{fret},
      -value => $val,
      -style => 'Toolbutton',
	);
    $rb->g_pack(qw/-side left -padx 2/);
  }

  ###########################
  # Slide/Hammer Bend/Release
  ###########################
  my $fr3 = $frm->new_ttk__labelframe(-text => ' Slide/Hammer/Bend/Release ', -padding => [0,0,4,0]);
  $fr3->g_grid(qw/-row 0 -column 2 -sticky new -padx 4 -pady 4/);

  foreach my $b (['Slide','s',0,0], ['Hammer','h',0,1], ['Bend','b',1,0], ['Bend/Release','r',1,1]) {
      my $rb = $fr3->new_ttk__radiobutton(
	-text => $b->[0],
	-variable => \$Tab->{shbr},
	-value => $b->[1],
	-style => 'Toolbutton',
	-command => sub{$EditBar->deselect()});
    $rb->g_grid(-row => $b->[2], -column => $b->[3], -sticky => 'ew', -padx => 8, -pady => 4);
  }
  my $c = $fr3->new_ttk__radiobutton(
	-text => '  Off  ',
	-variable => \$Tab->{shbr},
	-value => $b->[1],
	-style => 'Toolbutton',
	-command => sub{$Tab->{shbr} = ''});
  $c->g_grid(-row => 0, -column => 2, -rowspan => 2, -padx => [16,8], -pady => 4);
}

###################
# Bar Options .....
###################
sub editBarOpts {
  my($frm) = @_;

  my $lb1 = $frm->new_ttk__label(-text => 'Volta Bracket');

  my $mb1 = $frm->new_ttk__button(
    -textvariable => \$EditBar->{volta},
    -width => 7,
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$EditBar->{volta},
	      sub{$EditBar->volta()},
	      [qw/None Left Center Right Both/]);
    });
  my $lb2 = $frm->new_ttk__label(-text => 'Header Text');
  my $ent = $frm->new_ttk__entry(
    -width => 20,
    -validate => 'key',
    -validatecommand => [sub{$Tab->topVal(@_)}, Tkx::Ev("%P")]);
  $EditBar->{topEnt} = $ent;
  $ent->configure(-invalidcommand => sub{Tkx::bell();$ent->configure(-validate => 'key');});
  my $lb3 = $frm->new_ttk__label(-text => 'Justify -');
  my $mb2 = $frm->new_ttk__button(
    -textvariable => \$EditBar->{justify},
    -width => 6,
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$EditBar->{justify},
	      sub{$EditBar->topText()},
	      [qw/Left Right/]);
    });
  my $lb4 = $frm->new_ttk__label(-text => 'Repeat');
  my $mb3 = $frm->new_ttk__button(
    -textvariable => \$EditBar->{rep},
    -width => 7,
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$EditBar->{rep},
	      sub{$EditBar->repeat()},
	      [qw/None Start End/]);
    });
  my $lb5 = $frm->new_ttk__label(-text => 'Note Font');
  my $mb4 = $frm->new_ttk__button(
    -textvariable => \$Tab->{noteFsize},
    -width => 8,
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$Tab->{noteFsize},
	      undef,
	      [qw/Normal Small/]);
    });
  my $lb6 = $frm->new_ttk__label(-text => "Bar Starts:");
  my $cb1 = $frm->new_ttk__checkbutton(
    -text => 'Line',
    -variable => \$EditBar->{newline},
    -command => sub{$EditBar->{newpage} = 0 if ($EditBar->{newline} == 1);});
  my $cb2 = $frm->new_ttk__checkbutton(
    -text => 'Page',
    -variable => \$EditBar->{newpage},
    -command => sub{$EditBar->{newline} = 0 if ($EditBar->{newpage} == 1);});

  $lb1->g_grid(qw/-row 0 -column 0 -sticky e/, -padx => [0,2],  -pady => [0,4]); #VB
  $mb1->g_grid(qw/-row 0 -column 1 -sticky w/, -padx => [0,16], -pady => [0,4]);
  $lb2->g_grid(qw/-row 0 -column 2 -sticky e/, -padx => [0,2],  -pady => [0,4]); #HT
  $ent->g_grid(qw/-row 0 -column 3 -columnspan 2 -sticky w/, -padx => [0,0],  -pady => [0,4]);
  $lb3->g_grid(qw/-row 0 -column 5 -sticky e/, -padx => [2,2],  -pady => [0,4]); #Just
  $mb2->g_grid(qw/-row 0 -column 6 -sticky w/, -padx => [0,0],  -pady => [0,4]);

  $lb4->g_grid(qw/-row 1 -column 0 -sticky e/, -padx => [0,2],  -pady => [0,4]); #Rep
  $mb3->g_grid(qw/-row 1 -column 1 -sticky w/, -padx => [0,16], -pady => [0,4]);
  $lb5->g_grid(qw/-row 1 -column 2 -sticky e/, -padx => [0,2],  -pady => [0,4]); #NF
  $mb4->g_grid(qw/-row 1 -column 3 -sticky w/, -padx => [0,0],  -pady => [0,4]);
  $lb6->g_grid(qw/-row 1 -column 4 -sticky e/); # Bar Starts
  $cb1->g_grid(qw/-row 1 -column 5/);
  $cb2->g_grid(qw/-row 1 -column 6 -sticky w/);
}

sub shiftOpt {
  my($frm,$pe) = @_;

  my $lb1 = $frm->new_ttk__label(-text => 'Semi-tones');

  my $me1 = $frm->new_ttk__button(
    -textvariable => \$Tab->{trans},
    -width => 3,
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$Tab->{trans},
	      sub {},
	      [qw/+12 +11 +10 +9 +8 +7 +6 +5 +4 +3 +2 +1 0
	       -1 -2 -3 -4 -5 -6 -7 -8 -9 -10 -11 -12/]);
    });

  my $bu1 = $frm->new_ttk__button(
    -text    => ' Go ',
    -width   => 4,
    -command => sub{transCmnd(\&CP::Tab::transpose, $pe)});

  my $lb2 = $frm->new_ttk__label(-text => 'One String');

  my $bu2 = $frm->new_ttk__button(
    -text    => ' Up ',
    -width   => 4,
    -command => sub{transCmnd(\&CP::Tab::ud1string, $pe, +5)});

  my $bu3 = $frm->new_ttk__button(
    -text    => ' Down ',
    -width   => 6,
    -command => sub{transCmnd(\&CP::Tab::ud1string, $pe, -5)});

  my $lb4 = $frm->new_ttk__label(-text => 'Adjust Strings');

  my $cb4 = $frm->new_ttk__checkbutton(-variable => \$Opt->{Refret});

  $lb1->g_grid(qw/-row 0 -column 0 -sticky e/, -padx => [4,0], -pady => [0,4]);
  $me1->g_grid(qw/-row 0 -column 1 -sticky w/, -padx => [2,2], -pady => [0,4]);
  $bu1->g_grid(qw/-row 0 -column 2 -sticky w/, -padx => [4,0], -pady => [0,4]);
  $lb2->g_grid(qw/-row 0 -column 3 -sticky e/, -padx => [16,0], -pady => [0,4]);
  $bu2->g_grid(qw/-row 0 -column 4 -sticky e/, -padx => [2,2], -pady => [0,4]);
  $bu3->g_grid(qw/-row 0 -column 5 -sticky e/, -padx => [4,0], -pady => [0,4]);
  $lb4->g_grid(qw/-row 1 -column 0 -sticky e/, -padx => [4,0], -pady => [0,4]);
  $cb4->g_grid(qw/-row 1 -column 1/,           -padx => [4,0], -pady => [0,4]);
}

sub transCmnd {
  my($func,$pe,$cnt) = @_;

  my($sel1,$sel2);
  if ($pe == EDIT) {
    $sel1 = $Tab->{select1};
    $sel2 = $Tab->{select2};
    $Tab->{select1} = $Tab->{select2} = $EditBar;
  }
  &$func($Tab, $pe, $cnt);
  if ($pe == EDIT) {
    $Tab->{select1} = $sel1;
    $Tab->{select2} = $sel2;
  }
}

####################
# Page Options .....
####################
sub pageOpts {
  my($subfrm) = @_;

  my @menu_opt = qw/
      -width 3
      -relief solid
      -borderwidth 1
      -anchor c
      -direction flush
      -indicatoron 0
      -tearoff 0
      -pady 0/;
  my $frt = $subfrm->new_ttk__frame();
  $frt->g_pack(qw/-side top -expand 1 -fill both/);

  my $hl = $subfrm->new_ttk__separator(qw/-orient horizontal/);
  $hl->g_pack(qw/-side top -expand 1 -fill x -pady 4/);

  my $frm = $subfrm->new_ttk__frame(-padding => [0,0,4,4]);
  $frm->g_pack(qw/-side top -expand 1 -fill both/);

  my $frd = $subfrm->new_ttk__frame(-padding => [4,8,4,8]);
  $frd->g_pack(qw/-side top/);

  my $frb = $subfrm->new_ttk__labelframe(-text => ' Transpose ');
  $frb->g_pack(qw/-side top -expand 1 -fill both -padx 4 -pady 4/);

##########

  my $lb2 = $frt->new_ttk__label(-text => 'Tab File Name');
  my $en2 = $frt->new_ttk__entry(-textvariable => \$Tab->{fileName}, -width => 38,
				 -state => 'disabled');
  my $lb3 = $frt->new_ttk__label(-text => 'PDF File Name');
  my $en3 = $frt->new_ttk__entry(-textvariable => \$Tab->{PDFname}, -width => 38);
  my $lb4 = $frt->new_ttk__label(-text => 'Title');
  my $en4 = $frt->new_ttk__entry(-textvariable => \$Tab->{title}, -width => 38);
  $en4->g_bind("<KeyRelease>" => sub{$Tab->pageTitle();main::setEdited(1);});
  my $lb6 = $frt->new_ttk__label(-text => 'Heading Note');
  my $en6 = $frt->new_ttk__entry(
    -textvariable => \$Tab->{note},
    -width        => 30);
  $en6->g_bind("<KeyRelease>" => sub{$Tab->pageNote();main::setEdited(1);});

  $lb2->g_grid(qw/-row 0 -column 0 -sticky e/, -padx => [0,2], -pady => [4,4]);  # TFN
  $en2->g_grid(qw/-row 0 -column 1 -sticky w/, -padx => [0,4], -pady => [4,4]);
  $lb3->g_grid(qw/-row 1 -column 0 -sticky e/, -padx => [0,2], -pady => [0,4]);  # PDF FN
  $en3->g_grid(qw/-row 1 -column 1 -sticky w/, -padx => [0,4], -pady => [0,4]);
  $lb4->g_grid(qw/-row 2 -column 0 -sticky e/, -padx => [0,2], -pady => [0,4]);  # Title
  $en4->g_grid(qw/-row 2 -column 1 -sticky w/, -padx => [0,4], -pady => [0,4]);
  $lb6->g_grid(qw/-row 3 -column 0 -sticky e/, -padx => [0,2], -pady => [0,4]);  # HN
  $en6->g_grid(qw/-row 3 -column 1 -sticky w/, -padx => [0,0], -pady => [0,4]);
##########

  my $inl = $frm->new_ttk__label(-text => 'Instrument');
  my $inm = $frm->new_ttk__button(
    -textvariable => \$Opt->{Instrument},
    -style => 'Menu.TButton',
    -width => 8,
    -command => sub{popMenu(\$Opt->{Instrument},
			    sub{$Tab->drawPageWin();main::setEdited(1);},
			    $Opt->{Instruments});
    });
###
  my $tml = $frm->new_ttk__label(-text => 'Timing');
  my $tmm = $frm->new_ttk__button(
    -textvariable => \$Opt->{Timing},
    -style => 'Menu.TButton',
    -width => 4,
    -command => sub{popMenu(\$Opt->{Timing},
			    sub{(my $t = $Opt->{Timing}) =~ s/(\d).*/$1/;
				$Opt->{BarEnd} = $t * 8;
				$Tab->drawPageWin();
				editWindow();
				main::setEdited(1);},
			    [qw{2/4 3/4 4/4}]);
    });
###
  my $kyl = $frm->new_ttk__label(-text => 'Set Key as');
  my $kym = $frm->new_ttk__button(
    -textvariable => \$Tab->{key},
    -width => 3,
    -style => 'Menu.TButton',
    -command => sub{popMenu(\$Tab->{key},
			    sub{$Tab->pageKey();main::setEdited(1);},
			    [' ', qw/Ab Abm A Am A# A#m Bb Bbm B Bm C Cm C# C#m Db Dbm D Dm D# D#m Eb Ebm E Em F Fm F# F#m Gb Gbm G Gm G# G#m/]);
    });
######
  my $bsl = $frm->new_ttk__label(-text => "Bars/Stave");
  my $bsm = $frm->new_ttk__button(
    -textvariable => \$Opt->{Nbar},
    -style => 'Menu.TButton',
    -width => 3,
    -command => sub{popMenu(\$Opt->{Nbar},
			    sub{$Tab->drawPageWin();main::setEdited(1);},
			    [qw/3 4 5 6 7 8 9 10/]);
    });
###
  my $ssl = $frm->new_ttk__label(-text => "String\nSpacing");
  my $ssm = $frm->new_ttk__button(
    -textvariable => \$Opt->{StaffSpace},
    -style => 'Menu.TButton',
    -width => 3,
    -command => sub{popMenu(\$Opt->{StaffSpace},
			    sub{$Tab->drawPageWin();editWindow();main::setEdited(1);},
			    [qw/6 7 8 9 10 11 12 13 14 15 16/]);
    });
###
  my $sgl = $frm->new_ttk__label(-text => "Inter\nStave Gap");
  my $sgm = $frm->new_ttk__button(
    -textvariable => \$Tab->{staveGap},
    -style => 'Menu.TButton',
    -width => 3,
    -command => sub{popMenu(\$Tab->{staveGap},
			    sub{
			      $Tab->drawPageWin();
			      main::setEdited(1);;
			    },
			    [qw/0 1 2 3 4 5 6 8 9 10 11 12 13 14 16 18 20/]);
    });
###
  my $esl = $frm->new_ttk__label(-text => "Edit\nScale");
  my $esm = $frm->new_ttk__button(
    -textvariable => \$Opt->{EditScale},
    -style => 'Menu.TButton',
    -width => 3,
    -command => sub{popMenu(\$Opt->{EditScale},
			    sub{editWindow();},
			    [qw/3 3.5 4 4.5 5 5.5 6/]);
    });
###
  my $lll = $frm->new_ttk__label(-text => "Lyric\nLines");
  my $llm = $frm->new_ttk__button(
    -textvariable => \$Opt->{LyricLines},
    -style => 'Menu.TButton',
    -width => 3,
    -command => sub{my $ll = $Opt->{LyricLines};
		    popMenu(\$ll,
			    sub{$Tab->{lyrics}->adjust($ll);
				$Tab->drawPageWin();
				main::setEdited(1);},
			    [qw/0 1 2 3/]);
    });
###
  my $lsl = $frm->new_ttk__label(-text => "Lyric\nSpacing");
  my $lsm = $frm->new_ttk__button(
    -textvariable => \$Tab->{lyricSpace},
    -style => 'Menu.TButton',
    -width => 3,
    -command => sub{popMenu(\$Tab->{lyricSpace},
			    sub{$Tab->drawPageWin();main::setEdited(1);},
			    [qw/0 2 4 6 8 10 12 14 16 18 20/]);
    });
###

  $inl->g_grid(qw/-row 0 -column 0 -sticky e/,                 -pady => [2,4]);
  $inm->g_grid(qw/-row 0 -column 1 -sticky w/, -padx => [2,0], -pady => [0,4]);
  $tml->g_grid(qw/-row 1 -column 0 -sticky e/,                 -pady => [0,4]);
  $tmm->g_grid(qw/-row 1 -column 1 -sticky w/, -padx => [2,0], -pady => [0,4]);
  $kyl->g_grid(qw/-row 2 -column 0 -sticky e/,                 -pady => [0,4]);
  $kym->g_grid(qw/-row 2 -column 1 -sticky w/, -padx => [2,0], -pady => [0,4]);


  $bsl->g_grid(qw/-row 0 -column 2 -sticky e/, -padx => [16,0],-pady => [0,4]);
  $bsm->g_grid(qw/-row 0 -column 3 -sticky w/, -padx => [2,0], -pady => [0,4]);
  $ssl->g_grid(qw/-row 1 -column 2 -sticky e/,                 -pady => [0,4]);
  $ssm->g_grid(qw/-row 1 -column 3 -sticky w/, -padx => [2,0], -pady => [0,4]);
  $sgl->g_grid(qw/-row 2 -column 2 -sticky e/,                 -pady => [0,4]);
  $sgm->g_grid(qw/-row 2 -column 3 -sticky w/, -padx => [2,0], -pady => [0,4]);

  $esl->g_grid(qw/-row 0 -column 4 -sticky e/,                 -pady => [0,4]);
  $esm->g_grid(qw/-row 0 -column 5 -sticky w/, -padx => [2,0], -pady => [0,4]);
  $lll->g_grid(qw/-row 1 -column 4 -sticky e/,                 -pady => [0,4]);
  $llm->g_grid(qw/-row 1 -column 5 -sticky w/, -padx => [2,0], -pady => [0,4]);
  $lsl->g_grid(qw/-row 2 -column 4 -sticky e/, -padx => [16,0],-pady => [0,4]);
  $lsm->g_grid(qw/-row 2 -column 5 -sticky w/, -padx => [2,0], -pady => [0,4]);

###
  defButtons($frd, \&main::saveOpt, \&main::loadOpt, \&main::resetOpt);
###
  shiftOpt($frb, PAGE);
}

# This is a duplicate of the CP::WIN sub except we use
# the grid manager to spread the buttons over 2 rows
sub defButtons {
  my($wid,$save,$load,$reset) = @_;

  my $sa = $wid->new_ttk__button(
    -text => " Save as Default Options ",
    -style => 'Green.TButton',
    -command => $save);

  my $lo = $wid->new_ttk__button(
    -text => " Load Saved Options ",
    -style => 'Green.TButton',
    -command => $load);

  my $re = $wid->new_ttk__button(
    -text => " Reset Options to Default ",
    -style => 'Red.TButton',
    -command => $reset);

  $sa->g_grid(qw/-row 0 -column 0 -padx/ => [10,6]);
  $lo->g_grid(qw/-row 0 -column 1 -padx/ => [6,10]);
  $re->g_grid(qw/-row 1 -column 0 -columnspan 2 -pady 8/);
}

#############################
#############################
##
## Page Frame (right) Section
##
#############################
#############################

sub pButtons {
  my($frm) = shift;

  my @tb = ([['Edit Bar',        sub{$Tab->editBar},     'Green'],
	     ['Clone Bar(s)',    sub{$Tab->Clone},       'Green']],
	    [['SEP']],
	    [['Copy Bar(s)',     sub{$Tab->Copy},        'Green']],
	    [['Paste Over',      sub{$Tab->PasteOver},   'Green'],
	     ['Paste Before',    sub{$Tab->PasteBefore}, 'Green'],
	     ['Paste After',     sub{$Tab->PasteAfter},  'Green']],
	    [['SEP']],
	    [['Clear Selection', sub{$Tab->ClearSel},    'Red'],
	     ['Clear Bar(s)',    sub{$Tab->ClearBars},   'Red'],
	     ['Delete Bar(s)',   sub{$Tab->DeleteBars},  'Red']],
	    [['SEP']],
	    [[' Set Background ',  sub{$Tab->setBG},     'Green'],
	     [' Clear Background ',sub{$Tab->clearBG},   'Red']],
	    [['SEP']],
	    [[' -  Lyrics  - ',      0,                  'Green']],
            [['SEP']],
	    [['<<< Prev Page',    sub{$Tab->PrevPage},   'Blue'],
	     ['>>> Next Page',    sub{$Tab->NextPage},   'Blue']],
      );
  my $row = 0;
  foreach my $r (@tb) {
    my $col = 0;
    foreach my $c (@{$r}) {
      my($txt,$func,$fg) = @{$c};
      if ($txt eq 'SEP') {
	my $sep = $frm->new_ttk__separator(qw/-orient horizontal/);
	$sep->g_grid(-row => $row, qw/-columnspan 3 -sticky we -pady 4/);
	last;
      } elsif ($txt =~ /^ -/) {
	my $sfrm = $frm->new_ttk__frame(-padding => [0,2,0,2]);
	$sfrm->g_grid(-row => $row, -column => 1);
	
	makeImage("arru", \%XPM);
	my $up = $sfrm->new_ttk__button(-image => 'arru', -command => sub{$Tab->{lyrics}->shiftUp});
	$up->g_grid(qw/-row 0 -column 0/);

	my $lb = $sfrm->new_ttk__label(-text => $txt);
	$lb->g_grid(qw/-row 0 -column 1/);

	makeImage("arrd", \%XPM);
	my $dn = $sfrm->new_ttk__button(-image => 'arrd', -command => sub{$Tab->{lyrics}->shiftDown});
	$dn->g_grid(qw/-row 0 -column 2/);
      } else {
	my $bu = $frm->new_ttk__button(
	  -text => $txt,
	  -style => "$fg.TButton",
	  -command => $func);
	$bu->g_grid(-row => $row, -column => $col, qw/-sticky we -padx 4 -pady 4/);
      }
      $col++;
    }
    $row++;
  }
  my $cb = $frm->new_ttk__label(-text => 'Copy Buffer:');
  $cb->g_grid(-row => 2, -column => 1, qw/-sticky e -padx 4 -pady 4/);
  my $cbs = $frm->new_ttk__label(-textvariable => \$CP::Tab::CopyIdx);
  $cbs->g_grid(-row => 2, -column => 2, qw/-sticky w -padx 4 -pady 4/);

  foreach my $c (0..2) { $frm->g_grid_columnconfigure($c, -weight => 1) }
}

sub pageCanvas {
  my $can = $Tab->{pCan};
  if ($can ne '') {
    if ($Opt->{LyricLines}) {
      # We need to preserve lyrics across Canvases
      $Tab->{lyrics}->collect();
    }
    $can->delete('all');
    $can->configure(-width => $Media->{width} - 1, -height => $Media->{height});
  } else {
    $can = $Tab->{pCan} = $Tab->{pFrm}->new_tk__canvas(
      -bg => "WHITE",
      -width => $Media->{width} - 1,
      -height => $Media->{height},
      -relief => 'solid',
      -borderwidth => 1,
      -selectborderwidth => 0,
      -highlightthickness => 0);
    $can->g_pack(qw/-side top -expand 0/);
  }

  my $off = $Tab->{pOffset};
  my $w = $off->{width};
  my $h = $off->{height};
  my $y = $Tab->{pageHeader} + INDENT;
  my $pidx = 0;
  foreach my $r (0..($Tab->{rowsPP} - 1)) {
    my $x = INDENT;
    foreach (1..$Opt->{Nbar}) {
      CP::Bar::outline($Tab, $pidx++, $x, $y);
      $x += $w;
    }
    $y += $h;
  }
  $Tab->{lyrics}->widgets();
}

1;
