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

use CP::Cconst qw/:LENGTH :SMILIE :COLOUR/;
use CP::Global qw/:FUNC :OPT :WIN :PRO :SETL :MEDIA :XPM/;
use Tkx;
use CP::Fonts;
use CP::Cmsg;

our %medias;

our %Fonts = (
  Comment   => {qw/size 16 weight normal slant roman  color #000000 family/ => "Times New Roman"},
  Highlight => {qw/size 16 weight normal slant italic color #000000 family/ => "Times New Roman"},
  Title     => {qw/size 16 weight bold   slant roman  color #700070 family/ => "Times New Roman"},
  Lyric     => {qw/size 16 weight normal slant roman  color #000000 family/ => "Arial"},
  Chord     => {qw/size 16 weight normal slant roman  color #700070 family/ => "Comic Sans MS"},
  Tab       => {qw/size 16 weight normal slant roman  color #000000 family/ => "Courier New"},
  Notes     => {qw/size  9 weight bold   slant roman  color #000000 family/ => "Tahoma"},
  SNotes    => {qw/size  5 weight bold   slant roman  color #000000 family/ => "Tahoma"},
  Header    => {qw/size  8 weight bold   slant roman  color #D00000 family/ => "Arial"},
  Words     => {qw/size  8 weight normal slant roman  color #00A000 family/ => "Times New Roman"},
);

our %BGs = (qw/commentBG   #E0E0E0
	       highlightBG #FFFF80
	       verseBG     #FFFFFF
	       chorusBG    #CDFFCD
	       bridgeBG    #FFFFFF
	       titleBG     #FFFFFF
	       tabBG       #FFFFFF/);

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
  my($proto,$typeref) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;

  if (-e "$Path->{Media}") {
    load() if (scalar keys %medias == 0);
  } else {
    %EditFont = (qw/family Arial size 14 weight normal slant roman
		 color #A00000 background #FFF8E0
		 brace #008000 bracesz 12
		 bracket #008000 bracketsz 12 bracketoff 2/);
    copy(\%Sizes, \%medias);
    foreach my $s (keys %Sizes) {
      copy(\%Fonts, \%{$medias{$s}});
      copy(\%BGs, \%{$medias{$s}});
    }
    save();
  }
  if ($$typeref eq '' || ! defined $medias{$$typeref}) {
    $$typeref = 'a4';
    $Opt->save();
  }
  copy($medias{$$typeref}, $self);
  $self;
}

sub default {
  my($self) = shift;

  copy(\%Fonts, $self);
  copy(\%BGs, $self);
  copy($Sizes{$Opt->{Media}}, $self);
}

sub list { sort keys %medias }

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
}

sub change {
  my($self,$newref) = @_;

  if (! defined $medias{$$newref}) {
    message(SAD, "Media definiton for $$newref does not exist.\nMedia type changed to: a4");
    $$newref = 'a4';
  }
  copy(\%{$medias{$$newref}}, $self);
  CP::Win::TButtonBGset();
}

sub load {
  unless (do "$Path->{Media}") {
    errorPrint("Load '$Path->{Media}' failed: $@");
  } else {
    my $save = 0;
    foreach my $k (keys %medias) {
      # We need to do a quick check here in case any new font user is defined.
      foreach my $f (keys %Fonts) {
	if (! defined $medias{$k}{$f}) {
	  $medias{$k}{$f} = {};
	  copy(\%{$Fonts{$f}}, \%{$medias{$k}{$f}});
	  $save++;
	}
      }
      foreach my $bg (keys %BGs) {
	if (! defined $medias{$k}{$bg} || $medias{$k}{$bg} eq '') {
	  $medias{$k}{$bg} = $BGs{$bg};
	  $save++;
	}
      }
      bless($medias{$k}, 'CP::Media');
    }
    my $sz = $EditFont{size} - 2;
    $EditFont{brace} = DRED if (! defined $EditFont{brace});
    $EditFont{bracesz} = $sz if (! defined $EditFont{bracesz});
    $EditFont{bracket} = DGREEN if (! defined $EditFont{bracket});
    $EditFont{bracketsz} = $sz if (! defined $EditFont{bracketsz});
    $EditFont{bracketoff} = 2 if (! defined $EditFont{bracketoff});
    $EditFont{background} = VLMWBG if (! defined $EditFont{background});
    save() if ($save);
  }
}

sub save {
  my($self,$type) = @_;

  my $OFH = openConfig("$Path->{Media}");
  if ($OFH == 0) {
    errorPrint("Failed to open '$Path->{Media}': $@");
    return(0);
  }

  print $OFH "# This is the default Editor font.\n";
  print $OFH "\%EditFont = (\n";
  foreach my $k (sort keys %EditFont) {
    if ($k eq 'size' || $k =~ /sz$/ || $k =~ /off$/) {
      print $OFH "  $k => $EditFont{$k},\n";
    } else {
      print $OFH "  $k => '$EditFont{$k}',\n";
    }
  }
  print $OFH ");\n\n";

  print $OFH "#\n# width, height and size values are in 'points' (72 'points' per inch)\n#\n";
  print $OFH "\%medias = (\n";
  foreach my $s (sort keys %medias) {
    next if ($s =~ /^tmp/);
    my $ref = ($s eq $type) ? $self : \%{$medias{$s}};
    print $OFH "  '$s' => {\n";
    print $OFH "    width  => ".$ref->{width}.",\n";
    print $OFH "    height => ".$ref->{height}.",\n";
    foreach my $bg (keys %BGs) {
      printf $OFH "    %-11s => '%s',\n", $bg, $ref->{$bg};
    }
    foreach my $f (keys %Fonts) {
      my $fp = \%{$ref->{$f}};
      printf $OFH ("    %-9s => {qw/size %-2d weight %-6s slant %-6s color %s family/ => '%s'},\n",
		  $f, $fp->{size}, $fp->{weight}, $fp->{slant}, $fp->{color}, $fp->{family});
    }
   print $OFH "  },\n";
  }
  print $OFH ");\n\n1;\n";
  close($OFH);
}

our($Done,%Edit,$Tmp,$TmpMedia);

sub edit {
  my($self) = shift;

  our($a,$b,$c,$d,$e,$f,$g,$h,$i,$j,$k,$m,$n,$o,$wstr,$hstr);

  my($top,$wt) = popWin(0, 'Media Editor');
  $top->g_wm_protocol(
    'WM_DELETE_WINDOW',
    sub {copy($medias{$Opt->{Media}}, $self); $top->g_destroy();});

  my $tf = $wt->new_ttk__frame(qw/-borderwidth 2 -relief ridge/);
  $tf->g_pack(qw/-side top -expand 1 -fill x/);

  my $bf = $wt->new_ttk__frame();
  $bf->g_pack(qw/-side top -expand 1 -fill x/);

  my $orgMedia = $TmpMedia = $Opt->{Media};
  $Tmp = new('CP::Media', \$TmpMedia);
  $Edit{NewName} = '';
  $Edit{U} = $Edit{NewU} = 'pt';
  $Edit{W} = $self->{width};
  $Edit{H} = $self->{height};
  changeUnits($self);

  $a = $tf->new_ttk__label(-text => "Media:");
  $b = $tf->new_ttk__button(
    -width => 20,
    -textvariable => \$TmpMedia,
    -style => 'Menu.TButton',
    -command => sub{
      my @lst = list();
      popMenu(\$TmpMedia, \&changeMedia, \@lst);
    });

  $c = $tf->new_ttk__button(qw/-text Delete -width 8 -command/ => sub{mdelete($self)} );

  $d = $tf->new_ttk__label(-text => "Width: ");
  $e = $tf->new_ttk__entry(qw/-width 6 -textvariable/ => \$Edit{W});
  $f = $tf->new_ttk__button(
    -width => 5,
    -textvariable => \$Edit{U},
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$Edit{NewU}, \&changeUnits, [qw/in mm pt/]);
    });

  $g = $tf->new_ttk__label(-text => "Height: ", -width => 10, -anchor => 'e');
  $h = $tf->new_ttk__entry(qw/-width 6 -textvariable/ => \$Edit{H});
  $i = $tf->new_ttk__button(
    -width => 5,
    -textvariable => \$Edit{U},
    -style => 'Menu.TButton',
    -command => sub{
      popMenu(\$Edit{NewU}, \&changeUnits, [qw/in mm pt/]);
    });

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

  ($bf->new_ttk__button(
     -text => "Cancel",
     -command => sub{$Done = "Cancel";},
      ))->g_grid(qw/-row 0 -column 0 -sticky w -padx 40/, -pady => [4,2]);

  ($bf->new_ttk__button(
     -text => "OK",
     -command => sub{$Done = "OK";},
      ))->g_grid(qw/-row 0 -column 1 -sticky e -padx 40/, -pady => [4,2]);

  Tkx::vwait(\$Done);
  if ($Done eq "OK") {
    $Opt->{Media} = $TmpMedia;
    change($Media, \$Opt->{Media});
    $Media->{width} = $Edit{W};
    $Media->{height} = $Edit{H};
    message(SMILE, "Changes have been made but not saved.");
  } else {
    $Opt->{Media} = $orgMedia;
    change($Media, \$Opt->{Media});
  }
  $top->g_destroy();
  $Done;
}

sub changeMedia {
  change($Tmp, \$TmpMedia);
  $Edit{U} = $Edit{NewU} = 'pt';
  $Edit{W} = $Tmp->{width};
  $Edit{H} = $Tmp->{height};
  changeUnits();
}

sub changeUnits {
  my $newu = $Edit{NewU};
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
  if (CP::Cmsg::msgYesNo("Do you really want to\ndelete Media: $TmpMedia") eq "Yes") {
    delete($medias{$TmpMedia});
    $TmpMedia = (list())[0];
    changeMedia($Tmp, \$TmpMedia);
    save($Tmp, $TmpMedia);
  }
}

sub mnew {
  my($self) = shift;

  my $nn = $Edit{NewName};
  if ($nn ne '') {
    if (defined $medias{$nn}) {
      message(SAD, "Media type '$nn' already exists!");
    } else {
      $medias{$nn} = {};
      copy(\%{$medias{a4}}, \%{$medias{$nn}});
      $TmpMedia = $nn;
      changeMedia($Tmp, \$TmpMedia);
      save($Tmp, $TmpMedia);
    }
  }
}

sub mrename {
  my $nn = $Edit{NewName};
  if ($nn ne '') {
    if (defined $medias{$nn}) {
      message(SAD, "Media type '$nn' already exists!");
    } else {
      $medias{$nn} = {};
      copy($Tmp, \%{$medias{$nn}});
      delete($medias{$TmpMedia});
      my $onam = $TmpMedia;
      $TmpMedia = $nn;
      $Edit{NewName} = '';
      changeMedia($Tmp, \$TmpMedia);
      save($Tmp, $TmpMedia);
      # Now we have to go through each Collection and change the
      # $Opts->{Media} entry if it matches the old name.
      $Opt->changeAll('Media', $onam, $nn);
    }
  }
}

sub pickClr {
  my($title,$fontp,$clr,$ent) = @_;

  $ColourEd = CP::FgBgEd->new() if (! defined $ColourEd);
  $ColourEd->title("$title Font");
  my($fg,$bg) = $ColourEd->Show($fontp->{color}, VLMWBG, FOREGRND);
  if ($fg ne '') {
    $fontp->{color} = $fg;
    $ent->m_configure(-fg => $fg);
    $clr->m_configure(-bg => $fg);
  }
}

1;
