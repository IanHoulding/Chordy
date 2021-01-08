package CP::List;
# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

#
# VERY simple module to aggregate the various entities
# we need for a ListBox widget into one object.
#
use strict;
use warnings;

use CP::Cconst qw/:COLOUR/;
use CP::Global qw/:OPT :WIN/;
use Tkx;

our($SearchIdx, $OldSearch, %LoLists);

sub new {
  my($proto) = shift;
  my $class = ref($proto) || $proto;

  my $self = {};
  my $widget = shift;
  my $sb = shift;
  $self->{tcl} = '';
  my $frm = $self->{frame} = $widget->new_ttk__frame(-padding => 0);
  $self->{lb} = $frm->new_tk__listbox(
    -relief => 'raised',
    -borderwidth => 2,
    -selectmode => 'single',
    -selectforeground => BLACK,
    -selectbackground => DBLBG,
    -selectborderwidth => 0,
    -activestyle => 'none',
    -highlightthickness => 0,
    -listvariable => \$self->{tcl},
    @_,
);
  $self->{lb}->g_grid(qw/-row 1 -column 1 -sticky ns/);
  if ($sb ne '') {
    my $sbns = '';
    my $sbwe = '';
    # We only allow 2 scrollbars with preference given to South and East.
    if ($sb =~ /n|s/) {
      $self->{xscrbar} = $frm->new_ttk__scrollbar(
	-orient => 'horizontal', -command => [$self->{lb}, 'xview']);
      my $r = ($sb =~ /s/) ? 2 : 0;
      $self->{xscrbar}->g_grid(-row => $r, -column => 1, -sticky => 'we');
      $self->{lb}->configure(-xscrollcommand => [$self->{xscrbar}, 'set']);
    }
    if ($sb =~ /w|e/) {
      $self->{yscrbar} = $frm->new_ttk__scrollbar(
	-orient => 'vertical', -command => [$self->{lb}, 'yview']);
      my $c = ($sb =~ /e/) ? 2 : 0;
      $self->{yscrbar}->g_grid(-row => 1, -column => $c, -sticky => 'ns');
      $self->{lb}->configure(-yscrollcommand => [$self->{yscrbar}, 'set']);
    }
  }

  $self->{array} = [];
  $self->{hash} = {};

  bless $self, $class;
  $LoLists{$self->{lb}} = $self->{lb};
  background();
  return $self;
}

# If $set is not defined then we assume $Opt->{ListFG} and/or $Opt->{ListBG} have been.
sub background {
  my($set) = shift;

  my $fg = (defined $Opt->{ListFG}) ? $Opt->{ListFG} : BLACK;
  my $bg = (defined $Opt->{ListBG}) ? $Opt->{ListBG} : WHITE;
  my($nfg,$nbg) = ('','');
  if (defined $set) {
    CP::FgBgEd->new("List Colours");
    ($nfg,$nbg) = $ColourEd->Show($fg, $bg, (FOREGRND|BACKGRND));
    $fg = $nfg if ($nfg ne '');
    $bg = $nbg if ($nbg ne '');
  }
  foreach my $k (keys %LoLists) {
    if (Tkx::winfo_exists($LoLists{$k})) {
      $LoLists{$k}->m_configure(-foreground => $fg);
      $LoLists{$k}->m_configure(-background => $bg);
    } else {
      delete $LoLists{$k};
    }
  }
  $Opt->{ListFG} = $fg;
  $Opt->{ListBG} = $bg;
  Tkx::ttk__style_configure("List.TButton", -foreground => $fg);
  Tkx::ttk__style_configure("List.TButton", -background => $bg);
}

sub set {
  my($self,$idx) = @_;

  my $lb = $self->{lb};
  $lb->selection_clear(0, 'end');
  $lb->selection_set($idx);
  $lb->activate($idx);
  $lb->see($idx);
}

sub clear {
  my($self) = shift;

  $self->{array} = [];
  $self->{hash} = {};
  $self->{tcl} = '';
}

sub remove {
  my($self,$idx) = @_;

  my $f = splice(@{$self->{array}}, $idx, 1);
  delete($self->{hash}{$f}) if (defined $self->{hash}{$f});
  a2tcl($self);
}

sub replace {
  my($self,$idx,$fn) = @_;

  my $f = $self->{array}[$idx];
  $self->{array}[$idx] = $fn;
  if (defined $self->{hash}{$f}) {
    delete($self->{hash}{$f});
    $self->{hash}{$fn} = 1;
  }
  a2tcl($self);
}

sub add2a {
  my($self,$f) = @_;

  push(@{$self->{array}}, $f);
  $self->{tcl} .= ' {'.$f.'}';
}

sub a2tcl {
  my($self) = shift;

  $self->{tcl} = '{'.join('} {', @{$self->{array}}).'}';
}

sub h2tcl {
  my($self) = shift;

  h2a($self);
  a2tcl($self);
}

sub h2a {
  my($self) = shift;

  $self->{array} = [];
  foreach (sort {avSort($self,$a,$b)} keys %{$self->{hash}}) {
    push(@{$self->{array}}, $_) if ($self->{hash}{$_});
  }
}

sub avSort {
  my($self,$a,$b) = @_;

  if ($self->{hash}{$a} == 0) {
    return($Opt->{RevSort} ? 1 : -1);
  }
  if ($self->{hash}{$b} == 0) {
    return($Opt->{RevSort} ? -1 : 1);
  }
  my $cmp = 0;
  if ($Opt->{SortBy} =~ /^Alpha/) {
    if ($Opt->{IgnArticle}) {
      $a =~ s/^($Opt->{Articles})\s+//i if (defined $a);
      $b =~ s/^($Opt->{Articles})\s+//i if (defined $b);
    }
    $cmp = uc($a) cmp uc($b);
  } elsif ($Opt->{SortBy} =~ /^Date/) {
    my $path = $self->{path};
    $a = (stat("$path/$a"))[9];
    $b = (stat("$path/$b"))[9];
    $cmp = $b <=> $a;
  }
  $cmp = -$cmp if ($Opt->{RevSort});
  return($cmp);
}

sub search {
  my($self,$ent) = @_;

  return(0) if ($OldSearch eq $ent);
  # Use what's currently displayed in Listbox to search through  
  # This is a non-complicated in order search

  my $idx = 0;
  foreach my $f ($self->h2a()) {
    if ($self->{hash}{$f}) {
      if ($f =~ /$ent/i) {
	$self->set($idx);
	$SearchIdx = $idx;
	last;
      }
      $idx++;
    }
  }
  $OldSearch = $ent;
  1;
}

sub next_search {
  my($self) = shift;

  my @list = $self->h2a();
  my $si = $SearchIdx;
  while (++$SearchIdx <= $#list) {
    if ($list[$SearchIdx] =~ /$OldSearch/i) {
      $self->set($SearchIdx);
      last;
    }
  }
  if ($SearchIdx > $#list) {
    for($SearchIdx = 0; $SearchIdx <= $si; $SearchIdx++) {
      if ($list[$SearchIdx] =~ /$OldSearch/i) {
	$self->set($SearchIdx);
	last;
      }
    }
  }
}

# $a is always a single upper case character A..Z
sub moveTo {
  my($self,$a,$ht) = @_;

  if ($Opt->{SortBy} eq 'Date Modified') {
    Tkx::bell();
    return;
  }
  my $low = my $idx = 0;
  my $high = $self->{lb}->size();
  while ($low < $high) {
    $idx = int((($low + $high) / 2));
    my $b = $self->get($idx);
    if ($Opt->{IgnArticle}) {
      $b =~ s/^($Opt->{Articles})\s+//i;
    }
    $b = ucfirst($b);
    if ($Opt->{RevSort}) {
      if ($b gt $a) {
	$low = $idx + 1;
      } else {
	$high = $idx;
      }
    } else {
      if ($b lt $a) {
	$low = $idx + 1;
      } else {
	$high = $idx;
      }
    }
  }
  $low-- if ($Opt->{RevSort});
  $self->set($low);
}

sub curselection {
  my($self,$idx) = @_;

  ($self->{lb}->curselection())[$idx];
}

sub selection_set {
  my($self,$idx) = @_;

  $self->{lb}->selection_clear(0, 'end');
  $self->{lb}->selection_set($idx);
  $self->{lb}->see($idx);
}

sub selection_clear {
  my($self,$start,$end) = @_;

  $self->{lb}->selection_clear($start, $end);
}

sub get {
  my($self,$idx) = @_;

  $self->{lb}->get($idx);
}

sub focus {
  my($self) = @_;

  $self->{lb}->g_focus();
}

sub bind {
  my($self) = shift;

  $self->{lb}->g_bind(@_);
}

1;
