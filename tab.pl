#!/usr/bin/perl

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

BEGIN {
  use FindBin 1.51 qw( $RealBin );
  use lib (($^O =~ /win32/i) ? $RealBin : ($^O =~ /darwin/i) ? '/Applications/Chordy.app/lib' : '/usr/local/lib/Chordy');
  if ($^O =~ /win32/i) {
    $ENV{PATH} = "C:\\Program Files\\Chordy\\Tcl\\bin;$ENV{PATH}";
  }
}

use strict;

use PDF::API2;
use PDF::API2::Resource::CIDFont::TrueType;
use CP::Cconst qw(:OS :PATH :LENGTH :PDF :MUSIC :TEXT :SHFL :INDEX :BROWSE :SMILIE :COLOUR);
use CP::Global qw/:FUNC :PATH :OPT :WIN :CHORD :SCALE :XPM/;
use CP::Pop qw/:POP :MENU/;
use CP::Collection;
use CP::Path;
use CP::Cmnd;
use CP::Opt;
use CP::Media;
use CP::Swatch;
use CP::Browser;
use CP::Cmsg;
use CP::Fonts qw/&fontSetup/;
use CP::Win;
use CP::Tab;
use CP::TabPDF;

#
#  Directive = {...:txt}
#    One bar = []
#     A rest = r,duration,position
#     A note = string,fret,position
#
# Directives appear as the first and ONLY item on a line.
# The lowest sounding string is 1 (low E on a 4 string bass or 6 string electric),
# the next (A) is 2 etc.
# 'fret' is fairly obvious with 0 being the open string.
# 'position' is a number from 0 to 31 and represents the time interval for a
# demi-semi-quaver
# So, for example, the first note in a bar is at 'position' 0. If the first note
# is a crotchet, the second note would be at 'position' 8, the third at 16 and
# the last crotchet at 24 (assuming 4/4 timing :-) )
#
# So a bar that traditionally looks like this:
# +-----------------+
# +-----------------+
# +-----2-------3---+
# +-3-------5-----3-+
#
# would look like this:
#
# [1(3,0 5,16 3,28) 2(2,8 3,24)]
#
# but could just as easily be written as:
#
# [1(3,0) 2(2,8) 1(5,16) 2(3,24) 1(3,28)]
#
# It depends on what you find easiest and/or more readable.
# See Note.pm for a more detailed explanation of notes.
#

use Getopt::Std;
our($opt_d);
getopts('d');

if (! -e ERRLOG) {
  open OFH, ">", ERRLOG;
  print OFH "Created: ".localtime."\n";
  close OFH;
}
if (!defined $opt_d) {
  open STDERR, '>>', ERRLOG or die "Can't redirect STDERR: $!";
  if (OS ne 'aqua') {
    open STDOUT, ">&STDERR" or die "Can't dup STDOUT to STDERR: $!";
  }
}

our $FN = '';
if (@ARGV) {
  if (-e $ARGV[0]) {
    $FN = $ARGV[0];
  }
}

##########################################
#### Define a whole bunch of defaults ####

setDefaults();

fontSetup();

restXPMs();

CP::Win::init();
makeImage("Ticon", \%XPM);
$MW->g_wm_iconphoto("Ticon");
$MW->g_wm_protocol('WM_DELETE_WINDOW' => \&exitTab);
#
# To be able to realisticaly manipulate Canvas fonts to look like the PDF result we
# need a screen scaling of 1:1 but that makes (on my screen, at least) all the button
# etc. fonts too small so we scale them up by whatever the screen scaling factor is.
#
my $sc = POSIX::ceil(Tkx::tk_scaling()*10) / 10;
if ($sc != 1) {
  Tkx::tk_scaling(1);
  foreach (qw/TkDefaultFont TkTextFont TkFixedFont TkMenuFont TkHeadingFont TkCaptionFont TkSmallCaptionFont TkIconFont TkTooltipFont BTkDefaultFont STkDefaultFont/) {
    my $sz = Tkx::font_actual($_, '-size');
    $sz = int($sz * $sc);
    Tkx::font_configure($_, -size => $sz);
  }
}

CP::Tab->new($FN);

tabTitle($FN);

#Tkx::set("perl_bgerror", sub {
#  print "Error: @_\n";
#});

$SIG{CHLD} = sub {wait if (shift eq "CHLD");};

$MW->g_wm_deiconify();
$MW->g_raise();
Tkx::MainLoop();

###########################################################################################
###########################################################################################

sub setEdited {
  $Tab->{edited} = shift;
  tabTitle($Tab->{fileName});
}

sub tabTitle {
  my($fn) = shift;

  my $ed = ($Tab->{edited}) ? ' (edited)' : '';
  $MW->g_wm_title("Tab Editor  |  Collection: ".$Collection->name()."  |  Media: $Opt->{Media}  |  File: $fn$ed");
}

sub openTab {
  my $fn = (CP::Browser->new($MW, TABBR, $Path->{Tab}, '.tab'))[0];
  if ($fn ne '') {
    CP::Tab->new("$Path->{Tab}/$fn");
  }
}

sub newTab {
  if (checkSave() ne 'Cancel') {
    makeNew() if ($Tab->{fileName} eq '');
    CP::Tab->new("$Path->{Tab}/$Tab->{fileName}");
    tabTitle($Tab->{fileName});
  }
}

sub makeNew {
  my $fn = "";
  my $ans = msgSet("Enter a name for the new file", \$fn);
  return if ($ans eq "Cancel");
  if ($fn eq "") {
    message(QUIZ, "How about a file name then?");
    return(0);
  }
  (my $title = $fn) =~ s/.tab$//i;
  $fn = $title.'.tab';
  if (-e "$Path->{Tab}/$fn") {
    $ans = msgYesNo("$fn already exists.\nDo you want to overwrite it?");
    return(0) if ($ans eq "No");
  }
  open OFH, ">", "$Path->{Tab}/$fn" or die "failed open '$Path->{Tab}/$fn' : $!\n";
  print OFH "{title:$title}\n";
  close OFH;
  $Tab->{fileName} = $fn;
  return(1);
}

sub delTab {
  if ($Tab->{fileName} ne '') {
    my $ans = msgYesNo("Do you really want to delete\n  $Tab->{fileName}");
    return if ($ans eq "No");
    unlink("$Path->{Tab}/$Tab->{fileName}");
    CP::Tab->new('');
  }
}

sub renameTab {
  if ($Tab->{fileName} ne '') {
    my $ofn = $Tab->{fileName};
    my $newfn = $ofn;
    my $ans = msgSet("Enter a new name for the file:", \$newfn);
    return if ($ans eq 'Cancel');
    $newfn =~ s/\.tab$//i;
    $newfn .= '.tab';
    if (-e "$Path->{Tab}/$newfn") {
      $ans = msgYesNo("$Path->{Tab}/$newfn\nFile already exists.\nDo you want to replace it?");
      return if ($ans eq "No");
    }
    rename("$Path->{Tab}/$ofn", "$Path->{Tab}/$newfn");
    $Tab->{fileName} = $newfn;
    tabTitle("$newfn");
  } else {
    Tkx::bell();
  }
}

sub closeTab {
  if (checkSave() ne 'Cancel') {
    CP::Tab->new('');
  }
}

sub exportTab {
  if ($Tab->{loaded} == 0) {
    Tkx::bell();
    return;
  }
  my $dest = Tkx::tk___chooseDirectory(
    -title => "Choose Destination Folder",
    -initialdir => "$Home",);
  $dest =~ s/\/$//;
  if ($dest ne '') {
    if ($dest eq $Path->{Tab}) {
      message(QUIZ, "Destination Folder cannot be:\n    \"$dest\"\nPlease try again!");
      return;
    }
    if (! -e $dest) {
      make_path($dest, {chmod => 0777});
    }
    if ($Tab->save($dest, 0) == 1) {
      # We now have the current Tab in a temporary file: "$Path->{Temp}/$Tab->{fileName}"
      my $tmp = "$Path->{Temp}/$Tab->{fileName}";
      my $txt = read_file($tmp);
      if (write_file("$dest/$Tab->{fileName}", $txt) == 1) {
	unlink($tmp);
      } else {
	message(SAD, "Failed to write \"$Tab->{fileName}\" to \"$dest\"\nOriginal is in: \"$tmp\"");
	return;
      }
      message(SMILE, "\"$Tab->{fileName}\" Exported", -1);
    }
  }
}

sub exitTab {
  if (checkSave() ne 'Cancel') {
    $MW->g_destroy();
    exit(0);
  }
}

sub checkSave {
  my $ans = '';
  if ($Tab->{edited}) {
    $ans = msgYesNoCan("Do you want to save any changes made to:\n$Tab->{fileName}");
    if ($ans eq 'Yes') {
      $Tab->save();
      $Tab->{fileName} = '';
    }
  }
  return($ans);
}

sub collectionSel {
  my $cc = $Collection->name();
  popMenu(\$cc, undef, [sort keys %{$Collection}]);
  $Collection->change($cc);
  $Tab->drawPageWin();
}

sub mediaSel {
  popMenu(\$Opt->{Media}, undef, [CP::Media::list()]);
  $Media = $Media->change($Opt->{Media});
  $Tab->drawPageWin();
}

sub mediaSave {
  $Media->save($Opt->{Media});
}

sub mediaLoad {
  $Media->load();
}

sub mediaDefault {
  $Media->default();
}

sub fontEdit {
  my $pop = CP::Pop->new(0, '.fo', 'Font Selector', -1, -1);
  return if ($pop eq '');
  my($top,$wt) = ($pop->{top}, $pop->{frame});

  my $Done;
  my $mcopy = {};
  $Media->copy($mcopy);

  $wt->m_configure(qw/-relief raised -borderwidth 2/);

  my $tf = $wt->new_ttk__frame(qw/-borderwidth 2 -relief ridge/, -padding => [4,4,4,4]);
  $tf->g_pack(qw/-side top/);

  my $ff = $tf->new_ttk__frame();
  $ff->g_pack(qw/-side top -expand 1 -fill x/);

  my $df = $tf->new_ttk__frame();
  $df->g_pack(qw/-side bottom -expand 1 -fill x/, -pady => [12,4]);
  CP::Win::defButtons($df, 'Fonts', \&mediaSave, \&mediaLoad, \&mediaDefault);

  my $bf = $wt->new_ttk__frame();
  $bf->g_pack(qw/-side top -expand 1 -fill x/);

  makeImage("tick", \%XPM);

  CP::Fonts::fonts($ff, [qw/Title Header Notes SNotes Words/]);

  ($bf->new_ttk__button(-text => "Cancel", -command => sub{$Done = "Cancel";})
  )->g_grid(qw/-row 0 -column 0 -padx 60/, -pady => [4,0]);
  ($bf->new_ttk__button(-text => "OK", -command => sub{$Done = "OK";})
  )->g_grid(qw/-row 0 -column 1 -sticky e -padx 60/, -pady => [4,0]);

  Tkx::vwait(\$Done);
  if ($Done eq "OK") {
    $Tab->drawPageWin();
  } else {
    $mcopy->copy($Media);
  }
  $pop->destroy();
}

sub saveOpt {
  $Opt->save();
}

sub loadOpt {
  $Opt = CP::Opt->new();
}

# Place-holder for Collection.pm which calls this in chordy.pl
sub selectClear {}

#################################################
# The rest of this file is XPM image definitions
#################################################

sub restXPMs {
$XPM{'b1'} = <<'EOXPM',
/* XPM */
static char * b1[] = {
"20 20 2 1",
"  s None c None",
". c #000000",
"                    ",
"                    ",
"                    ",
"                    ",
"....................",
"    ............    ",
"    ............    ",
"    ............    ",
"                    ",
"                    ",
"                    ",
"....................",
"                    ",
"                    ",
"                    ",
"                    ",
"                    ",
"                    ",
"                    ",
"                    "};
EOXPM

$XPM{'b16'} = <<'EOXPM',
/* XPM */
static char * b16[] = {
"20 20 9 1",
" 	c None",
".	c #000400",
"+	c #1B1D1B",
"@	c #373836",
"#	c #525451",
"$	c #60625F",
"%	c #878986",
"&	c #90928F",
"*	c #B1B3B0",
"                    ",
"                    ",
"       &.&**@       ",
"       ...&%@       ",
"       &..+.$       ",
"        &**@&       ",
"          *@*       ",
"      &.& &@        ",
"      ... ##        ",
"      &..@.%        ",
"       &*%+*        ",
"         &@         ",
"         ##         ",
"         @%         ",
"        *+*         ",
"        %+          ",
"        ##          ",
"                    ",
"                    ",
"                    "};
EOXPM

$XPM{'b2'} = <<'EOXPM',
/* XPM */
static char * b2[] = {
"20 20 2 1",
"  s None c None",
". c #000000",
"                    ",
"                    ",
"                    ",
"                    ",
"....................",
"                    ",
"                    ",
"                    ",
"    ............    ",
"    ............    ",
"    ............    ",
"....................",
"                    ",
"                    ",
"                    ",
"                    ",
"                    ",
"                    ",
"                    ",
"                    "};
EOXPM

$XPM{'b32'} = <<'EOXPM',
/* XPM */
static char * b32[] = {
"20 20 9 1",
" 	c None",
".	c #010400",
"+	c #1C1E1C",
"@	c #373936",
"#	c #515351",
"$	c #6C6E6B",
"%	c #898B88",
"&	c #A5A7A4",
"*	c #B6B9B6",
"         %.% &      ",
"         ...&@      ",
"         %..+#      ",
"          %*%$      ",
"            #%      ",
"       %.%**@*      ",
"       ...%%@       ",
"       %..+.$       ",
"        %*&@%       ",
"          *@*       ",
"      %.% %@        ",
"      ... ##        ",
"      %..@.%        ",
"       %*$+&        ",
"         %@         ",
"         ##         ",
"         @%         ",
"        &+&         ",
"        $+          ",
"        ##          "};
EOXPM

$XPM{'b4'} = <<'EOXPM',
/* XPM */
static char * b14[] = {
"20 20 8 1",
"  s None c None",
". c #282828",
"# c #000000",
"a c #787878",
"b c #313131",
"c c #d1d1d1",
"d c #797979",
"e c #a4a4a4",
"        b           ",
"        a#          ",
"         ab         ",
"          #e        ",
"          ##e       ",
"         e###       ",
"        e####       ",
"        #####       ",
"        ####e       ",
"        ###e        ",
"        e##         ",
"         e#         ",
"          a#        ",
"        .###e       ",
"       e#####       ",
"       ####e        ",
"       ###e         ",
"       d##          ",
"        ##          ",
"         c          "};
EOXPM

$XPM{'b8'} = <<'EOXPM',
/* XPM */
static char * b18[] = {
"20 20 9 1",
" 	c None",
".	c #000300",
"+	c #1B1D1A",
"@	c #383A38",
"#	c #4F514E",
"$	c #696B68",
"%	c #8A8C89",
"&	c #A9ABA8",
"*	c #B9BCB8",
"                    ",
"                    ",
"                    ",
"                    ",
"       %.%**@       ",
"       ...%%@       ",
"       %..+.$       ",
"        %*&@%       ",
"          *@&       ",
"          %@        ",
"          ##        ",
"         *.%        ",
"         $+&        ",
"         %@         ",
"         ##         ",
"                    ",
"                    ",
"                    ",
"                    ",
"                    "};
EOXPM

$XPM{Ticon} = <<'EOXPM',
/* XPM */
static char * Ticon[] = {
"32 32 16 1",
". c #000000",
"# c #a8a8a8",
"a c #1a1a1a",
"b c #8c8c8c",
"c c #b7b7b7",
"d c #fefefe",
"e c #4e4e4e",
"f c #9b9b9b",
"g c #c3c3c3",
"h c #7c7c7c",
"i c #ffffff",
"j c #6b6b6b",
"k c #2a2a2a",
"l c #9c9c9c",
"m c #c4c4c4",
"n c #696969",
"diididddiddidddiidddim#####miiii",
"ddiddddiiidiidididddd#.....jiiid",
"iiiiiiiiiiiiiiiiiiiii#.#iiiiiiii",
"iiiiiiiiiiiiiiiiiiiii#.#iiiiiiii",
"iiiiiiiiiiiiiiiiiiiii#.j##iiiiii",
"flffffllllflflfllfffln....abllfl",
"................................",
"iiiiiiiiiiiiiiiiiiiiiiiiim.jiiii",
"iiiiiiiiiiiiiiiiiiiiiiiiim.jiiii",
"iiiiiiiiiiiiiiiiiiiiihcime.#iiii",
"iiiiiiiiiiiiiiiiiiiii.....jiiiii",
"iiiiiiiiiiiiiiiiiiiiim###miiiiii",
"iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii",
"lfllfllllffllfflfflllflllffflllf",
"................................",
"iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii",
"iiiigfjjbgiiiiiiiiiiiiiiiiiiiiii",
"iiii..ee.kgiiiiiiiiiiiiiiiiiiiii",
"iiiihgddh.#iiiiiiiiiiiiiiiiiiiii",
"iiiiiiddf.#iiiiiiiiiiiiiiiiiiiii",
"iiiiiig#.kiiiiiiiiiiiiiiiiiiiiii",
"fffflf...nllffflffffflfllfflllff",
"................................",
"iiiiiiiim.jiiiiiiiiiiiiiiiiiiiii",
"iiiiiiiig.jiiiiiiiiiiiiiiiiiiiii",
"iiigegige.giiiiiiiiiiiiiiiiiiiii",
"iiig.....eiiiiiiiiiiiiiiiiiiiiii",
"iiiig###miiiiiiiiiiiiiiiiiiiiiii",
"iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii",
"fllfllfllllffllfflllfffllffflllf",
"................................",
"iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii"};
EOXPM
}
