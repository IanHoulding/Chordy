package CP::Editor;

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
use CP::Cconst qw(:OS :LENGTH :PDF :MUSIC :TEXT :SHFL :INDEX :BROWSE :SMILIE :COLOUR);
use CP::Global qw/:FUNC :OPT :WIN :XPM :MEDIA :CHORD/;
use CP::Win;
use CP::Collection;
use CP::Cmnd;
use CP::Path;
use CP::Opt;
use CP::Swatch;
use CP::Media;
use CP::Cmsg;
use CP::List;
use CP::FgBgEd;
use CP::CHedit;
use CP::Fonts;
use CP::A2Crd;
use CP::HelpEd;
use FileHandle;
use File::Basename;

our $Ed = {};
our $Done;
our $helpWin = '';
our $TempPath = '';
our $TempFN = '';
our $Saved = 0;
our $ChordTag = 0;
our $Ctrl = 0;

sub new {
  my($class) = shift;

  if (ref($Ed) eq 'CP::Editor') {
    $Ed->{TxtWin}->delete('1.0', 'end');
    return();
  }
  bless $Ed, $class;
  $Ed->{Top} = '';
  $Ed->{FileName} = '';
  $Ed->{IgnCase} = 0;
  $Ed->{Tagged} = 0;
  $Ed->{TxtWin} = '';
  $Ed->{CntrLabel} = '';
  $Ed->{TotlLabel} = '';
  $Ed->{FindV} = '';
  $Ed->{RepV} = '';
  $Ed->{TaggedChord} = '';

  # Create MainWindow first to handle X11 options.
  if (defined $MW && Tkx::winfo_exists($MW)) {
    $Ed->{Top} = $MW->new_toplevel();
  } else {
    # Running stand-alone.
    CP::Global::init();
    $Collection = CP::Collection->new();
    $Path = CP::Path->new();
    $Cmnd = CP::Cmnd->new();
    $Opt = CP::Opt->new();
    $Media = CP::Media->new(\$Opt->{Media});
    $Swatches = CP::Swatch->new();

    fontSetup();

    CP::Win::init();
    $Ed->{Top} = $MW;
  }
  $Ed->{Top}->g_wm_withdraw();
  $Ed->{Top}->g_wm_protocol('WM_DELETE_WINDOW' => \&ExitCheck);

  makeImage("Eicon", \%XPM);
  $Ed->{Top}->g_wm_iconphoto("Eicon");

  $ColourEd = CP::FgBgEd->new() if (! defined $ColourEd);

  CP::CHedit::readFing('Guitar');
  CP::CHedit::mkChords();
  makeImage("sharp", \%CHRD);
  makeImage("flat",  \%CHRD);
  makeImage("minor", \%CHRD);

  ##############################################
  ## set up 2 frames to put everything into.
  ##   Left: chordpro_frame, chord_frame, dirtv_frame and counter_frame
  ##  Right: menu_frame and text_frame
  ##############################################

  my $mainFrame = $Ed->{Top}->new_ttk__frame(qw/-relief raised -borderwidth 2/);
  $mainFrame->g_pack(qw/-expand 1 -fill both/);

  my $leftF = $Ed->{leftFrame} = $mainFrame->new_ttk__frame(-padding => [4,4,2,4]);
  $leftF->g_pack(qw/-side left -expand 0 -fill y/);

  my $rightF = $mainFrame->new_ttk__frame(-padding => [0,4,0,0]);
  $rightF->g_pack(qw/-side right -expand 1 -fill both/);

  ########

  my $chord_frame = $leftF->new_ttk__labelframe(-text => " Chords ", -labelanchor => 'n');
  $chord_frame->g_pack(qw/-side top -fill x -anchor nw/);

  my $cfl = $chord_frame->new_ttk__frame();
  $cfl->g_pack(qw/-side left -anchor nw -padx 8 -pady 2/);
  foreach my $r (['bracket',   'braceColour', 'Colour', 0],
		 ['bracketsz', 'braceSize',   'Size',   7],
		 ['bracketoff','braceOffset', 'Offset', 0]) {
    my($img,$func,$desc,$pad) = @{$r};
    makeImage($img, \%XPM);
    my $br = $cfl->new_ttk__button(-image => $img, -command => [\&$func, $img]);
    $br->g_pack(qw/-side top/, -pady => $pad);
    balloon($br, 'Chord '.$desc);
  }

  my $cf = $chord_frame->new_ttk__frame();
  $cf->g_pack(qw/-side left -anchor nw/);
  chords($cf);

  my $dirtv_frame = $leftF->new_ttk__labelframe(-text => " Directives ", -labelanchor => 'n');
  $dirtv_frame->g_grid_anchor('n');
  $dirtv_frame->g_pack(qw/-side top -fill x -anchor n -pady 10/);
  directives($dirtv_frame);

  my $counter_frame = $leftF->new_ttk__frame(qw/-relief raised -borderwidth 2/, -padding => [4,0,4,0]);
  $counter_frame->g_pack(qw/-side bottom -fill x/);

  #########

  my $menu_frame = $rightF->new_ttk__frame(qw/-relief raised -borderwidth 2 -padding/ => [4,0,0,0]);
  $menu_frame->g_pack(qw/-side top -expand 0 -fill x/, -padx => [4,0]);
  quickButtons($menu_frame);

  my $text_frame = $rightF->new_ttk__frame();
  $text_frame->g_pack(qw/-side right -anchor n -expand 1 -fill both/, -padx => [4,0]);

  ##############################################
  ## now set up text window with contents.
  ##############################################
  ## autosizing is set up such that when the outside window is
  ## resized, the text box adjusts to fill everything else in.
  ## the text frame and the text window in the frame are both
  ## set up for autosizing.

  my $tw = $Ed->{TxtWin} = $text_frame->new_tk__text(
    -insertwidth => 2,
    -font => "\{$EditFont{family}\} $EditFont{size} $EditFont{weight} $EditFont{slant}",
    -relief => 'raised',
    -foreground => $EditFont{color},
    -background => $EditFont{background},
    -borderwidth => 2,
    -highlightthickness => 0,
    -selectborderwidth => 0,
    -exportselection => 'true',
    -selectbackground => SELECT,
    -selectforeground => BLACK,
    -wrap=> 'none',
    -spacing1 => 6,
    -undo => 1,
    -setgrid => 'true'); # use this for autosizing

  $tw->g_bind("<<Modified>>",  sub{Tkx::after(20, \&update_indicators)});
  $tw->g_bind("<KeyPress>",   [\&press,Tkx::Ev("%K")]);
  $tw->g_bind("<KeyRelease>", [sub{Tkx::after(20, [\&update_indicators,@_])},Tkx::Ev("%K")]);
  $tw->g_bind("<ButtonPress>", sub{Tkx::after(20, \&update_indicators)});
  if (OS eq 'aqua') {
    $tw->g_bind("<Command-v>", [\&clipPaste, 1]);
  } else {
    $tw->g_bind("<Control-v>", [\&clipPaste, 1]);
  }
  Tkx::clipboard_clear();

  my $sv = $text_frame->new_ttk__scrollbar(-orient => "vertical",   -command => [$tw, "yview"]);
  my $sh = $text_frame->new_ttk__scrollbar(-orient => "horizontal", -command => [$tw, "xview"]);

  $tw->configure(-yscrollcommand => [$sv, 'set']);
  $tw->configure(-xscrollcommand => [$sh, 'set']);

  $text_frame->g_grid_rowconfigure(0, -weight => 1);
  $text_frame->g_grid_columnconfigure(0, -weight => 1);

  $tw->g_grid(qw/-row 0 -column 0 -sticky nsew/);
  $sv->g_grid(qw/-row 0 -column 1 -sticky nsw/);
  $sh->g_grid(qw/-row 1 -column 0 -sticky new/);

  $tw->tag_configure('mysel', -background => SELECT);
  $tw->g_bind('<KeyRelease-[>' => \&chordstart);
  $tw->g_bind('<KeyRelease-]>' => \&chordend);
  $tw->g_bind('<KeyRelease-{>' => \&dirstart);
  $tw->g_bind('<KeyRelease-}>' => \&dirend);
#  $MW->g_bind('<Control-Left>'  => sub{Tkx::after(20, [\&moveChord, '-1c'])});
#  $MW->g_bind('<Control-Right>' => sub{Tkx::after(20, [\&moveChord, '+1c'])});
#  $tw->g_bind('<Control-Up>'    => sub{Tkx::after(20, [\&moveChord, '-1l'])});
#  $tw->g_bind('<Control-Down>'  => sub{Tkx::after(20, [\&moveChord, '+1l'])});
  $Ed->{chordstart} = '';
  $Ed->{dirstart} = '';

  $tw->tag_configure(
    'chord',
    -offset => $EditFont{bracketoff},
    -font => "\{$EditFont{family}\} $EditFont{bracketsz} $EditFont{weight} $EditFont{slant}",
    -foreground => $EditFont{bracket});
  $tw->tag_configure(
    'dirtv',
    -font => "\{$EditFont{family}\} $EditFont{bracesz} $EditFont{weight} $EditFont{slant}",
    -foreground => $EditFont{brace});

  ##############################################
  ## set up current line number display
  ##############################################

  $Ed->{CntrLabel} = $counter_frame->new_ttk__label(
    -text => 'line:  1   column:  0',
    -width => 20,
    -justify => 'center');
  $Ed->{CntrLabel}->g_grid(qw/-row 0 -column 0/, -pady => [4,2]);

  my $goto = '';
  my $gotob = $counter_frame->new_ttk__button(-text => 'Go To:', -width => 6, -command => sub{JumpTo($goto)});
  my $gotoe = $counter_frame->new_ttk__entry(-width => 6, -textvariable => \$goto);
  $gotob->g_grid(qw/-row 0 -column 1 -rowspan 2 -pady 2 -sticky e/, -padx => [20,2]);
  $gotoe->g_grid(qw/-row 0 -column 2 -rowspan 2 -pady 2 -sticky w/, -padx => [2,8]);

  CORE::state $helpWin = '';
  my $help = $counter_frame->new_ttk__button(
    -text => 'Help',
    -width => 5,
    -style => 'Green.TButton',
    -command => sub{$helpWin = CP::HelpEd::help($helpWin)} );
  $help->g_grid(qw/-row 0 -column 3 -rowspan 2 -padx 4 -sticky e/);
  $counter_frame->g_grid_columnconfigure(3, -weight => 1);

  $Ed->{TotlLabel} = $counter_frame->new_ttk__label(
    -text => 'total lines: 1',
    -justify => 'center');
  $Ed->{TotlLabel}->g_grid(qw/-row 1 -column 0/, -pady => [2,4]);

  Tkx::update();
}

sub chordstart {
  my($line,$col) = split(/\./, $Ed->{TxtWin}->index('insert'));
  $Ed->{chordstart} = $line.".".--$col;
}

sub chordend {
  if ((my $lc = $Ed->{chordstart}) ne '') {
    my($line,$col) = split(/\./, $lc);
    my($lend,$cend) = split(/\./, $Ed->{TxtWin}->index('insert'));
    if ($lend == $line) {
      $Ed->{TxtWin}->tag_add('chord', $lc, "$lend.$cend");  # defines the font used.
      $Ed->{TxtWin}->tag_add('CH_'.$ChordTag++, $lc, "$lend.$cend");
    }
    $Ed->{chordstart} = '';
  }
}

sub dirstart {
  my($line,$col) = split(/\./, $Ed->{TxtWin}->index('insert'));
  $Ed->{dirstart} = $line.".".--$col;
}

sub dirend {
  if ($Ed->{dirstart} ne '') {
    my($line,$col) = split(/\./, $Ed->{dirstart});
    my($lend,$cend) = split(/\./, $Ed->{TxtWin}->index('insert'));
    if ($lend == $line) {
      $Ed->{TxtWin}->tag_add('dirtv', $Ed->{dirstart}, "$lend.$cend");
    }
    $Ed->{dirstart} = '';
  }
}

# $fn MUST be a full path + filename.
# If the file exists, a copy is made and ALL edits are made to the copy.
# All 'Save's are also made to the copy and ONLY an 'Exit' with saves made
# will result in the copy being put back as the original. The original
# file will be incorporated into a numbered chain of backups.
sub Edit {
  my($fn,$unpck) = @_;

  $Done = '';
  $Saved = 0;
  new('CP::Editor');
  $TempPath = $Path->{Temp};

  if ($fn eq '') {
    $Ed->{FileName} = '';
    $Ed->{FilePath} = $Path->{Pro};
  } elsif (Open($fn) == 0) {
    return('');
  }

  update_indicators();
  $Ed->{leftFrame}->g_pack_forget() if (defined $unpck);
  $Ed->{Top}->g_wm_deiconify();
  $Ed->{Top}->g_raise();
  $Ed->{TxtWin}->mark_set('insert', '1.0');
  $Ed->{TxtWin}->g_focus();

 WAIT:
  Tkx::tkwait_variable(\$Done);

  if ($Done eq 'Cancel') {
    Tkx::update();
    $Ed->{TxtWin}->g_focus();
    $Done = '';
    goto WAIT;
  }
  if ($Ed->{Top} eq $MW) {
    # Running stand-alone
    $Ed->{Top}->g_destroy();
    exit(0);
  }
  $Ed->{leftFrame}->g_pack(qw/-side left -expand 0 -fill y/) if (defined $unpck);
  $Ed->{Top}->g_wm_withdraw();
  Tkx::update_idletasks();
  return($Done);
}

###################
###################
##               ##
##  SUBROUTINES  ##
##               ##
###################
###################

###################################################
## create all the quick access buttons plus images
###################################################

sub quickButtons {
  my($frame) = shift;

  my %but = ();
  foreach my $b (
    ['open',       'fileOpen',    'Open File'],
    ['new',        'fileNew',     'New File'],
    ['save',       'fileSave',    'Save File'],
    ['saveAs',     'fileSaveAs',  'Save File As'],
    ['close',      'Close',       'Close File'],
    ['exit',       'ExitCheck',   'Exit'],
    ['text',       'editFont',    'Editor Font'],
    ['textsize',   'fontUpdt',    'Font Size'],
    ['textfg',     'fgSet',       'Font Colour'],
    ['textbg',     'bgSet',       'Editor Background'],
    ['cut',        'clipCut',     'Cut'],
    ['copy',       'clipCopy',    'Copy'],
    ['paste',      'clipPaste',   'Paste'],
    ['include',    'fileInclude', 'Include'],
    ['wrap',       'wrapText',    'Wrap'],
    ['SelectAll',  'selectAll',   'Select All'],
    ['Unselect',   'unselectAll', 'Deselect All'],
    ['Undo',       'un_do',       'Undo'],
    ['Redo',       're_do',       'Redo'],
    ['settags',    'setTags',     'Reformat Buffer'],
    ['chordL',     'MC -1c',  'Move Chord Left'],
    ['chordR',     'MC +1c',  'Move Chord Right'],
    ['chordU',     'MC -1l',  'Move Chord Up'],
    ['chordD',     'MC +1l',  'Move Chord Down'],
    ['Find',       'Find',        'Find'],
    ['FindNext',   'FindNext',    'Find next'],
    ['FindPrev',   'FindPrev',    'Find prev'],
    ['Replace',    'FindRepl',    'Find and Replace'],
    ['ReplaceAll', 'FindReplAll', 'Find and Replace All']) {
    my($img,$func,$desc) = @{$b};
    makeImage($img, \%XPM);
    if ($func =~ /^MC (.*)/) {
      my $dir = $1;
      $but{$img} = $Ed->{Top}->new_ttk__button(-image => $img, -command => [\&moveChord, $dir]);
    } else {
      $but{$img} = $Ed->{Top}->new_ttk__button(-image => $img, -command => \&$func);
    }
    balloon($but{$img}, $desc);
  }

  my $fontsizes = [qw(5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20)];
  $but{textsize}->m_configure(
    -command => sub{popMenu(\$EditFont{size}, \&fontUpdt, $fontsizes); });

  my $spcl = $Ed->{Top}->new_ttk__label(-text => "Line Spacing: ", -justify => 'center');
  my $lspc = 6;
  my $spcb = $Ed->{Top}->new_ttk__button(
    -textvariable => \$lspc,
    -style => 'Menu.TButton',
    -width => 2,
    -command => sub{
      popMenu(\$lspc,
	      sub{$Ed->{TxtWin}->m_configure(-spacing1 => $lspc);},
	      [qw/2 4 6 8 10 12/]);
    });

  my $a2cp = $Ed->{Top}->new_ttk__button(-text => 'Text to ChordPro', -command => \&text2cp);

  my $rfrm = $frame->new_ttk__frame(-padding => [4,0,4,0]);
  $rfrm->g_pack(qw/-side right/);
  my $lfrm = $frame->new_ttk__frame(-padding => [0,0,4,0]);
  $lfrm->g_pack(qw/-side right/);

  my $ignc = $frame->new_ttk__checkbutton(-text => " Ignore\n Case", -variable => \$Ed->{IgnCase});

  $Ed->{FindV} = '';
  my $findl = $frame->new_ttk__label(-text => 'Find:');
  my $finde = $frame->new_ttk__entry(-width => 10, -textvariable => \$Ed->{FindV});

  my($repl,$repe);
  $Ed->{RepV} = '';
  if (OS ne 'aqua') {
    $repl = $frame->new_ttk__label(-text => 'Replace with:');
    $repe = $frame->new_ttk__entry(-width => 10, -textvariable => \$Ed->{RepV});
  }
  $findl->g_grid(          -in => $rfrm, qw/-row 0 -column 0 -pady 2 -sticky e/, -padx => [0,2]);
  $finde->g_grid(          -in => $rfrm, qw/-row 0 -column 1 -pady 2 -sticky w/, -padx => [0,4]);
  $but{Find}->g_grid(      -in => $rfrm, qw/-row 0 -column 2 -padx 4 -pady 2/);
  $but{FindNext}->g_grid(  -in => $rfrm, qw/-row 0 -column 3 -padx 4 -pady 2/);
  $but{FindPrev}->g_grid(  -in => $rfrm, qw/-row 0 -column 4 -padx 4 -pady 2/);
  $ignc->g_grid(           -in => $rfrm, qw/-row 0 -column 5 -columnspan 2 -sticky w/, -padx => [8,0]);
  if (OS ne 'aqua') {
    $repl->g_grid(           -in => $rfrm, qw/-row 1 -column 0 -pady 2 -sticky e/, -padx => [0,2]);
    $repe->g_grid(           -in => $rfrm, qw/-row 1 -column 1 -pady 2 -sticky w/, -padx => [0,4]);
    $but{Replace}->g_grid(   -in => $rfrm, qw/-row 1 -column 2 -padx 4 -pady 2/);
    $but{ReplaceAll}->g_grid(-in => $rfrm, qw/-row 1 -column 3 -padx 4 -pady 2/);
  }

  $spcl->g_grid(          -in => $lfrm, qw/-row 0 -column 0 -pady 2 -sticky e/, -padx => [0,2]);
  $spcb->g_grid(          -in => $lfrm, qw/-row 0 -column 1 -pady 2 -sticky w/, -padx => [0,16]);
  $a2cp->g_grid(          -in => $lfrm, qw/-row 1 -columnspan 2 -sticky w -padx 4 -pady 2/);

  $but{open}->g_grid(     -in => $lfrm, qw/-row 0 -column 2 -padx 2 -pady 2/);
  $but{new}->g_grid(      -in => $lfrm, qw/-row 0 -column 3 -padx 2 -pady 2/);
  $but{close}->g_grid(    -in => $lfrm, qw/-row 0 -column 4 -padx 2 -pady 2/);
  $but{include}->g_grid(  -in => $lfrm, qw/-row 0 -column 5         -pady 2 -padx/ => [2,8]);
  $but{save}->g_grid(     -in => $lfrm, qw/-row 0 -column 6 -padx 2 -pady 2/);
  $but{saveAs}->g_grid(   -in => $lfrm, qw/-row 0 -column 7         -pady 2 -padx/ => [2,8]);
  $but{text}->g_grid(     -in => $lfrm, qw/-row 0 -column 8 -padx 2 -pady 2/);
  $but{textsize}->g_grid( -in => $lfrm, qw/-row 0 -column 9 -padx 2 -pady 2/);
  $but{textfg}->g_grid(   -in => $lfrm, qw/-row 0 -column 10 -padx 2 -pady 2/);
  $but{textbg}->g_grid(   -in => $lfrm, qw/-row 0 -column 11         -pady 2 -padx/ => [2,8]);
  $but{chordL}->g_grid(   -in => $lfrm, qw/-row 0 -column 12 -padx 2 -pady 2/);
  $but{chordR}->g_grid(   -in => $lfrm, qw/-row 0 -column 13 -padx 2 -pady 2/);
  $but{exit}->g_grid(     -in => $lfrm, qw/-row 0 -column 14 -padx 12 -pady 2/);

  $but{cut}->g_grid(      -in => $lfrm, qw/-row 1 -column 2 -padx 2 -pady 2/);
  $but{copy}->g_grid(     -in => $lfrm, qw/-row 1 -column 3 -padx 2 -pady 2/);
  $but{paste}->g_grid(    -in => $lfrm, qw/-row 1 -column 4 -padx 2 -pady 2/);
  $but{wrap}->g_grid(     -in => $lfrm, qw/-row 1 -column 5         -pady 2 -padx/ => [2,8]);
  $but{SelectAll}->g_grid(-in => $lfrm, qw/-row 1 -column 6 -padx 2 -pady 2/);
  $but{Unselect}->g_grid( -in => $lfrm, qw/-row 1 -column 7 -padx 2 -pady 2 -padx/ => [2,8]);
  $but{Undo}->g_grid(     -in => $lfrm, qw/-row 1 -column 8 -padx 2 -pady 2/);
  $but{Redo}->g_grid(     -in => $lfrm, qw/-row 1 -column 9 -padx 2 -pady 2/);
  $but{settags}->g_grid(  -in => $lfrm, qw/-row 1 -column 11         -pady 2 -padx/ => [2,8]);
  $but{chordU}->g_grid(   -in => $lfrm, qw/-row 1 -column 12 -padx 2 -pady 2/);
  $but{chordD}->g_grid(   -in => $lfrm, qw/-row 1 -column 13 -padx 2 -pady 2/);
}

sub text2cp {
  my @text = ();
  foreach (split(/\r|\n/, $Ed->{TxtWin}->get('1.0', 'end'))) {
    push(@text, $_) if ($_ ne '');
  }
  $Ed->{TxtWin}->delete('1.0', 'end');
  foreach (CP::A2Crd::a2cho(\@text)) {
    $Ed->{TxtWin}->insert('end', "$_\n");
  }
  setTags();
}

sub editFont {
  CP::Fonts::fontPick(\%EditFont, VLMWBG, 'Editor Font');
  fontUpdt();
}

sub checkFont {
  my($Fontlb) = shift;

  my $idx = $Fontlb->curselection(0);
  if ($idx ne '') {
    $EditFont{family} = $Fontlb->{array}[$idx];
    fontUpdt();
  }
}

sub fontUpdt {
  $Ed->{TxtWin}->m_configure(
    -font => "\{$EditFont{family}\} $EditFont{size} $EditFont{weight} $EditFont{slant}");
  $Ed->{TxtWin}->tag_configure(
    'chord',
    -offset => $EditFont{bracketoff},
    -font => "\{$EditFont{family}\} $EditFont{bracketsz} $EditFont{weight} $EditFont{slant}",
    -foreground => $EditFont{bracket});
  $Ed->{TxtWin}->tag_configure(
    'dirtv',
    -font => "\{$EditFont{family}\} $EditFont{bracesz} $EditFont{weight} $EditFont{slant}",
    -foreground => $EditFont{brace});
  $Media->save($Opt->{Media});
}

sub bgSet {
  my($fg,$bg) = $ColourEd->Show($EditFont{color}, $EditFont{background}, BACKGRND);
  if ($bg ne '') {
    $Ed->{TxtWin}->m_configure(-background => $bg);
    $EditFont{background} = $bg;
  }
}

sub fgSet {
  my($fg,$bg) = $ColourEd->Show($EditFont{color}, $EditFont{background}, FOREGRND);
  if ($fg ne '') {
    $Ed->{TxtWin}->m_configure(-foreground => $fg);
    $EditFont{color} = $fg;
  }
}

sub braceColour {
  my($what) = shift;

  my($fg,$bg) = $ColourEd->Show($EditFont{$what}, $EditFont{background}, FOREGRND);
  if ($fg ne '') {
    $EditFont{$what} = $fg;
    fontUpdt();
  }
}

sub braceSize {
  my($what) = @_;

  my $fontsizes = [qw(5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20)];
  popMenu(\$EditFont{$what}, \&fontUpdt, $fontsizes);
}

sub braceOffset {
  my $offsets = [qw/-4 -3 -2 -1 0 1 2 3 4 6 8 10 12 14 16 18 20/];
  popMenu(\$EditFont{bracketoff}, \&fontUpdt, $offsets);
}

sub chords {
  my($frame) = shift;

  my $row = CP::CHedit::chordButtons($frame, \&ichord);

  makeImage("brace", \%CHRD);

  my $br = $frame->new_ttk__button(
    -image => 'brace',
    -style => 'Chord.TButton',
    -command => sub{ichord('br')} );
  $br->g_grid(-row => $row, -column => 0, -columnspan => 6, -padx => 1, -pady => [4,8]);
}

  my %LongName = (
    be => 'end_of_bridge',
    br => 'bridge',
    bs => 'start_of_bridge',
    ca => 'capo',
    cb => 'comment_box',
    cc => 'chordcolour',
    cd => 'chord',
    cf => 'chordfont',
    ch => 'chorus',
    ci => 'comment_italic',
    cl => 'colour',
    co => 'comment',
    cs => 'chordsize',
    de => 'define',
    eb => 'x_end_background',
    ec => 'end_of_chorus',
    eg => 'end_of_grid',
    et => 'end_of_tab',
    ev => 'end_of_verse',
    hl => 'highlight',
    hz => 'x_horizontal_line',
    vs => 'x_vspace',
    ky => 'key',
    np => 'new_page',
    nt => 'x_note',
    sb => 'x_start_background',
    sc => 'start_of_chorus',
    sg => 'start_of_grid',
    st => 'start_of_tab',
    sv => 'start_of_verse',
    Tb => 'tab',
    Tf => 'tabfont',
    Tc => 'tabcolour',
    Ts => 'tabsize',
    tc => 'textcolour',
    te => 'tempo',
    tf => 'textfont',
    ti => 'title',
    ts => 'textsize',
    ve => 'verse',
      );

sub setFont {
  my($name,$fp) = @_;

  my %font = (family => $fp->{family},
	      size   => $fp->{size},
	      weight => $fp->{weight},
	      slant  => $fp->{slant},
	      color  => $fp->{color});
  if (fontPick(\%font, WHITE, 'Font') eq 'OK') {
    idef($name, \%font);
  }
}

sub directives {
  my($frame) = shift;

  makeImage("colour", \%XPM);

  #                     function                  row,col,rspn,cspn
  my $items = [
    [['bc', 'braceclr', [\&braceColour, 'brace'], 0,0,1,2],
     ['bz', 'bracesz',  [\&braceSize, 'bracesz'], 0,1,1,2]],

    [['ti', '#F0D050',  [\&idef, 'ti'], 1,0,1,2],
     ['ky', '#F0D050',  [\&idef, 'ky'], 1,1,1,2]],

    [['ca', '#FFE0E0',  [\&idef, 'ca'], 2,0,1,1],
     ['te', '#FFE0E0',  [\&idef, 'te'], 2,1,1,1],
     ['nt', '#FFE0E0',  [\&idef, 'nt'], 2,2,1,1]],

    [['hz', '#E0E0F8',  [\&idef, 'hz'], 3,0,1,1],
     ['vs', '#E0E0F8',  [\&idef, 'vs'], 3,1,1,1],
     ['np', '#E0E0F8',  [\&idef, 'np'], 3,2,1,1]],

    [['cd', '#FFE8B8',  [\&idef, 'cd'], 4,0,1,2],
     ['de', '#FFE8B8',  sub{my $s=CHedit('Define'); idef('de', $s) if ($s ne ''); }, 4,1,1,2]],

    [['cf', '#FFE8B8',  [\&setFont, 'cf', \%{$Media->{Chord}}], 5,0,1,1],
     ['cs', '#FFE8B8',  [\&idef, 'cs'], 5,1,1,1],
     ['cc', '#FFE8B8',  [\&idef, 'cc'], 5,2,1,1]],

    [['tf', '#F0D8A8',  [\&setFont, 'tf', \%{$Media->{Lyric}}], 6,0,1,1],
     ['ts', '#F0D8A8',  [\&idef, 'ts'], 6,1,1,1],
     ['tc', '#F0D8A8',  [\&idef, 'tc'], 6,2,1,1]],

    [['Tf', '#E0C898',  [\&setFont, 'Tf', \%{$Media->{Tab}}], 7,0,1,1],
     ['Ts', '#E0C898',  [\&idef, 'Ts'], 7,1,1,1],
     ['Tc', '#E0C898',  [\&idef, 'Tc'], 7,2,1,1]],

    [['sg', '#D0EFA0',  [\&idef, 'sg'], 8,0,1,2],
     ['eg', '#D0EFA0',  [\&idef, 'eg'], 8,1,1,2]],

    [['sv', $Media->{verseBG},     [\&idef, 'sv'], 9,0,1,1],
     ['ev', $Media->{verseBG},     [\&idef, 'ev'], 9,1,1,1],
     ['ve', $Media->{verseBG},     [\&idef, 've'], 9,2,1,1]],

    [['sc', $Media->{chorusBG},    [\&idef, 'sc'], 10,0,1,1],
     ['ec', $Media->{chorusBG},    [\&idef, 'ec'], 10,1,1,1],
     ['ch', $Media->{chorusBG},    [\&idef, 'ch'], 10,2,1,1]],

    [['bs', $Media->{bridgeBG},    [\&idef, 'bs'], 11,0,1,1],
     ['be', $Media->{bridgeBG},    [\&idef, 'be'], 11,1,1,1],
     ['br', $Media->{bridgeBG},    [\&idef, 'br'], 11,2,1,1]],

    [['st', $Media->{tabBG},       [\&idef, 'st'], 12,0,1,1],
     ['et', $Media->{tabBG},       [\&idef, 'et'], 12,1,1,1],
     ['Tb', $Media->{tabBG},       [\&idef, 'tb'], 12,2,1,1]],

    [['hl', $Media->{highlightBG}, [\&idef, 'hl'], 13,1,1,1]],

    [['co', $Media->{commentBG},   [\&idef, 'co'], 14,0,1,1],
     ['ci', $Media->{commentBG},   [\&idef, 'ci'], 14,1,1,1],
     ['cb', $Media->{commentBG},   [\&idef, 'cb'], 14,2,1,1]],
      ];
  foreach my $r (@{$items}) {
    foreach my $c (@{$r}) {
      if ($c->[1] =~ /^\#/) {
	# Text button
	txtButton($frame, @${c});
      }
      else {
	#Image button
	my($name,$img,$func,$row,$col,$rspn,$cspn) = @{$c};
	makeImage($img, \%XPM);
	my $but = $frame->new_ttk__button(-image => $img, -command => $func);
	balloon($but, 'Directive '.(($name eq 'bz') ? 'Size' : 'Colour'));
	$but->g_grid(-row => $row, -column => $col,
		     -rowspan => $rspn, -columnspan => $cspn,
		     -padx => 4, -pady => 4);
      }
    }
  }
  my $sbfrm = $frame->new_ttk__frame();
  $sbfrm->g_grid(-row => 15, -column => 0, -columnspan => 3);
  foreach my $c (['sb', '#D0E0B0',  [\&idef, 'sb'], 0,0,1,1],
		 ['eb', '#D0E0B0',  [\&idef, 'eb'], 0,1,1,1] ) {
    txtButton($sbfrm, @{$c});
  }
  my $cfrm = $frame->new_ttk__frame();
  $cfrm->g_grid(-row => 16, -column => 0, -columnspan => 3);
  my $clrb = $cfrm->new_ttk__button(
    -image => 'colour',
    -command => \&colourEd);
  $clrb->g_grid(qw/-row 0 -column 0/, -pady => [4,6]);
  balloon($clrb, "Colour Selector");

  foreach my $btn (
    [0,1, 'HighLight', 'highlightBG'],
    [0,2, 'Comment',   'commentBG'],
    [0,3, 'Verse',     'verseBG'],
    [0,4, 'Chorus',    'chorusBG'],
    [0,5, 'Bridge',    'bridgeBG'],
    [0,6, 'Tab',       'tabBG'],
      ) {
    my($r,$c,$stl,$med) = @{$btn};
    Tkx::ttk__style_configure("$stl.TButton", -background => $Media->{$med});
    Tkx::ttk__style_map("$stl.TButton", -background => "active $Media->{$med}");
    my $but = $cfrm->new_ttk__button(
      -image => 'blank',
      -style => "$stl.TButton",
      -command => sub {$Ed->{TxtWin}->insert('insert', $Media->{$med});$Ed->{TxtWin}->g_focus();}
	);
    $but->g_grid(-row => $r, -column => $c, -padx => 8, -pady => [0,4]);
    balloon($but, "$stl Background");
  }
}

sub colourEd {
  my($fg,$bg) = (BLACK, WHITE);
  if ((my $lst = $Ed->{TxtWin}->tag_ranges('sel')) ne '') {
    my $clr = $Ed->{TxtWin}->get(Tkx::SplitList($lst));
    if ($clr =~ /(\#[0-9a-fA-F]{6})/) {
      $bg = $1;
    } elsif ($clr =~ /([0-9]{1,3}),([0-9]{1,3}),([0-9]{1,3})/) {
      my $r = $1, my $g = $2, my $b = $3;
      $bg = sprintf "#%02x%02x%02x", $r, $g, $b;
    }
  }
  ($fg,$bg) = $ColourEd->Show(BLACK, $bg, BACKGRND);
  $Ed->{TxtWin}->insert('insert', $bg) if ($bg ne '');
  $Ed->{TxtWin}->g_focus();
}

sub txtButton {
  my($frm,$name,$clr,$func,$row,$col,$rspn,$cspn) = @_;

  Tkx::ttk__style_configure("$clr.TButton", -background => $clr);
  (my $txt = $LongName{$name}) =~ s/x_//;
  $txt =~ s/_/ /g;
  my $but = $frm->new_ttk__button(-text => $txt, -style => "$clr.TButton", -command => $func);
  $but->g_grid(-row => $row, -column => $col,
	       -rowspan => $rspn, -columnspan => $cspn,
	       -padx => 4, -pady => 4);
}

sub press {
  my($key) = shift;

  if (defined $key && $key =~ /^Contr/) {
    $Ctrl ^= 1;
  }
}

sub update_indicators {
  my($key) = shift;

  if (defined $key && $key =~ /^Contr/) {
    $Ctrl ^= 1;
    return;
  }
  my $lc = $Ed->{TxtWin}->index('insert');
  my($line,$column)= split(/\./, $lc);

  my($height,$last_col) = split(/\./,$Ed->{TxtWin}->index('end'));

  my $lab = sprintf "line: %3d   column: %3d", $line, $column;
  my $tot = sprintf "total lines: %3d", --$height;

  $Ed->{CntrLabel}->m_configure(-text => $lab);
  $Ed->{TotlLabel}->m_configure(-text => $tot);

  my $edit_flag = ($Ed->{TxtWin}->edit_modified()) ? 'edited' : '';
  $Ed->{Top}->g_wm_title("Editor  |  Collection: ".$Collection->name()."  |  $edit_flag $Ed->{FileName}");
  if ($Ed->{Tagged}) {
    $Ed->{TxtWin}->tag_remove('mysel', '1.0', 'end');
    $Ed->{Tagged} = 0;
  }
  if ($Ed->{TxtWin}->tag_names($lc) =~ /(CH_\d+)/) {
    my $t = $1;
    if ($Ed->{TaggedChord} ne '') {
      if ($Ed->{TaggedChord} ne $t) {
	chordDesel();
      }
    } else {
      chordSel($t);
    }
  } elsif ($Ed->{TaggedChord} ne '') {
    chordDesel();
  }
  Tkx::update_idletasks();
  $Ed->{TxtWin}->g_focus();
}

#
# fileOpen() allows you to open ANY file from ANYWHERE
# but it will always be written to the TempPath folder.
#
my $Ftypes = [['ChordPro Files', '.pro'],
	      ['All Files', '*']];
sub fileOpen {
  return if (checkAndSave() eq 'Cancel');
  # return a complete path/filename
  my $fn = Tkx::tk___getOpenFile(
    -initialdir => $Path->{Pro},
    -title => 'File Load',
    -filetypes => $Ftypes);
  if ($fn ne '') {
    my($fln,$flp) = fileparse($fn);
    $flp = "$Path->{Pro}/$fln";;
    if (! -e "$flp") {
      open OFH, ">", "$flp";
      (my $t = $fln) =~ s/\.pro$//;
      print OFH "{title:$t}\n";
      close OFH;
    }
    Open($flp);
  }
}

sub fileNew {
  return if (checkAndSave() eq 'Cancel');
  my $fn = "";
  return if (setFileName(\$fn) eq 'Cancel');
  if (-e "$Path->{Pro}/$fn") {
    my $ans = msgYesNo("$fn already exists.\nDo you want to continue and edit it?");
    return if ($ans eq "No");
  } else {
    open OFH, ">", "$Path->{Pro}/$fn";
    (my $t = $fn) =~ s/\.pro$//;
    print OFH "{title:$t}\n";
    close OFH;
  }
  Open("$Path->{Pro}/$fn");
}

sub fileInclude {
  my $fn = Tkx::tk___getOpenFile(
    -initialdir => $Path->{Pro},
    -title => 'File Include',
    -filetypes => $Ftypes);
  if (defined($fn) and length($fn)) {
    Include($fn);
  }
}

sub ExitCheck {
  my $ret = checkAndSave();
  if ($ret ne 'Cancel') {
    if ($ret eq 'Yes' && $Ed->{FileName} ne '') {
      if (! -e "$Path->{Pro}/$Ed->{FileName}") {
	# Result of New or Save As
	my $txt = read_file($TempFN);
	if (write_file("$Path->{Pro}/$Ed->{FileName}", $txt) != 1) {
	  message(SAD,
      "Failed to write \"$Ed->{FileName}\" to \"$Path->{Pro}\".\nEdited file is in\n    \"$TempFN\"");
	} else {
	  unlink($TempFN);
	}
      } elsif ($TempFN ne '' && $Saved) {
	backupFile($Ed->{FilePath}, $Ed->{FileName}, $TempFN, 1);
      }
      $Done = $Ed->{FileName};
    } else {
      $Done = 'No';
    }
  } else {
    $Done = 'Cancel';
  }
}

sub checkAndSave {
  if ($Ed->{TxtWin}->edit_modified() != 0) {
    my $ans;
    if ($Ed->{FileName} eq "") {
      $ans = msgYesNoCan("Do you want to save the changes?");
      return($ans) if ($ans ne 'Yes');
      return('Cancel') if (setFileName(\$Ed->{FileName}) eq 'Cancel');
    } else {
      $ans = msgYesNo("Do you want to save the changes?");
      return('No') if ($ans eq 'No');
    }
    Save($Ed->{FileName});
  }
  return('Yes');
}

sub fileSave {
  if ($Ed->{FileName} eq '') {
    checkAndSave();
  } else {
    Save($Ed->{FileName});
    backupFile($Ed->{FilePath}, $Ed->{FileName}, $TempFN, 0);
  }
}

sub fileSaveAs {
  my $fn = $Ed->{FileName};
  if (setFileName(\$fn) eq 'OK' && $fn ne '') {
    my $text = $Ed->{TxtWin}->get('1.0', 'end');
    # Remove any extraneous NL/CR/space
    my $c;
    while (($c = chop($text)) =~ /\r|\n|\s/) {}
    write_file("$Path->{Pro}/$fn", "$text$c\n");
    Open("$Path->{Pro}/$fn");
  }
}

# Returns 'Yes' if a unique filename is entered otherwise 'Cancel'.
sub setFileName {
  my($fnptr) = shift;

 AGAIN:
  if (msgSet("Enter a name for the new file", $fnptr) eq 'Cancel' || $$fnptr eq '') {
    return('Cancel');
  }
  # Just in case they added a .pro extension.
  $$fnptr =~ s/\.pro//i;
  $$fnptr .= '.pro';
  if (-e "$Path->{Pro}/$$fnptr") {
    my $ans = msgYesNoCan("File '$$fnptr' already exists.\nDo you want to overwrite it?");
    goto AGAIN if ($ans eq 'No');
    return($ans) if ($ans eq 'Cancel');
  }
  return('OK');
}

sub Open {
  my($fn) = shift;

  $Ed->{TxtWin}->delete('1.0', 'end');
  #
  # Create a copy of the original.
  # The only reason for a temp file is so that at the end of an edit
  # session we can put it into a numbered backup chain.
  #
  ($Ed->{FileName},$Ed->{FilePath}) = fileparse($fn);
  if (! open(IFH, "<", "$fn")) {
    message(SAD, "Editor could not access \"$fn\"");
    return(0);
  }
  $TempFN = "$TempPath/$Ed->{FileName}";
  if (! open(OFH, ">", "$TempFN")) {
    close(IFH);
    message(SAD, "Editor could not create \"$TempFN\"");
    return(0);
  }
  while (<IFH>) {
    # Ensure only Unix style line-feeds & strip any spaces from line end.
    $_ =~ s/[\s\r\n]$//;
    print OFH "$_\n";
    $Ed->{TxtWin}->insert('end', "$_\n", []);
  }
  close(IFH);
  close(OFH);
  setTags();
  $Ed->{TxtWin}->edit_reset();
  $Ed->{TxtWin}->edit_modified(0);
  view('1.0');
  update_indicators();
  return(1);
}

sub Close {
  return if (checkAndSave() eq 'Cancel');
  backupFile($Ed->{FilePath}, $Ed->{FileName}, $TempFN, 1) if ($Saved);
  $Ed->{TxtWin}->delete('1.0', 'end');
  $Ed->{TxtWin}->edit_modified(0);
  $Ed->{FilePath} = $Ed->{FileName} = $TempFN = '';
  update_indicators();
}

# Writes any changes out to the temporary file.
sub Save {
  my($fn) = shift;

  my $text = $Ed->{TxtWin}->get('1.0', 'end');
  my @lines = split(/^/, $text);
  while ($lines[-1] =~ /^[\r\n\s]+$/) {
    pop(@lines);
  }
  $text = join('', @lines);
  write_file("$TempPath/$fn", $text);
  $Ed->{TxtWin}->edit_modified(0);
  $Saved++;
  message(SMILE, "Saved \"$fn\"", 1);
}

# Unlike Load, Save and SaveAs - Include's $fn is a full path/file
sub Include {
  my($fn) = shift;

  my $text = read_file("$fn");
  $Ed->{TxtWin}->insert('insert', $text);
  $Ed->{TxtWin}->edit_modified(1);
}

my $about_pop_up_reference;
sub about_pop_up {
  my $name = ref($about_pop_up_reference);
  if (defined($about_pop_up_reference)) {
    $about_pop_up_reference->g_raise();
    $about_pop_up_reference->g_focus();
  }
  else {
    my($pop,$fr) = popWin(0, 'About');

    my $txt = <<EOF;
This was Gedi (Gregs EDItor) Ver. 1.0
Copyright 1999 Greg London
All Rights Reserved.
This program is free software.
You can redistribute it and/or
modify it under the same terms
as Perl itself.
Special Thanks to Nick Ing-Simmons.
  
Modified by Ian Houlding (2015-19)
for use with Chordy running under Tkx.
Not much (if any) of the original
code survives :-)
EOF
    my $tl = $fr->new_ttk__label(-text => $txt, -justify => 'center');
    $tl->g_pack();

    my $ok = $fr->new_ttk__button(
      -text=>'OK',
      -command => sub {
	$pop->g_destroy();
	$about_pop_up_reference = undef;
      });
    $ok->g_pack();
    $pop->g_wm_resizable('no','no');
    $about_pop_up_reference = $pop;
  }
}

sub ichord {
  my($k) = @_;

  my $s;
  if ($k eq "br") {
    $s = "[    ]";
  } elsif ($k =~ /^[A-G]/) {
    $s = "[$k]";
  }
  $Ed->{TxtWin}->insert('insert', $s, ['chord', "CH_".$ChordTag++]);
  update_indicators();
}

sub moveChord {
  my($dir) = shift;

  if ($Ed->{TaggedChord} =~ /(CH_\d+)/) {
    my $tag = $1;
    my $tw = $Ed->{TxtWin};
    my $lc = $tw->index('insert');
    # Have to make sure we're at the start of the tag.
    my($line,$column) = split(/\./, $lc);
    while ($column > 0 && $tw->tag_names("$line.".($column-1)) =~ /$tag/) {
      $column--;
    }
    my($stt,$end) = Tkx::SplitList($tw->tag_nextrange($tag, "$line.$column"));
    ($line,$column)= split(/\./, $stt);
    if (defined $stt) {
      my $chrd = $tw->get($stt, $end);
      $tw->delete($stt, $end);
      if ($dir =~ /^\-/) {
	if ($dir =~ /c/) {
	  if ($column) {
	    $column--;
	  } elsif ($line > 1) {
	    $column = 'end';
	    $line--;
	  }	    
	} else {
	  $line-- if ($line > 1);
	}
      } else {
	if ($dir =~ /c/) {
	  if ($tw->get("$line.$column") =~ /\r|\n/) {
	    $column=0;
	    $line++;
	  } else {
	    $column++;
	  }
	} else {
	  $line++;
	}
      }
      $tw->mark_set('insert', "$line.$column");
      $lc = my $pc = $tw->index('insert');
      $dir = '-1c' if ($dir ne '+1c');
      while ($tw->tag_names($lc) ne '' && $lc ne '1.0') {
	$pc = $lc;
	$tw->mark_set('insert', "$lc $dir");
	$lc = $tw->index('insert');
      }
      $pc = $lc if ($dir =~ /^\+/);
      $tw->mark_set('insert', $pc);
      $tw->insert('insert', $chrd, ['chord', $tag]);
      chordSel($tag);
      $tw->mark_set('insert', $pc);
      $tw->see('insert');
    }
  }
  $Ed->{TxtWin}->g_focus();
}

sub chordSel {
  my($tag) = shift;

  $Ed->{TxtWin}->tag_configure($tag,
			       -foreground => MAGENT,
			       -background => PBLUE);
  $Ed->{TaggedChord} = $tag;
}

sub chordDesel {
  $Ed->{TxtWin}->tag_configure("$Ed->{TaggedChord}",
			       -foreground => $EditFont{bracket},
			       -background => $EditFont{background});
  $Ed->{TaggedChord} = '';
}


#  ti = 'title',              co = 'comment',
#  np = 'new_page',	      ci = 'comment_italic',
#  ca = 'capo',	              cb = 'comment_box',
#  ky = 'key',	              sb = 'x_start_background',
#  te = 'tempo'
#  nt = 'x_note',	      eb = 'x_end_background',
#  sv = 'start_of_verse',     cd = 'chord',
#  ev = 'end_of_verse',       de = 'define',
#  ve = 'verse',	      hz = 'x_horizontal_line',
#  sc = 'start_of_chorus',    cl = 'colour',
#  ec = 'end_of_chorus',      cf = 'chordfont',
#  ch = 'chorus',	      cs = 'chordsize',
#  bs = 'start_of_bridge',    cc = 'chordcolour',
#  be = 'end_of_bridge',      tf = 'textfont',
#  br = 'bridge',	      ts = 'textsize',
#  st = 'start_of_tab',	      tc = 'textcolour',
#  et = 'end_of_tab',	      Tf = 'tabfont',
#  tb = 'tab',	      	      Ts = 'tabsize',
#  hl = 'highlight',	      Tc = 'tabcolour',

sub idef {
  my($k,$str) = @_;

  my $long = $LongName{$k};
  my $adj = 0;
  #
  # Find the current insertion point.
  #
  my($l,$c) = split(/\./, $Ed->{TxtWin}->index("insert"));
  my $s = '{';
  if ($k =~ /eb|sv|ev|ve|sc|ec|ch|bs|be|br|st|et|tb|np|eg/) {
    $s .= $long."\}\n";
    $l = 2 if ($k eq 'gr');
    $Ed->{TxtWin}->mark_set('insert', "$l.0");
  } else {
    $s .= $long.":";
    if ($k eq 'ti') {
      (my $fn = $Ed->{FileName}) =~ s/.pro$//;
      $fn =~ s/.*\///;
      $s .= $fn;
      $Ed->{TxtWin}->mark_set('insert', '1.0');
      $adj = 2;
    } elsif ($k =~ /ky|ca|nt|te/i) {
      $Ed->{TxtWin}->mark_set('insert', '2.0');
      $adj = 2;
    } else {
      $Ed->{TxtWin}->mark_set('insert', "$l.0");
      if ($k eq 'de') {
	$s .= $str;
      } elsif ($k eq 'hz') {
	$s .= "1 #000000";
      } elsif ($k =~ /cf|tf|Tf/) {
	$s .= "\{$str->{family}\} $str->{size} $str->{weight} $str->{slant}";
      } else {
	$adj = 2;
      }
    }
    $s .= "}\n";
  }
  $Ed->{TxtWin}->insert('insert', $s, 'dirtv');
  $Ed->{TxtWin}->mark_set('insert', "insert - $adj chars") if ($adj);
  update_indicators();
}

sub un_do {
  $Ed->{TxtWin}->edit_undo() if ($Ed->{TxtWin}->edit_canundo && $Ed->{TxtWin}->edit_modified());
  $Ed->{TxtWin}->g_focus();
}

sub re_do {
  $Ed->{TxtWin}->edit_redo() if ($Ed->{TxtWin}->edit_canredo);
  $Ed->{TxtWin}->g_focus();
}

sub clipCopy {
  Tkx::tk___textCopy($Ed->{TxtWin});
  unselectAll();
  $Ed->{TxtWin}->g_focus();
}

sub clipCut {
  Tkx::tk___textCut($Ed->{TxtWin});
  unselectAll();
  $Ed->{TxtWin}->g_focus();
}

# The problem here is that if a user hits Ctrl-V to paste then
# our bind() is invoked bringing us here. We paste the text and
# go away whereupon Tcl/Tk goes ahead and pastes the text AS WELL!!!!
# Hitting the 'Paste' button works fine hence the code to insert
# an undo separator and then call un_do().
sub clipPaste {
  my($undo) = shift;

  my $slc = $Ed->{TxtWin}->index('insert');
  Tkx::tk___textPaste($Ed->{TxtWin});
  unselectAll();
  my $elc = $Ed->{TxtWin}->index('insert');
  if ($slc ne $elc) {
    $Ed->{TxtWin}->edit_separator() if (defined $undo);
    setTags($slc, $elc);
    Tkx::after(20, \&un_do) if (defined $undo);
  }
  $Ed->{TxtWin}->g_focus();
}

sub setTags {
  my($fst,$lst) = @_;

  if (! defined $fst) {
    $fst = '1.0' ;
    $lst = 'end';
    $ChordTag = 0;
  }
  my @lines = split(/^/, $Ed->{TxtWin}->get($fst, $lst));
  my($lnum,$col) = split(/\./, $fst);
  foreach my $ln (@lines) {
    my $chdstart = my $dirstart = '';
    foreach my $c (split('', $ln)) {
      next if ($c eq "\r");
      if ($c eq "\n") {
	$lnum++;
	$col = 0;
	last;
      }
      my $curr = "$lnum.$col";
      foreach my $t (Tkx::SplitList($Ed->{TxtWin}->tag_names($curr))) {
	my($stt,$end) = Tkx::SplitList($Ed->{TxtWin}->tag_nextrange($t, $curr));
	if (defined $stt) {
	  $Ed->{TxtWin}->tag_remove($t, $stt, $end);
	}
      }
      if ($c eq '[') {
	$chdstart = $curr;
      } elsif ($c eq ']' && $chdstart ne '') {
	my $chdend = "$lnum.".($col+1);
	$Ed->{TxtWin}->tag_add('chord', $chdstart, $chdend);
	$Ed->{TxtWin}->tag_add("CH_".$ChordTag++, $chdstart, $chdend);
	$chdstart = '';
      } elsif ($c eq '{' && $dirstart eq '') {
	$dirstart = "$lnum.$col";
      }
      $col++;
    }
    if ($dirstart ne '') {
      $Ed->{TxtWin}->tag_add('dirtv', $dirstart, "$lnum.$col");
    }
  }
}

sub wrapText {
  my $vr = $Ed->{TxtWin}->m_cget(-wrap);
  popMenu(\$vr, undef, ['word','char','none']);
  Tkx::update();
  $Ed->{TxtWin}->m_configure(-wrap => $vr);
}

sub selectAll {
  $Ed->{TxtWin}->tag_add('sel', '1.0', 'end');
  $Ed->{TxtWin}->g_focus();
}

sub unselectAll {
  $Ed->{TxtWin}->tag_remove('sel', '1.0', 'end');
  $Ed->{TxtWin}->g_focus();
}

sub Find {
  my($fb) = shift;

  if ($Ed->{FindV} ne '') {
    $Ed->{TxtWin}->tag_remove('mysel', '1.0', 'end');
    $fb = '-forward' if (! defined $fb);
    my $cnt;
    my @args = ($fb, '-regexp', '-count', \$cnt);
    push(@args, '-nocase') if ($Ed->{IgnCase});
    push(@args, '--');
    my $lc = $Ed->{TxtWin}->search(@args, $Ed->{FindV}, $Ed->{TxtWin}->index('insert'));
    my $end = '';
    if ($lc ne '') {
      my ($l,$c)= split(/\./, $lc);
      view($lc);
      $c += $cnt;
      $end = "$l.$c";
      $Ed->{TxtWin}->tag_add('mysel', $lc, $end);
      $Ed->{Tagged}++;
    }
    ($lc,$end);
  } else {
    message(SAD, "No 'Find' string defined.");
    return('');
  }
}

sub FindNext {
  my ($l,$c)= split(/\./, $Ed->{TxtWin}->index('insert'));
  $c++;
  $Ed->{TxtWin}->mark_set('insert', "$l.$c");
  Find('-forward');
}

sub FindPrev {
  Find('-backward');
}

sub JumpTo {
  my($ln) = shift;

  view("$ln.0") if ($ln =~ /^\d+$/);
}

our($Pop);
our $OneOrAll = undef;
sub FindRepl {
  $OneOrAll = $_[0];

  if ($Ed->{FindV} ne '') {
    my ($lcf,$lce) = Find('-forward');
    Tkx::update();
    if ($lcf ne '') {
      my $x = Tkx::winfo_rootx($Ed->{TxtWin});
      my $y = Tkx::winfo_rooty($Ed->{TxtWin});
      my($ulx,$uly,$w,$h) = split(/ /, $Ed->{TxtWin}->bbox($lce));
      popYN(($x+$ulx+$w),$y+$uly-$h,$lcf,$lce);
    } else {
      message(SAD, "String \"$Ed->{FindV}\" not found.");
      $OneOrAll = undef;
    }
  }
}

sub replace {
  my($key,$lcf,$lce) = @_;

  $Pop->g_bind('<KeyRelease>', sub{});
  $key = chr($key);
  if ($key =~ /y/i) {
    $Ed->{TxtWin}->replace($lcf, $lce, $Ed->{RepV});
    $Ed->{TxtWin}->sync();
  } elsif ($key =~ /n/i) {
    $Ed->{TxtWin}->mark_set('insert', $lce);
  } else {
    $OneOrAll = undef;
  }
  $Pop->g_destroy();
  if ($Ed->{Tagged}) {
    $Ed->{TxtWin}->tag_remove('mysel', '1.0', 'end');
    $Ed->{Tagged} = 0;
  }
  if (defined $OneOrAll) {
    Tkx::after(150, \&FindReplAll);
  }
}

sub FindReplAll {
  FindRepl(1);
}

sub view {
  my($lc) = shift;

  $Ed->{TxtWin}->mark_set('insert', $lc);
  my($l,$c)= split(/\./, $lc);
  my $mid = $l - 10;
  $mid = 1 if ($mid < 1);
  $Ed->{TxtWin}->yview("$mid.$c");
  update_indicators();
}

sub popYN {
  my($x,$y,$lcf,$lce) = @_;

  $Pop = $Ed->{Top}->new_toplevel();
  $Pop->g_wm_overrideredirect(1);

  my $lab = $Pop->new_ttk__label(-text => 'Replace?', -style => 'YN.TLabel');
  $lab->g_pack();
  $Pop->g_bind('<KeyRelease>', [\&replace, Tkx::Ev('%k'), $lcf, $lce]);
  Tkx::update_idletasks();
  $Pop->g_wm_deiconify();
  $Pop->g_raise();
  $Pop->g_wm_geometry("+$x+$y");
  $Pop->g_focus();
}

1;
