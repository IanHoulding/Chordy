package CP::BarEd;

# List of tags used for various elements within the display
# where a # indicates the bar's page index.
#
#  EDIT PAGE
#  barn       Bar # header for edit display
#  ebl        Lines which create the edit display bar
#  rep           Repeat start/end indicator
#  rep           Repeat end indicator
#  fret bar#     All notes/rests in a bar

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

#
# Called once at start-up
#
sub editWindow {
  my($tab) = shift;

  if ($tab->{eWin} eq '') {
    my $pop = CP::Pop->new(0, '.be', 'Bar Editor', -1, -1);
    ($tab->{eWin}, my $outer) = ($pop->{top}, $pop->{frame});
    $pop->{top}->g_wm_withdraw();

    $tab->{eWin}->g_wm_protocol('WM_DELETE_WINDOW', \&Cancel);
    $outer->g_pack(qw//);

    $EditBar = CP::Bar->new($tab);
    $EditBar->{offset} = $tab->{eOffset};
    $EditBar->{pidx} = -1;
    $EditBar->{pbar} = 0;
    $EditBar1 = CP::Bar->new($tab);
    $EditBar1->{offset} = $tab->{eOffset};
    $EditBar1->{pidx} = -2;
    $EditBar1->{pbar} = 0;
    $EditBar->{next} = $EditBar1;
    $EditBar1->{prev} = $EditBar;

    my $frnp = $outer->new_ttk__frame();
    $frnp->g_pack(qw/-side top -anchor n/, -padx => 16, -pady => [4,4]);
    prevNext($tab, $frnp);

    my $eFrm = $tab->{eFrm} = $outer->new_ttk__frame();
    $eFrm->g_pack(qw/-side top -expand 0/);
    canvas($tab);

    my $frnum = $outer->new_ttk__frame(qw/-borderwidth 0/);
    $frnum->g_pack(qw/-side top -expand 1 -fill x/, -padx => [4,0]);
    fretsAndRests($tab, $frnum);

    my $frb = $outer->new_ttk__frame(qw/-borderwidth 0/);
    $frb->g_pack(qw/-side top -expand 1 -fill x/, -padx => [4,0], -pady => [0,4]);

    my $baropt = $frb->new_ttk__labelframe(-text => ' Bar Options ', -padding => [0,0,4,4]);
    $baropt->g_pack(qw/-side left -anchor w/, -padx => 0, -pady => [8,0]);
    barOpts($tab, $baropt);

    my $shiftopt = $frb->new_ttk__labelframe(-text => ' Note Shift ', -padding => [4,0,4,4]);
    $shiftopt->g_pack(qw/-side left -anchor nw/, -padx => [16,0], -pady => [8,0]);
    CP::TabWin::shiftOpt($tab, $shiftopt, EDIT);

    my $efb = $outer->new_ttk__frame(qw/-borderwidth 0/);
    $efb->g_pack(qw/-side bottom -fill x/);
    buttons($efb);

    my $hl = $outer->new_ttk__separator(-orient => 'horizontal'); 
    $hl->g_pack(qw/-side bottom -fill x -pady 4/);
  }
  else {
    canvas($tab);
  }
}

sub prevNext {
  my($tab,$frnp) = @_;

  my $bps = $frnp->new_ttk__button(
    -text => '<<< Prev w/Save ',
    -style => "Green.TButton",
    -command => [\&EditPrev, $tab, 1]);
  $bps->g_pack(qw/-side left -pady 4/);
  my $bp = $frnp->new_ttk__button(
    -text => '<<< Prev Bar ',
    -style => "Green.TButton",
    -command => [\&EditPrev, $tab, 0]);
  $bp->g_pack(qw/-side left -pady 4/, -padx => [16,20]);

  my $bns = $frnp->new_ttk__button(
    -text => ' Next w/Save >>>',
    -style => "Green.TButton",
    -command => [\&EditNext, $tab, 1]);
  $bns->g_pack(qw/-side right -pady 4/);
  my $bn = $frnp->new_ttk__button(
      -text => ' Next Bar >>>',
    -style => "Green.TButton",
    -command => [\&EditNext, $tab, 0]);
  $bn->g_pack(qw/-side right -pady 4/, -padx => [20,16]);
}

############################
############################
##
## Edit Frame (left) Section
##
############################
############################

sub buttons {
  my($frm) = @_;

  foreach my $t (['Save',             'Save',         'Green'],
		 ['Update',           'Update',       'Green'],
		 ['Insert After',     'InsertAfter',  'Green'],
		 ['Insert Before',    'InsertBefore', 'Green'],
		 ['Clear Background', 'RemoveBG',     'Red'],
		 ['Set Background',   'Background',   'Green'],
		 ['Clear Bar',        'Clear',        'Red']) {
    my($txt,$func,$fg) = @{$t};
    my $b = $frm->new_ttk__button(-text => $txt,
				  -style => "$fg.TButton",
				  -command => \&$func);
    $b->g_pack(qw/-side right -padx 10 -pady 4/);
  }
  my $c = $frm->new_ttk__button(-text => '>> Cancel <<',
				-style => "Red.TButton",
				-command => \&Cancel);
  $c->g_pack(qw/-side left -padx 10 -pady 4/);
}

sub canvas {
  my($tab) = shift;

  my $frame = $tab->{eFrm};
  my $ecan = $tab->{eCan};
  my $off = $tab->{eOffset};
  my $eh = $off->{height} + (INDENT * 2);
  my $ew = (INDENT * 2) + (POSIX::ceil($off->{width}) * 2) + INDENT;
  $frame->configure(-width => $ew, -height => $eh);
  if ($ecan ne '') {
    $ecan->delete('all');
    $ecan->configure(-width => $ew, -height => $eh);
  } else {
    $ecan = $tab->{eCan} = $frame->new_tk__canvas(-width => $ew,
						  -height => $eh,
						  -bg => "WHITE",
						  -relief => 'solid',
						  -borderwidth => 1);
    $ecan->g_pack(qw//);
  }

  my $hd = int($tab->{barnSize} * 1.4);
  # Green area at the top for the Bar number
  $ecan->create_rectangle(0, 0, $ew+3, $hd, -fill => DPOPBG, -width => 0);
  $ecan->create_line(0, $hd, $ew+3, $hd, -fill => BROWN, -width => 1);

  $tab->{editX} = 0;
  $tab->{editY} = $hd;
  $EditBar->{canvas} = $EditBar1->{canvas} = $ecan;

  $EditBar->{x} = INDENT * 2;
  $EditBar->{y} = $tab->{editY} + INDENT;
  $EditBar->editBarOutline();

  $EditBar1->{x} = (INDENT * 2) + $off->{width};
  $EditBar1->{y} = $EditBar->{y};
  $EditBar1->editBarOutline();
}

sub fretsAndRests {
  my($tab,$frm) = @_;

  my $fr1 = $frm->new_ttk__labelframe(-text => ' Fret Number ', -padding => [4,0,4,4]);
  $fr1->g_grid(qw/-row 0 -column 0 -sticky nsew -pady 4/);

  my $fr2 = $frm->new_ttk__labelframe(-text => ' Rest ', -padding => [0,0,4,0]);
  $fr2->g_grid(qw/-row 0 -column 1 -sticky nsew -padx 16 -pady 4/);

  my $fr3 = $frm->new_ttk__labelframe(-text => ' Slide/Hammer/Bend/Release ', -padding => [0,0,4,0]);
  $fr3->g_grid(qw/-row 0 -column 2 -sticky nsew -pady 4/);

  ####################
  # Fret Numbers .....
  ####################
  my $i = -1;
  my $row = my $col = 0;
  foreach $row (0..1) {
    foreach $col (0..12) {
      my $txt = ($row | $col) ? $i : 'X';
      my $rb = $fr1->new_ttk__radiobutton(-text => "$txt",
					  -width => 2,
					  -variable => \$tab->{fret},
					  -value => $txt,
					  -style => 'Toolbutton',
	);
      $rb->g_grid(-row => $row, -column => $col, -padx => 3, -pady => 3);
      $i++;
    }
  }

  #############
  # Rests .....
  #############
  $row = $col = 0;
  foreach my $r (qw/1 2 4 8 16 32/) {
    my $val = "r$r";
    my $lbl = ($r > 1) ? "1/$r" : $r;
    my $but = "b$r";
    my $lb = $fr2->new_ttk__label(-text => $lbl, -width => length($lbl), -anchor => 'e');
    $lb->g_grid(-row => $row, -column => $col++, -padx => [4,0], -pady => [0,4]);
    makeImage("$but", \%XPM);
    my $rb = $fr2->new_ttk__radiobutton(-image => $but,
					-variable => \$tab->{fret},
					-value => $val,
					-style => 'Toolbutton',
	);
    $rb->g_grid(-row => $row, -column => $col++, -padx => 2, -pady => [0,4]);
    if ($col == 6) {
      $row++;
      $col = 0;
    }
  }

  ###########################
  # Slide/Hammer Bend/Release
  ###########################
  foreach my $b (['Slide',       's',0,0],
		 ['Hammer',      'h',0,1],
		 ['Bend',        'b',1,0],
		 ['Bend/Release','r',1,1]) {
    my $rb = $fr3->new_ttk__radiobutton(-text => $b->[0],
					-variable => \$tab->{shbr},
					-value => $b->[1],
					-style => 'Toolbutton',
					-command => sub{$EditBar->deselect()});
    $rb->g_grid(-row => $b->[2], -column => $b->[3], -padx => 8, -pady => 4);
  }
  my $c = $fr3->new_ttk__radiobutton(-text => '  Off  ',
				     -variable => \$tab->{shbr},
				     -value => '',
				     -style => 'Toolbutton',
				     -command => sub{$tab->{shbr} = ''});
  $c->g_grid(-row => 0, -column => 2, -rowspan => 2, -padx => [16,8], -pady => 4);
}

###################
# Bar Options .....
###################
sub barOpts {
  my($tab,$frm) = @_;

  my $vbl = $frm->new_ttk__label(-text => 'Volta Bracket');

  my $vbb = $frm->new_ttk__button(-textvariable => \$EditBar->{volta},
				  -width => 8,
				  -style => 'Menu.TButton',
				  -command => sub{
				    popMenu(\$EditBar->{volta},
					    sub{$EditBar->volta()},
					    [qw/None Left Center Right Both/]);
				  });
  my $htl = $frm->new_ttk__label(-text => 'Header Text');
  my $hte = $frm->new_ttk__entry(-width => 40,
				 -validate => 'key',
				 -validatecommand => [sub{
				   $EditBar->{header} = shift;
				   $EditBar->topText();
				   1;}, Tkx::Ev("%P")]);
  $EditBar->{topEnt} = $hte;
  my $jul = $frm->new_ttk__label(-text => 'Justify ');
  my $jub = $frm->new_ttk__button(-textvariable => \$EditBar->{justify},
				  -width => 8,
				  -style => 'Menu.TButton',
				  -command => sub{
				    popMenu(\$EditBar->{justify},
					    sub{$EditBar->topText()},
					    [qw/Left Right/]);
				  });
  my $rel = $frm->new_ttk__label(-text => 'Repeat');
  my $reb = $frm->new_ttk__button(-textvariable => \$EditBar->{rep},
				  -width => 8,
				  -style => 'Menu.TButton',
				  -command => sub{
				    popMenu(\$EditBar->{rep},
					    sub{$EditBar->repeat()},
					    [qw/None Start End/]);
				  });
  my $nfl = $frm->new_ttk__label(-text => 'Note Font');
  my $nfb = $frm->new_ttk__button(-textvariable => \$tab->{noteFsize},
				  -width => 8,
				  -style => 'Menu.TButton',
				  -command => sub{
				    popMenu(\$tab->{noteFsize},
					    undef,
					    [qw/Normal Small/]);
				  });
  my $bsl = $frm->new_ttk__label(-text => "Bar Starts:");
  my $cb1 = $frm->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				       -compound => 'left',
				       -image => ['xtick', 'selected', 'tick'],
				       -text => 'Line',
				       -variable => \$EditBar->{newline},
				       -command => sub{$EditBar->{newpage} = 0 if ($EditBar->{newline} == 1);});
  my $cb2 = $frm->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				       -compound => 'left',
				       -image => ['xtick', 'selected', 'tick'],
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

  $bsl->g_grid(qw/-row 1 -column 2 -rowspan 2 -sticky e/, -pady => [0,4]); # Bar Starts
  $cb1->g_grid(qw/-row 1 -column 3 -sticky sw -padx 2/);
  $cb2->g_grid(qw/-row 2 -column 3 -sticky nw -padx 2/);
}

sub EditPrev { _pn('prev', @_) }
sub EditNext { _pn('next', @_) }

sub _pn {
  my($pn,$tab,$save) = @_;

  my $bar = $tab->{select1};
  if ($save) {
    Update();
    $tab->indexBars();
    $tab->newPage($bar->{pnum}); # Clears the selection
    $bar->select();
  } else {
    if (($bar && $EditBar->comp($bar)) || ($bar == 0 && ! $EditBar->isblank())) {
      my $ans = CP::Cmsg::msgYesNoCan("Save current Bar?");
      return if ($ans eq 'Cancel');
      Save() if ($ans eq 'Yes');
    }
  }
  $bar = $bar->{$pn};
  if ($bar == 0) {
    if ($pn eq 'prev') {
      CP::Cmsg::message(SAD, "This is the first Bar.", 1);
      return;
    } else {
      if ($EditBar->isblank()) {
	CP::Cmsg::message(SAD, "This is the last Bar.", 1);
	return;
      }
      $bar = $tab->add1bar();
      $tab->indexBars();
      $tab->newPage($bar->{pnum});
    }
  }
  $EditBar->ClearEbars();
  $bar->select();
  $bar->Edit($tab);
}

sub InsertBefore { insert(BEFORE); }
sub InsertAfter  { insert(AFTER); }

sub insert {
  my($where) = @_;

  my $tab = $EditBar->{tab};
  if ($tab->{select1}) {
    $EditBar->{pbar} = $tab->{select1};
    save_bar($EditBar, $where);
    $tab->ClearAndRedraw();
  } else {
    message(SAD, "No Bar selected - don't know where to put this one!", 1);
  }
}

sub Save {
  save_bar($EditBar1, REPLACE) if ($EditBar1->{pbar} && $EditBar1->comp($EditBar1->{pbar}));
  save_bar($EditBar, REPLACE) if ($EditBar->comp($EditBar->{pbar}));
  $EditBar->{tab}->ClearAndRedraw();
}

# This updates the bar on the page but leaves the Edit Bar intact.
sub Update {
  if ($EditBar->{pbar}) {
    save_bar($EditBar1, UPDATE) if ($EditBar1->{pbar} && $EditBar1->comp($EditBar1->{pbar}));
    save_bar($EditBar, UPDATE) if ($EditBar->comp($EditBar->{pbar}));
  } else {
    # Editing a bar to tack on the end.
    save_bar($EditBar, UPDATE) if (! $EditBar->isblank());
  }
}

sub save_bar {
  my($ebar,$insert) = @_;

  my $tab = $ebar->{tab};
  my($bar);
  if ($tab->{select1} == 0) {
    # Shouldn't happen but someone could edit a bar (new or old)
    # and deselect the original so we tack this onto the end.
    $bar = $ebar->{pbar} = $tab->add1bar();
    $bar->select();
    $insert = REPLACE if ($insert != UPDATE);
  } else {
    my $dest = $ebar->{pbar};
    if ($insert == BEFORE || $insert == AFTER) {
      $bar = CP::Bar->new($tab);
      if ($insert == AFTER) {
	$bar->{prev} = $dest;
	$bar->{next} = $dest->{next};
	$dest->{next}{prev} = $bar;
	$dest->{next} = $bar;
      } else {
	if ($dest->{prev} == 0) {
	  $bar->{next} = $dest;
	  $dest->{prev} = $bar;
	  $tab->{bars} = $bar;
	} else {
	  $bar->{prev} = $dest->{prev};
	  $bar->{next} = $dest;
	  $dest->{prev}{next} = $bar;
	  $dest->{prev} = $bar;
	}
      }
    } else {
      $bar = $dest;
    }
  }
  $tab->{lastBar} = $bar if ($bar->{next} == 0);
  foreach my $v (qw/newline newpage volta header justify rep bg/) {
    $bar->{$v} = $ebar->{$v};
  }
  $bar->{notes} = [];
  foreach my $n ($ebar->noteSort()) {
    $n->{bar} = $bar;
    push(@{$bar->{notes}}, $n);
  }
  if ($insert == UPDATE) {
    $bar->unMap();
    $tab->indexBars();
    $tab->newPage($tab->{pageNum});
  }
  $tab->setEdited(1);
}

sub Cancel {
  my $tab = $EditBar->{tab};
  if ($EditBar->{pbar}->isblank()) {
    $tab->DeleteBars(0);
  }
  $EditBar->ClearEbars();
  $tab->ClearSel();
  $tab->{eWin}->g_wm_withdraw();
}

sub Background {
  if ((my $bg = $EditBar->bgGet()) ne '') {
    $EditBar->{bg} = $bg;
    $EditBar->{canvas}->itemconfigure("bg-1", -fill => $bg);
  }
}

sub RemoveBG {
  $EditBar->{canvas}->itemconfigure("bg-1", -fill => BLANK);
  $EditBar->{bg} = BLANK;
}

1;
