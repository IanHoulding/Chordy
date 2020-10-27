package CP::Browser;

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
use CP::Cconst qw/:BROWSE :SMILIE :COLOUR/;
use CP::Global qw/:FUNC :WIN :OPT :PRO :SETL :XPM/;
use CP::Pop qw /:POP :MENU/;
use CP::List;
use CP::Cmsg;

my $Arrows = 0;

sub new {
  my($proto,$top,$what,$path,$ext,$list) = @_;

  return('') if ($top eq $MW && popExists('.fb'));
  my($pop,$fileBr,$frame);
  if ($top eq $MW) {
    $pop = CP::Pop->new(0, '.fb', "File Browser  |  Collection: ".$Collection->{name});
    ($fileBr,$frame) = ($pop->{top}, $pop->{frame});
  } else {
    $frame = $top;
  }
  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;

  $self->{avLB} = '';
  $self->{selLB} = '';
  $self->{oldSearch} = '';
  $self->{searchIdx} = 0;

  my $listHt = 16;
  my $done = '';
  my($avail,$select);

  mkArrows() if ($Arrows == 0);

  ### Sort By & Search Frame
  my $topFrm = $frame->new_ttk__frame();

  my $srt = $topFrm->new_ttk__label(-text => 'Sort By: ');
  my $sby = $topFrm->new_ttk__button(
    -textvariable => \$Opt->{SortBy},
    -width => 14,
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$Opt->{SortBy}, undef, ["Alphabetical", "Date Modified"]);
      $avail->h2tcl();
      $Opt->saveOne('SortBy');
    } );
  my $rev = $topFrm->new_ttk__checkbutton(-variable => \$Opt->{RevSort},
					  -style => 'NM.TCheckbutton',
					  -command => sub{$Opt->saveOne('RevSort');
							  $avail->h2tcl();});
  my $revlab = $topFrm->new_ttk__label(-text => 'Reverse',
				       -font => 'BTkDefaultFont',
				       -padding => [0,0,0,0]);

  my $mfs = $topFrm->new_ttk__label(-text => 'Search: ');
  my $entry = $topFrm->new_ttk__entry(-width => 20, -validate => 'key');
  $entry->m_configure(-validatecommand => [sub{do_search($self,@_)}, Tkx::Ev("%P")]);
  my $mfn = $topFrm->new_ttk__button(-text => 'Find Next', -command => sub{next_search($self)});

  ### Available Files
  my $leftFrm = $frame->new_ttk__labelframe(
    -text => ' Available Files ',
    -labelanchor => 'n',
    -padding => [2,0,4,0]);
  $avail = $self->{avLB} = CP::List->new(
    $leftFrm, 'e',
    -height => $listHt,
    -width => SLWID,
    -selectmode => 'browse',
    -takefocus => 1);

  if ($what & TABBR) {
    $avail->bind('<Double-Button-1>' => sub{$done = 'OK'});
  } else {
    $avail->bind('<Double-Button-1>' => sub{moveOneItem($self,$avail,$select);});
  }

  if (readInAvail($self, $path, $ext) == 0 && $what & (FILE | TABBR)) {
    $fileBr->popDestroy();
    message(SAD, "Sorry - couldn't find any '$ext' files!");
    return('');
  }
  $avail->h2tcl();  # doesn't actually "show" - just sets the $tcl variable

  my $igna = $leftFrm->new_ttk__checkbutton(
    -text => "Ignore leading \"$Opt->{Articles}\" when sorting",
    -variable => \$Opt->{IgnArticle},
    -command => sub{$avail->h2tcl()});

  ### Left/Right Arrows & Alpha shortcuts
  my $centerFrm = $frame->new_ttk__frame();
  my $arrowFrm = $centerFrm->new_ttk__frame();
  my $alphaFrm = $centerFrm->new_ttk__frame();

  ### Selected Files
  my $title = ($what & (FILE | TABBR)) ? ' Selected Files ' : ' Setlist Files ';
  my $rightFrm = $frame->new_ttk__labelframe(
    -text => $title,
    -labelanchor => 'n',
    -padding => [4,0,4,0]);
  $self->{frame} = $rightFrm;
  $select = $self->{selLB} = CP::List->new(
    $rightFrm, 'e', -height => $listHt, -width => SLWID, -selectmode => 'browse', -takefocus => 1);
  $select->bind('<Double-Button-1>' => sub{moveOneItem($self,$select,$avail);});

  ### Up/Down Arrows
  my $rightFrmR;
  if (($what & (FILE | TABBR)) == 0) {
    $rightFrmR = $frame->new_ttk__frame();
  }

  ##############################
  #### Now fill out the Frames

  ### LEFT
  ## Now pack everything except, possibly, the Cancel/OK buttons

  # Sort By and Search box
  $topFrm->g_pack(qw/-side top -fill x/, -padx => [0,4], -pady => [4,4]);

  $srt->g_pack(qw/-side left/, -padx => [4,0]);
  $sby->g_pack(qw/-side left/, -padx => [2,0]);
  $rev->g_pack(qw/-side left -anchor e/, -padx => [4,0]);
  $revlab->g_pack(qw/-side left -anchor w/, -padx => [0,0]);

  $mfs->g_pack(  qw/-side left/, -padx => [30,0]);
  $entry->g_pack(qw/-side left/, -padx => [2,0]);
  $mfn->g_pack(  qw/-side left/, -padx => [8,0]);

  # Available files
  $leftFrm->g_pack(qw/-side left -expand 1 -fill y/, -padx => [0,4]);
  $avail->{frame}->g_grid(qw/-row 0 -column 0 -sticky nsew/);
  $igna->g_grid(qw/-row 2 -column 0 -sticky w/, -pady => [8,2]);

  # Left/Right Arrows
  $centerFrm->g_pack(qw/-side left -anchor n -expand 0 -fill x/);
  $arrowFrm->g_pack(qw/-side top -expand 0 -pady 6/);
  $alphaFrm->g_pack(qw/-side top -expand 0 -fill y/);

  # Selected Files
  $rightFrm->g_pack(qw/-side left -expand 1 -fill y/, -padx => [4,4]);

  # columnspan is 2 so that we can put 2 buttons below the ListBox.
  $select->{frame}->g_grid(qw/-row 0 -column 0 -columnspan 2 -sticky nsew/);

  # Up/Down Arrows only for Setlists
  if (($what & (FILE | TABBR)) == 0) {
    $rightFrmR->g_pack(qw/-side left -expand 0 -fill x/, -padx => [0,2]);
  }

  ### CENTER
  leftRightArrows($self, $arrowFrm, $avail, $select);
  my $r = my $c = 0;

  foreach my $a ('A'..'Z') {
    my $wid = $alphaFrm->new_ttk__button(
      -style => 'SF.TButton',
      -text => $a, -width => 2,
      -command => sub{$avail->moveTo($a, $listHt)});
    $wid->g_grid(-row => $r, -column => $c++, -padx => 2, -pady => 2);
    $c %= 3;
    $r++ if ($c == 0);
  }


  ### RIGHT
  # Already done above.

  ### Optional Far RIGHT
  if (($what & (FILE | TABBR)) == 0) {
    upDownArrows($rightFrmR, $select);
  }

  ########
  
  $avail->focus() if (Tkx::winfo_exists($avail->{lb}));

  if ($top eq $MW) {
    my $a = $rightFrm->new_ttk__button(
      -text => "Cancel",
      -width => 8,
      -style => 'Red.TButton',
      -command => sub{$done = 'Cancel'});
    my $b = $rightFrm->new_ttk__button(
      -text => "OK",
      -width => 8,
      -style => 'Green.TButton',
      -command => sub{$done = 'OK'});
    $a->g_grid(qw/-row 1 -column 0 -padx 4/, -pady => [8,4]);
    $b->g_grid(qw/-row 1 -column 1 -padx 4/, -pady => [8,4]);

    Tkx::update();
    $fileBr->g_raise();
    $fileBr->g_focus();

    Tkx::vwait(\$done);

    my @sl;
    if ($done eq 'OK') {
      if ($what == TABBR) {
	if (@{$select->{array}} == 0) {
	  my $idx = $avail->curselection(0);
	  $sl[0] = $avail->get($idx);
	} else {
	  $sl[0] = $select->{array}[0];
	}
      } else {
	@sl = @{$select->{array}};
      }
    } else {
      $sl[0] = '';
    }
    $pop->popDestroy();
    return(@sl);
  }
  return($self);
}

sub leftRightArrows {
  my($self,$frame,$av,$sel) = @_;

  my $rt = $frame->new_ttk__button(
    -image => 'arrr',
    -command => sub{moveOneItem($self,$av,$sel);});
  $rt->g_pack(qw/-side top -pady 2/, -ipady => 1);

  my $lt = $frame->new_ttk__button(
    -image => 'arrl',
    -command => sub{moveOneItem($self,$sel,$av);});
  $lt->g_pack(qw/-side top -pady 2/, -ipady => 1);

  my $al = $frame->new_ttk__button(
    -image => 'alll',
    -command => sub{moveAllItems($self,$sel,$av);});
  $al->g_pack(qw/-side bottom -pady 2/);

  my $ar = $frame->new_ttk__button(
    -image => 'allr',
    -command => sub{moveAllItems($self,$av,$sel);});
  $ar->g_pack(qw/-side bottom -pady 2/);
}

sub upDownArrows {
  my($frame,$sel) = @_;

  my $ub = $frame->new_ttk__button(
    -image => 'arru',
    -command => sub{moveSel($sel, -1);});
  $ub->g_pack(qw/-side top -pady 4/, -ipady => 2);

  my $db = $frame->new_ttk__button(
    -image => 'arrd',
    -command => sub{moveSel($sel, 1);});
  $db->g_pack(qw/-side top -pady 4/, -ipady => 2);
}

sub do_search {
  my($self,$ent) = @_;

  return(0) if ($self->{oldSearch} eq $ent);
  # Use what's currently displayed in Listbox to search through  
  # This is a non-complicated in order search
  my $avLB = $self->{avLB};
  $avLB->h2a() if (@{$avLB->{array}} == 0);
  my $idx = $self->{searchIdx} = 0;
  foreach my $f (@{$avLB->{array}}) {
    if ($f =~ /$ent/i) {
      $avLB->set($idx);
      $self->{searchIdx} = $idx;
      last;
    }
    $idx++;
  }
  if ($idx == @{$avLB->{array}}) {
    message(SAD, "String '$ent' not found.");
  }
  $self->{oldSearch} = $ent;
  1;
}

sub next_search {
  my($self) = shift;

  my $avail = $self->{avLB};
  my $sidx = $self->{searchIdx};
  while (++$sidx < @{$avail->{array}}) {
    if ($avail->{array}[$sidx] =~ /$self->{oldSearch}/i) {
      $avail->set($sidx);
      last;
    }
  }
  if ($sidx >= @{$avail->{array}}) {
    my $si = $sidx;
    for($sidx = 0; $sidx < $si; $sidx++) {
      if ($avail->{array}[$sidx] =~ /$self->{oldSearch}/i) {
	$avail->set($sidx);
	last;
      }
    }
  }
  if ($sidx == @{$avail->{array}}) {
    message(SAD, "String '$self->{oldSearch}' not found.");
  }
  $self->{searchIdx} = $sidx;
}

sub mkArrows {
  foreach my $ar (qw/arrr arrl allr alll arru arrd/) {
    makeImage("$ar", \%XPM);
  }
  $Arrows++;
}

#
# Move one item from alb to blb where alb & blb
# are always either avLB or selLB
#
sub moveOneItem {
  my($self,$alb,$blb) = @_;

  my $idx = $alb->curselection(0);
  if ($idx ne '') {
    my $f = $alb->get($idx);
    if ($blb eq $self->{avLB}) {
      $blb->{hash}{$f} = 1;
      splice(@{$self->{selLB}{array}}, $idx, 1);
    } else {
      $self->{avLB}{hash}{$f} = 0;
      $self->{selLB}->add2a($f);
    }
    $self->{avLB}->h2tcl();
    $self->{selLB}->a2tcl();
    if ($alb eq $self->{avLB}) {
      $alb->set($idx);
    }
    $blb->set('end') if ($blb eq $self->{selLB});
  }
}

#
# Move everything from 'a' to 'b'
#
sub moveAllItems {
  my($self,$alb,$blb) = @_;

  if ($alb eq $self->{avLB}) {
    $alb->h2a() if (@{$alb->{array}} == 0);
    foreach my $fl (@{$alb->{array}}) {
      if ($alb->{hash}{$fl} == 1) {
	$alb->{hash}{$fl} = 0;
	push(@{$blb->{array}}, $fl);
      }
    }
  } else {
    foreach my $fl (@{$alb->{array}}) {
      $blb->{hash}{$fl} = 1;
    }
    $alb->{array} = [];
  }
  $self->{avLB}->h2tcl();
  $self->{selLB}->a2tcl();
}

#
# Handle Up/Down arrows on the $Select->{lb}
# -1 = UP  +1 = DOWN
#
sub moveSel {
  my($lbox,$dir) = @_;

  my $idx = $lbox->curselection(0);
  if (($dir == -1 && $idx > 0) || ($dir == 1 && $idx < (@{$lbox->{array}} - 1))){
    my $item = splice(@{$lbox->{array}}, $idx, 1);
    splice(@{$lbox->{array}}, ($idx + $dir), 0, $item);
    $lbox->a2tcl();
    $lbox->selection_clear(0, 'end');
    $idx += $dir;
    $lbox->set($idx);
    $idx = $idx - int($lbox->{lb}->m_cget(-height) / 2);
    $idx = 0 if ($idx < 0);
    $lbox->{lb}->yview($idx);
  }
}

#
# Read in a list of .pro/.tab files in folder $path
#
sub readInAvail {
  my ($self,$path,$ext) = @_;

  $self->{avLB}{hash} = {};
  $self->{avLB}{path} = $path;
  if (-d $path) {
    opendir DIR, "$path";
    my $hash = $self->{avLB}{hash};
    foreach my $f (grep /$ext$/, readdir DIR) {
      $hash->{$f} = 1;
    }
    closedir(DIR);
  }
  return(scalar keys(%{$self->{avLB}{hash}}));
}

sub remListFromAvail {
  my($self,$list) = @_;

  # Reset the Available list
  allAvail($self);
  # Now remove all the Set files from the Available List
  my $hash = $self->{avLB}{hash};
  foreach my $sl (@{$list}) {
    $hash->{$sl} = 0 if (exists $hash->{$sl});
  }
}

sub reset {
  my($self) = shift;

  $self->{selLB}{array} = [];
  $self->{selLB}->a2tcl();
  allAvail($self);
  $self->{avLB}->h2tcl();
}

sub allAvail {
  my($self) = shift;

  # Reset the Available list
  my $hash = $self->{avLB}{hash};
  foreach my $av (keys %{$hash}) {
    $hash->{$av} = 1;
  }
}

sub refresh {
  my($self,$path,$ext) = @_;

  if (readInAvail($self, $path, $ext)) {
    my $ar = [];
    foreach my $fl (@{$self->{selLB}{array}}) {
      if (-e "$path/$fl") {
	$self->{avLB}{hash}{$fl} = 0;
	push(@{$ar}, $fl);
      }
    }
    $self->{selLB}{array} = $ar;
    $self->{avLB}->h2tcl();
    $self->{selLB}->a2tcl();
  }
}

1;
