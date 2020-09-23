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
  $MW->g_wm_protocol('WM_DELETE_WINDOW' => sub{$MW->g_destroy()}); 
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
  $MW->g_wm_title(shift);
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

  Tkx::ttk__style_configure('TFrame',
			    -highlightthickness => 0,
			    -borderwidth => 0,
			    -activeborderwidth => 0,
			    -selectborderwidth => 0);
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

  Tkx::ttk__style_configure('TCanvas',
			    -highlightthickness => 0,
			    -borderwidth => 0,
			    -selectborderwidth => 0);

  Tkx::ttk__style_configure('TText', qw/-highlightthickness 0/);

  Tkx::ttk__style_configure('TNotebook.Tab',
			    -font => "BTkDefaultFont");

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
  Tkx::ttk__style_configure("List.TButton",
			    -foreground => $Opt->{ListFG},
			    -background => $Opt->{ListBG});
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

  Tkx::ttk__style_configure('TCheckbutton',
			    -highlightthickness => 0,
			    -foreground => bFG);
  Tkx::ttk__style_configure('Pop.TCheckbutton', -background => POPBG);
  Tkx::ttk__style_configure('NM.TCheckbutton',
			    -indicatormargin => [0,0,0,0]);
  Tkx::ttk__style_configure('Wh.TCheckbutton',
			    -background => WHITE,
			    -indicatormargin => [0,0,0,0]);

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

  Tkx::ttk__style_configure('TScrollbar',
			    -relief => 'raised',
			    -borderwidth => 1);

  Tkx::ttk__style_configure('Red.Horizontal.TScale',   -troughcolor => 'red');
  Tkx::ttk__style_configure('Green.Horizontal.TScale', -troughcolor => 'green');
  Tkx::ttk__style_configure('Blue.Horizontal.TScale',  -troughcolor => 'blue');
}

sub TButtonBGset {
  my($media) = shift;

  $media = $Media if (! defined $media);
  foreach my $h (qw/comment highlight title verse chorus bridge tab/) {
    Tkx::ttk__style_configure(ucfirst($h).".BG.TButton", -background => $media->{$h."BG"});
  }
}

sub TLabelBGset {
  my($media) = shift;

  $media = $Media if (! defined $media);
  foreach my $h (qw/comment highlight title chord lyric tab/) {
    my $bg = ($h =~ /cho|lyr/) ? $media->{verseBG} : $media->{"$h.BG"};
    Tkx::ttk__style_configure(ucfirst($h).".Font.TLabel", -background => $media->{"$h.BG"});
  }
}

sub PBclr {
  my($fg,$bg) = FgBgClr("Push Button", 'TButton');
  if ($fg ne '') {
    $Opt->{PushFG} = $fg;
    $Opt->save();
  }
  if ($bg ne '') {
    $Opt->{PushBG} = $bg;
    $Opt->save();
  }
}

sub MBclr {
  my($fg,$bg) = FgBgClr("Menu Button", 'Menu.TButton');
  if ($fg ne '') {
    $Opt->{MenuFG} = $fg;
    $Opt->save();
  }
  if ($bg ne '') {
    $Opt->{MenuBG} = $bg;
    $Opt->save();
  }
}

sub ENTclr {
  my($fg,$bg) = FgBgClr("Entry Box", 'Ent.TButton');
  if ($fg ne '') {
    $Opt->{EntryFG} = $fg;
    $Opt->save();
  }
  if ($bg ne '') {
    $Opt->{EntryBG} = $bg;
    $Opt->save();
  }
  Tkx::ttk__style_configure('TEntry', -fieldforeground => $Opt->{EntryFG});
  Tkx::ttk__style_configure('TEntry', -fieldbackground => $Opt->{EntryBG});
}

sub MSGclr {
  my($fg,$bg) = FgBgClr("Message Pop-Up", 'Msg.TButton');
  if ($fg ne '') {
    $Opt->{PopFG} = $fg;
    $Opt->save();
  }
  if ($bg ne '') {
    $Opt->{PopBG} = $bg;
    $Opt->save();
  }
  Tkx::ttk__style_configure('Pop.TLabel', -foreground => $Opt->{PopFG});
  Tkx::ttk__style_configure('Pop.TLabel', -background => $Opt->{PopBG});
  Tkx::ttk__style_configure('Pop.TFrame', -background => $Opt->{PopBG});
}

sub FgBgClr {
  my($title,$style) = @_;

  my $fg = Tkx::ttk__style_lookup($style, -foreground);
  my $bg = Tkx::ttk__style_lookup($style, -background);
  CP::FgBgEd->new("$title Colour");
  my($nfg,$nbg) = $ColourEd->Show($fg, $bg, (FOREGRND|BACKGRND));
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

  my($fg,$bg);
  if (! defined $clr) {
    CP::FgBgEd->new("Window Background");
    $fg = Tkx::ttk__style_lookup('TLabelframe.Label', -foreground);
    $bg = Tkx::ttk__style_lookup('TFrame', -background);
    $ColourEd->{fgcolor} = $fg;
    $ColourEd->{bgcolor} = $bg;
    $ColourEd->{colorop} = BACKGRND;
    (my $x,$clr) = $ColourEd->Show($fg, $bg, BACKGRND);
  } else {
    $bg = 'x';
  }
  if ($clr ne '' && $clr ne $bg) {
    foreach (qw/TFrame Win.TButton TCheckbutton TRadiobutton TLabel TLabelframe TLabelframe.Label/) {
      Tkx::ttk__style_configure($_, -background => $clr);
    }
    $Opt->{WinBG} = $clr;
  }
}

sub defLook {
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

sub newLook {
  Tkx::ttk__style_configure('TEntry', -fieldforeground => $Opt->{EntryFG});
  Tkx::ttk__style_configure('TEntry', -fieldbackground => $Opt->{EntryBG});
  CP::List::background();
  Tkx::ttk__style_configure("Menu.TButton", -foreground => $Opt->{MenuFG});
  Tkx::ttk__style_configure("Menu.TButton", -background => $Opt->{MenuBG});
  Tkx::ttk__style_configure("TButton", -foreground => $Opt->{PushFG});
  Tkx::ttk__style_configure("TButton", -background => $Opt->{PushBG});
  BGclr(MWBG);
}

sub defButtons {
  my($wid,$str,$save,$load,$reset) = @_;

  my $sa = $wid->new_ttk__button(
    -text => " Save as Default $str ",
    -style => 'Green.TButton',
    -command => $save);

  my $lo = $wid->new_ttk__button(
    -text => " Load Default $str ",
    -style => 'Green.TButton',
    -command => $load);

  my $re = $wid->new_ttk__button(
    -text => " Reset $str to Default ",
    -style => 'Red.TButton',
    -command => $reset);

  $sa->g_pack(qw/-side left -padx/ => [10,6]);
  $lo->g_pack(qw/-side left -padx/ => [6,0]);
  $re->g_pack(qw/-side right -padx/ => [6,10]);
}

1;
