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
use CP::Pop qw/:MENU/;
use CP::Cmsg;
use CP::Date;

my @strOpt = (qw/date setup soundcheck s1start s1end s2start s2end/);

sub new {
  my($proto) = @_;
  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;

  $self->load();
  $self->{setsLB} = '';
  $self->{browser} = '';
  $self->select($CurSet);
  return $self;
}

sub load {
  my($self) = shift;

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
	if (defined $list{$_}{set1time}) {
	  $list{$_}{s1start} = $list{$_}{set1time};
	  $list{$_}{s2start} = $list{$_}{set2time};
	  delete($list{$_}{set1time});
	  delete($list{$_}{set2time});
	}
	$sets->{$_} = $list{$_};
      }
    }
  }
}

sub save {
  my ($self,$col) = @_;

  my $SL = "$Home/SetList";
  if (-e "${SL}.bak") {
    unlink("${SL}.bak");
  }
  if (-e "${SL}.cfg") {
    rename("${SL}.cfg", "${SL}.bak");
  }
  unless (open OFH, ">${SL}.cfg") {
    message(SAD, "Couldn't create Setlist file. (${SL}.cfg)");
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
  if (! defined $col) {
    $col = '';
  } else {
    $col = "$col ";
  }
  message(SMILE, $col."Setlists updated and saved.", 1);
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

  $self->{setsLB}{array} = ($Opt->{SLrev}) ?
      [reverse sort keys %{$self->{sets}}] :
      [sort keys %{$self->{sets}}];
  $self->{setsLB}->a2tcl();
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
    if (defined $AllSets) {
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
}

sub change {
  my($self) = shift;

  $self->load();
  $self->listSets();
  if ($CurSet ne '') {
    if (! defined $self->{sets}{$CurSet}) {
      $CurSet = '';
    } else {
      $self->{browser}{selLB}{array} = $self->{sets}{$CurSet}{songs};
    }
  }
  $self->{browser}->refresh($Path->{Pro}, '.pro');
  $self->select($CurSet);
}

#
# This is called from New, Rename or Clone
sub setNRC {
  my($self,$what,$newname) = @_;

  my $oldname = $CurSet;
  if (defined $self->{sets}{$newname}) {
    message(SAD, "Setlist \"$newname\" already exists\nPlease choose another name.");
  } else {
    if ($newname ne '') {
      my $sp = $self->{sets};
      if ($what & (SLCLN | SLREN)) {
	# Copy the selected Setlist into a new one
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

sub showSet {
  my($self) = shift;

  my $idx = $self->{setsLB}->curselection(0);
  my $sl = $self->{setsLB}{array}[$idx];
  if ($sl ne '') {
    $self->select($sl);
    $self->{browser}{selLB}{array} = $self->{sets}{$sl}{songs};
    $self->{browser}->refresh($Path->{Pro}, '.pro');
  }
}

sub delete {
  my($self) = shift;

  my $todel = $CurSet;
  if ($todel ne '') {
    return if (msgYesNo("Are you sure you want to delete Set '$todel'?") =~ /no/i);
    delete $self->{sets}{$todel};
    $self->{setsLB}{array} = [sort keys %{$self->{sets}}];
    $self->{setsLB}->a2tcl();
    $self->select('');
  }
}

sub importSet {
  my($self) = shift;

  my $types = [
    ['SetList Files', '.sel'],
    ['All Files',      '*'],
      ];
  my $f = Tkx::tk___getOpenFile(
    -initialdir => "$Home",
    -filetypes => $types,
    -defaultextension => '.sel',
    -multiple => 1);
  if ($f ne '') {
    foreach my $f (Tkx::SplitList($f)) {
      our %list;
      do "$f";
      foreach $CurSet (sort keys %list) {
	if (exists $self->{sets}{$CurSet}) {
	  my $ans = msgYesNoCan("SetList \"$CurSet\" already exists.\n  Overwrite it?");
	  return if ($ans eq 'Cancel');
	  next if ($ans eq 'No');
	}
	$self->{sets}{$CurSet} = $list{$CurSet};
	message(SMILE, "\"$CurSet\" imported (but not saved)", -1);
      }
    }
    $self->{setsLB}{array} = [sort keys %{$self->{sets}}];
    $self->{setsLB}->a2tcl();
    $self->select($CurSet);
    $self->showSet();
  }
}

sub export {
  my($self) = shift;

  return if ($CurSet eq '');
  my $newC = my $orgC = $Collection->name();
  my @lst = sort keys %{$Collection};
  unshift(@lst, 'All');
  push(@lst, 'SeP', 'File');
  popMenu(
    \$newC,
    sub{
      if ($newC ne $orgC) {
	if ($newC eq 'File') {
	  my $file = $CurSet.'.sel';
	  $file = Tkx::tk___getSaveFile(
	    -title => "Save As",
	    -initialdir => "$Home",
	    -initialfile => $file,
	    -confirmoverwrite => 1,
	      );
	  return if ($file eq '');
	  unless (open OFH, '>', $file) {
	    errorPrint("Couldn't create SetList file:\n   '$file'\n$!");
	    return();
	  }
	  my $sp = \%{$self->{sets}{$CurSet}};
	  print OFH "#!/usr/bin/perl\n\n";
	  print OFH "\%list = (\n";
	  print OFH "  \"$CurSet\" => {\n";
	  foreach my $s (@strOpt) {
	    print OFH "    $s => '$sp->{$s}',\n";
	  }
	  print OFH "    songs => [\n";
	  foreach my $s (@{$sp->{songs}}) {
	    print OFH '      "'.$s."\",\n";
	  }
	  print OFH "    ],\n";
	  print OFH "  },\n";
	  print OFH ");\n1;\n";
	  close(OFH);
	  message(SMILE, " Done ", 1);
	  return;
	} elsif ($newC eq 'All') {
	  shift(@lst);
	} else {
	  @lst = ($newC);
	}
	# Remove the Seperator and File entries.
	pop(@lst);
	pop(@lst);
	my $orgHome = $Home;
	my $all = 0;
	foreach my $col (@lst) {
	  next if ($col eq $orgC);
	  $Home = "$Collection->{$col}/$col";
	  my $sl = CP::SetList->new();
	  if (exists $sl->{sets}{$CurSet} && $all == 0) {
	    my $ans = msgYesNoAll("The Setlist:    \"$CurSet\"\nalready exists in Collection:\n    \"$col\"\nDo you want to overwrite it?");
	    if ($ans eq "No") {
	      undef $sl;
	      next;
	    } elsif ($ans eq 'All') {
	      $all++;
	    }
	  }
	  $sl->{sets}{$CurSet} = $self->{sets}{$CurSet};
	  $sl->save($col);
	  undef $sl;
	}
	$Home = $orgHome;
      }
    },
    \@lst);
}

1;
