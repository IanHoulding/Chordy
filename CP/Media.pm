package CP::Media;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

use strict;

use Tkx;
use CP::Cconst qw/:LENGTH :SMILIE :COLOUR/;
use CP::Global qw/:FUNC :OPT :WIN :PRO :SETL :MEDIA :XPM/;
use CP::Tab;
use CP::Pop qw/:POP :MENU/;
use CP::Fonts;
use CP::Cmsg;

our %AllMedia;

our %Fonts = (
  Comment   => {qw/size 16 weight normal slant roman  family/ => "Times New Roman"},
  Highlight => {qw/size 16 weight normal slant italic family/ => "Times New Roman"},
  Title     => {qw/size 16 weight bold   slant roman  family/ => "Times New Roman"},
  Lyric     => {qw/size 16 weight normal slant roman  family/ => "Arial"},
  Chord     => {qw/size 16 weight normal slant roman  family/ => "Comic Sans MS"},
  Tab       => {qw/size 16 weight normal slant roman  family/ => "Courier New"},
  Label     => {qw/size 16 weight normal slant roman  family/ => "Times New Roman"},
  Notes     => {qw/size  9 weight bold   slant roman  family/ => "Tahoma"},
  SNotes    => {qw/size  5 weight bold   slant roman  family/ => "Tahoma"},
  Header    => {qw/size  8 weight bold   slant roman  family/ => "Arial"},
  Words     => {qw/size  8 weight normal slant roman  family/ => "Times New Roman"},
);

# Sizes are all stored in pt
our %Sizes = (
  'a3'           => {qw/width 842 height 1190/},
  'a4'           => {qw/width 595 height  842/}, # Default
  'a5'           => {qw/width 421 height  595/},
  'a6'           => {qw/width 297 height  421/},
  'b4'           => {qw/width 707 height 1000/},
  'b5'           => {qw/width 500 height  707/},
  'b6'           => {qw/width 353 height  500/},
  'iPad'         => {qw/width 420 height  560/},
  'iPadPro'      => {qw/width 560 height  745/},
  'letter'       => {qw/width 612 height  792/},
  'tabloid'      => {qw/width 792 height 1224/},
  'legal'        => {qw/width 612 height 1008/},
  'executive'    => {qw/width 522 height  756/},
  'HANSpad 13.3' => {qw/width 468 height  814/},
  'Samsung 10.1' => {qw/width 383 height  615/},
  'Samsung 12.2' => {qw/width 465 height  746/},
);

sub new {
  my($proto,$type) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;

  my $type = $Opt->{Media};
  if (-e "$Path->{Media}") {
    load() if (scalar keys %AllMedia == 0);
  } else {
    %EditFont = (qw/family Arial size 14 weight normal slant roman
		 brace #008000 bracesz 12
		 bracket #008000 bracketsz 12 bracketoff 2/);
    copy(\%Sizes, \%AllMedia);
    foreach my $s (keys %Sizes) {
      copy(\%Fonts, \%{$AllMedia{$s}});
    }
    save();
  }
  if ($type eq '' || ! defined $AllMedia{$type}) {
    $type = $Opt->{Media} = 'a4';
    $Opt->saveOne('Media');
  }
  $self = $AllMedia{$type};
  if (defined $EditFont{color}) {
    # We've got all the FG/BG colours defined in Media.cfg
    # and we need to transfer them to the Options file.
    foreach my $b (qw/Bridge Chorus Comment Editor Highlight Tab Title Verse/) {
      $Opt->{'BG'.$b} = $self->{lc($b).'BG'};
    }
    $Opt->{BGEditor} = $EditFont{background};
    foreach my $f (qw/Chord Comment Header Highlight Label Lyric Notes SNotes Tab Title Words/) {
      $Opt->{'FG'.$f} = $self->{$f}{color};
    }
    $Opt->{FGEditor} = $EditFont{color};
    save();
    $Opt->save();
  }
  $self;
}

sub default {
  my($self) = shift;

  copy(\%Fonts, $self);
#  copy(\%BGs, $self);
  copy($Sizes{$Opt->{Media}}, $self);
}

sub list {
  my @lst = sort keys %AllMedia;
  \@lst;
}

sub copy {
  my($src,$dst) = @_;

  foreach my $k (keys %{$src}) {
    next if ($k =~ /^tmp/);
    if (ref($src->{$k}) eq 'HASH') {
      foreach my $kf (keys %{$src->{$k}}) {
	$dst->{$k}{$kf} = $src->{$k}{$kf};
      }
    } else {
      $dst->{$k} = $src->{$k};
    }
  }
  bless $dst, 'CP::Media';
  $dst;
}

sub change {
  my($self,$new) = @_;

  if (! defined $AllMedia{$new}) {
    message(SAD, "Media definiton for $new does not exist.\nMedia type changed to: a4");
    $new = 'a4';
  }
  $self = new('CP::Media', $new);
  CP::Win::TButtonBGset();
  $self;
}

sub load {
  our %medias;
  unless (do "$Path->{Media}") {
    errorPrint("Load '$Path->{Media}' failed: $@");
  } else {
    my $save = 0;
    foreach my $k (keys %medias) {
      copy(\%{$medias{$k}}, \%{$AllMedia{$k}});
      # We need to do a quick check here in case any new Font entry is defined.
      foreach my $f (keys %Fonts) {
	if (! defined $AllMedia{$k}{$f}) {
	  $AllMedia{$k}{$f} = {};
	  copy(\%{$Fonts{$f}}, \%{$AllMedia{$k}{$f}});
	  $save++;
	}
      }
#      foreach my $bg (keys %BGs) {
#	if (! defined $AllMedia{$k}{$bg} || $AllMedia{$k}{$bg} eq '') {
#	  $AllMedia{$k}{$bg} = $BGs{$bg};
#	  $save++;
#	}
#      }
      bless($AllMedia{$k}, 'CP::Media');
    }
    my $sz = $EditFont{size} - 2;
    $EditFont{brace} = DRED if (! defined $EditFont{brace});
    $EditFont{bracesz} = $sz if (! defined $EditFont{bracesz});
    $EditFont{bracket} = DGREEN if (! defined $EditFont{bracket});
    $EditFont{bracketsz} = $sz if (! defined $EditFont{bracketsz});
    $EditFont{bracketoff} = 2 if (! defined $EditFont{bracketoff});
#    $EditFont{background} = VLMWBG if (! defined $EditFont{background});
    save() if ($save);
  }
}

sub save {
  my $OFH = openConfig("$Path->{Media}");
  if ($OFH == 0) {
    errorPrint("Failed to open '$Path->{Media}': $@");
    return(0);
  }

  print $OFH "# This is the default Editor font.\n";
  print $OFH "\%EditFont = (\n";
  foreach my $k (qw/brace bracesz bracket bracketoff bracketsz family size slant weight/) {
    if ($k eq 'size' || $k =~ /sz$/ || $k =~ /off$/) {
      print $OFH "  $k => $EditFont{$k},\n";
    } else {
      print $OFH "  $k => '$EditFont{$k}',\n";
    }
  }
  print $OFH ");\n\n";

  print $OFH "#\n# width, height and size values are in 'points' (72 'points' per inch)\n#\n";
  print $OFH "\%medias = (\n";
  foreach my $s (sort keys %AllMedia) {
    next if ($s =~ /^tmp/);
    my $ref = \%{$AllMedia{$s}};
    print $OFH "  '$s' => {\n";
    print $OFH "    width  => ".$ref->{width}.",\n";
    print $OFH "    height => ".$ref->{height}.",\n";
    foreach my $f (keys %Fonts) {
      my $fp = \%{$ref->{$f}};
      printf $OFH ("    %-9s => {qw/size %-2d weight %-6s slant %-6s family/ => '%s'},\n",
		  $f, $fp->{size}, $fp->{weight}, $fp->{slant}, $fp->{family});
    }
   print $OFH "  },\n";
  }
  print $OFH ");\n\n1;\n";
  close($OFH);
}

our(%Edit,$Tmp);

sub edit {
  my($self) = shift;

  our($a,$b,$c,$d,$e,$f,$g,$h,$i,$j,$k,$m,$n,$o,$newu,$wstr,$hstr);

  my $pop = CP::Pop->new(0, '.me', 'Media Editor');
  return if ($pop eq '');
  my($top,$wt) = ($pop->{top}, $pop->{frame});

  my $orgM = $Edit{Media} = $Opt->{Media};
  $top->g_wm_protocol(
    'WM_DELETE_WINDOW',
    sub {copy($AllMedia{$Opt->{Media}}, $self); $pop->popDestroy();});

  my $tf = $wt->new_ttk__frame(qw/-borderwidth 2 -relief ridge/);
  $tf->g_pack(qw/-side top -expand 1 -fill x/);

  my $bf = $wt->new_ttk__frame();
  $bf->g_pack(qw/-side top -expand 1 -fill x/);

  $Tmp = {};
  bless $Tmp, 'CP::Media';
  $Tmp = copy($self, $Tmp);
  $Edit{NewName} = '';
  $Edit{W} = $self->{width};
  $Edit{H} = $self->{height};
  $Edit{U} = $newu = 'pt';

  $a = $tf->new_ttk__label(-text => "Media:");
  $b = popButton($tf,
		 \$Edit{Media},
		 \&changeMedia,
		 sub{list()},
		 -width => 20,
		 -style => 'Menu.TButton',
	);

  $c = $tf->new_ttk__button(qw/-text Delete -width 8 -command/ => \&mdelete );

  $d = $tf->new_ttk__label(-text => "Width: ");
  $e = $tf->new_ttk__entry(qw/-width 6 -textvariable/ => \$Edit{W});
  $f = popButton($tf,
		 \$newu,
		 sub{changeUnits($newu)},
		 [qw/in mm pt/],
		 -width => 5,
		 -style => 'Menu.TButton',
	);

  $g = $tf->new_ttk__label(-text => "Height: ", -width => 10, -anchor => 'e');
  $h = $tf->new_ttk__entry(qw/-width 6 -textvariable/ => \$Edit{H});
  $i = popButton($tf,
		 \$newu,
		 sub{changeUnits($newu)},
		 [qw/in mm pt/],
		 -width => 5,
		 -style => 'Menu.TButton',
	);

  $j = $tf->new_ttk__separator(qw/-orient horizontal/);

  $k = $tf->new_ttk__label(-text => "New Media Name: ");
  $m = $tf->new_ttk__entry(qw/-width 16 -textvariable/ => \$Edit{NewName});

  $n = $tf->new_ttk__button(qw/-text New -width 5 -command/ => sub{mnew($self)} );
  $o = $tf->new_ttk__button(qw/-text Rename -width 8 -command/ => sub{mrename($self)} );

  $a->g_grid(qw/-row 0 -column 0 -sticky e/);
  $b->g_grid(qw/-row 0 -column 1 -sticky w -columnspan 3/);
  $c->g_grid(qw/-row 0 -column 4 -columnspan 2 -pady 4/);

  $d->g_grid(qw/-row 1 -column 0 -sticky e/);
  $e->g_grid(qw/-row 1 -column 1 -sticky we/);
  $f->g_grid(qw/-row 1 -column 2 -sticky w -padx 4/);
  $g->g_grid(qw/-row 1 -column 3 -sticky e/);
  $h->g_grid(qw/-row 1 -column 4 -sticky we/);
  $i->g_grid(qw/-row 1 -column 5 -sticky w -padx 4/);

  $j->g_grid(qw/-row 2 -column 0 -sticky we -columnspan 6 -pady 4/);

  $k->g_grid(qw/-row 3 -column 0 -sticky e/, -pady => [0,4]);
  $m->g_grid(qw/-row 3 -column 1 -columnspan 2/, -pady => [0,4]);
  $n->g_grid(qw/-row 3 -column 3/, -pady => [0,4]);
  $o->g_grid(qw/-row 3 -column 4 -sticky w -columnspan 2/, -pady => [0,4]);

  our $done = '';
  ($bf->new_ttk__button(
     -text => "Cancel",
     -command => sub{$done = "Cancel";},
      ))->g_grid(qw/-row 0 -column 0 -sticky w -padx 40/, -pady => [4,2]);

  ($bf->new_ttk__button(
     -text => "OK",
     -command => sub{$done = "OK";},
      ))->g_grid(qw/-row 0 -column 1 -sticky e -padx 40/, -pady => [4,2]);

  Tkx::vwait(\$done);
  if ($done eq "OK") {
    changeUnits('pt');
    $Tmp->{width} = $Edit{W};
    $Tmp->{height} = $Edit{H};
    copy($Tmp, $AllMedia{$Edit{Media}});
    if ($Edit{Media} ne $Opt->{Media}) {
      $Opt->{Media} = $Edit{Media};
      $Media = change($Media, $Opt->{Media});
      $Opt->saveOne('Media');
    }
    save();
  } else {
    $Media = change($Media, $Opt->{Media});
  }
  $pop->popDestroy();
  $done;
}

sub changeMedia {
  copy($AllMedia{$Edit{Media}}, $Tmp);
  $Edit{W} = $Tmp->{width};
  $Edit{H} = $Tmp->{height};
  $Edit{U} = 'pt';
  changeUnits('pt');
}

sub changeUnits {
  my($newu) = shift;

  my $w = $Edit{W};
  my $h = $Edit{H};
  # Convert from current units to points then to new units.
  if ($Edit{U} ne 'pt') {
    my $un = ($Edit{U} eq 'mm') ? MM : IN;
    $w = int($w / $un);
    $h = int($h / $un);
  }
  # Now in points ..
  if ($newu ne 'pt') {
    my $un = ($newu eq 'mm') ? MM : IN;
    $w *= $un;
    $h *= $un;
    if ($newu eq 'mm') {
      $w = int($w * 10) / 10;
      $h = int($h * 10) / 10;
    } else {
      $w = int($w * 100) / 100;
      $h = int($h * 100) / 100;
    }
  }
  $Edit{W} = $w;
  $Edit{H} = $h;
  $Edit{U} = $newu;
}

sub mdelete {
  if (CP::Cmsg::msgYesNo("Do you really want to\ndelete Media: $Edit{Media}") eq "Yes") {
    delete($AllMedia{$Edit{Media}});
    if ($Edit{Media} eq $Opt->{Media}) {
      $Opt->{Media} = $Edit{Media} = (list())->[0];
    }
    changeMedia();
    save();
  }
}

sub mnew {
  my($self) = shift;

  my $nn = $Edit{NewName};
  if ($nn ne '') {
    if (defined $AllMedia{$nn}) {
      message(SAD, "Media type '$nn' already exists!");
    } else {
      $AllMedia{$nn} = {};
      copy(\%{$AllMedia{a4}}, \%{$AllMedia{$nn}});
      $Edit{Media} = $nn;
      changeMedia();
      save();
    }
  }
}

sub mrename {
  my $nn = $Edit{NewName};
  if ($nn ne '') {
    if (defined $AllMedia{$nn}) {
      message(SAD, "Media type '$nn' already exists!");
    } else {
      $AllMedia{$nn} = {};
      copy($Tmp, \%{$AllMedia{$nn}});
      delete($AllMedia{$Edit{Media}});
      my $onam = $Edit{Media};
      $Edit{Media} = $nn;
      $Edit{NewName} = '';
      changeMedia();
      save();
      # Now we have to go through each Collection and change the
      # $Opt->{Media} entry if it matches the old name.
      $Opt->changeAll('Media', $onam, $nn);
      $Opt->{Media} = $nn;
    }
  }
}

#sub pickClr {
#  my($title,$fontp,$clr,$ent) = @_;
#
#  CP::FgBgEd->new("$title Font");
#  my($fg,$bg) = $ColourEd->Show($fontp->{color}, VLMWBG, '', FOREGRND);
#  if ($fg ne '') {
#    $fontp->{color} = $fg;
#    $ent->m_configure(-fg => $fg);
#    $clr->m_configure(-bg => $fg);
#  }
#}

1;
