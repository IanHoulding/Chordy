package CP::CHedit;

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
use CP::Cconst qw/:OS :PATH :SMILIE :COLOUR/;
use CP::Global qw/:FUNC :OPT :WIN :XPM :CHORD/;
use CP::Pop qw/:POP :MENU/;
use CP::Collection;
use CP::Cmnd;
use CP::Path;
use CP::Opt;
use CP::Swatch;
use CP::Cmsg;

use Exporter;

Tkx::package_require("img::xpm");

our @ISA = qw/Exporter/;

our @EXPORT = qw/&CHedit &mkChords &chordButtons %CHRD/;

our(%Groups, %CHRD, %IDs, %Chord);
our($Canvas, $Indent, $Y);

our $Ed;

# @String is a square array - one primary element for each string.
# The first element is what is displayed above the fret board:
#    X   if the string is not played
#    0   if the string is played open
#    ' ' (blank) if the string is fretted and played
# The second element is -1 for not played, 0 for open or a number from 1 to $Nfret
# The third element is a widget ID for the finger indicator on the string.
our(@String);
our($Centry);

my $BASE = 1.5;
my $Ffret = 1;
my $Nfret = 5;
my $Pitch = $BASE * 15;
my $Dot = int($Pitch / 3);    # 'dot' inlay radius

sub CHedit {
  my($what) = @_; # Currently either 'Save' or 'Define'

  my $standAlone = 0;
  my $done = '';
  my($pop,$frame,$bf);
  if (ref($Ed) ne 'HASH') {
    if (defined $MW && Tkx::winfo_exists($MW)) {
      $pop = CP::Pop->new(0, '.ct', 'Chord Editor', undef, undef, 'Eicon');
      $Ed = {};
      $Ed->{top} = $pop->{top};
      $Ed->{frame} = $frame = $pop->{frame};
    } else {
      use CP::Win;
      CP::Global::init();
      $Collection = CP::Collection->new();
      $Path = CP::Path->new();
      $Cmnd = CP::Cmnd->new();
      $Opt = CP::Opt->new();
      CP::Win::init();
      $MW->g_wm_title('Chord Editor');
      makeImage("Eicon", \%XPM);
      $MW->g_wm_iconphoto("Eicon");
      $Ed->{top} = $MW;
      $Ed->{frame} = $frame = $MW->new_ttk__frame(qw/-relief raised -borderwidth 2/);
      $Ed->{frame}->g_pack(qw/-expand 1 -fill both/);

      $standAlone++;
    }

    $Ed->{top}->g_wm_protocol('WM_DELETE_WINDOW' => sub{$done = 'Cancel'});

    init();

    # Create and layout all the Frames
    #
    my $tf = $frame->new_ttk__frame(-relief => 'raised', -borderwidth => 2, -padding => [4,4,4,4]);
    $tf->g_pack(qw/-side top/);

    $Ed->{bf} = $bf = $frame->new_ttk__frame();
    $bf->g_pack(qw/-side bottom -fill x/);

    my $lf = $tf->new_ttk__frame();
    $lf->g_pack(qw/-side left -fill both -padx/ => [0,4]);
    #
    my $rf = $tf->new_ttk__frame();
    $rf->g_pack(qw/-side right -fill both -padx/ => [4,0]);

    my $ltf = $lf->new_ttk__frame();
    $ltf->g_pack(qw/-side top -fill x/);
    #
    my $lbf = $lf->new_ttk__frame();
    $lbf->g_pack(qw/-side top -fill both -pady/ => [8,0]);

    # Now fill the Frames with their Widgets.
    #
    my $ltfb = $ltf->new_ttk__button(
      -text => " Clear ",
      -command => sub{
	newChord();
	fretBoard(); });
    $ltfb->g_pack(qw/-side top -pady/ => [4,8]);
  
    my $ltfl = $ltf->new_ttk__label(-text => "Chord name: ");
    $ltfl->g_pack(qw/-side left/);
  
    my $ltfe = $ltf->new_ttk__entry(
      -width => 8,
      -textvariable => \$Centry,
      -justify => 'center');
    $ltfe->g_pack(qw/-side left/);

    chordButtons($lbf,\&showChord);

    my $rfl = $rf->new_ttk__label(-text => "Instrument: ");
    $rfl->g_grid(qw/-row 0 -column 0 -sticky e -pady 4/);
    my $val = '{'.join('} {',@{$Opt->{Instruments}}).'}';
    my $rlm = $rf->new_ttk__combobox(
      -textvariable => \$Opt->{Instrument},
      -values => $val,
      -width => 8,
	);
    $rlm->g_grid(qw/-row 0 -column 1 -sticky w -pady 4/);
    $rlm->g_bind("<<ComboboxSelected>>", sub{
      readFing($Opt->{Instrument});
      chordButtons($lbf,\&showChord);
      newChord();
      fretBoard(); });
    $Canvas = $rf->new_tk__canvas(-bg => MWBG, -highlightthickness => 0);
    $Canvas->g_grid(qw/-row 1 -column 0 -columnspan 2 -sticky nsew/);
    
    fretBoard();
  }
  foreach my $c (Tkx::SplitList(Tkx::winfo_children($Ed->{bf}))) {
    Tkx::destroy($c);
  }
  my($lb,$rb);
  if ($what eq 'Save') {
    $lb = $Ed->{bf}->new_ttk__button(-text => 'Exit', -style => 'Red.TButton',
				     -command => sub{
				       if ($standAlone) {
					 $MW->g_destroy();
					 exit(0);
				       } else {
					 $done = 'OK';
				       } });
    $rb = $Ed->{bf}->new_ttk__button(-text => 'Save', -style => 'Green.TButton',
				     -command => sub{
				       save();
				       if ($standAlone) {
					 $MW->g_destroy();
					 exit(0);
				       } else {
					 $done = 'OK';
				       } });
  }
  else {
    $lb = $Ed->{bf}->new_ttk__button(-text => 'Cancel', -style => 'Red.TButton',
				     -command => sub{
				       if ($standAlone) {
					 $MW->g_destroy();
					 exit(0);
				       } else {
					 $done = 'Cancel';
				       } });
    $rb = $Ed->{bf}->new_ttk__button(-text => 'OK', -style => 'Green.TButton',
				     -command => sub{$done = 'OK';});
  }
  $lb->g_pack(qw/-side left -pady 8 -padx 20/);
  $rb->g_pack(qw/-side right -pady 8 -padx 20/);

  newChord();

  $Ed->{top}->g_wm_deiconify();
  $Ed->{top}->g_raise();

  if ($standAlone == 0) {
    Tkx::vwait(\$done);
    my $str = '';
    if ($done eq 'OK' && $what eq 'Define' && $Centry ne '') {
      $str = sprintf("%s base-fret %d frets", $Centry, $Ffret);
      foreach my $s (@String) {
	$str .= ($s->[1] == -1) ? ' x' : ' '.$s->[1];
      }
    }
    $Ed->{top}->g_wm_withdraw();
    Tkx::update_idletasks();
    return $str;
  }
}

sub init {
  $Centry = "";
  %Chord = ();
  readFing($Opt->{Instrument});
  mkChords();
  makeImage("sharp", \%CHRD);
  makeImage("flat",  \%CHRD);
  makeImage("minor", \%CHRD);
}

sub chordButtons {
  my($frame,$func) = @_;

  %Chord = ();
  my $row = 0;
  foreach my $p (['b','A','#'],
		 ['b','B',''],
		 ['', 'C','#'],
		 ['b','D','#'],
		 ['b','E',''],
		 ['', 'F','#'],
		 ['b','G','#']) {
    my($flat,$base,$sharp) = @{$p};
    makeImage("$base", \%CHRD);

    if ($flat ne '') {
      my $but = oneButton($frame, $row, 0, $base, 'b', $func);
      oneButton($frame, $row, 1, $but, 'm', $func);
    }

    oneButton($frame, $row, 2, $base, '', $func);
    oneButton($frame, $row, 3, $base, 'm', $func);

    if ($sharp ne '') {
      my $but = oneButton($frame, $row, 4, $base, '#', $func);
      oneButton($frame, $row, 5, $but, 'm', $func);
    }
    $row++;
  }
  $row;
}

sub oneButton {
  my($frame,$row,$col,$base,$sfm,$func) = @_;

  my $name = $base.$sfm;

  my $but;
  if (!defined $Chord{"$name"}) {
    if ($sfm ne '') {
      my $ht = Tkx::image_height($base);
      my $wd = Tkx::image_width($base);
      my $w = ($sfm eq 'b') ? Tkx::image_width('flat') :
	  ($sfm eq 'm') ? Tkx::image_width('minor') : Tkx::image_width('sharp');
      Tkx::image_create_photo($name, -height => $ht, -width => ($wd + $w));
      my $subr = 'Tkx::'.$name.'_copy';
      no strict 'refs';
      &$subr($base);
      if ($sfm eq 'm') {
	$sfm = 'minor';
      } elsif ($sfm eq 'b') {
	$sfm = 'flat';
      } else {
	$sfm = 'sharp';
      }
      &$subr($sfm, -to => ($wd,0));
    }
    $but = $frame->new_ttk__button(
      -compound => 'center',
      -text => '',
      -image => $name,
      -style => 'Chord.TButton',
      -width => 3,
      -command => [$func, $name]);
    $Chord{$name} = $but;
  } else {
    $but = $Chord{"$name"};
  }
  my $pad = ($col & 1) ? [2,4] : [4,2];
  $but->g_grid(-row => $row, -column => $col, -padx => $pad, -pady => 2);

  if (@{$Groups{$name}}) {
    $but->g_bind(
      '<Enter>' => sub{ $IDs{$name} = Tkx::after(600, sub{popChords($but, $name, $func);}) }
      );
  } else {
    $but->g_bind('<Enter>' => sub{} );
    $but->g_bind('<Leave>' => sub{} );
  }
  $but->g_bind('<Button-1>' => sub{popCancel($name)});
  $name;
}

my $Pop = '';

sub popCancel {
  my($name) = shift;

  if (popExists('.ch')) {
    Tkx::after_cancel($IDs{$name}) if ($IDs{$name} ne '');
    $Pop->popDestroy();
    $IDs{$name} = '';
  }
}

sub popChords {
  my($but,$name,$func) = @_;

  if (popExists('.ch')) {
    $Pop->{top}->g_raise();
  } elsif (@{$Groups{$name}}) {
    if ($but->m_instate('active')) {
      my($x,$y) = (Tkx::winfo_pointerx($MW), Tkx::winfo_pointery($MW));
      $Pop = CP::Pop->new(1, '.ch', '', $x, $y);
      my($top,$fr) = ($Pop->{top}, $Pop->{frame});
      my($row,$col) = qw/0 0/;
      my $chord = "$name";
      foreach my $ch (sort @{$Groups{$name}}) {
	my $rb = $fr->new_ttk__radiobutton(
	  -text => $ch,
	  -variable => \$chord,
	  -value => $ch,
	  -command => sub{&$func($chord);$Pop->popDestroy();},
	    );
	$rb->g_grid(-row => $row++, -column => $col, -sticky => 'w');
	if ($row == 8) {
	  $row = 0;
	  $col++;
	}
      }
      Tkx::update_idletasks();
      $top->g_raise();
      my($w,$h) = (Tkx::winfo_reqwidth($fr), Tkx::winfo_reqheight($fr));
      $x -= int($w / 2);
      $y -= int($h / 3);
      $top->g_wm_geometry("+$x+$y"); 
      Tkx::after(200, sub{Where($Pop,$x,$y,$w,$h)});
    } else {
      popCancel($name);
    }
  }
}

sub Where {
  my($pop,$Px,$Py,$Pw,$Ph) = @_;

  if (popExists('.ch')) {
    my $top = $pop->{top};
    my($x,$y) = (Tkx::winfo_pointerx($MW), Tkx::winfo_pointery($MW));
    if ($x < $Px || $x >= ($Px + $Pw) || $y < $Py || $y >= ($Py + $Ph)) {
      $pop->popDestroy();
    } else {
      Tkx::after(200, sub{Where($pop,$Px,$Py,$Pw,$Ph)});
    }
  }
}

sub readFing {
  my($inst) = shift();

  %Groups = %Fingers = ();
  if (-e USER."/$inst.chd") {
    do USER."/$inst.chd";
  } else {
    $Nstring = 6;
  }
  no warnings;
  foreach my $ch (qw/Ab A A# Bb B C C# Db D D# Eb E F F# Gb G G#/) {
    $Groups{$ch} = [];
    $Groups{$ch.'m'} = [];
  }
  use warnings;
  foreach my $chd (keys %Fingers) {
    my $sf = '';
    my @c = split('', $chd);
    my $ch = shift(@c);
    my $n = shift(@c);
    if (defined $n && $n =~ /#|b/) {
      $sf = $n;
      $n = shift(@c);
    }
    my $gr = $ch.$sf;
    if (defined $n && $n eq 'm' && (@c == 0 || $c[0] ne 'a')) {
      $gr .= 'm';
    }
    push(@{$Groups{$gr}}, $chd);
  }
}

sub newChord {
  $Centry = "";
  $Ffret = 1;
  # set them all, just in case
  $Canvas->delete('fret');
  foreach (0..($Nstring-1)) {
    setString($_, 'X');
  }
}

# Draw a new blank fretboard with the dot inlays
# in the correct position (assumes $Ffret is set).
# Remove any previous finger blobs and clear the
# @Strings array.
#
sub fretBoard {
  # Clear the Canvas.
  $Canvas->delete('FB','DOT');
  # fretboard position
  $Indent = 10;

  my $top = $Ed->{top};
  my $sw = $BASE;      # these are both half
  my $fw = $BASE * 2;  # the actual width
  my $w = ($Pitch * $Nstring);
  my $fh = int($w * 0.6);
  my $h = $fh * $Nfret;

  # open/unplayed string indicators.
  my $x = $Indent + int($Pitch / 2);
  my $bh;
  foreach my $s (0..($Nstring-1)) {
    my $wid = popButton($top,
			\$String[$s][0],
			sub{setString($s)},
			[qw/0 X/],
			-width => 1,
			-style => 'Menu.TButton',
	);
    $bh = Tkx::winfo_reqheight($wid) if ($s == 0);
    $Canvas->create_window($x,$bh/2, -window => $wid, -anchor => 'center', -tags => 'FB');
    $x += $Pitch;
  }
  $Y = ($bh + $fw + 4);

  # Fret Board
  $Canvas->create_rectangle($Indent, $Y, $Indent+$w, $Y+$h, -fill => BROWN, -tags => 'FB');

  # Frets
  my $y = $Y;
  my $dx = $Indent + $w;
  foreach (0..$Nfret) {
    if ($_ == 0 && $Ffret == 1) {
      $Canvas->create_rectangle($Indent,$y-$fw, $Indent+$w,$y+$fw+2, -fill => BLACK, -tags => 'FB');
    } else {
      $Canvas->create_rectangle($Indent,$y-$fw, $Indent+$w,$y+$fw, -fill => 'grey', -tags => 'FB');
    }
    if ($_ == 1) {
      my $wb = popButton($top,
			\$Ffret,
			\&fretBoard,
			[1..20],
			-width => 2,
			-style => 'Menu.TButton',
	);
      $bh = Tkx::winfo_reqwidth($wb);
      $Canvas->create_window($Indent+$w+8,$y, -window => $wb, -anchor => 'w', -tags => 'FB');
      $dx += ($bh + 4);
      my $wl = $top->new_ttk__label(
	-text => "Base\nFret",
	-font => "Arial 10 bold");
      $Canvas->create_window($Indent+$w+$bh+10,$y, -window => $wl, -anchor => 'w', -tags => 'FB');
      $dx += (Tkx::winfo_reqwidth($wl) + 2);
    }
    # place dot inlays
    my $f = $_ + $Ffret;
    my $yh = $y - int($fh / 2);
    if ($_ > 0) {
      if ($f =~ /^(4|6|8|10|16|18|20|22)$/) {
	my $cx = $Indent + ($w / 2);
	$Canvas->create_oval($cx-$Dot,$yh-$Dot, $cx+$Dot,$yh+$Dot, -fill => 'white', -tags => 'DOT');
      } elsif ($f == 13) {
	my $cx = $Indent + $Pitch;
	$Canvas->create_oval($cx-$Dot,$yh-$Dot, $cx+$Dot,$yh+$Dot, -fill => 'white', -tags => 'DOT');
	$cx = $Indent + $w - $Pitch;
	$Canvas->create_oval($cx-$Dot,$yh-$Dot, $cx+$Dot,$yh+$Dot, -fill => 'white', -tags => 'DOT');
      }
    }
    $y += $fh;
  }

  # Strings
  $x = $Indent + int($Pitch / 2);
  foreach my $s (0..($Nstring-1)) {
    $Canvas->create_rectangle($x-$sw, $Y-$fw, $x+$sw, $Y+$h+$fw,
			     -width => 0, -fill => 'white', -tags => 'FB');
    $x += $Pitch;
  }

  # finger position rectangle detection areas
  foreach my $f (0..($Nfret-1)) {
    foreach my $s (0..($Nstring-1)) {
      my $x = $Indent+($Pitch*$s);
      my $y = $Y+($fh*$f);
      my $wid = $Canvas->create_rectangle($x+2, $y+$fw, $x+$Pitch-2, $y+$fh-$fw,
				      -width => 0, -outline => 'blue', -tags => 'FB');
      $Canvas->bind($wid, "<Button-1>", sub{finger($s, $f+1);});
    }
  }
  foreach (0..($Nstring-1)) {
    setString($_, 'X');
  }
  $Canvas->m_configure(-width => $dx + $Indent, -height => ($Y+$h+$Indent));
}

sub showChord {
  my($name) = shift;

  if (!defined $Fingers{$name}) {
    newChord();
    $Ffret = 1;
  } else {
    $Ffret = $Fingers{$name}{base};
  }
  $Centry = $name;
  fretBoard();
  if (defined $Fingers{$name}) {
    my $s = 0;
    foreach (@{$Fingers{$name}{fret}}) {
      $String[$s][0] = ($_ =~ /X|0/) ? $_ : ' ';
      $String[$s][1] = ($_ eq 'X') ? -1 : $_;
      finger($s++);
    }
  }
}

#
# Show one finger position blob.
# If it's the same position, un-blob it.
# If it's a different position, un-blob the
#   existing position and blob the new one
#
sub finger {
  my($s,$fret) = @_;

  my $str = \@{$String[$s]};
  $fret = $str->[1] if (!defined $fret);
  my $exf = $str->[1];
  if (defined $str->[2]) {
    setString($s, 'X');
    return if ($fret == $exf);
  }
  $str->[0] = ($fret < 0) ? 'X' : ($fret == 0) ? '0' : ' ';
  $str->[1] = $fret;
  if (defined $fret && $fret > 0) {
    my $fx = $Indent + int($Pitch / 2) + ($Pitch * $s);
    my $fh = int($Pitch * $Nstring * 0.6);
    my $dot = int($Dot * 1.3);
    my $yh = $Y + int($fh / 2) + ($fh * ($str->[1] - 1)) + $dot;
    $str->[2] = $Canvas->create_oval($fx-$dot,$yh-$dot, $fx+$dot,$yh+$dot, -fill => '#A0D8FF', -tags => 'fret');
    # Also have to make the finger dot clickable.
    $Canvas->bind($str->[2], "<Button-1>", sub{finger($s, $str->[1]);});
  }
}

sub setString {
  my($str,$val) = @_;

  if (defined $val) {
    $String[$str][0] = $val;
  } else {
    $val = $String[$str][0];
  }
  $String[$str][1] = ($val eq 'X') ? -1 : $val;
  $Canvas->delete($String[$str][2]) if (defined $String[$str][2]);
  $String[$str][2] = undef;
}

sub save {
  if ($Centry ne '') {
    if ($Centry !~ /^[A-G]/) {
      message(QUIZ, "A Chord name MUST start with one\nof the letters A, B, C, D, E, F or G", 3);
      return;
    }
    my $cdp = USER.'/'.$Opt->{Instrument};
    if (-e "$cdp.chd") {
      rename("$cdp.chd", "$cdp.bak");
    }
    unless (open OFH, ">$cdp.chd") {
      message(SAD, "Couldn't create Chord definition file:\n    ($cdp.chd)", 0);
      rename("$cdp.bak", "$cdp.chd") if (-e "$cdp.bak");
      return;
    }
    $Fingers{$Centry}{base} = $Ffret;
    foreach my $s (0..($Nstring-1)) {
      my $fp = $String[$s][1];
      $Fingers{$Centry}{fret}[$s] = ($fp >= 0) ? $fp : 'X';
    }
    print OFH "#!/usr/bin/perl\n";
    print OFH "\$Nstring = $Nstring;\n";
    my $tune;
    if (@Tuning == 0) {
      my %t = (
	Banjo    => 'G D G B D',
	Bass4    => 'E A D G',
	Bass5    => 'B E A D G',
	Guitar   => 'E A D G B E',
	Mandolin => 'G D A E',
	Ukelele  => 'G C E A',
	  );
      $tune = $t{$Opt->{Instrument}};
    } else {
      $tune = join(' ', @Tuning);
    }
    print OFH "\@Tuning = (qw/$tune/);\n";
    print OFH "\%Fingers = (\n";
    foreach my $c (sort keys %Fingers) {
      next if (! defined $Fingers{$c}{base});
      print OFH "'$c'=>{";
      print OFH "base=>".$Fingers{$c}{base}.",";
      print OFH "fret=>[qw/".join(' ', @{$Fingers{$c}{fret}})."/]},\n";
    }
    printf OFH ");\n1;\n";
    close(OFH);
    message(SMILE, "Saved", -1);
  }
  else {
    message(QUIZ, "You need to specify a Chord name at the very least!");
  }
}

#
# CHORDS
#
sub mkChords {
$CHRD{'flat'} = <<'EOXPM';
/* XPM */
static char *flat[] = {
"5 18 15 1",
"  c None",
". c #5f8989",
"# c #000000",
"c c #4d6f6f",
"d c #638f8f",
"g c #73a7a7",
"h c #90d0d0",
"j c #5f8a8a",
"k c #618d8d",
"l c #334a4a",
"m c #659393",
"n c #070a0a",
"p c #1f2d2d",
"q c #4b6d6d",
"B c #202e2e",
"     ",
"gg   ",
".j   ",
"kd   ",
"dppq ",
"dB nh",
"dm ck",
"ddc# ",
"q#l  ",
"h    ",
"     ",
"     ",
"     ",
"     ",
"     ",
"     ",
"     ",
"     "};
EOXPM

$CHRD{'sharp'} = <<'EOXPM';
/* XPM */
static char *sharp[] = {
"5 16 12 1",
"  c None",
". c #344c4c",
"# c #000000",
"b c #202f2f",
"c c #adfbfb",
"d c #659292",
"f c #253535",
"i c #8dcdcd",
"k c #1d2a2a",
"m c #090d0d",
"s c #608b8b",
"v c #94d7d7",
"   s ",
" k kv",
"vbc#d",
"d#f# ",
" f f ",
" f fv",
"v###w",
"dm b ",
" k . ",
" i   ",
"     ",
"     ",
"     ",
"     ",
"     ",
"     "};
EOXPM

$CHRD{'minor'} = <<'EOXPM';
/* XPM */
static char *minor[] = {
"10 16 9 1",
"  c None",
". c #566b6b",
"# c #000000",
"a c #a0c5c5",
"b c #647d7d",
"c c #465858",
"d c #aad1d1",
"f c #95b8b8",
"g c #c7f4f4",
"          ",
"          ",
" gdgdggd  ",
" d#c#.c#b ",
" d#da#df# ",
" d# d# d# ",
" d# d# d# ",
" d# d# d# ",
" d# d# d# ",
"          ",
"          ",
"          ",
"          ",
"          ",
"          ",
"          "};
EOXPM

$CHRD{'A'} = <<'EOXPM';
/* XPM */
static char *A[] = {
"11 16 13 1",
"  c None",
". c #000000",
"# c #3a5858",
"a c #7eb8b8",
"b c #74aaaa",
"c c #5f8d8d",
"e c #6a9c9c",
"f c #476b6b",
"g c #90d1d1",
"h c #a8f4f4",
"i c #98dddd",
"j c #a0e9e9",
"k c #172626",
"           ",
"           ",
"           ",
"           ",
"    #.#    ",
"   j...j   ",
"   b...b   ",
"   #.c.#   ",
"  j.k k.j  ",
"  b.c c.b  ",
"  #.egb.#  ",
" j.......j ",
" b.fgggf.b ",
" #.a   a.# ",
"j..h   h..j",
"hgi     igh"};
EOXPM

$CHRD{'B'} = <<'EOXPM';
/* XPM */
static char *B[] = {
"8 16 14 1",
"  c None",
". c #000000",
"# c #7eb8b8",
"a c #74aaaa",
"b c #5f8d8d",
"d c #6a9c9c",
"e c #2a4242",
"f c #87c5c5",
"g c #476b6b",
"h c #90d1d1",
"i c #a8f4f4",
"j c #98dddd",
"k c #a0e9e9",
"l c #172626",
"        ",
"        ",
"        ",
"        ",
".....ea ",
"..aab..f",
"..   d.a",
"..   b.#",
"..aab.g ",
"......ej",
"..  ib.g",
"..    ..",
"..   k.l",
"..hh#e.d",
"......d ",
"hhhhhi  "};
EOXPM

$CHRD{'brace'} = <<'EOXPM';
/* XPM */
static char *brace[] = {
"34 16 13 1",
"  c None",
". c #000000",
"# c #7eb8b8",
"a c #3a5858",
"b c #74aaaa",
"c c #5f8d8d",
"e c #6a9c9c",
"f c #2a4242",
"g c #476b6b",
"h c #a8f4f4",
"i c #90d1d1",
"j c #98dddd",
"k c #83c0c0",
"                                  ",
"                                  ",
"                                  ",
"  hkkkk                    #bbbi  ",
"  i.fgg                    ega.b  ",
"  i.b                        i.b  ",
"  i.b                        i.b  ",
"  i.b                        i.b  ",
"  i.b                        i.b  ",
"  i.b                        i.b  ",
"  i.b                        i.b  ",
"  i.b                        i.b  ",
"  i.b                        i.b  ",
"  i.b                        i.b  ",
"  i.cii                    jib.b  ",
"  i....                    g...b  "};
EOXPM

$CHRD{'C'} = <<'EOXPM';
/* XPM */
static char *C[] = {
"9 16 14 1",
"  c None",
". c #000000",
"# c #3a5858",
"a c #74aaaa",
"b c #5f8d8d",
"d c #6a9c9c",
"e c #87c5c5",
"f c #476b6b",
"g c #90d1d1",
"h c #a8f4f4",
"i c #98dddd",
"j c #547d7d",
"k c #a0e9e9",
"l c #172626",
"         ",
"         ",
"         ",
"    ggg  ",
"  al...ld",
" d.lagal.",
"k..i   hj",
"a.b      ",
"f.e      ",
"f.g      ",
"f.g      ",
"d.d      ",
"e.lh    a",
" #.#g gf.",
" hf.....f",
"   iaaai "};
EOXPM

$CHRD{'D'} = <<'EOXPM';
/* XPM */
static char *D[] = {
"10 16 14 1",
"  c None",
". c #000000",
"# c #7eb8b8",
"a c #74aaaa",
"b c #5f8d8d",
"d c #6a9c9c",
"e c #2a4242",
"f c #87c5c5",
"g c #476b6b",
"h c #90d1d1",
"i c #a8f4f4",
"j c #98dddd",
"k c #a0e9e9",
"l c #172626",
"          ",
"          ",
"          ",
"          ",
"a....ebk  ",
"a.gade.lf ",
"a.a   a.li",
"a.a    g.a",
"a.a    #.g",
"a.a    h.g",
"a.a    f.g",
"a.a    b.a",
"a.a   j..k",
"a.bhfb..# ",
"a.....ef  ",
"khhhhk    "};
EOXPM

$CHRD{'E'} = <<'EOXPM';
/* XPM */
static char *E[] = {
"8 16 9 1",
"  c None",
". c #000000",
"# c #5f8d8d",
"a c #6a9c9c",
"b c #74aaaa",
"d c #90d1d1",
"e c #2a4242",
"f c #476b6b",
"g c #a0e9e9",
"        ",
"        ",
"        ",
"        ",
"b.......",
"b.fbbbbb",
"b.b     ",
"b.b     ",
"b.effffa",
"b.effffa",
"b.b     ",
"b.b     ",
"b.b     ",
"b.#ddddd",
"b.......",
"gddddddd"};
EOXPM

$CHRD{'F'} = <<'EOXPM';
/* XPM */
static char *F[] = {
"8 16 9 1",
"  c None",
". c #7eb8b8",
"# c #000000",
"a c #74aaaa",
"c c #a8f4f4",
"d c #2a4242",
"e c #476b6b",
"f c #90d1d1",
"g c #98dddd",
"        ",
"        ",
"        ",
"        ",
"f######e",
"f#daaaa.",
"f#e     ",
"f#e     ",
"f#daaaaf",
"f######a",
"f#e     ",
"f#e     ",
"f#e     ",
"f#e     ",
"f#e     ",
"cfg     "};
EOXPM

$CHRD{'G'} = <<'EOXPM';
/* XPM */
static char *G[] = {
"10 16 14 1",
"  c None",
". c #000000",
"# c #7eb8b8",
"a c #3a5858",
"b c #5f8d8d",
"c c #74aaaa",
"e c #6a9c9c",
"f c #2a4242",
"g c #87c5c5",
"h c #476b6b",
"i c #a8f4f4",
"j c #90d1d1",
"k c #a0e9e9",
"l c #172626",
"          ",
"          ",
"          ",
"    kjjk  ",
"  jf....fg",
" j..bjgb.h",
" f.c    je",
"j.f       ",
"c.e       ",
"c.c  #ccc#",
"c.e  h...h",
"g.a    j.h",
"i..j   j.h",
" c.l#  c.h",
"  e......c",
"   kccc#i "};
EOXPM
}

1;
