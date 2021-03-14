package CP::Win;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018/19 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

use strict;
use warnings;

use CP::Cconst qw/:LENGTH :TEXT :SHFL :INDEX :PDF :BROWSE :SMILIE :COLOUR/;
use CP::Global qw(:FUNC :OPT :PRO :XPM :WIN :MEDIA);
use CP::FgBgEd;
use CP::List;
use CP::Opt;
use CP::Cmsg;
use CP::Fonts;

#
# This is all the GUI stuff. Just kept in a separate file
# to make editing/managing easier.
#

sub init {
  $MW = Tkx::widget->new(".");
  $MW->g_wm_withdraw();
  Tkx::update();
  foreach (Tkx::SplitList(Tkx::ttk__style_theme_names())) {
    if ($_ eq 'clam') {
      Tkx::ttk__style_theme_use('clam');
      last;
    }
  }

  MWoptions();

  makeImage('blank', \%XPM); # used by Editor.pm, FgBgEd.pm and Fonts.pm
}

sub title {
  $MW->g_wm_title("Chordy | Collection: ".$Collection->{name}." | Media: ".$Opt->{Media});
}

sub MWoptions {
  Tkx::option_add("*tearOff", 0);
  #
  # Proportional Fonts - Arial by default.
  # These are the fonts used by buttons, labels etc.
  #
  my $w = ($Opt->{UseBold}) ? 'bold' : 'normal';
  Tkx::font_configure('TkDefaultFont', -weight => $w);
  my %list = (Tkx::SplitList(Tkx::font_actual("TkDefaultFont")));
  $list{'-weight'} = 'bold';
  Tkx::font_create("BTkDefaultFont", %list);
  $list{'-weight'} = 'normal';
  Tkx::font_create("NTkDefaultFont", %list);
  $list{'-size'} -= 3;
  $list{'-weight'} = 'bold';
  Tkx::font_create("STkDefaultFont", %list);

  BGclr($Opt->{WinBG});

  Tkx::ttk__style_configure('TNotebook.Tab',
			    -font => "BTkDefaultFont",
			    -background => LGREY,
			    -foreground => $Opt->{TabFG});
  Tkx::ttk__style_map('TNotebook.Tab',
		      -background => "selected ".$Opt->{TabBG}." active ".$Opt->{TabAC});

  Tkx::ttk__style_configure('TFrame',
			    -highlightthickness => 0,
			    -borderwidth => 0,
			    -activeborderwidth => 0,
			    -selectborderwidth => 0);

  Tkx::ttk__style_configure('PopMenu.TFrame',
			    -bordercolor => BLACK,
			    -background => $Opt->{MenuBG});
  Tkx::ttk__style_configure('PopMenu.TButton',
			    -padding => [8,0,8,0],
			    -anchor => 'w',
			    -highlightthickness => 0,
			    -borderwidth => 0,
			    -activeborderwidth => 0,
			    -selectborderwidth => 0,
			    -background => $Opt->{MenuBG},
			    -foreground => $Opt->{MenuFG});
  Tkx::ttk__style_map('PopMenu.TButton',
		      -background => "active #3830FF",
		      -foreground => "active #FFFFFF");
  Tkx::ttk__style_configure('PopShad.TFrame',
			    -borderwidth => 1,
			    -bordercolor => '#C8C8C8',
			    -relief => 'raised',
			    -background => '#B0B0B0');

  Tkx::ttk__style_configure('Pop.TFrame',
			    -background => $Opt->{PopBG});
  Tkx::ttk__style_configure('Wh.TFrame',
			    -background => WHITE);

  Tkx::ttk__style_configure('TLabelframe',
			    -labeloutside => 0,
			    -labelmargins => [8,0,8,0],
			    -relief => 'raised',
			    -bd => 2);
  Tkx::ttk__style_configure('TLabelframe.Label',
			    -font => "BTkDefaultFont",
			    -justify => 'center',
			    -foreground => MAGENT);

  Tkx::ttk__style_configure('Wh.TLabelframe', -background => WHITE);
  Tkx::ttk__style_configure('Wh.TLabelframe.Label', -background => WHITE);

  Tkx::ttk__style_configure('H.TSeparator', -background => BLACK);

  Tkx::ttk__style_configure('TCanvas',
			    -highlightthickness => 0,
			    -borderwidth => 0,
			    -selectborderwidth => 0);

  Tkx::ttk__style_configure('TText', qw/-highlightthickness 0/);

  Tkx::ttk__style_configure('Toolbutton',
			    -relief => 'raised',
			    -background => fBG,
			    -highlightbackground => 'red');
  Tkx::ttk__style_map('Toolbutton', -background => "selected ".mBG);

  Tkx::ttk__style_configure('TButton',
			    -foreground => $Opt->{PushFG},
			    -background => $Opt->{PushBG},
			    -relief => 'raised',
			    -borderwidth => [4,4,4,4],
			    -justify => 'center',
			    -activebackground => bACT,
			    -activeforeground => bFG,
			    -activeborderwidth => 0,
			    -highlightcolor => DGREY,
			    -disabledforeground => BLACK,
			    -highlightthickness => 0,
			    -selectborderwidth => 0,
			    -padding => [0,0,0,0]);

  Tkx::ttk__style_configure('SF.TButton',
			    -borderwidth => [0,0,0,0],
			    -font => 'STkDefaultFont');

  Tkx::ttk__style_configure('Red.TButton',   -foreground => 'darkred');
  Tkx::ttk__style_configure('Green.TButton', -foreground => 'darkgreen');
  Tkx::ttk__style_configure('Blue.TButton',  -foreground => 'darkblue');

  Tkx::ttk__style_configure("Menu.TButton",
			    -foreground => $Opt->{MenuFG},
			    -background => $Opt->{MenuBG});
  Tkx::ttk__style_configure("Ent.TButton",
			    -foreground => $Opt->{EntryFG},
			    -background => $Opt->{EntryBG});
  Tkx::ttk__style_configure("Msg.TButton",
			    -foreground => $Opt->{PopFG},
			    -background => $Opt->{PopBG});
  Tkx::ttk__style_configure("PDF.TButton",
			    -background => $Opt->{PageBG});
  Tkx::ttk__style_configure("Chord.TButton",
			    -background => PBLUE);

  TButtonBGset();

  Tkx::ttk__style_configure('My.TCheckbutton',
			    -indicatorsize => 0,
			    -indicatormargin => [0,0,0,0],
			    -relief => 'flat',
			    -borderwidth => 0,
			    -highlightthickness => 0,
			    -padding => 0,
			    -foreground => bFG);
  Tkx::ttk__style_configure('Wh.My.TCheckbutton', -background => WHITE);
  Tkx::ttk__style_configure('Pop.My.TCheckbutton',   -background => POPBG);

  Tkx::ttk__style_configure('TRadiobutton',
			    -activeforeground => BLACK,
			    -highlightthickness => 0);

  Tkx::ttk__style_configure('Fret.TRadiobutton', -background => fBG);

  Tkx::ttk__style_configure('TLabel', -foreground => bFG);

  Tkx::ttk__style_configure('Pop.TLabel',
			    -background => $Opt->{PopBG},
			    -foreground => $Opt->{PopFG});

  Tkx::ttk__style_configure('Wh.TLabel',
			    -background => WHITE,
			    -relief => 'solid',
			    -borderwidth => 0,
			    -selectborderwidth => 0,
			    -highlightthickness => 0,
			    -padding => [0,0,0,0]);

  Tkx::ttk__style_configure('YN.TLabel',
			    -background => SELECT,
			    -relief => 'ridge',
			    -borderwidth => 1,
			    -bordercolor => BLACK,
			    -selectborderwidth => 0,
			    -highlightthickness => 0,
			    -padding => [1,1,1,1]);

  Tkx::ttk__style_configure('YNnf.TLabel',
			    -font => "NTkDefaultFont",
			    -background => SELECT,
			    -relief => 'ridge',
			    -borderwidth => 1,
			    -bordercolor => BLACK,
			    -selectborderwidth => 0,
			    -highlightthickness => 0,
			    -padding => [1,1,1,1]);

  Tkx::ttk__style_configure('YNb.TLabel',
			    -font => "BTkDefaultFont",
			    -background => SELECT,
			    -relief => 'ridge',
			    -borderwidth => 1,
			    -bordercolor => BLACK,
			    -selectborderwidth => 0,
			    -highlightthickness => 0,
			    -padding => [1,1,1,1]);

  Tkx::ttk__style_configure('Font.TLabel',
			    -selectborderwidth  => 0,
			    -borderwidth => 1,
			    -highlightthickness => 0,
			    -bordercolor => BLACK,
			    -relief  => 'ridge',
			    -padding => [4,0,0,0]);
  TLabelBGset();

  Tkx::ttk__style_configure('TEntry',
			    -fieldforeground => $Opt->{EntryFG},
			    -fieldbackground => $Opt->{EntryBG},
			    -highlightcolor => DGREY,
			    -highlightthickness => 0,
			    -relief => 'sunken');
  Tkx::ttk__style_map('TEntry', -foreground => "disabled ".BROWN." readonly ".BROWN);
  Tkx::ttk__style_map('TEntry', -fieldbackground => "disabled ".LGREY." readonly ".LGREY);

  Tkx::ttk__style_configure("TSpinbox",
			    -foreground => $Opt->{MenuFG},
			    -arrowcolor => BLACK,
			    -fieldbackground => $Opt->{MenuBG},
			    -background => $Opt->{MenuBG});

  Tkx::ttk__style_configure('TScrollbar',
			    -relief => 'raised',
			    -borderwidth => 1);

  Tkx::ttk__style_configure('Red.Horizontal.TScale',   -troughcolor => 'red');
  Tkx::ttk__style_configure('Green.Horizontal.TScale', -troughcolor => 'green');
  Tkx::ttk__style_configure('Blue.Horizontal.TScale',  -troughcolor => 'blue');
}

sub TButtonBGset {
  foreach my $h (qw/Comment Highlight Title Verse Chorus Bridge Tab/) {
    Tkx::ttk__style_configure($h.".BG.TButton", -background => $Opt->{"BG$h"});
  }
  foreach my $h (qw/Comment Highlight/) {
    my $frst = substr($h, 0, 1);
    Tkx::ttk__style_configure($h.".BD.TButton",
			      -background => $Opt->{"BG".$h},
			      -bordercolor => $Opt->{$frst."borderColour"},);
  }
}

sub TLabelBGset {
  foreach my $h (qw/Comment Highlight Title Chord Lyric Tab/) {
    my $bg = ($h =~ /Cho|Lyr/) ? $Opt->{BGVerse} : $Opt->{"BG$h"};
    Tkx::ttk__style_configure($h.".Font.TLabel", -background => $bg);
  }
}

sub PBclr {
  my($fg,$bg) = FgBgClr("Push Button", 'TButton');
  my $save = 0;
  if ($fg ne '') {
    $Opt->{PushFG} = $fg;
    $save++;
  }
  if ($bg ne '') {
    $Opt->{PushBG} = $bg;
    $save++;
  }
  $Opt->save() if ($save);
}

sub MBclr {
  my($fg,$bg) = FgBgClr("Menu Button", 'Menu.TButton');
  my $save = 0;
  if ($fg ne '') {
    $Opt->{MenuFG} = $fg;
    $save++;
  }
  if ($bg ne '') {
    $Opt->{MenuBG} = $bg;
    $save++;
  }
  $Opt->save() if ($save);
}

sub ENTclr {
  my($fg,$bg) = FgBgClr("Entry Box", 'Ent.TButton');
  my $save = 0;
  if ($fg ne '') {
    $Opt->{EntryFG} = $fg;
    $save++;
  }
  if ($bg ne '') {
    $Opt->{EntryBG} = $bg;
    $save++;
  }
  $Opt->save() if ($save);
  Tkx::ttk__style_configure('TEntry', -fieldforeground => $Opt->{EntryFG});
  Tkx::ttk__style_configure('TEntry', -fieldbackground => $Opt->{EntryBG});
}

sub MSGclr {
  my($fg,$bg) = FgBgClr("Message Pop-Up", 'Msg.TButton');
  my $save = 0;
  if ($fg ne '') {
    $Opt->{PopFG} = $fg;
    $save++;
  }
  if ($bg ne '') {
    $Opt->{PopBG} = $bg;
    $save++;
  }
  $Opt->save() if ($save);
  Tkx::ttk__style_configure('Pop.TLabel', -foreground => $Opt->{PopFG});
  Tkx::ttk__style_configure('Pop.TLabel', -background => $Opt->{PopBG});
  Tkx::ttk__style_configure('Pop.TFrame', -background => $Opt->{PopBG});
}

sub FgBgClr {
  my($title,$style) = @_;

  my $fg = Tkx::ttk__style_lookup($style, -foreground);
  my $bg = Tkx::ttk__style_lookup($style, -background);
  CP::FgBgEd->new("$title Colour");
  my($nfg,$nbg) = $ColourEd->Show($fg, $bg, '', (FOREGRND|BACKGRND));
  if ($nfg ne '' && $nfg ne $fg) {
    Tkx::ttk__style_configure($style, -foreground => $nfg);
  }
  if ($nbg ne '' && $nbg ne $bg) {
    Tkx::ttk__style_configure($style, -background => $nbg);
  }
  ($nfg,$nbg);
}

sub BGclr {
  my($clr) = shift;

  my $fg = Tkx::ttk__style_lookup('TLabelframe.Label', -foreground);
  my $bg = Tkx::ttk__style_lookup('TFrame', -background);
  if (! defined $clr) {
    CP::FgBgEd->new("Window Background");
    (my $x,$clr) = $ColourEd->Show($fg, $bg, '', BACKGRND);
  }
  if ($clr ne '' && $clr ne $bg) {
    foreach (qw/TFrame Win.TButton TCheckbutton TRadiobutton TLabel TLabelframe TLabelframe.Label/) {
      Tkx::ttk__style_configure($_, -background => $clr);
    }
    $Opt->{WinBG} = $clr;
    $Opt->saveOne('WinBG');
  }
}

sub TABclr {
  my $save = 0;
  my $fg = $Opt->{TabFG};
  my $bg = $Opt->{TabBG};
  CP::FgBgEd->new("Window Background");
  my($nfg,$nbg) = $ColourEd->Show($fg, $bg, '', (FOREGRND|BACKGRND));
  if ($nfg ne '' && $nfg ne $fg) {
    Tkx::ttk__style_configure('TNotebook.Tab', -foreground => $nfg);
    $Opt->{TabFG} = $nfg;
    $save++;
  }
  if ($nbg ne '' && $nbg ne $bg) {
    $Opt->{TabBG} = $nbg;
    $save++;
    my $grey = 208;  # D0
    my($nr,$ng,$nb) = ($nbg =~ /\#(..)(..)(..)/);
    $nr = $grey - int(($grey - hex($nr)) / 2);
    $ng = $grey - int(($grey - hex($ng)) / 2);
    $nb = $grey - int(($grey - hex($nb)) / 2);
    $Opt->{TabAC} = sprintf "#%02x%02x%02x", $nr, $ng, $nb;
    Tkx::ttk__style_map('TNotebook.Tab',
			-background => "selected ".$nbg." active ".$Opt->{TabAC});
  }
  $Opt->save() if ($save);
}

sub defLook {
  if (msgYesNo("Are you sure you want to reset\nall Colours to their defaults?") eq 'Yes') {
    $Opt->{EntryFG} = BLACK;
    $Opt->{EntryBG} = WHITE;
    $Opt->{ListFG} = BLACK;
    $Opt->{ListBG} = WHITE;
    $Opt->{MenuFG} = bFG;
    $Opt->{MenuBG} = mBG;
    $Opt->{PushFG} = bFG;
    $Opt->{PushBG} = bBG;
    $Opt->{WinBG}  = MWBG;
    newLook();
    $Opt->save();
  }
}

sub newLook {
  Tkx::ttk__style_configure('TEntry', -fieldforeground => $Opt->{EntryFG});
  Tkx::ttk__style_configure('TEntry', -fieldbackground => $Opt->{EntryBG});
  Tkx::ttk__style_configure("Menu.TButton", -foreground => $Opt->{MenuFG});
  Tkx::ttk__style_configure("Menu.TButton", -background => $Opt->{MenuBG});
  Tkx::ttk__style_configure("TButton", -foreground => $Opt->{PushFG});
  Tkx::ttk__style_configure("TButton", -background => $Opt->{PushBG});
  BGclr($Opt->{WinBG});
  CP::List::background();
}

1;
