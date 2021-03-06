package CP::Opt;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

use strict;

use CP::Cconst qw/:PATH :COLOUR :TEXT :SHFL :SMILIE/;
use CP::Global qw/:FUNC :VERS :WIN :OPT/;
use CP::Cmsg;

my @strOpt = (qw/Articles Instrument Media PDFpath PrintMedia
	         BGBridge BGChorus BGComment BGEditor BGHighlight BGTab BGTitle BGVerse
	         FGChord FGComment FGEditor FGHeader FGHighlight FGLabel FGLyric
	         FGNotes FGSNotes FGTab FGTitle FGWords
	         HborderRelief HborderColour CborderRelief CborderColour
	         PopFG PopBG PushFG PushBG MenuFG MenuBG ListFG ListBG EntryFG EntryBG
	         TabAC TabFG TabBG WinBG PageBG SortBy/);
my @numOpt = (qw/AutoSave Bold Heavy Center EditScale
	         FullLineCM CborderWidth
	         FullLineHL HborderWidth
	         Grid HHBL
	         SaveFonts IgnArticle IgnCapo ShowLabels LabelPC
	         TopMargin BottomMargin LeftMargin RightMargin
	         Italic LineSpace LyricLines LyricOnly Nbar NewLine NoWarn
	         OnePDFfile PDFview PDFmake PDFprint
	         Refret RevSort SLrev SharpFlat StaffSpace Together UseBold/);

sub new {
  my($proto) = @_;
  my $class = ref($proto) || $proto;

  my $self = {};
  bless $self, $class;
  default($self);

  if (-e "$Path->{Option}") {
    load($self);
  }
  else {
    save($self);
  }
  return($self);
}

sub default {
  my($self) = shift;

  $self->{Articles}    = 'the|a|an';
  $self->{AutoSave}    = 0;
  $self->{Bold}        = 2;    # This is the 'heavyness' weight for PDF bold fonts.
  $self->{BottomMargin}= INDENT;
  $self->{BGBridge}    = '#FFF8C8';
  $self->{BGChorus}    = '#CDFFCD';
  $self->{BGComment}   = '#D8E8FF';
  $self->{BGEditor}    = '#FFF8E0';
  $self->{BGHighlight} = '#FFFF80';
  $self->{BGTab}       = '#FFFFFF';
  $self->{BGTitle}     = '#FFF0D0';
  $self->{BGVerse}     = '#FFFFFF';
  $self->{Capo}        = 'No';
  $self->{CborderRelief} = 'raised';
  $self->{CborderWidth}  = 2;
  $self->{Center}      = 0;
  $self->{EditScale}   = 4;
  $self->{EntryFG}     = BLACK;
  $self->{EntryBG}     = WHITE;
  $self->{FGChord}     = '#700070';
  $self->{FGComment}   = '#000060';
  $self->{FGEditor}    = '#000000';
  $self->{FGHeader}    = '#D00000';
  $self->{FGHighlight} = '#800000';
  $self->{FGLabel}     = '#900000';
  $self->{FGLyric}     = '#000000';
  $self->{FGNotes}     = '#540054';
  $self->{FGSNotes}    = '#540054';
  $self->{FGTab}       = '#000000';
  $self->{FGTitle}     = '#700070';
  $self->{FGWords}     = '#084040';
  $self->{FullLineCM}  = 0;
  $self->{FullLineHL}  = 0;
  $self->{Grid}        = 0;
  $self->{Heavy}       = 5;
  $self->{HborderRelief} = 'raised';
  $self->{HborderWidth}  = 2;
  $self->{HHBL}        = 0;    # Half Height Blank Lines
  $self->{IgnArticle}  = 0;
  $self->{IgnCapo}     = 0;
  $self->{Instrument}  = 'Guitar';
  $self->{Instruments} = [qw/Banjo Bass4 Bass5 Guitar Mandolin Ukelele/];
  $self->{Italic}      = 12;    # This is the slant angle for PDF italic fonts.
  $self->{LabelPC}     = 6;
  $self->{LeftMargin}  = INDENT;
  $self->{LineSpace}   = 1;
  $self->{ListFG}      = BLACK;
  $self->{ListBG}      = WHITE;
  $self->{LyricLines}  = 1;
  $self->{LyricOnly}   = 0;
  $self->{Media}       = 'a4';
  $self->{MenuFG}      = bFG;
  $self->{MenuBG}      = mBG;
  $self->{Nbar}        = 5;
  $self->{NewLine}     = 0;
  $self->{NoWarn}      = 0;
  $self->{OnePDFfile}  = 0;
  $self->{PageBG}      = WHITE;
  $self->{PDFpath}     = '';
  $self->{PDFview}     = 1;
  $self->{PDFmake}     = 0;
  $self->{PDFprint}    = 0;
  $self->{PrintMedia}  = 'a4';
  $self->{PopFG}       = bFG;
  $self->{PopBG}       = POPBG;
  $self->{PushFG}      = bFG;
  $self->{PushBG}      = bBG;
  $self->{SLrev}       = 0;
  $self->{Refret}      = 0;
  $self->{RevSort}     = 0;
  $self->{RightMargin} = INDENT;
  $self->{SaveFonts}   = 0;
  $self->{SharpFlat}   = SHARP;
  $self->{SortBy}      = 'Alphabetical';
  $self->{StaffSpace}  = 10;
  $self->{ShowLabels}  = 0;
  $self->{TabAC}       = '#CCDCDC';
  $self->{TabFG}       = '#000060';
  $self->{TabBG}       = LGREY;
  $self->{Together}    = 1;
  $self->{TopMargin}   = INDENT;
  $self->{UseBold}     = 1;
  $self->{WinBG}       = MWBG;
  $self->{RecentPro}   = [];
  $self->{RecentTab}   = [];
}

sub resetOpt {
  my($self) = shift;

  return if (msgYesNo("Are you sure you want to reset\nALL options to their defaults?") eq "No");
  $self->default();
  $self->save();
  message(SMILE, "Done");
}

sub add2recent {
  my($self,$name,$key,$refresh) = @_;

  my $idx = 0;
  foreach my $f (@{$self->{$key}}) {
    if ($f eq $name) {
      splice(@{$self->{$key}}, $idx, 1);
      last;
    }
    $idx++;
  }
  unshift(@{$self->{$key}}, $name);
  if (@{$self->{$key}} > 10) {
    pop(@{$self->{$key}});
  }
  &$refresh();
  $self->save();
}

sub load {
  my($self) = shift;

  our($version,%opts);
  do "$Path->{Option}";
  #
  # Now merge the file options into our hash.
  #
  foreach my $o (keys %opts) {
    $self->{$o} = $opts{$o};
  }
  if (! defined $opts{FGChord}) {
    save($self);
  }
  undef %opts;
  if ("$version" ne "$Version") {
    print localtime."\n  $Path->{Option} saved: version mismatch - old=$version new=$Version\n";
    save($self);
  }
#  CP::Win::newLook();
}

sub save {
  my($self) = shift;

  Tkx::update();  # Make sure any variables dependant on buttons/menus get updated.
  my $OFH = openConfig("$Path->{Option}");
  return(0) if ($OFH == 0);

  print $OFH "\%opts = (\n";

  print $OFH "  Instruments => [qw/".join(' ',@{$self->{Instruments}})."/],\n";

  foreach my $str (@strOpt) {
    print $OFH "  $str => '$self->{$str}',\n";
  }

  foreach my $num (@numOpt) {
    print $OFH "  $num => ".($self->{$num}+0).",\n";
  }

  foreach my $t (qw/Pro Tab/) {
    print $OFH "  Recent$t => [\n";
    foreach my $f (@{$self->{"Recent$t"}}) {
      print $OFH "                \"$f\",\n";
    }
    print $OFH "               ],\n";
  }

  printf $OFH ");\n1;\n";

  close($OFH);  
}

sub saveOne {
  my($self,$opt) = @_;

  our($version,%opts);
  do "$Path->{Option}";
  $opts{$opt} = $self->{$opt};
  save(\%opts);
}

# Save the Entry/List/Menu etc. FG and BG to all Collections.
#
sub saveClr2all {
  my($self) = shift;

  our ($which,%coll);
  do USER."/Chordy.cfg";
  #
  # Now read the file options into our hash.
  #
  my $tmpOptPath = $Path->{Option};
  foreach my $name (keys %coll) {
    my $path = $coll{$name};
    my $optpath = "$path/$name/Option.cfg",
    our($version,%opts);
    do "$optpath";
    foreach my $fgbg (qw/EntryFG EntryBG ListFG ListBG MenuFG MenuBG PopFG PopBG PushFG PushBG WinBG/) {
      $opts{$fgbg} = $Opt->{$fgbg};
    }
    bless(\%opts, 'CP::Opt');
    $Path->{Option} = $optpath;
    save(\%opts);
  }
  $Path->{Option} = $tmpOptPath;
  message(SMILE, "Copied", 1);
}

sub changeAll {
  my($self,$opt,$old,$new) = @_;

  my $opath = $Path->{Option};
  foreach my $c (@{$Collection->list()}) {
    $Path->{Option} = $Collection->path($c)."/Option.cfg";
    our($version,%opts);
    do "$Path->{Option}";
    if ($opts{$opt} eq $old) {
      $opts{$opt} = $new;
      save(\%opts);
    }
  }
  $Path->{Option} = $opath;
}

1;
