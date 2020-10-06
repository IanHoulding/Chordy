package CP::Cconst;

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

use Exporter;

# Set OS - this mimics Tkx::tk_windowingsystem()
use constant OS => ($^O =~ /win32/i) ? 'win32' : ($^O eq 'darwin') ? 'aqua' : 'x11';

# Folder Constants
use constant PROG => (OS eq 'win32') ?
    'C:/Program Files/Chordy' :
    (OS eq 'aqua') ? '/Applications/Chordy.app' : '/usr/local/bin';
use constant USER => (OS eq 'win32') ? "C:/Users/$ENV{USERNAME}/Chordy" : "$ENV{HOME}/Chordy";
use constant ERRLOG => USER."/Error.log";
# Constants for lengths and their formats
use constant {
  IN  => (1 / 72),
  INF => "%5.2f",
  MM  => (25.4 / 72),
  MMF => "%4d",
  PT  => 1,
  PTF => "%4d",
};
# Constants for single/multiple PDF files
use constant {
  MULTIPLE => 0,
  SINGLE   => 1,
};
# Constants for use with fonts
use constant {
  PAGEMUL  => 0.7,
  KEYMUL   => 0.8,
};
# Constants for use with fonts and decomposing the ChordPro files
use constant {
  TITLE  =>  0,
  LYRIC  =>  1,
  VERSE  =>  2,
  CHORUS =>  3,
  BRIDGE =>  4,
  CMMNT  =>  5,
  CMMNTI =>  6,
  CMMNTB =>  7,
  HLIGHT =>  8,
  CHORD  =>  9,
  CHRD   => 10,
  GRID   => 11,
  TAB    => 12,
  LABEL  => 13,
  HLINE  => 14,
  VSPACE => 15,
};
  ## Add any new entries before here and then
  ## adjust the values of NL onwards if needed
use constant {
  NL      => 20,
  NP      => 21,
  CFONT   => 23,
  CFSIZ   => 24,
  CFCLR   => 25,
  LFONT   => 26,
  LFSIZ   => 27,
  LFCLR   => 28,
  TFONT   => 29,
  TFSIZ   => 30,
  TFCLR   => 31,
};
# Constants for handling Lyrics and Chords
use constant INDENT  => 5;
# Sharp/Flat constants
use constant {
  SHARP => 1,
  FLAT  => 2,
};
# Chord Index constants
use constant {
  NONE   => 0,
  FIRSTP => 1,
  ALLP   => 2,
};
# Browser constants
use constant {
  SLWID => ($^O =~ /win32/i) ? 38 : 32,
  FILE  =>  1,
  SLNEW =>  2,
  SLREN =>  4,
  SLCLN =>  8,
  SLDEL => 16,
  TABBR => 32,
};
# Make passing message images easier
# Indexes into the Smiley array
use constant {
  SAD   => 0,
  QUIZ  => 1,
  SMILE => 2,
  QUEST => 3,
};
# Various colours
use constant {
  BACKGRND => 1,
  FOREGRND => 2,
  BLANK  => '',
  WHITE  => '#FFFFFF',
  BLACK  => '#000000',
  BROWN  => '#604040',
  DRED   => '#600000',
  DGREEN => '#006000',
  DBLUE  => '#3030D0',
  PBLUE  => '#D8FFFF',
  SELECT => '#F0E0D0',
  RED    => '#D00000',
  GREEN  => '#00D000',
  BLUE   => '#0000D0',
  MWBG   => '#EEEEE0',  # MainWindow
  VLMWBG => '#FFF8F0',
  DBLBG  => '#B0D0D0',
  POPBG  => '#E0FFE0',
  DPOPBG => '#D0F0D0',
  bFG    => '#000080',  # The buttons
  bBG    => '#C8C8FF',  #
  mBG    => '#D0E8D0',  #
  fBG    => '#E8D0D0',  #
  bACT   => '#A8A8DF',  #
  HFG    => '#500080',  # Heading text
  RFG    => '#A00000',
  OWHITE => '#E8E8E8',
  LGREY  => '#D0D0D0',
  DGREY  => '#808080',
  MAGENT => '#700070',
};
#
# Constants for the Tab Editor
#
# Constants for changes to a Bar
use constant {
  PAGE => 0,
  EDIT => 1,
};
use constant {
  VOLTA  => 1,
  HEAD   => 2,
  REPEAT => 4,
  NOTE   => 8,
};
# Constants for use with fonts
# use constant TITLE  => 0, --- see above
use constant {
  NOTES  => 1,
  SNOTES => 2,
  HEADER => 3,
  WORDS  => 4,
  RESTS  => 5,
  RESTFONT => 'TabSym',
};
# Constants for Bar copy & insertion
use constant {
  HONLY   =>  1,
  NONLY   =>  2,
  HANDN   =>  3,
  BEFORE  => -1,
  REPLACE =>  0,
  AFTER   =>  1,
  UPDATE  =>  2,
};
# Constant for the Bar number Canvas width
use constant BNUMW => 30;
# Constants for Drawing Staves
use constant {
  FAT   => 1.5,
  THICK => 1.0,
  THIN  => 0.5,
};
# Constants for media player
use constant {
  STOP  => 0,
  PLAY  => 1,
  PAUSE => 2,
  LOOP  => 3,
  MET   => 4,
  RATE  => 8000,
};

our @ISA = qw/Exporter/;

our @EXPORT_OK = qw/
  OS
  PROG USER ERRLOG
  MM IN PT MMF INF PTF
  MULTIPLE SINGLE
  PAGEMUL KEYMUL
  NL LYRIC VERSE CHORUS BRIDGE CMMNT CMMNTI CMMNTB
    HLIGHT CHORD TITLE NP CHRD GRID TAB LABEL HLINE VSPACE
    CFONT CFSIZ CFCLR LFONT LFSIZ LFCLR TFONT TFSIZ TFCLR
  INDENT
  SHARP FLAT
  NONE FIRSTP ALLP
  SLWID FILE SLNEW SLREN SLCLN SLDEL SLSEL TABBR
  SAD QUIZ SMILE QUEST
  BACKGRND FOREGRND BLANK WHITE BLACK BROWN DRED DGREEN DBLUE PBLUE SELECT
  RED GREEN BLUE MWBG
  DBLBG VLMWBG POPBG DPOPBG bFG bBG mBG fBG bACT HFG RFG
  OWHITE LGREY DGREY MAGENT

  PAGE EDIT
    VOLTA HEADER REPEAT NOTE
    NOTES SNOTES HEADER WORDS RESTS RESTFONT
    HONLY NONLY HANDN BEFORE REPLACE AFTER UPDATE
    BNUMW FAT THICK THIN
  STOP PLAY PAUSE LOOP MET RATE
/;

our %EXPORT_TAGS = (
  OS      => [qw/OS/],
  PATH    => [qw/PROG USER ERRLOG/],
  LENGTH  => [qw/MM IN PT MMF INF PTF/],
  PDF     => [qw/MULTIPLE SINGLE/],
  FONT    => [qw/PAGEMUL KEYMUL RESTFONT/],
  MUSIC   => [qw/NL LYRIC VERSE CHORUS BRIDGE CMMNT CMMNTI CMMNTB
                 HLIGHT CHORD TITLE NP CHRD GRID TAB LABEL HLINE VSPACE
                 CFONT CFSIZ CFCLR LFONT LFSIZ LFCLR TFONT TFSIZ TFCLR/],
  TEXT    => [qw/INDENT/],
  SHFL    => [qw/SHARP FLAT/],
  INDEX   => [qw/NONE FIRSTP ALLP/],
  BROWSE  => [qw/SLWID FILE SLNEW SLREN SLCLN SLDEL SLSEL TABBR/],
  SMILIE  => [qw/SAD QUIZ SMILE QUEST/],
  COLOUR  => [qw/BACKGRND FOREGRND BLANK WHITE BLACK BROWN DRED DGREEN DBLUE PBLUE SELECT
	         RED GREEN BLUE MWBG
	         DBLBG VLMWBG POPBG DPOPBG bFG bBG mBG fBG bACT
	         HFG RFG OWHITE LGREY DGREY MAGENT/],

  TAB     => [qw/PAGE EDIT
	         VOLTA HEADER REPEAT NOTE
	         TITLE NOTES SNOTES HEADER WORDS RESTS
	         HONLY NONLY HANDN BEFORE REPLACE AFTER UPDATE
	         BNUMW FAT THICK THIN/],

  PLAY    => [qw/STOP PLAY PAUSE LOOP MET RATE/],
    );

1;
