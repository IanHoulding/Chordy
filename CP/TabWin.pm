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
  if ($Tab->{pFrm} eq '') {
    my $outer = $MW->new_ttk__frame(qw/-relief raised -borderwidth 2/, -padding => [0,0,0,4]);
    $outer->g_pack(qw//);
    $Tab->{pFrm} = $outer;

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
      -command => sub{$Tab->PrevPage});
    $bup->g_grid(qw/-row 0 -column 0 -sticky w -padx 16/);
    my $bue = $leftFt->new_ttk__button(
      -text => 'Edit Lyrics',
      -style => "Blue.TButton",
      -command => sub{CP::LyricEd->Edit($Tab);});
    $bue->g_grid(qw/-row 0 -column 1/);
    my $bun = $leftFt->new_ttk__button(
      -text => ' Next Page >>>',
      -style => "Blue.TButton",
      -command => sub{$Tab->NextPage});
    $bun->g_grid(qw/-row 0 -column 2 -sticky e -padx 16/);

    $Tab->{nCan} = $leftF->new_tk__canvas(
      -bg => MWBG,
      -relief => 'solid',
      -borderwidth => 0,
      -highlightthickness => 0,
      -selectborderwidth => 0,
      -width => BNUMW,
      -height => $Media->{height});
    $Tab->{nCan}->g_grid(qw/-row 1 -column 0 -sticky n/);

    $Tab->{pCan} = $leftF->new_tk__canvas(
      -bg => "WHITE",
      -width => $Media->{width} - 1,
      -height => $Media->{height},
      -relief => 'solid',
      -borderwidth => 1,
      -selectborderwidth => 0,
      -highlightthickness => 0);
    $Tab->{pCan}->g_grid(qw/-row 1 -column 1 -sticky n/);


    my $rightF = $outer->new_ttk__frame(qw/-borderwidth 0/);
    $rightF->g_pack(qw/-side right -fill y/, -padx => [8,4]);

    my $rightF = $rightF->new_ttk__frame(qw/-borderwidth 0/);
    $rightF->g_pack(qw/-side top -fill x -pady 4/);

    pageCanvas();

    pageButtons($rightF);

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
    my $pop = CP::Pop->new(0, '.be', 'Bar Editor', -1, -1);
    ($Tab->{eWin}, my $outer) = ($pop->{top}, $pop->{frame});

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

  foreach my $b (['Slide',       's',0,0],
		 ['Hammer',      'h',0,1],
		 ['Bend',        'b',1,0],
		 ['Bend/Release','r',1,1]) {
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
	-value => '',
	-style => 'Toolbutton',
	-command => sub{$Tab->{shbr} = ''});
  $c->g_grid(-row => 0, -column => 2, -rowspan => 2, -padx => [16,8], -pady => 4);
}

###################
# Bar Options .....
###################
sub editBarOpts {
  my($frm) = @_;

  my $vbl = $frm->new_ttk__label(-text => 'Volta Bracket');

  my $vbb = $frm->new_ttk__button(
    -textvariable => \$EditBar->{volta},
    -width => 8,
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$EditBar->{volta},
	      sub{$EditBar->volta()},
	      [qw/None Left Center Right Both/]);
    });
  my $htl = $frm->new_ttk__label(-text => 'Header Text');
  my $hte = $frm->new_ttk__entry(
    -width => 40,
    -validate => 'key',
    -validatecommand => [sub{
      $EditBar->{header} = shift;
      $EditBar->topText();
      1;}, Tkx::Ev("%P")]);
  $EditBar->{topEnt} = $hte;
  my $jul = $frm->new_ttk__label(-text => 'Justify ');
  my $jub = $frm->new_ttk__button(
    -textvariable => \$EditBar->{justify},
    -width => 8,
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$EditBar->{justify},
	      sub{$EditBar->topText()},
	      [qw/Left Right/]);
    });
  my $rel = $frm->new_ttk__label(-text => 'Repeat');
  my $reb = $frm->new_ttk__button(
    -textvariable => \$EditBar->{rep},
    -width => 8,
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$EditBar->{rep},
	      sub{$EditBar->repeat()},
	      [qw/None Start End/]);
    });
  my $nfl = $frm->new_ttk__label(-text => 'Note Font');
  my $nfb = $frm->new_ttk__button(
    -textvariable => \$Tab->{noteFsize},
    -width => 8,
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$Tab->{noteFsize},
	      undef,
	      [qw/Normal Small/]);
    });
  my $bsl = $frm->new_ttk__label(-text => "Bar Starts:");
  my $cb1 = $frm->new_ttk__checkbutton(
    -text => 'Line',
    -variable => \$EditBar->{newline},
    -command => sub{$EditBar->{newpage} = 0 if ($EditBar->{newline} == 1);});
  my $cb2 = $frm->new_ttk__checkbutton(
    -text => 'Page',
    -variable => \$EditBar->{newpage},
    -command => sub{$EditBar->{newline} = 0 if ($EditBar->{newpage} == 1);});

  $vbl->g_grid(qw/-row 0 -column 0 -sticky e/, -padx => [0,2],  -pady => [0,4]);
  $vbb->g_grid(qw/-row 0 -column 1 -sticky w/, -padx => [0,16], -pady => [0,4]);

  $rel->g_grid(qw/-row 1 -column 0 -sticky e/, -padx => [0,2],  -pady => [0,4]);
  $reb->g_grid(qw/-row 1 -column 1 -sticky w/, -padx => [0,16], -pady => [0,4]);

  $nfl->g_grid(qw/-row 2 -column 0 -sticky e/, -padx => [0,2],  -pady => [0,4]);
  $nfb->g_grid(qw/-row 2 -column 1 -sticky w/, -padx => [0,0],  -pady => [0,4]);


  $htl->g_grid(qw/-row 0 -column 2 -sticky e/, -padx => [0,2],  -pady => [0,4]);
  $hte->g_grid(qw/-row 0 -column 3 -columnspan 4 -sticky w/, -padx => [0,0],  -pady => [0,4]);

  $jul->g_grid(qw/-row 1 -column 5 -rowspan 2 -sticky e/, -padx => [12,0], -pady => [0,0]);
  $jub->g_grid(qw/-row 1 -column 6 -rowspan 2 -sticky w/, -padx => [0,0],  -pady => [0,0]);

  $bsl->g_grid(qw/-row 1 -column 2 -rowspan 2 -sticky e/); # Bar Starts
  $cb1->g_grid(qw/-row 1 -column 3 -rowspan 2/);
  $cb2->g_grid(qw/-row 1 -column 4 -rowspan 2 -sticky w/);
}

sub topVal {
  my($val) = shift;

  $EditBar->{header} = $val;
  $EditBar->topText();
  return(1);
}

sub shiftOpt {
  my($frm,$pe) = @_;

  my $lb1 = $frm->new_ttk__label(-text => 'Semi-tones');

  my $me1 = $frm->new_ttk__button(
    -textvariable => \$Tab->{trans},
    -width => 4,
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

  $lb1->g_grid(qw/-row 0 -column 0 -columnspan 2 -sticky we/, -padx => [8,4], -pady => [0,4]);
  $me1->g_grid(qw/-row 1 -column 0 /,              -padx => [8,2], -pady => [0,4]);
  $bu1->g_grid(qw/-row 1 -column 1 /,              -padx => [2,8], -pady => [0,4]);

  $lb2->g_grid(qw/-row 0 -column 2 -columnspan 2 -sticky we/, -padx => [16,4], -pady => [0,4]);
  $bu2->g_grid(qw/-row 1 -column 2 /,              -padx => [16,2], -pady => [0,4]);
  $bu3->g_grid(qw/-row 1 -column 3 /,              -padx => [2,8],  -pady => [0,4]);

  if ($pe == PAGE) {
    $lb4->g_grid(qw/-row 1 -column 4 -sticky e/, -padx => [16,0], -pady => [0,4]);
    $cb4->g_grid(qw/-row 1 -column 5 -sticky w/, -padx => [2,0], -pady => [0,4]);
  } else {
    $lb4->g_grid(qw/-row 2 -column 0 -columnspan 2 -sticky e/, -padx => [8,0], -pady => [0,4]);
    $cb4->g_grid(qw/-row 2 -column 2 -sticky w/,               -padx => [4,0], -pady => [0,4]);
  }
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

#############################
#############################
##
## Page Frame (right) Section
##
#############################
#############################

sub pageButtons {
  my($frm) = shift;

  my $frt = $frm->new_ttk__frame(qw/-relief raised -borderwidth 2/);
  $frt->g_pack(qw/-side top -expand 1 -fill both -padx 4 -pady/ => [0,16]);

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

  my $edit = $frm->new_ttk__labelframe(-text => ' Edit ');
  $edit->g_pack(qw/-side top -expand 1 -fill both/, -padx => [4,8], -pady => [4,4]);
  my $bu1 = $edit->new_ttk__button(-text => 'Edit Bar',
				   -style => "Green.TButton",
				   -command => sub{$Tab->editBar});
  $bu1->g_grid(qw/-row 0 -column 0 -sticky we/, -padx => [4,8], -pady => [0,4]);
  my $bu2 = $edit->new_ttk__button(-text => 'Clone Bar(s)',
				   -style => "Green.TButton",
				   -command => sub{$Tab->Clone});
  $bu2->g_grid(qw/-row 0 -column 1 -sticky we/, -padx => [4,8], -pady => [0,4]);
  my $bue = $edit->new_ttk__button(-text => 'Edit Lyrics',
				   -style => "Green.TButton",
				   -command => sub{CP::LyricEd->Edit($Tab);});
  $bue->g_grid(qw/-row 0 -column 2 -sticky we/, -padx => [4,8], -pady => [0,4]);
######
  makeImage('hyphen', \%XPM);
  my $cp = $frm->new_ttk__labelframe(-text => ' Copy/Paste ');
  $cp->g_pack(qw/-side top -expand 1 -fill both -padx 4 -pady 4/);

  my $cb = $cp->new_ttk__label(-text => 'Copy Buffer:', -font => "BTkDefaultFont");
  $cb->g_grid(qw/-row 0 -column 0 -columnspan 3 -sticky e/);
  my $cbs = $cp->new_ttk__label(-textvariable => \$CP::Tab::CopyIdx);
  $cbs->g_grid(qw/-row 0 -column 3 -columnspan 4 -sticky w -padx 2/);

  my $copy = $cp->new_ttk__label(-text => 'Copy', -font => "BTkDefaultFont");
  $copy->g_grid(qw/-row 1 -column 0 -sticky e -padx/ => [4,0]);
  my $ch1 = $cp->new_ttk__label(-image => 'hyphen', -font => "BTkDefaultFont");
  $ch1->g_grid(qw/-row 1 -column 1 -padx 2/);
  my $bu3 = $cp->new_ttk__button(-text => 'Header',
				 -style => "Green.TButton",
				 -command => sub{$Tab->Copy(HONLY)});
  $bu3->g_grid(qw/-row 1 -column 2 -sticky we/, -pady => [2,4]);
  my $ch2 = $cp->new_ttk__label(-image => 'hyphen', -font => "BTkDefaultFont");
  $ch2->g_grid(qw/-row 1 -column 3 -padx 2/);
  my $bu4 = $cp->new_ttk__button(-text => 'Notes',
				 -style => "Green.TButton",
				 -command => sub{$Tab->Copy(NONLY)});
  $bu4->g_grid(qw/-row 1 -column 4 -sticky we/, -pady => [2,4]);
  my $ch3 = $cp->new_ttk__label(-image => 'hyphen', -font => "BTkDefaultFont");
  $ch3->g_grid(qw/-row 1 -column 5 -padx 2/);
  my $bu5 = $cp->new_ttk__button(-text => 'All',
				 -style => "Green.TButton",
				 -command => sub{$Tab->Copy(HANDN)});
  $bu5->g_grid(qw/-row 1 -column 6 -sticky we/, -pady => [2,4]);

  my $paste = $cp->new_ttk__label(-text => 'Paste', -font => "BTkDefaultFont");
  $paste->g_grid(qw/-row 2 -column 0 -sticky e -padx/ => [4,0]);
  my $ph1 = $cp->new_ttk__label(-image => 'hyphen', -font => "BTkDefaultFont");
  $ph1->g_grid(qw/-row 2 -column 1 -padx 2/);
  my $bu6 = $cp->new_ttk__button(-text => 'Before',
				 -style => "Green.TButton",
				 -command => sub{$Tab->PasteBefore});
  $bu6->g_grid(qw/-row 2 -column 2 -sticky we/, -pady => [4,4]);
  my $ph2 = $cp->new_ttk__label(-image => 'hyphen', -font => "BTkDefaultFont");
  $ph2->g_grid(qw/-row 2 -column 3 -padx 2/);
  my $bu7 = $cp->new_ttk__button(-text => 'Over',
				 -style => "Green.TButton",
				 -command => sub{$Tab->PasteOver});
  $bu7->g_grid(qw/-row 2 -column 4 -sticky we/, -pady => [4,4]);
  my $ph3 = $cp->new_ttk__label(-image => 'hyphen', -font => "BTkDefaultFont");
  $ph3->g_grid(qw/-row 2 -column 5 -padx 2/);
  my $bu8 = $cp->new_ttk__button(-text => 'After',
				 -style => "Green.TButton",
				 -command => sub{$Tab->PasteAfter});
  $bu8->g_grid(qw/-row 2 -column 6 -sticky we/, -pady => [4,4]);
######
  my $sel = $frm->new_ttk__labelframe(-text => ' Selection ');
  $sel->g_pack(qw/-side top -expand 1 -fill both -padx 4 -pady 4/);
  my $bu9 = $sel->new_ttk__button(-text => 'Clear Selection',
				   -style => "Red.TButton",
				   -command => sub{$Tab->ClearSel});
  $bu9->g_grid(qw/-row 0 -column 0 -sticky we/, -padx => [4,8], -pady => [0,4]);
  my $bu10 = $sel->new_ttk__button(-text => 'Clear Bar(s)',
				   -style => "Red.TButton",
				   -command => sub{$Tab->ClearBars});
  $bu10->g_grid(qw/-row 0 -column 1 -sticky we/, -padx => [4,8], -pady => [0,4]);
  my $bu11 = $sel->new_ttk__button(-text => 'Delete Bar(s)',
				   -style => "Green.TButton",
				   -command => sub{$Tab->DeleteBars});
  $bu11->g_grid(qw/-row 0 -column 2 -sticky we/, -padx => [4,8], -pady => [0,4]);
######
  my $bg = $frm->new_ttk__labelframe(-text => ' Background ');
  $bg->g_pack(qw/-side top -expand 1 -fill both -padx 4 -pady 4/);
  my $bu12 = $bg->new_ttk__button(-text => 'Set',
				  -style => "Green.TButton",
				  -command => sub{$Tab->setBG});
  $bu12->g_grid(qw/-row 0 -column 0 -sticky we/, -padx => [4,8], -pady => [0,4]);
  my $bu13 = $bg->new_ttk__button(-text => 'Clear',
				  -style => "Red.TButton",
				  -command => sub{$Tab->clearBG});
  $bu13->g_grid(qw/-row 0 -column 1 -sticky we/, -padx => [4,8], -pady => [0,4]);
######
  my $lyr = $frm->new_ttk__labelframe(-text => ' Lyrics ');
  $lyr->g_pack(qw/-side top -expand 1 -fill both -padx 4 -pady 4/);
  my $bu14 = $lyr->new_ttk__button(-text => 'Shift Up One Line',
				   -style => "Green.TButton",
				   -command => sub{$Tab->{lyrics}->shiftUp()});
  $bu14->g_grid(qw/-row 0 -column 0 -sticky we/, -padx => [4,8], -pady => [0,4]);
  my $bu15 = $lyr->new_ttk__button(-text => 'Shift Down One Line',
				   -style => "Green.TButton",
				   -command => sub{$Tab->{lyrics}->shiftDown()});
  $bu15->g_grid(qw/-row 0 -column 1 -sticky we/, -padx => [4,8], -pady => [0,4]);

  my $sel = $frm->new_ttk__labelframe(-text => ' Select ');
  $sel->g_pack(qw/-side top -expand 1 -fill both -padx 4 -pady 4/);

  my $coll = $sel->new_ttk__label(-text => 'Collection');
  my $colb = $sel->new_ttk__button(
    -textvariable => \$Collection->{name},
    -style => 'Menu.TButton',
    -command => sub{$Collection->select($Tab)}
    );
  my $medl = $sel->new_ttk__label(-text => 'Media');
  my $medb = $sel->new_ttk__button(
    -textvariable => \$Opt->{Media},
    -style => 'Menu.TButton',
    -command => \&newMedia,
    );

  $coll->g_grid(qw/-row 0 -column 0 -sticky e/, -padx => [4,0], -pady => [0,4]);
  $colb->g_grid(qw/-row 0 -column 1 -sticky w/, -padx => [2,0], -pady => [0,4]);
  $medl->g_grid(qw/-row 0 -column 2 -sticky e/, -padx => [20,0], -pady => [0,4]);
  $medb->g_grid(qw/-row 0 -column 3 -sticky w/, -padx => [2,0], -pady => [0,4]);

###
  my $frb = $frm->new_ttk__labelframe(-text => ' Transpose ');
  $frb->g_pack(qw/-side top -expand 1 -fill both -padx 4 -pady 4/);

  shiftOpt($frb, PAGE);
###
  my $mrgn = $frm->new_ttk__labelframe(-text => " Margins ", -padding => [4,0,0,0]);
  $mrgn->g_pack(qw/-side top -expand 1 -fill both -padx 4 -pady 4/);

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
      -command => sub{$Opt->saveOne("${m}Margin");$Tab->drawPageWin();});
    $a->g_grid(-row => 0, -column => $col, -padx => [2,16], -pady => [0,4]);
    $b->g_grid(-row => 1, -column => $col, -padx => [2,16], -pady => [0,4]);
    $col++;
  }
}

sub newMedia {
  popMenu(\$Opt->{Media}, undef, $Media->list());
  $Media = $Media->change($Opt->{Media});
  $Tab->drawPageWin();
  CP::TabMenu::refresh();
}

sub pageCanvas {
  my $can = $Tab->{pCan};
  if ($Opt->{LyricLines}) {
    # We need to preserve lyrics across Canvas refreshes.
    $Tab->{lyrics}->collect();
  }
  $can->delete('all');
  $can->configure(-width => $Media->{width} - 1, -height => $Media->{height});

  my $off = $Tab->{pOffset};
  my $w = $off->{width};
  my $h = $off->{height};
  my $y = $Tab->{pageHeader} + $Opt->{TopMargin};
  my $pidx = 0;
  foreach my $r (0..($Tab->{rowsPP} - 1)) {
    my $x = $Opt->{LeftMargin};
    foreach (1..$Opt->{Nbar}) {
      CP::Bar::outline($Tab, $pidx++, $x, $y);
      $x += $w;
    }
    $y += $h;
  }
  $Tab->{lyrics}->widgets();
}

1;
