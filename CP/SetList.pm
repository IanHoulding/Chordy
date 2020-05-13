package CP::SetList;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

use strict;

use CP::Cconst qw/:SMILIE :BROWSE/;
use CP::Global qw/:FUNC :PATH :OPT :PRO :SETL :XPM/;
use CP::Cmsg;
use CP::Date;

my @strOpt = (qw/date setup soundcheck set1time set2time/);

sub new {
  my($proto) = @_;
  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;

  my $sets = $self->{sets} = {};
  if (-e "$Home/SetList.cfg") {
    our %list;
    do "$Home/SetList.cfg";
    my @lst = sort keys %list;
    if (ref($list{$lst[0]}) eq 'ARRAY') {
      conv2new(\%list, $sets);
      save($self);
    } else {
      foreach (@lst) {
	$sets->{$_} = $list{$_};
      }
    }
  }
  $self->{setsLB} = '';
  $self->{browser} = '';
  $self->select($CurSet);
  return $self;
}

sub conv2new {
  my($list,$sets) = @_;

  foreach my $c (sort keys %{$list}) {
    foreach my $s (@{$list->{$c}}) {
      push(@{$sets->{$c}{songs}}, $s);
      foreach (@strOpt) {
	$sets->{$c}{$_} = '';
      }
    }
  }
}

sub listSets {
  my($self) = shift;

  [sort keys %{$self->{sets}}];
}

sub save {
  my ($self) = shift;

  my $SL = "$Home/SetList";
  if (-e "${SL}.bak") {
    unlink("${SL}.bak");
  }
  if (-e "${SL}.cfg") {
    rename("${SL}.cfg", "${SL}.bak");
  }
  unless (open OFH, ">${SL}.cfg") {
    message(SAD, "Couldn't create Set List file. (${SL}.cfg)");
    if (-e "${SL}.bak") {
      rename( "${SL}.bak", "${SL}.cfg");
    }
    return(0);
  }
  print OFH "#!/usr/bin/perl\n\n";
  print OFH "\%list = (\n";
  foreach my $c (keys %{$self->{sets}}) {
    if ($c ne '') {
      my $sp = \%{$self->{sets}{$c}};
      print OFH "  \"$c\" => {\n";
      foreach my $s (@strOpt) {
	print OFH "    $s => '$sp->{$s}',\n";
      }
      print OFH "    songs => [\n";
      foreach my $s (@{$sp->{songs}}) {
	print OFH '      "'.$s."\",\n";
      }
      print OFH "    ],\n";
      print OFH "  },\n";
    }
  }
  print OFH ");\n1;\n";
  close(OFH);
  message(SMILE, "Set Lists updated and saved.", 1);
}

sub select {
  my($self,$set) = @_;

  $CurSet = $set;
  if ($set eq '') {
    foreach my $o (@strOpt) {
      $self->{meta}{$o} = '';
    }
    if (defined $AllSets) {
      $AllSets->{setsLB}->selection_clear(0,'end');
    }
  } else {
    my $sp = $self->{sets}{$set};
    foreach my $o (@strOpt) {
      $self->{meta}{$o} = $sp->{$o};
    }
    my $idx = 0;
    foreach my $a (@{$AllSets->{setsLB}{array}}) {
      if ($a eq $CurSet) {
	$AllSets->{setsLB}->selection_set($idx);
	last;
      }
      $idx++;
    }
  }
}

sub change {
  my($self) = shift;

  my $slb = $self->{setsLB};
  my $br = $self->{browser};
  $AllSets = CP::SetList->new();
  $AllSets->{setsLB} = $slb;
  $AllSets->{browser} = $br;
  $slb->{array} = $AllSets->listSets();
  $slb->a2tcl();
  if ($CurSet ne '') {
    if (! defined $AllSets->{sets}{$CurSet}) {
      $CurSet = '';
    } else {
      $AllSets->{browser}{selLB}{array} = $AllSets->{sets}{$CurSet}{songs};
    }
  }
  $br->refresh($Path->{Pro}, '.pro');
  $AllSets->select($CurSet);
}

#
# This is called from New, Rename or Clone
sub setNRC {
  my($self,$what,$newname) = @_;

  my $oldname = $CurSet;
  if (defined $self->{sets}{$newname}) {
    message(SAD, "Set List \"$newname\" already exists\nPlease choose another name.");
  } else {
    if ($newname ne '') {
      my $sp = $self->{sets};
      if ($what & (SLCLN | SLREN)) {
	# Copy the selected Set List into a new one
	$sp->{$newname} = $sp->{$oldname};
	if ($what == SLREN) {
	  delete $sp->{$oldname};
	}
      } else {
	# New
	$sp->{$newname} = {};
	foreach my $s (@strOpt) {
	  $sp->{$newname}{$s} = '';
	}
	$sp->{$newname}{songs} = [];
      }
      $self->select($newname);
      $self->{setsLB}{array} = [sort keys %{$sp}];
      $self->{setsLB}->a2tcl();
    } else {
      my $w = 'You need a Name ';
      if    ($what == SLNEW) {$w .= 'for the New Set!';}
      elsif ($what == SLCLN) {$w .= 'for the Cloned Set!';}
      elsif ($what == SLREN) {$w .= 'to Rename the Set to!';}
      message(QUIZ, $w);
      return;
    }
  }
}

sub delete {
  my($self) = @_;

  my $todel = $CurSet;
  if ($todel ne '') {
    return if (msgYesNo("Are you sure you want to delete Set '$todel'?") =~ /no/i);
    delete $self->{sets}{$todel};
    $self->{setsLB}{array} = [sort keys %{$self->{sets}}];
    $self->{setsLB}->a2tcl();
    $self->select('');
  }
}

sub export {
  my($self) = shift;

  return if ($CurSet eq '');
  my $newC = my $orgC = $Collection->name();
  my @lst = sort keys %{$Collection};
  unshift(@lst, 'All');
  popMenu(
    \$newC,
    sub{
      if ($newC ne $orgC) {
	my $all = 0;
	if ($newC eq 'All') {
	  shift(@lst);
	} else {
	  @lst = ($newC);
	}
	my $orgHome = $Home;
	foreach my $col (@lst) {
	  next if ($col eq $orgC);
	  $Home = "$Collection->{$col}/$col";
	  my $sl = CP::SetList->new();
	  if (exists $sl->{sets}{$CurSet} && $all == 0) {
	    my $ans = msgYesNoAll("The Set List:    \"$CurSet\"\nalready exists in Collection:\n    \"$col\"\nDo you want to overwrite it?");
	    if ($ans eq "No") {
	      undef $sl;
	      next;
	    } elsif ($ans eq 'All') {
	      $all++;
	    }
	  }
	  $sl->{sets}{$CurSet} = $self->{sets}{$CurSet};
	  $sl->save();
	  undef $sl;
	}
	$Home = $orgHome;
      }
    },
    \@lst);
}

sub edit {
  my($self) = shift;

  CORE::state $DT;
  if (! defined $DT) {
    $DT = CP::Date->new();
  }
  my($top,$wt) = popWin(0, 'Set List Date/Times');

  my $tf = $wt->new_ttk__labelframe(
    -text => $CurSet,
    -labelanchor => 'n',
    -padding => [16,4,4,4]);
  $tf->g_pack(qw/-side top -expand 1 -fill x/);
  my $bf = $wt->new_ttk__frame();
  $bf->g_pack(qw/-side top -expand 1 -fill x/);

  makeImage('ellipsis', \%XPM);
  my $done = '';
  my $lab = $tf->new_ttk__label(-text => "Date: ");
  $lab->g_grid(qw/-row 0 -column 0 -pady 2 -sticky e/);
  my $ent = $tf->new_ttk__entry(-width => 18, -textvariable => \$self->{meta}{date});
  $ent->g_grid(qw/-row 0 -column 1 -columnspan 2 -pady 2 -sticky w/);
  my $sd = $tf->new_ttk__button(-image => 'ellipsis',
				-width => 5,
				-command => sub{if ($DT->newDate()) {
				                  $self->{meta}{date} = sprintf "%d %s %d",
						      $DT->{day}, $DT->{months}, $DT->{year};
						}});
  $sd->g_grid(qw/-row 0 -column 3 -padx 8 -pady 2 -sticky w/);
  my $row = 1;
  foreach my $i (['Setup',       'setup'],
		 ['Sound Check', 'soundcheck'],
		 ['Set 1 Start', 'set1time'],
		 ['Set 2 Start', 'set2time']) {
    my($lab,$key) = @{$i};
    my $lab = $tf->new_ttk__label(-text => "$lab: ");
    $lab->g_grid(-row => $row, qw/-column 0 -pady 2 -sticky e/);
    my $var = \$self->{meta}{$key};
    my $ent = $tf->new_ttk__entry(-width => 8, -textvariable => $var);
    $ent->g_grid(-row => $row, qw/-column 1 -pady 2 -sticky w/);
    my $sel = $tf->new_ttk__button(-image => 'ellipsis',
				   -width => 5,
				   -command => sub{if ($DT->newTime()) {
						     $$var = sprintf "%02d:%02d",
							 $DT->{hour}, $DT->{minute};
						   }});
    $sel->g_grid(-row => $row++, qw/-column 2 -padx 0 -pady 2 -sticky w/);
    $ent->g_focus() if ($row == 1);
  }

  ($bf->new_ttk__button(-text => "Cancel", -command => sub{$done = "Cancel";},
   ))->g_pack(qw/-side left/, -padx => [20,0], -pady => [4,2]);

  ($bf->new_ttk__button(-text => "OK", -command => sub{$done = "OK";},
   ))->g_pack(qw/-side right/, -padx => [0,20], -pady => [4,2]);

  Tkx::vwait(\$done);
  if ($done eq "OK") {
    my $sp = $self->{sets}{$CurSet};
    foreach my $o (@strOpt) {
      $sp->{$o} = $self->{meta}{$o};
    }    
  } else {
    my $sp = $self->{sets}{$CurSet};
    foreach my $o (@strOpt) {
      $self->{meta}{$o} = $sp->{$o};
    }    
  }
  $top->g_destroy();
  $done;
}

1;
