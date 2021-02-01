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
use CP::Global qw/:FUNC :VERS :OPT :WIN :XPM :MEDIA :CHORD/;
use CP::Pop qw/:MENU :POP/;
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
our $IsPro = 0;
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
    $Ed->{TxtWin}->configure(-font => "\{$EditFont{family}\} $EditFont{size} $EditFont{weight} $EditFont{slant}");
    return();
  }
  bless $Ed, $class;
  my($pop,$mainFrame);
  $Ed->{Top} = '';
  $Ed->{FileName} = '';
  $Ed->{IgnCase} = 0;
  $Ed->{Tagged} = 0;
  $Ed->{TxtWin} = '';
  $Ed->{CntrLabel} = '';
  $Ed->{FindV} = '';
  $Ed->{RepV} = '';
  $Ed->{TaggedChord} = '';

  # Create MainWindow first to handle X11 options.
  if (defined $MW && Tkx::winfo_exists($MW)) {
    $pop = CP::Pop->new(0, '.ed', 'ChordPro Editor', undef, undef, 'Eicon');
    $Ed->{Top} = $pop->{top};
    $mainFrame = $pop->{frame};
    $Ed->{standAlone} = 0;
  } else {
    # Running stand-alone.
    CP::Global::init();
    $Collection = CP::Collection->new();
    $Path = CP::Path->new();
    $Cmnd = CP::Cmnd->new();
    $Opt = CP::Opt->new();
    $Media = CP::Media->new();
    $Swatches = CP::Swatch->new();

    fontSetup();

    CP::Win::init();
    $Ed->{Top} = $MW;
    $mainFrame = $MW->new_ttk__frame(qw/-relief raised -borderwidth 2/);
    $mainFrame->g_pack(qw/-expand 1 -fill both/);

    makeImage("tick", \%XPM);
    makeImage("xtick", \%XPM);
    $Ed->{standAlone} = 1;
  }
  $Ed->{Top}->g_wm_withdraw();
  $Ed->{Top}->g_wm_protocol('WM_DELETE_WINDOW' => \&ExitCheck);

  makeImage("Eicon", \%XPM);
  $Ed->{Top}->g_wm_iconphoto("Eicon");

  menu($Ed->{Top});
  CP::FgBgEd->new();

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

  my $leftF = $Ed->{leftFrame} = $mainFrame->new_ttk__frame(-padding => [4,4,2,4]);
  $leftF->g_pack(qw/-side left -expand 0 -fill y/);

  my $rightF = $mainFrame->new_ttk__frame(-padding => [0,4,0,0]);
  $rightF->g_pack(qw/-side right -expand 1 -fill both/);

  ########

  my $chord_frame = $leftF->new_ttk__labelframe(-text => " Chords ", -labelanchor => 'n');
  $chord_frame->g_pack(qw/-side top -fill x -anchor nw/);

#  my $cfl = $chord_frame->new_ttk__frame();
#  $cfl->g_pack(qw/-side left -anchor nw -padx 8 -pady 2/);
#  foreach my $r (['bracket',   'braceColour', 'Colour', 0],
#		 ['bracketsz', 'braceSize',   'Size',   7],
#		 ['bracketoff','braceOffset', 'Offset', 0]) {
#    my($img,$func,$desc,$pad) = @{$r};
#    makeImage($img, \%XPM);
#    my $br = $cfl->new_ttk__button(-image => $img, -command => [\&$func, $img]);
#    $br->g_pack(qw/-side top/, -pady => $pad);
#    balloon($br, 'Chord '.$desc);
#  }

  my $cf = $chord_frame->new_ttk__frame();
  $cf->g_pack(qw/-side top -anchor n/);
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
    -foreground => $Opt->{FGEditor},
    -background => $Opt->{BGEditor},
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
    -text => 'line: 1   column: 0   total lines: 0');
  $Ed->{CntrLabel}->g_grid(qw/-row 0 -column 0 -columnspan 2 -pady 0/);
  my $goto = '';
  my $gotob = $counter_frame->new_ttk__button(-text => 'Go To Line', -command => sub{JumpTo($goto)});
  my $gotoe = $counter_frame->new_ttk__entry(-width => 6, -textvariable => \$goto);
  $gotob->g_grid(qw/-row 1 -column 0 -pady 4 -sticky e/, -padx => [20,2]);
  $gotoe->g_grid(qw/-row 1 -column 1 -pady 4 -sticky w/, -padx => [2,8]);

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
  if (defined $unpck) {
    $Ed->{leftFrame}->g_pack_forget();
    $Ed->{menuFrame}->g_grid_forget();
  }
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
  if ($Ed->{standAlone}) {
    $Ed->{Top}->g_destroy();
    exit(0);
  }
  if (defined $unpck) {
    $Ed->{leftFrame}->g_pack(qw/-side left -expand 0 -fill y/);
    $Ed->{menuFrame}->g_grid(qw/-row 0 -column 1/);
  }
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

sub menu {
  my($win) = shift;

  my($m,$menu,$file,$edit,$opts,$help);
  if (OS eq 'aqua') {
    $m = $win->new_menu();
    $menu = Tkx::widget->new(Tkx::menu($m->_mpath . ".apple"));
    $m->add_cascade(-menu => $menu);
  } else {
    $menu = $win->new_menu();
    $win->configure(-menu => $menu);
  }
  $file = $menu->new_menu();
  $edit = $menu->new_menu();
  $opts = $menu->new_menu();
  $help = $menu->new_menu();

  $menu->add_cascade(-menu => $file, -label => "File");
  $menu->add_cascade(-menu => $edit, -label => "Edit");
  $menu->add_cascade(-menu => $opts, -label => "Options");
  $menu->add_cascade(-menu => $help, -label => "Help");

  $file->add_command(-label => 'Open',    -command => \&fileOpen);
  $file->add_command(-label => 'New',     -command => \&fileNew);
  $file->add_command(-label => 'Close',   -command => \&Close);
  $file->add_command(-label => 'Include', -command => \&fileInclude);
  $file->add_separator;
  $file->add_command(-label => 'Save',    -command => \&fileSave);
  $file->add_command(-label => 'Save As', -command => \&fileSaveAs);
  $file->add_separator;
  $file->add_command(-label => 'Exit',    -command => \&ExitCheck);

  $edit->add_command(-label => 'Cut',     -command => \&clipCut);
  $edit->add_command(-label => 'Copy',    -command => \&clipCopy);
  $edit->add_command(-label => 'Paste',   -command => \&clipPaste);
  $edit->add_separator;
  {
    my $wr = $edit->new_menu;
    $edit->add_cascade(-menu => $wr, -label => 'Wrap');
    my $vr = 'none';
    foreach (qw{word char none}) {
      $wr->add_radiobutton(-label => $_,
			   -variable => \$vr,
			   -command => sub{$Ed->{TxtWin}->m_configure(-wrap => $vr)} );
    }
  }
  $edit->add_separator;
  $edit->add_command(-label => 'Select Al', -command => \&SelectAll);
  $edit->add_command(-label => 'Deselect',  -command => \&deselectAll);
  $edit->add_separator;
  $edit->add_command(-label => 'Text to ChordPro',  -command => \&text2cp);

  {
    my $ls = $opts->new_menu;
    my $lspc = 6;
    $opts->add_cascade(-menu => $ls, -label => 'Line Spacing');
    foreach (qw(2 4 6 8 10 12)) {
      $ls->add_radiobutton(-label => $_,
			   -variable => \$lspc,
			   -command => sub{$Ed->{TxtWin}->m_configure(-spacing1 => $lspc)});
    }
  }

  $opts->add_separator;
  $opts->add_command(-label => 'Editor Font',  -command => \&editFont);
  {
    my $fs = $opts->new_menu;
    $opts->add_cascade(-menu => $fs, -label => 'Font Size');
    foreach (qw/5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20/) {
      $fs->add_radiobutton(-label => $_, -variable => \$EditFont{size}, -command => \&fontUpdt);
    }
  }
  $opts->add_command(-label => 'Font Colour',  -command => \&fgSet);
  $opts->add_command(-label => 'Editor Background',  -command => \&bgSet);
  $opts->add_separator;
  $opts->add_command(-label => 'Chord Colour', -command => [\&braceColour, 'bracket']);
  {
    my $cs = $opts->new_menu;
    $opts->add_cascade(-menu => $cs, -label => 'Chord Size');
    foreach (qw/5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20/) {
      $cs->add_radiobutton(-label => $_, -variable => \$EditFont{bracketsz},
			   -command => \&fontUpdt);
    }
  }
  {
    my $co = $opts->new_menu;
    $opts->add_cascade(-menu => $co, -label => 'Chord Offset');
    foreach (qw/-4 -3 -2 -1 0 1 2 3 4 6 8 10 12 14 16 18 20/) {
      $co->add_radiobutton(-label => $_, -variable => \$EditFont{bracketoff},
			   -command => \&fontUpdt);
    }
  }
  $opts->add_separator;
  $opts->add_command(-label => 'Directive Colour', -command => [\&braceColour, 'brace']);
  {
    my $cs = $opts->new_menu;
    $opts->add_cascade(-menu => $cs, -label => 'Directive Size');
    foreach (qw/5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20/) {
      $cs->add_radiobutton(-label => $_, -variable => \$EditFont{bracesz},
			   -command => \&fontUpdt);
    }
  }

#  $opt->add_checkbutton(-label => " Ignore Capo Directives",
#			-variable => \$Opt->{IgnCapo},
#			-command => sub{$Opt->saveOne('IgnCapo')},
#			 @cbopts ); 

  $help->add_command(-label => 'Help',  -command => \&CP::HelpEd::help);
  $help->add_command(-label => 'About', -command => sub{message(SMILE, "Version $Version\nian\@houlding.me.uk");});
  if (OS eq 'aqua') {
    $win->configure(-menu => $m);
  }
}

###################################################
## create all the quick access buttons plus images
###################################################

sub quickButtons {
  my($frame) = shift;

  my %but = ();
  foreach my $b (
    ['Undo',       'un_do',       'Undo'],
    ['Redo',       're_do',       'Redo'],
    ['settags',    'setTags',     'Reformat Buffer'],
    ['chordL',     'MC -1c',      'Move Chord Left'],
    ['chordR',     'MC +1c',      'Move Chord Right'],
    ['chordU',     'MC -1l',      'Move Chord Up'],
    ['chordD',     'MC +1l',      'Move Chord Down'],
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

  my $lfrm = $frame->new_ttk__frame();
  $lfrm->g_grid(qw/-row 0 -column 0/);
  my $mfrm = $frame->new_ttk__frame();
  $mfrm->g_grid(qw/-row 0 -column 1/);
  $Ed->{menuFrame} = $mfrm;
  my $rfrm = $frame->new_ttk__frame(-padding => [24,4,0]);
  $rfrm->g_grid(qw/-row 0 -column 2/);

  my $ignc = $frame->new_ttk__checkbutton(-style => 'My.TCheckbutton',
					  -compound => 'left',
					  -image => ['xtick', 'selected', 'tick'],
					  -text => "Ignore Case",
					  -variable => \$Ed->{IgnCase});

  $Ed->{FindV} = '';
  my $findl = $frame->new_ttk__label(-text => 'Find');
  my $finde = $frame->new_ttk__entry(-width => 10, -textvariable => \$Ed->{FindV});

  my($repl,$repe);
  $Ed->{RepV} = '';
  if (OS ne 'aqua') {
    $repl = $frame->new_ttk__label(-text => 'Replace with');
    $repe = $frame->new_ttk__entry(-width => 10, -textvariable => \$Ed->{RepV});
  }
  $findl->g_grid(        -in => $rfrm, qw/-row 0 -column 0 -pady 0 -sticky e/, -padx => [0,2]);
  $finde->g_grid(        -in => $rfrm, qw/-row 0 -column 1 -pady 0 -sticky w/, -padx => [0,4]);
  $but{Find}->g_grid(    -in => $rfrm, qw/-row 0 -column 2 -padx 4 -pady 0/);
  $but{FindNext}->g_grid(-in => $rfrm, qw/-row 0 -column 3 -padx 4 -pady 0/);
  $but{FindPrev}->g_grid(-in => $rfrm, qw/-row 0 -column 4 -padx 4 -pady 0/);
  if (OS ne 'aqua') {
    $repl->g_grid(           -in => $rfrm, qw/-row 0 -column 5 -pady 0 -sticky e/, -padx => [8,2]);
    $repe->g_grid(           -in => $rfrm, qw/-row 0 -column 6 -pady 0 -sticky w/, -padx => [0,4]);
    $but{Replace}->g_grid(   -in => $rfrm, qw/-row 0 -column 7 -padx 4 -pady 0/);
    $but{ReplaceAll}->g_grid(-in => $rfrm, qw/-row 0 -column 8 -padx 4 -pady 0/);
  }
  $ignc->g_grid(             -in => $rfrm, qw/-row 1 -column 0 -columnspan 2 -padx 0/);

  $but{Undo}->g_grid(   -in => $lfrm, qw/-row 0 -column 0 -rowspan 2 -padx 2  -pady 2/);
  $but{Redo}->g_grid(   -in => $lfrm, qw/-row 0 -column 1 -rowspan 2 -padx 2  -pady 2/);
  $but{settags}->g_grid(-in => $mfrm, qw/-row 0 -column 0 -rowspan 2 -padx 16 -pady 2/);
  $but{chordU}->g_grid( -in => $mfrm, qw/-row 0 -column 1 -padx 2 -pady 2/);
  $but{chordD}->g_grid( -in => $mfrm, qw/-row 0 -column 2 -padx 2 -pady 2/);
  $but{chordL}->g_grid( -in => $mfrm, qw/-row 0 -column 3 -padx 2 -pady 2/);
  $but{chordR}->g_grid( -in => $mfrm, qw/-row 0 -column 4 -padx 2 -pady 2/);
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
  CP::Fonts::fontPick(\%EditFont, $Opt->{FGEditor}, $Opt->{BGEditor}, 'Editor Font');
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
  my($fam,$wt,$sl) = ($EditFont{family},$EditFont{weight},$EditFont{slant});
  $Ed->{TxtWin}->m_configure(
    -font => "\{$fam\} $EditFont{size} $wt $sl");
  $Ed->{TxtWin}->tag_configure(
    'dirtv',
    -font => "\{$fam\} $EditFont{bracesz} $wt $sl",
    -foreground => $EditFont{brace});
  $Ed->{TxtWin}->tag_configure(
    'chord',
    -offset => $EditFont{bracketoff},
    -font => "\{$fam\} $EditFont{bracketsz} $wt $sl",
    -foreground => $EditFont{bracket});
  $Media->save();
}

sub bgSet {
  my($fg,$bg) = $ColourEd->Show($Opt->{FGEditor}, $Opt->{BGEditor}, '', BACKGRND);
  if ($bg ne '') {
    $Ed->{TxtWin}->m_configure(-background => $bg);
    $Opt->{BGEditor} = $bg;
  }
}

sub fgSet {
  my($fg,$bg) = $ColourEd->Show($Opt->{FGEditor}, $Opt->{BGEditor}, '', FOREGRND);
  if ($fg ne '') {
    $Ed->{TxtWin}->m_configure(-foreground => $fg);
    $Opt->{FGEditor} = $fg;
  }
}

sub braceColour {
  my($what) = shift;

  my($fg,$bg) = $ColourEd->Show($EditFont{$what}, $Opt->{BGEditor}, '', FOREGRND);
  if ($fg ne '') {
    $EditFont{$what} = $fg;
    fontUpdt();
  }
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

my %Dtv = (
  be => {dir => 'end_of_bridge',      lab => 'End Bridge',     clr => 'BGBridge'},
  br => {dir => 'bridge',             lab => 'Bridge',         clr => 'BGBridge'},
  bs => {dir => 'start_of_bridge',    lab => 'Start Bridge',   clr => 'BGBridge'},
  ca => {dir => 'capo',               lab => 'Capo',           clr => '#FFE0E0'},
  cb => {dir => 'comment_box',        lab => 'Cmnt Box',       clr => 'BGComment'},
  cc => {dir => 'chordcolour',        lab => 'Chord Colour',   clr => '#FFE8B8'},
  cd => {dir => 'chord',              lab => 'Chord',          clr => '#FFE8B8'},
  cf => {dir => 'chordfont',          lab => 'Chord Font',     clr => '#FFE8B8'},
  ch => {dir => 'chorus',             lab => 'Chorus',         clr => 'BGChorus'},
  ci => {dir => 'comment_italic',     lab => 'Cmnt Italic',    clr => 'BGComment'},
  cl => {dir => 'colour',             lab => 'Colour',         clr => ''},
  co => {dir => 'comment',            lab => 'Comment',        clr => 'BGComment'},
  cs => {dir => 'chordsize',          lab => 'Chord Size',     clr => '#FFE8B8'},
  de => {dir => 'define',             lab => 'Define',         clr => '#FFE8B8'},
  eb => {dir => 'x_end_background',   lab => 'End Backgrnd',   clr => '#D0E0B0'},
  ec => {dir => 'end_of_chorus',      lab => 'End Chorus',     clr => 'BGChorus'},
  eg => {dir => 'end_of_grid',        lab => 'End Grid',       clr => '#D0EFA0'},
  et => {dir => 'end_of_tab',         lab => 'End Tab',        clr => 'BGTab'},
  ev => {dir => 'end_of_verse',       lab => 'End Verse',      clr => 'BGVerse'},
  hl => {dir => 'highlight',          lab => 'Highlight',      clr => 'BGHighlight'},
  hz => {dir => 'x_horizontal_line',  lab => 'Horiz\'l Line',  clr => '#E0E0F8'},
  ky => {dir => 'key',                lab => 'Key',            clr => '#F0D050'},
  md => {dir => 'meta',               lab => 'Meta',           clr => '#FFF090'},
  me => {dir => '',                   lab => 'Meta Entry',     clr => '#FFF090'},
  np => {dir => 'new_page',           lab => 'New Page',       clr => '#E0E0F8'},
  nt => {dir => 'x_note',             lab => 'Note',           clr => '#FFE0E0'},
  sb => {dir => 'x_start_background', lab => 'Start Backgrnd', clr => '#D0E0B0'},
  sc => {dir => 'start_of_chorus',    lab => 'Start Chorus',   clr => 'BGChorus'},
  sg => {dir => 'start_of_grid',      lab => 'Start Grid',     clr => '#D0EFA0'},
  st => {dir => 'start_of_tab',       lab => 'Start Tab',      clr => 'BGTab'},
  sv => {dir => 'start_of_verse',     lab => 'Start Verse',    clr => 'BGVerse'},
  Tb => {dir => 'tab',                lab => 'Tab',            clr => 'BGTab'},
  Tf => {dir => 'tabfont',            lab => 'Tab Font',       clr => '#E0C898'},
  Tc => {dir => 'tabcolour',          lab => 'Tab Colour',     clr => '#E0C898'},
  Ts => {dir => 'tabsize',            lab => 'Tab Size',       clr => '#E0C898'},
  tc => {dir => 'textcolour',         lab => 'Text Colour',    clr => '#F0D8A8'},
  te => {dir => 'tempo',              lab => 'Tempo',          clr => '#FFE0E0'},
  tf => {dir => 'textfont',           lab => 'Text Font',      clr => '#F0D8A8'},
  ti => {dir => 'title',              lab => 'Title',          clr => '#F0D050'},
  ts => {dir => 'textsize',           lab => 'Text Size',      clr => '#F0D8A8'},
  ve => {dir => 'verse',              lab => 'Verse',          clr => 'BGVerse'},
  vs => {dir => 'x_vspace',           lab => 'Vert\'l Space',  clr => '#E0E0F8'},
);

sub directives {
  my($frame) = shift;

  makeImage("colour", \%XPM);

  #    id   col,cspn
  my @items = (
    [['ti', 0,2],
     ['ky', 1,2]],

    [['ca', 0,1],
     ['te', 1,1],
     ['nt', 2,1]],

    [['hz', 0,1],
     ['vs', 1,1],
     ['np', 2,1]],

    [['md', 0,2],
     ['me', 1,2]],
    
    [['cd', 0,2],
     ['de', 1,2]],

    [['cf', 0,1],
     ['cs', 1,1],
     ['cc', 2,1]],

    [['tf', 0,1],
     ['ts', 1,1],
     ['tc', 2,1]],

    [['Tf', 0,1],
     ['Ts', 1,1],
     ['Tc', 2,1]],

    [['sg', 0,2],
     ['eg', 1,2]],

    [['sv', 0,1],
     ['ev', 1,1],
     ['ve', 2,1]],

    [['sc', 0,1],
     ['ec', 1,1],
     ['ch', 2,1]],

    [['bs', 0,1],
     ['be', 1,1],
     ['br', 2,1]],

    [['st', 0,1],
     ['et', 1,1],
     ['Tb', 2,1]],

    [['hl', 1,1]],

    [['co', 0,1],
     ['ci', 1,1],
     ['cb', 2,1]],
      );
  my $row = 0;
  foreach my $r (@items) {
    foreach my $c (@{$r}) {
      my($id,$co,$cs) = (@{$c});
      my $cv = $Dtv{$id}{clr};
      my $clr = ($cv =~ /^#/) ? $cv : $Opt->{$cv};
      txtButton($frame, $id, $clr, [\&idef, $id], $row, $co, $cs);
    }
    $row++;
  }
  my $sbfrm = $frame->new_ttk__frame();
  $sbfrm->g_grid(-row => $row, -column => 0, -columnspan => 3);
  foreach my $c (['sb', 0,1],
		 ['eb', 1,1] ) {
    my($id,$co,$cs) = (@{$c});
    txtButton($sbfrm, $id, $Dtv{$id}->{clr}, [\&idef, $id], 0, $co, $cs);
  }
  $row++;
  my $cfrm = $frame->new_ttk__frame();
  $cfrm->g_grid(-row => $row, -column => 0, -columnspan => 3);
  my $clrb = $cfrm->new_ttk__button(
    -image => 'colour',
    -command => \&colourEd);
  $clrb->g_grid(qw/-row 0 -column 0/, -pady => [4,6]);
  balloon($clrb, "Colour Selector");

  foreach my $btn (
    [0,1, 'HighLight', 'BGHighlight'],
    [0,2, 'Comment',   'BGComment'],
    [0,3, 'Verse',     'BGVerse'],
    [0,4, 'Chorus',    'BGChorus'],
    [0,5, 'Bridge',    'BGBridge'],
    [0,6, 'Tab',       'BGTab'],
      ) {
    my($r,$c,$stl,$med) = @{$btn};
    Tkx::ttk__style_configure("$stl.TButton", -background => $Opt->{$med});
    Tkx::ttk__style_map("$stl.TButton", -background => "active $Opt->{$med}");
    my $but = $cfrm->new_ttk__button(
      -image => 'blank',
      -style => "$stl.TButton",
      -command => sub {$Ed->{TxtWin}->insert('insert', $Opt->{$med});$Ed->{TxtWin}->g_focus();}
	);
    $but->g_grid(-row => $r, -column => $c, -padx => 8, -pady => [0,4]);
    balloon($but, "$stl Background");
  }
}

sub txtButton {
  my($frm,$id,$clr,$func,$row,$col,$cspn) = @_;

  Tkx::ttk__style_configure("$clr.TButton", -background => $clr);
  my $lab = $Dtv{$id}{lab};
  my $but = $frm->new_ttk__button(-text => $lab, -style => "$clr.TButton", -command => $func);
  $but->g_grid(-row => $row, -column => $col,
	       -columnspan => $cspn,
	       -padx => 2, -pady => 2);
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
  ($fg,$bg) = $ColourEd->Show(BLACK, $bg, '', BACKGRND);
  $Ed->{TxtWin}->insert('insert', $bg) if ($bg ne '');
  $Ed->{TxtWin}->g_focus();
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

  my $lab = sprintf "line: %3d   column: %3d   total lines: %3d", $line, $column, ($height - 1);

  $Ed->{CntrLabel}->m_configure(-text => $lab);

  my $edit_flag = ($Ed->{TxtWin}->edit_modified()) ? 'edited' : '';
  $Ed->{Top}->g_wm_title("Editor  |  Collection: ".$Collection->{name}."  |  $edit_flag $Ed->{FileName}");
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
# but it will always be written to the TempPath folder
# as a .pro file.
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
    (my $title = $fln) =~ s/\.[^\.]+$//;
    $flp = "$Path->{Pro}/${title}.pro";;
    if (! -e "$flp") {
      open OFH, ">", "$flp";
      print OFH "{title:$title}\n";
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
    my $ans = 'No';
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
  $IsPro = ($Ed->{FileName} =~ /.pro$/);
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
  my $pm = $/;
  $/ = '';
  chomp($text);
  $/ = $pm;
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

sub about_pop_up {
  my $pop = CP::Pop->new(0, '.ap', 'About');
  return if ($pop eq '');
  my($top,$fr) = ($pop->{top}, $pop->{frame});

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

  my $ok = $fr->new_ttk__button(-text=>'OK', -command => sub {$pop->popDestroy()});
  $ok->g_pack();
  $top->g_wm_resizable('no','no');
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
      if ($tw->tag_names($lc) =~ /(CH_\d+)/) {
	$dir = '-1c' if ($dir ne '+1c');
	my $t = $1;
	while ($tw->tag_names($lc) =~ /$t/ && $lc ne '1.0') {
	  $pc = $lc;
	  $tw->mark_set('insert', "$lc $dir");
	  $lc = $tw->index('insert');
	}
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
			       -background => $Opt->{BGEditor});
  $Ed->{TaggedChord} = '';
}


#  ti = 'title',              co = 'comment',
#  np = 'new_page',	      ci = 'comment_italic',
#  ca = 'capo',	              cb = 'comment_box',
#  ky = 'key',	              sb = 'x_start_background',
#  te = 'tempo',
#  me = 'meta',
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
  my($k) = shift;

  my $long = $Dtv{$k}{dir};
  my $adj = 0;
  #
  # Find the current insertion point.
  #
  my($l,$c) = split(/\./, $Ed->{TxtWin}->index("insert"));
  my $s = ($k eq 'me') ? '%{' : '{';
  if ($k =~ /eb|sv|ev|ve|sc|ec|ch|bs|be|br|st|et|tb|np|eg/) {
    $s .= $long."\}\n";
    $l = 2 if ($k eq 'gr');
    $Ed->{TxtWin}->mark_set('insert', "$l.0");
  } elsif ($k eq 'me') {
    $adj = 1;
    $s .= "}";
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
	if ((my $def = CHedit('Define')) ne '') {
	  $s .= $def;
	} else {
	  return;
	}
      } elsif ($k eq 'hz') {
	$s .= "1 #000000";
      } elsif ($k =~ /cf|tf|Tf/) {
	my $fp;
	if ($k eq 'cf') {
	  $fp = \%{$Media->{Chord}};
	} elsif ($k eq 'tf') {
	  $fp = \%{$Media->{Lyric}};
	} else {
	  $fp = \%{$Media->{Tab}};
	}
	my %font = (family => $fp->{family},
		    size   => $fp->{size},
		    weight => $fp->{weight},
		    slant  => $fp->{slant});
	if (fontPick(\%font, $Opt->{FGEditor}, $Opt->{BGEditor}, 'Font') eq 'OK') {
	  $s .= "\{$font{family}\} $font{size} $font{weight} $font{slant}";
	} else {
	  return;
	}
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
  deselectAll();
  $Ed->{TxtWin}->g_focus();
}

sub clipCut {
  Tkx::tk___textCut($Ed->{TxtWin});
  deselectAll();
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
  deselectAll();
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
	if ($dirstart ne '') {
	  $Ed->{TxtWin}->tag_lower('dirtv', 'chord');
	}
	$chdstart = '';
      } elsif ($c eq '{' && $dirstart eq '') {
	$dirstart = "$lnum.$col";
	$Ed->{TxtWin}->tag_add('dirtv', $dirstart, "$lnum.end");
      }
      $col++;
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

sub deselectAll {
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
