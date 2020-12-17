package CP::Tab;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

# List of tags used for various elements within the display
# where a # indicates the bar's page index.
#
#  EDIT PAGE
#  barn       Bar # header for edit display
#       b#    Lines which create bars on the page display
#  ebl        Lines which create the edit display bar
#       bg#   Bar background rectangle (always below b#/ebl)
#       det#  Detection rectangle (for page view) that is raised to the top
#
#  rep           Repeat start/end indicator
#       lyr#     Lyric lines
#  fret bar#     All notes/rests in a bar
#       bar#     All bar headers and repeats
#
#  pcnt     Bar numbers down the side of the page display
#  phdr     Everything in the page header - Title, Key, etc.

use strict;
use warnings;

BEGIN {
  our @ISA = qw(Exporter);
  our @EXPORT = qw/$EditBar $EditBar1/;
  require Exporter;
}

use Tkx;
use CP::Cconst qw/:LENGTH :SHFL :TEXT :SMILIE :COLOUR :FONT :TAB/;
use CP::Global qw/:FUNC :OPT :WIN :PATH :XPM :CHORD :SCALE/;
use File::Basename;
use File::Slurp;
use CP::Offset;
use CP::Bar;
use CP::Cmsg;
use CP::TabWin;
use CP::Lyric;
use POSIX;

our($EditBar, $EditBar1);
our(@pageXY, $SaveID);
our $OneOrMore = "Please select one or more bars first.";

@Tuning = ();

# $fn is a complete path + file_name
#
sub new {
  my($proto,$fn) = @_;

  CORE::state $Tab;
  if (! defined $Tab) {
    my $class = ref($proto) || $proto;
    $Tab = {};
    $Tab->{eWin} = '';
    bless $Tab, $class;
  }
  if ($fn eq '_EXIT_' && $Tab->checkSave() ne 'Cancel') {
    $MW->g_destroy();
    exit(0);
  }
  # These keys do NOT get reset:
  #   eWin eCan nFrm nCan pFrm pCan pOffset eOffset
  #
  $Tab->{fileName} = '';
  $Tab->{PDFname}  = '';
  $Tab->{loaded}   = 0;
  $Tab->{pageNum}  = 0;   # Keeps track of the current page we're working on. (1st page = 0)
  $Tab->{nPage}    = 0;   # Keeps track of the number of pages.
  $Tab->{rowsPP}   = 0;
  $Tab->{shbr}     = '';  # Can be one of 's', 'h', 'b' or 'r'.
  $Tab->{fret}     = '';
  $Tab->{edited}   = 0;
  $Tab->{selected} = 0;
  $Tab->{select1}  = 0;
  $Tab->{select2}  = 0;
  $Tab->{title}    = '';
  $Tab->{key}      = '-';
  $Tab->{note}     = '';
  $Tab->{tempo}    = 40;
  $Tab->{Timing}   = '4/4';
  $Tab->{BarEnd}   = 32;
  $Tab->{trans}    = 0;
  $Tab->{bars}     = 0;
  $Tab->{lastBar}  = 0;
  $Tab->{staveGap} = 0;
  $Tab->{lyricSpace} = 0;
  $Tab->{lyricEdit}  = 0;
  $Tab->{lyrics}   = CP::Lyric->new($Tab); # array containing ALL the lyrics
  $Tab->{rests}    = {};
  $Tab->{pstart}   = [];
  $Tab->{noteFsize} = 'Normal';
  foreach my $type (qw/title head note snote word tab/) {
    my $font = "${type}Font";
    delete $Tab->{$font};
  }

  if ($fn ne '') {
    $Tab->{fileName} = fileparse($fn);
    load($Tab, $fn);
    if ($Tab->{title} eq '') {
      ($Tab->{title} = $Tab->{fileName}) =~ s/\.tab(.\d+)?$//;
    }
    $Tab->{PDFname} = $Tab->{title}.'.pdf';
  }
  $Tab;
}

sub setEdited {
  my($self,$edit) = @_;

  $self->{edited} = ($self->{fileName} ne '') ? shift : 0;
  tabTitle($self, $self->{fileName});
}

sub tabTitle {
  my($self,$fn) = @_;

  my $ed = ($self->{edited}) ? ' (edited)' : '';
  $MW->g_wm_title("Tab Editor  |  Collection: ".$Collection->{name}."  |  Media: $Opt->{Media}  |  Tab: $fn$ed");
}

sub drawPageWin {
  my($self) = shift;

  readChords();  # Need $Nstring and @Tuning
  offsets($self);
  setXY($self);
  CP::TabWin::pageWindow($self);
  CP::TabWin::editWindow($self);
  $self->tabTitle($self->{fileName});
  indexBars($self);
  $self->pageHdr();
  $self->newPage(0);
}

#
# Each bar occupies a discreate rectangle on the page. This sub
# works out all the sizes and thence offset values (these are all
# in points).
# Everything changes if lyricLines, StaffSpace, bars/stave or any font changes.
#
sub offsets {
  my($self) = shift;

  # We can't work out the offsets unless
  # we have the correct Font distances.
  makeFonts($self);

  my %off = ();
  $off{scale} = 1;
  # thick must be twice thin - see Cconst.pm
  $off{fat}   = FAT;
  $off{thick} = THICK;
  $off{thin}  = THIN;
  $self->{pageHeader} = $self->{titleSize} + 3;
  $self->{barTop} = $self->{pageHeader} + 1 + $Opt->{TopMargin};

  $off{width} = int(($Media->{width} - ($Opt->{LeftMargin} + $Opt->{RightMargin})) / $Opt->{Nbar});
  my($t,$_t) = split('/', $self->{Timing});
  $self->{BarEnd} = $t * 8;
  $off{interval} = $off{width} / (($t * 8) + 3);
  # Distance between lines of a Staff.
  $off{staffSpace} = $Opt->{StaffSpace};
  $off{staffHeight} = $off{staffSpace} * ($Nstring - 1);

  # With something like "Verse" above a bar, the top staff line (staffY} is:
  #    Volta bar + The Text + 1/2 Note text size
  $off{staffX} = 0;
  $off{headY}  = $off{fat} + $self->{headSize} + 1;
  $off{staffY} = $off{header} = ceil($off{headY} + ($self->{noteCap} / 2));
  $off{staff0} = $off{header} + $off{staffHeight};

  # This is the TOP of the lyric area
  $off{lyricY} = int($off{staff0} + ceil($self->{noteSize} / 2));

  $off{lyricHeight} = 0;
  if ($Opt->{LyricLines}) {
    my $wid = $MW->new_tk__text(
      qw/-height 1 -borderwidth 0 -selectborderwidth 0 -spacing1 0 -spacing2 0/,
      -spacing3 => $self->{lyricSpace},
      -font => $self->{wordFont});
    $off{lyricHeight} = Tkx::winfo_reqheight($wid) * $Opt->{LyricLines};
    $wid->g_destroy();
  }

  my $pht = $Media->{height} - $self->{barTop} - $Opt->{BottomMargin};

  $off{height} = $off{lyricY} + $off{lyricHeight} + $self->{staveGap};

  $self->{rowsPP} = int($pht / $off{height});
  $self->{barsPP} = $Opt->{Nbar} * $self->{rowsPP};
  $off{pos0} = $off{interval} * 2;

  if (! defined $self->{pOffset}) {
    $self->{pOffset} = CP::Offset->new(\%off);
  } else {
    $self->{pOffset}->update(\%off);
  }
  #
  # Now scale everything up for the Edit Bar
  #
  my $editsc = $Opt->{EditScale};
  foreach my $v (qw/interval pos0 scale staffHeight staffSpace width fat thick thin/) {
    $off{$v} *= $editsc;
  }
  # These entries are not just multiples of the Edit Scale because
  # they depend (amonst other things) on the font size differences.
  $off{headY}  = $off{fat} + $self->{eheadSize} + 2;
  $off{staffY} = $off{header} = ceil($off{headY} + ceil($self->{enoteCap} / 2)); 
  $off{staff0} = $off{staffY} + $off{staffHeight};
  $off{height} = $off{staff0} + $self->{enoteCap};
  if (! defined $self->{eOffset}) {
    $self->{eOffset} = CP::Offset->new(\%off);
  } else {
    $self->{eOffset}->update(\%off);
  }
}

#
# Set up fonts
#
# As far as I can tell, text positioning is based on (Base Line - Descender).
# So if we use '-anchor => sw' in create_text, the lowest Descender (eg: the tail of a 'y')
# will sit on the 'y' coord. The text base line will be fnt->{des} above that and the top
# of the text will be fnt->{size) above the -anchor line.
# The formula ((fnt->{des} + $fnt->{size}) gives the MAXIMUM height of any text
# ie. Caps + descenders;
#
# One minor benefit of the Canvas text is that printing fret numbers is easy
# as create_text with no -anchor will center the number around the x,y co-ords.
#
sub makeFonts {
  my($self) = shift;

  my $es = $Opt->{EditScale};
  foreach my $fnt ([qw/Title  title/],
		   [qw/Header head/],
		   [qw/Notes  note/],
		   [qw/SNotes snote/],
		   [qw/Words  word/]) {
    my($med,$type) = @$fnt;
    my($fam,$size,$wt,$sl,$clr,$esize);
    my $font = "${type}Font";
    if (defined $self->{$font} && $self->{$font} =~ /\{([^\}]*)\}\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
      $fam = $1;
      $size = $2;
      $wt = $3;
      $sl = $4;
      $clr = $5;
    } else {
      my $fp = $Media->{$med};
      $fam = $fp->{family};
      $size = $fp->{size};
      $wt = $fp->{weight};
      $sl = $fp->{slant};
      $clr = $fp->{color};
    }
    $esize = int($size * $es);
    # PDF 'heavy' fonts show as bold on the screen.
    $wt = 'bold' if ($wt eq 'heavy');
    # Remove the colour element to form a pure font spec.
    $self->{"$font"} = "{$fam} $size $wt $sl";
    my $dsc = Tkx::font_metrics($self->{"$font"}, '-descent');
    $self->{"${type}Cap"} = $size - $dsc;
    $self->{"${type}Size"} = $size;
    $self->{"e$font"} = "{$fam} $esize $wt $sl";
    $dsc = Tkx::font_metrics($self->{"e$font"}, '-descent');
    $self->{"e${type}Cap"} = $esize - $dsc;
    $self->{"e${type}Size"} = $esize;

    $self->{"${type}Color"} = $clr;
  }
  
  my $size = ceil($self->{titleSize} * KEYMUL);
  $self->{keyFont} = newFont($self, $self->{titleFont}, $size);
  $self->{keySize} = $size;

  $size = ceil($self->{titleSize} * PAGEMUL);
  $self->{pageFont} = newFont($self, $self->{titleFont}, $size);
  $self->{pageSize} = $size;

  $self->{barnFont} = "{Times New Roman} 12 bold roman";
  $self->{barnSize} = 12;

  $size = int($Opt->{StaffSpace} * 2.5);

  $self->{symFont} = RESTFONT." $size normal roman";
  $self->{symSize} = $size;
  $size *= $Opt->{EditScale};
  $self->{esymFont} = RESTFONT." $size normal roman";
  $self->{esymSize} = $size;
}

sub newFont {
  my($self,$font,$size) = @_;

  if ($size < 1.0) {
    (my $orgs = $font) =~ s/(\{[^}]*\})\s+(\d+)\s+(.*)/$2/;
    $size = int($orgs * $size);
  }
  $font =~ s/(\{[^}]*\})\s+(\d+)\s+(.*)/$1 $size $3/;
  $font;
}

# Work out the X/Y co-ords for each bar.
sub setXY {
  my($self) = shift;

  my $off = $self->{pOffset};
  my $pidx = 0;
  my $w = $off->{width};
  my $h = $off->{height};
  my $y = $self->{barTop};
  foreach my $r (1..$self->{rowsPP}) {
    my $x = $Opt->{LeftMargin};
    foreach my $c (1..$Opt->{Nbar}) {
      $pageXY[$pidx++] = [$x,$y];
      $x += $w;
    }
    $y += $h;
  }
}

# indexBars() sorts out the bar page index's. It does nothing
# to the lyrics, they're left where they were.
sub indexBars {
  my($self) = shift;

  my($pnum,$pidx,$row,$col) = (0,0,0,0);
  $self->{pstart} = [];
  my $pcan = $self->{pCan};
  #
  # We use 2 bar index numbers:
  #   bidx 1.. - The index of the actual bar from the first.
  #              Currently only used in the EditBar header and the numbers
  #              down the side of the page display.
  #   pidx 0.. - The 'page' index, ie. where, physically, on the page the bar is.
  #
  my $bidx = 1;
  for(my $bar = $self->{bars}; $bar != 0; $bar = $bar->{next}) {
    $bar->{bidx} = $bidx++;
    #
    # If we've just done a load() then the Page Canvas gets deleted
    # and remade so we need to update the bar's canvas pointer.
    #
    $bar->{canvas} = $pcan;
    #
    # Handle a new page.
    #
    if ($bar->{newpage}) {
      $row = $col = $pidx = 0;
      $pnum++;
    }
    #
    # Handle a new line.
    #
    elsif ($bar->{newline} && $col) {
      if (++$row == $self->{rowsPP}) {
	$row = $pidx = 0;
	$pnum++;
      } else {
	$pidx = $Opt->{Nbar} * $row;
      }
      $col = 0;
    } else {
      $pidx = ($Opt->{Nbar} * $row) + $col;
    }
    $self->{pstart}[$pnum] = $bar if ($pidx == 0);
    $bar->{pnum} = $pnum; # first page is 0
    ($bar->{x},$bar->{y}) = @{$pageXY[$pidx]};
    $bar->{pidx} = $pidx;
    if (++$col == $Opt->{Nbar} && $bar->{next} != 0) {
      if (++$row == $self->{rowsPP}) {
	$row = $pidx = 0;
	$pnum++;
      }
      $col = 0;
    }
  }
  $self->{nPage} = $pnum + 1;
  $self->{lyrics}->adjust($Opt->{LyricLines}) if ($Opt->{LyricLines});
}

#sub startEdit {
#  my($self) = shift;
#
#  $self->setEdited(0);
#}

sub load {
  my($self,$fn) = @_;

  $self->{bars} = $self->{lastBar} = 0;
  open IFH, "<", $fn;
  my $newline = my $newpage = my $bar = 0;
  my $rep = 'None';
  my $volta = 'None';
  my $bg = my $hdr = '';
  my $just = 'Left';
  while (<IFH>) {
    (my $line = $_) =~ s/\r|\n//g;
    next if ($line =~ /^\s*\#/ || $line eq "");
    if ($line =~ /^\s*\{(.*)\}\s*$/g) {
      # Handle any directives.
      my ($cmd, $txt) = split(':', $1, 2);
      if ($cmd =~ /^key$/i)               {($self->{key} = $txt) =~ s/\s//g;}
      elsif ($cmd =~ /^title$/i)          {$self->{title} = $txt;}
      elsif ($cmd =~ /^PDFname$/i)        {
	$self->{PDFname} = ($txt eq '') ? $self->{title}.'.pdf' : $txt;
      }
      elsif ($cmd =~ /^newline$/i)        {$newline = 1;}
      elsif ($cmd =~ /^newpage$/i)        {$newpage = 1;}
      elsif ($cmd =~ /^instrument$/i)     {$Opt->{Instrument} = ucfirst(lc($txt)); readChords();}
      elsif ($cmd =~ /^bars_per_stave$/i) {$Opt->{Nbar} = $txt + 0;}
      elsif ($cmd =~ /^timing$/i)         {$self->{Timing} = $txt}
      elsif ($cmd =~ /^staff_space$/i)    {$Opt->{StaffSpace} = $txt + 0;}
      elsif ($cmd =~ /^stave_gap$/i)      {$self->{staveGap} = $txt + 0;}
      elsif ($cmd =~ /^lyric_space$/i)    {$self->{lyricSpace} = $txt + 0;}
      elsif ($cmd =~ /^note$/i)           {$self->{note} = $txt;}
      elsif ($cmd =~ /^tempo$/i)          {$self->{tempo} = $txt + 0;}
      elsif ($cmd =~ /^lyric_lines$/i)    {$Opt->{LyricLines} = $txt + 0;}
      elsif ($cmd =~ /^header$/i)         {($hdr = $txt) =~ s/'.'//;}
      elsif ($cmd =~ /^justify$/i)        {$just = ucfirst(lc($txt));}
      elsif ($cmd =~ /^volta$/i)          {$volta = ucfirst(lc($txt));}
      elsif ($cmd =~ /^repeat$/i)         {$rep = ucfirst(lc($txt));}
      elsif ($cmd =~ /^background$/i) {
	if ($txt =~ /(\d+),(\d+),(\d+)$/) {
	  $bg = sprint("#%02x%02x%02x", $1, $2, $3);
	} elsif ($txt =~ /(#[\da-fA-F]{6})$/) {
	  $bg = $1;
	}
      }
      elsif ($cmd =~ /^([^_]*)_font/i) {
	my $font = $1."Font";
	$self->{$font} = $txt;
      }
      elsif ($cmd =~ /^lyric$/i) {
	my($stave,$line,$lyr) = split(':', $txt, 3);
	$self->{lyrics}->set($stave, $line, $lyr);
      }
    } else {
      while ($line =~ /\[([^\]]*)\]/g) {
	my $notes = $1;
	$bar = $self->add1bar();
	$bar->{newline} = $newline;
	$bar->{newpage} = $newpage;
	$bar->{volta} = $volta;
	$bar->{header} = $hdr;
	$bar->{justify} = $just;
	$bar->{rep} = $rep;
	$bar->{bg} = $bg;
	while ($notes =~ /([r\d])\(([^\)]*)\)/g) {
	  my $n = $2;
	  my $string = $1;
	  $string -= 1 if ($string ne 'r');
	  foreach my $s (split(' ', $n)) {
	    my $nt = CP::Note->new($bar, $string, $s);
	    push(@{$bar->{notes}}, $nt);
	  }
	}
	$newline = $newpage = 0;
	$rep = $volta = 'None';
	$bg = $hdr = '';
	$just = 'Left';
      }
    }
  }
  $self->{Timing} .= '/4' if (length($self->{Timing}) == 1);
  close(IFH);
  $self->guessKey() if ($self->{key} eq '-');
  $self->{loaded} = 1;
}

sub add1bar {
  my($self) = shift;

  my $last = $self->{lastBar};
  my $bar = CP::Bar->new($self);
  if ($last == 0) {
    $self->{bars} = $bar;
  } else {
    $last->{next} = $bar;
    $bar->{prev} = $last;
  }
  $self->{lastBar} = $bar;
}

sub guessKey {
  my($self) = shift;

  for(my $bar = $self->{bars}; $bar != 0; $bar = $bar->{next}) {
    foreach my $n (@{$bar->{notes}}) {
      if ($n->{string} ne 'r' && $n->{fret} ne 'X') {
	my $idx = (idx($Tuning[$n->{string}]) + $n->{fret}) % 12;
	my $c = $Scale->[$idx];
	if ($c =~ /[a-g]/) {
	  $c = uc($c);
	  $c .= ($Scale == \@Fscale) ? 'b' : '#';
	}
	$self->{key} = $c;
	return;
      }
    }
  }
}

my $Sip = 0;   # Save In Progress

sub saveAs {
  my($self) = shift;

  my $newfn = $self->{fileName};
  my $ans = msgSet("Enter a name for the new file:", \$newfn);
  return if ($ans eq "Cancel" || $newfn eq $self->{fileName});

  if ($newfn ne '') {
    my $path = $Path->{Tab};
    if (-e "$path/$newfn") {
      $ans = msgYesNo("$path/$newfn\nFile already exists.\nDo you want to replace it?");
      return if ($ans eq "No");
    }
    if (checkSave($self) ne 'Cancel') {
      my $txt = read_file("$path/$self->{fileName}");
      if (write_file("$path/$newfn", $txt) != 1) {
	message(SAD, "Failed to write new file $path/$newfn\n    $!");
	return;
      }
      $self->new("$path/$newfn");
    }
  }
}

sub checkSave {
  my($self) = shift;

  my $ans = '';
  if ($self->{edited} && $self->{fileName} ne '') {
    $ans = msgYesNoCan("Do you want to save any changes made to:\n$self->{fileName}");
    if ($ans eq 'Yes') {
      $self->save();
      $self->{fileName} = '';
    }
  }
  return($ans);
}

sub save {
  my($self,$path,$bu) = @_;

  my $fileName = $self->{fileName};
  # Remove any blank bars from the end of the Tab.
  for(my $bar = $self->{lastBar}; $bar != 0; $bar = $bar->{prev}) {
    if ($bar->isblank()) {
      if ($self->{lastBar} = $bar->{prev}) {
	$bar->{prev}{next} = 0;
      } else {
	$self->{bars} = 0;
	last;
      }
    }
  }
  if ($Sip == 0) {
    $path = $Path->{Tab} if (! defined $path);
    $bu = 1 if (! defined $bu);
    if ($self->{fileName} eq '') {
      my $newfn = '';
      my $ans = msgSet("Enter a name for the new Tab file:", \$newfn);
      return if ($ans eq "Cancel");
      $newfn =~ s/\.tab$//i;
      $newfn .= '.tab';
      if (-e "$path/$newfn") {
	$ans = msgYesNo("$path/$newfn\nFile already exists.\nDo you want to replace it?");
	return if ($ans eq "No");
      }
      $self->{fileName} = $newfn;
    }
    $Sip++;
    $self->{lyrics}->collect() if ($Opt->{LyricLines});
    my $tmpTab = "$Path->{Temp}/$fileName";
    if (open(my $OFH, '>', $tmpTab)) {
      print $OFH '{title:'.$self->{title}."}\n";
      print $OFH '{PDFname:'.$self->{PDFname}."}\n" if ($self->{PDFname} ne '');
      print $OFH '{instrument:'.$Opt->{Instrument}."}\n";
      print $OFH '{key:'.$self->{key}."}\n"   if ($self->{key} ne '-');
      print $OFH '{note:'.$self->{note}."}\n" if ($self->{note} ne '');
      print $OFH '{tempo:'.$self->{tempo}."}\n";
      print $OFH '{bars_per_stave:'.$Opt->{Nbar}."}\n";
      print $OFH '{timing:'.$self->{Timing}."}\n";
      print $OFH '{staff_space:'.$Opt->{StaffSpace}."}\n";
      print $OFH '{stave_gap:'.$self->{staveGap}."}\n";
      print $OFH '{lyric_space:'.$self->{lyricSpace}."}\n";
      print $OFH '{lyric_lines:'.$Opt->{LyricLines}."}\n";
      if ($Opt->{SaveFonts}) {
	foreach my $type (qw/title head note snote word/) {
	  my $font = "${type}Font";
	  print $OFH "\{${type}_font:$self->{$font}\}\n";
	}
      }
      for(my $bar = $self->{bars}; $bar != 0; $bar = $bar->{next}) {
	print $OFH "{newline}\n"                   if ($bar->{newline});
	print $OFH "{newpage}\n"                   if ($bar->{newpage});
	print $OFH '{header:'.$bar->{header}."}\n" if ($bar->{header} ne '');
	print $OFH "{justify:Right}\n"             if ($bar->{justify} eq 'Right');
	print $OFH "{volta:".$bar->{volta}."}\n"   if ($bar->{volta} ne 'None');
	print $OFH "{repeat:".$bar->{rep}."}\n"    if ($bar->{rep} ne 'None');
	print $OFH "{background:".$bar->{bg}."}\n" if ($bar->{bg} ne '');
	print $OFH "[";
	foreach my $n ($bar->noteSort()) {
	  my $fs = '';
	  if ($n->{string} eq 'r') {
	    $fs = "r($n->{fret},$n->{pos})";
	  } else {
	    my $fnt = ($n->{font} eq 'Small') ? 'f' : '';
	    $fs = ($n->{string}+1).'('.$fnt.$n->{fret};
	    $fs .= ','.$n->{pos};
	    if ($n->{shbr} =~ /^[shbrv]{1}$/) {
	      $fs .= $n->{shbr};
	      if ($n->{shbr} =~ /b|r/) {
		$fs .= $n->{bend};
		if ($n->{shbr} eq 'r') {
		  $fs .= ','.$n->{hold};
		}
	      }
	    }
	  }
	  print $OFH "$fs)";
	}
	print $OFH "]\n";
      }
      $self->{lyrics}->lprint($OFH);
      close($OFH);
    } else {
      $Sip = 0;
      message(SAD, "Tab Save could not create temporary file:\n\"$tmpTab\"");
      return(0);
    }
    if ($bu) {
      backupFile($path, $fileName, $tmpTab, 1);
    } elsif (! -e "$path/$fileName") {
      my $txt = read_file("$tmpTab");
      if (write_file("$path/$fileName", $txt) != 1) {
	message(SAD, "Failed to write new file $fileName\nSee: $tmpTab");
      }
    }
#    if ($Opt->{AutoSave}) {
#      $SaveID = Tkx::after(($Opt->{AutoSave} * 60000), \&save);
#    }
    $self->setEdited(0);
    $Sip = 0;
    message(SMILE, " Saved ", 1);
    return(1);
  }
  return(0);
}

sub pageHdr {
  my($self) = shift;

  $self->{pCan}->delete(qw/hdrk hdrn hdrt hdrp hdrb/);
  if ($Media->{titleBG} ne WHITE) {
    my @ft = ('-width', 0, '-fill', $Media->{titleBG});
    $self->{pCan}->create_rectangle(0, 0, $Media->{width}, $self->{pageHeader}, @ft);
  }
  $self->pageKey();
  $self->pageTitle();
  $self->pageNum();

  my $ln = $self->{pageHeader};
  $self->{pCan}->create_line(0, $ln, $Media->{width}, $ln,
			     -width => THICK, -fill => DBLUE, -tags => 'phdr');
}

sub pageKey {
  my($self) = shift;

  my $can = $self->{pCan};
  $can->delete('hdrk');
  if ($self->{key} ne '-') {
    my $y = $self->{pageHeader} - 2;
    my $id = $can->create_text($Opt->{LeftMargin}, $y,
      -text   => "Key:",
      -anchor => 'sw',
      -fill   => bFG,
      -font   => $self->{keyFont},
      -tags   => 'hdrk',
	);
    my($x1,$y1,$x,$h) = split(/ /, $can->bbox($id));
    $x += 2;
    my $ch = [split('',$self->{key})];
    my @o = ('-fill', $self->{titleColor}, '-anchor', 'sw', '-tags', 'hdrk');
    $id = $can->create_text($x, $y, -text => shift(@{$ch}), -font => $self->{keyFont}, @o);
    if (@{$ch}) {
      ($x,$y1,$x1,$h) = split(/ /, $can->bbox($id));
      my $sfnt = newFont($self, $self->{keyFont}, int(($self->{keySize} * 0.8) + 0.5));
      $can->create_text($x1, $y - ($self->{keySize} / 3), -text => join('', @{$ch}), -font => $sfnt, @o);
    }
  }
}

sub chordAdd {
  my($self,$x,$y,$ch) = @_;

  my $can = $self->{pCan};
}

sub pageNote {
  my($self) = shift;

  my $can = $self->{pCan};
  $can->delete('hdrn');
  if ($self->{note} ne '') {
    my $id = $can->create_text(0, 0,
        -text   => " $self->{note} ",
        -anchor => 'sw',
        -fill   => '#000060',
        -font   => $self->{keyFont},
        -tags   => 'hdrn',
	);
    my($x1,$y1,$x2,$y2) = split(/ /, $can->bbox($id));
    my $w = $x2 - $x1;
    my $h = $y2 - $y1;
    my $x = $Media->{width} - $Opt->{RightMargin} - $w - 2;
    my $y = $self->{pageHeader} + $Opt->{TopMargin} + $h;
    $can->create_rectangle($x, $y, $x + $w, $y - $h,
			   -width => 0,
			   -fill => '#FFFF80',
			   -tags   => 'hdrn');
    $can->coords($id, $x, $y - 1);
    $can->raise($id);
  }
}

sub pageTitle {
  my($self) = shift;

  my $can = $self->{pCan};
  $can->delete('hdrt');
  $can->create_text(
    ($Media->{width} / 2), ($self->{pageHeader} / 2) - 1,
    -text => $self->{title},
    -fill => $self->{titleColor},
    -font => $self->{titleFont},
    -tags => 'hdrt',
      );
}

sub pageNum {
  my($self) = shift;

  my $can = $self->{pCan};
  $can->delete('hdrp');
  my $id = $can->create_text(
    0, 0,
    -text => "Page ".($self->{pageNum}+1)." of ".$self->{nPage},
    -fill => BROWN,
    -font => $self->{pageFont},
    -tags => 'hdrp',
      );
  my($x1,$y1,$x2,$y2) = split(/ /, $can->bbox($id));
  $can->coords($id, $Media->{width} - $Opt->{RightMargin} - $x2, ($self->{pageHeader} / 2) - 1);
}

sub pageTempo {
  my($self) = shift;

  if (defined $self->{tempo}) {
    my $can = $self->{pCan};
    $can->delete('hdrb');
    my $x = ($Media->{width} / 2) - 12;
    my $y = $self->{pageHeader} + 8;
    my $sz = $self->{symSize};
    my $nsz = int(($sz * (PAGEMUL - 0.1)) + 0.5);
    (my $fnt = $self->{symFont}) =~ s/ $sz / $nsz /;
    my $wid = $can->create_text(
      $x, $y + $Opt->{TopMargin} + 1,
      -text => 'O',     # crotchet symbol
      -font => $fnt,
      -tags => 'hdrb');
    my($x1,$y1,$x2,$y2) = split(/ /, $can->bbox($wid));
    $can->create_text(
      $x + ($x2 - $x1), $y + $Opt->{TopMargin} - 2,
      -text => '= '.$self->{tempo},
      -font => $self->{pageFont},
      -anchor => 'w',
      -tags => 'hdrb');
  }
}

sub pageBars {
  my($self) = shift;

  my $x = $Opt->{LeftMargin};
  my $off = $self->{pOffset};
  my $pidx = 0;
  my $h = $off->{height};
  my $y = $self->{barTop} + $off->{staffY} + ($off->{staffHeight} / 2);
  my @o = ('-fill', $self->{titleColor}, '-font', $self->{barnFont}, '-anchor', 'e', '-tags', 'pcnt');
  my $bar = $self->{pstart}[$self->{pageNum}];
  my $pcan = $self->{pCan};
  my $ncan = $self->{nCan};
  $ncan->delete('pcnt');
  foreach my $row (0..($self->{rowsPP} - 1)) {
    # Bar numbers down the left side of the page.
    # These are the ACTUAL bar numbers as opposed to the bars per page.
    $ncan->create_text(BNUMW - 4, $y, -text => $bar->{bidx}, @o) if ($bar);
    $y += $h;
    foreach my $col (0..($Opt->{Nbar} - 1)) {
      if ($bar && $bar->{pidx} == $pidx) {
	$bar->show();
	$bar = $bar->{next};
      } else {
	$pcan->itemconfigure("b$pidx", -fill => LGREY);
	my $tag = "det$pidx";
	foreach (qw/<Button-1> <Shift-Button-1> <Control-Button-1> <Button-3>/) {
	  $pcan->bind($tag, $_, '');
	}
      }
      $pidx++;
    }
    last if ($bar == 0 || $bar->{newpage});
  }
}

sub newPage {
  my($self,$pn) = @_;

  $self->{lyrics}->collect() if ($Opt->{LyricLines}); # && $pn != $self->{pageNum});
  $self->clearTab();
  $self->{nPage} = ($pn + 1) if (($pn + 1) > $self->{nPage});

  $self->{pageNum} = $pn;    # first page is 0
  $self->{pstart}[$pn] = 0 if (! defined $self->{pstart}[$pn]);
  $self->pageHdr();
  $self->pageBars();
  if ($self->{pageNum} == 0) {
    $self->pageNote();
    $self->pageTempo();
  }
  $self->{lyrics}->show() if ($Opt->{LyricLines});
}

#
# Clear out the Tab page but leave all the heading info
#
sub clearTab {
  my($self) = shift;

  $self->ClearSel();
  $self->{nCan}->delete('pcnt');
  my $can = $self->{pCan};
  foreach my $id (0..($self->{barsPP}-1)) {
    $can->itemconfigure("bg$id", -fill => BLANK);
    $can->delete("bar$id"); #, "rep$id");
    $can->itemconfigure("b$id", -fill => LGREY);
    my $tag = "det$id";
    foreach (qw/<Button-1> <Shift-Button-1> <Control-Button-1> <Button-3>/) {
      $can->bind($tag, $_, '');
    }
  }
  $self->{lyrics}->clear();
}

sub setBG {
  my($self) = shift;

  my($a,$b) = $self->diff();
  if ($a == 0) {
    message(QUIZ, $OneOrMore);
  } else {
    if ((my $bg = $a->bgGet()) ne '') {
      while ($a && $a->{prev} != $b) {
	$a->{bg} = $bg;
	$a->show();
	$a = $a->{next};
      }
    }
  }
  $self->ClearSel();
}

sub clearBG {
  my($self) = shift;

  my($a,$b) = $self->diff();
  if ($a == 0) {
    message(QUIZ, $OneOrMore);
  } else {
    while ($a != 0 && $a->{prev} != $b) {
      $a->{bg} = BLANK;
      $a->show();
      $a = $a->{next};
    }
  }
  $self->ClearSel();
}

sub editBar {
  my($self) = shift;

  my($a,$b) = $self->diff();
  if ($a == 0) {
    CP::Bar::Edit($self);
  } else {
    if ($a != $b) {
      if (msgYesNo("Only the first Bar will be edited.\nContinue?") eq "No") {
	return;
      }
      my $can = $self->{pCan};
      while ($b != $a) {
	$can->itemconfigure("bg$b->{pidx}", -fill => $b->{bg});
	$b = $b->{prev};
      }
      $self->{select1} = $a;
      $self->{select2} = 0;
    }
    $a->Edit();
  }
}

sub Clone {
  my($self) = shift;

  my($a,$b) = $self->diff();
  if ($a == 0) {
    message(QUIZ, $OneOrMore);
  } else {
    my $bp = $self->{lastBar};
    # In theory, the next test should always be false
    if ($bp && ! $bp->isblank()) {
      do {
	$bp = $self->add1bar();
	$a->copy($bp, HANDN);
	$a = $a->{next};
      } while ($a && $a->{prev} != $b);
      pasteEnd($self, $bp);
    }
  }
}

my @Copy = ();
our $CopyIdx = 'Empty';
sub Copy {
  my($self,$what) = @_;

  my($a,$b) = $self->diff();
  if ($a == 0) {
    message(QUIZ, $OneOrMore);
  } else {
    @Copy = ();
    do {
      my $copy = CP::Bar->new($self);
      $a->copy($copy, $what);
      $copy->{bidx} = $a->{bidx};
      push(@Copy, $copy);
      $a = $a->{next};
    } while ($a && $a->{prev} != $b);
    if (@Copy) {
      $CopyIdx = $Copy[0]->{bidx};
      if (@Copy > 1) {
	$CopyIdx .= ' .. '.$Copy[-1]->{bidx};
      }
    } else {
      $CopyIdx = 'Empty';
    }
    $self->ClearSel();
  }
}

sub PasteOver {
  my($self) = shift;

  if (pasteStart($self)) {
    my $dst = $self->{select1};
    my $lastdst;
    foreach my $src (@Copy) {
      $dst = $self->add1bar() if ($dst == 0); # $dst is pointing at {lastBar}
      $src->copy($dst, HANDN);
      $lastdst = $dst;
      $dst = $dst->{next};
    }
    pasteEnd($self, $lastdst);
  }
}

sub PasteBefore {
  my($self) = shift;

  if (pasteStart($self)) {
    my $dst = $self->{select1}{prev};
    foreach my $src (@Copy) {
      my $bar = CP::Bar->new($self);
      $src->copy($bar, HANDN);
      if ($dst == 0) {
	$self->{bars} = $bar;
      } else {
	$dst->{next} = $bar;
	$bar->{prev} = $dst;
      }
      $dst = $bar;
    }
    $dst->{next} = $self->{select1};
    $self->{select1}{prev} = $dst;
    pasteEnd($self, $dst);
  }
}

sub PasteAfter {
  my($self) = shift;

  if (pasteStart($self)) {
    my $dst = $self->{select1};
    my $next = $dst->{next};
    foreach my $src (@Copy) {
      my $bar = CP::Bar->new($self);
      $src->copy($bar, HANDN);
      $dst->{next} = $bar;
      $bar->{prev} = $dst;
      $dst = $bar;
    }
    if ($next != 0) {
      $dst->{next} = $next;
      $next->{prev} = $dst;
    } else {
      $self->{lastBar} = $dst;
    }
    pasteEnd($self, $dst);
  }
}

sub pasteStart {
  my($self) = shift;

  my $ret = 0;
  if (@Copy == 0) {
    message(SAD, "No Bars in the Copy buffer.");
  } elsif ($self->{select1} == 0) {
    message(QUIZ, "Please select a destination bar.");
  } else {
    $ret++;
  }
  $ret;
}

sub pasteEnd {
  my($self,$dst) = @_;

  $self->setEdited(1);
  $self->ClearSel();
  indexBars($self);
  $self->newPage($dst->{pnum});
}

sub ClearBars {
  my($self) = shift;

  my($a,$b) = $self->diff();
  if ($a == 0) {
    message(QUIZ, $OneOrMore);
  } else {
    my $can = $self->{pCan};
    do {
      $a->unMap();
      $a->blank();
      $can->itemconfigure("bg$a->{pidx}", -fill => $a->{bg});
      $a = $a->{next};
    } while ($a && $a->{prev} != $b);
    $self->ClearSel();
  }
}

sub ClearSel {
  my($self) = shift;

  my($a,$b) = $self->diff();
  if ($a != 0) {
    my $can = $self->{pCan};
    do {
      $can->itemconfigure("bg$a->{pidx}", -fill => $a->{bg});
      $a = $a->{next};
    } while ($a && $a->{prev} != $b);
  }
  $self->{select1} = $self->{select2} = 0;
}

sub DeleteBars {
  my($self) = shift;

  my($a,$b) = $self->diff();
  if ($a == 0) {
    message(QUIZ, $OneOrMore);
  } else {
    my $msg = "Are you sure you want to\ndelete the selected Bar";
    $msg .= 's' if ($a != $b);
    if (msgYesNo($msg) eq 'Yes') {
      if ($a->{prev} == 0) {
	$self->{bars} = $b->{next};
	$b->{next}{prev} = 0 if ($b->{next} != 0);
      } elsif ($b->{next} == 0) {
	$self->{lastBar} = $a->{prev};
	$a->{prev}{next} = 0;
      } else {
	$a = $a->{prev};
	$b = $b->{next};
	$a->{next} = $b;
	$b->{prev} = $a;
      }
    }
    indexBars($self);
    $self->newPage($self->{pageNum});
  }
}

sub PrevPage {
  my($self) = shift;

  $self->ClearSel();
  if ($self->{pageNum} > 0) {
    $self->newPage($self->{pageNum} - 1);
  }
}

sub NextPage {
  my($self) = shift;

  $self->ClearSel();
  $self->newPage($self->{pageNum} + 1);
}

# select1 & select2 are Bar object refs
# in any order and may set or not.
# Returns Bar Objects Low,High.
sub diff {
  my($self) = shift;

  my $a = $self->{select1};
  my $b = $self->{select2};
  if ($a == 0) {
    return($b, $b);
  } elsif ($b == 0) {
    return($a, $a);
  }
  my $bpp = $self->{barsPP};
  my($apn,$bpn) = (0,0);
  $apn = $a->{pidx} + ($a->{pnum} * $bpp) if ($a != 0);
  $bpn = $b->{pidx} + ($b->{pnum} * $bpp) if ($b != 0);
  return(($apn > $bpn) ? ($b,$a) : ($a,$b));
}

# Return the width of some text in a given font.
sub dx {
  my($can,$txt,$fnt) = @_;

  my $wid = $can->create_text(
    0, 0,
    -text   => $txt,
    -font   => $fnt,
    -anchor => 'nw',
    -tags   => 'tmp');
  my($lx,$ly,$rx,$ry) = split(/ /, $can->bbox($wid));
  $can->delete('tmp');
  $rx;
}

sub transpose {
  my($self,$pe) = @_;

  if ($self->{trans} != 0) {
    my $bar  = ($self->{select1}) ? $self->{select1} : $self->{bars};
    my $last = ($self->{select2}) ? $self->{select2} : $self->{lastBar};
    my $all = ($bar == $self->{bars} && $last == $self->{lastBar}) ? 1 : 0;
    my $nstr = $Nstring - 1;
    while ($bar && $bar->{prev} != $last) {
      my $tr = $self->{trans} + 0;
      foreach my $n (@{$bar->{notes}}) {
	if ($n->{string} ne 'r' && $n->{fret} ne 'X') {
	  $n->{fret} += $tr;
	  if ($Opt->{Refret}) {
	    foreach my $ups (5, 10) {
	      if ($tr >= $ups && $n->{string} < $nstr) {
		$n->{string} += 1;
		$n->{fret} -= 5;
	      }
	    }
	    while ($n->{fret} < 0) {
	      if ($n->{string} == 0) {
		# Shift up an octave.
		$n->{string} += 1;
		$n->{fret} += 7;
	      } else {
		$n->{string} -= 1;
		$n->{fret} += 5;
	      }
	    }
	  }
	}
      }
      $bar = $bar->{next};
    }
    if ($pe == PAGE) {
      $self->setKey($self->{trans}) if ($all);
      $self->newPage($self->{pageNum});
      $self->setEdited(1);
    } else {
      $EditBar->unMap();
      $EditBar->show();
    }
  }
  $self->{trans} = 0;
}

sub ud1string {
  my($self,$pe,$adj) = @_;

  my $bar  = ($self->{select1}) ? $self->{select1} : $self->{bars};
  my $last = ($self->{select2}) ? $self->{select2} : $self->{lastBar};
  my $all = ($bar == $self->{bars} && $last == $self->{lastBar}) ? 1 : 0;
  while ($bar && $bar->{prev} != $last) {
    foreach my $n (@{$bar->{notes}}) {
      my $str = $n->{string};
      if ($str ne 'r') {
	if (($adj > 0 && ($str + 1) == $Nstring) || ($adj < 0 && ($str - 1) < 0)) {
	  $n->{fret} += $adj if ($n->{fret} ne 'X');
	} else {
	  $n->{string} += ($adj < 0) ? -1 : 1;
	}
	if ($n->{fret} ne 'X' && $adj > 0 && $n->{fret} < 0 && $str > 0) {
	  $n->{fret} += 5;
	  $n->{string} -= 1;
	}
      }
    }
    $bar = $bar->{next};
  }
  if ($pe == PAGE) {
    $self->setKey($adj) if ($all);
    $self->newPage($self->{pageNum});
    $self->setEdited(1);
  } else {
    $EditBar->unMap();
    $EditBar->show();
  }
}

sub setKey {
  my($self,$shft) = @_;

  if ($self->{key} ne '-') {
    my $idx = idx($self->{key}) + $shft;
    $idx %= 12;
    my $c = $Scale->[$idx];
    if ($c =~ /[a-g]/) {
      $c = uc($c);
      $c .= ($Scale == \@Fscale) ? 'b' : '#';
    }
    $self->{key} = $c;
  } else {
    $self->guessKey();
  }
  $self->pageKey();
}

sub idx {
  my($key) = shift;

  my $i = 0;
  my $k = substr($key, 0, 1);
  while ($i < 12) {
    last if ($k eq $Scale->[$i]);
    $i++;
  }
  if ($key =~ /\#/) {
    $i++;
  }
  elsif ($key =~ /b/) {
    $i--;
  }
  return($i % 12);
}

sub saveAsText {
  my($self) = shift;

  if ($self->{fileName} eq '') {
    message(SAD, "No Tab file currently loaded.");
    return;
  }
  (my $file = $self->{fileName}) =~ s/\.tab$//i;
  $file .= '.txt';
  $file = Tkx::tk___getSaveFile(
    -title => "Save As",
    -initialdir => "$Home",
    -initialfile => $file,
    -confirmoverwrite => 1,
      );
  return if ($file eq '');
  unless (open OFH, '>', $file) {
    errorPrint("Couldn't create Tab text file:\n   '$file'\n$!");
    return();
  }
  my @bars = ();
  my($t,$_t) = split('/', $self->{Timing});
  my $div = 8;
  for(my $b = $self->{bars}; $b != 0; $b = $b->{next}) {
    foreach my $n (@{$b->{notes}}) {
      while (($n->{pos} % $div) != 0) {
	$div /= 2;
	last if ($div == 1);
      }
    }
  }
  my $cr = '+'.('-' x ((16 / $div) - 1));
  $cr = '|-'.($cr x $t);
  my $barw = length($cr);

  my @tune = reverse @Tuning;
  unshift(@tune, '');

  for(my $b = $self->{bars}; $b != 0; $b = $b->{next}) {
    my $bar = {};
    $bar->{asc}[0] = '';
    my $fmt = ($b->{justify} eq 'Right') ? '%*s' : '%-*s';
    if ((my $h = $b->{header}) ne '') {
      if ($h =~ /intro|verse|chorus|bridge|outro|instrumental|solo/i) {
	$h =~ s/^\s*//;
	$h = '['.$h.']';
      }
      $h = sprintf $fmt, $barw, $h;
      while ((my $lh = length($h)) > $barw) {
	$h =~ s/   /  /;
	last if (length($h) == $lh);
      }
      $bar->{asc}[0] .= $h;
    } else {
      $bar->{asc}[0] .= ' ' x $barw;
    }
    foreach my $s (1..$Nstring) {
      $bar->{asc}[$s] = $cr;
    }
    $bar->{width} = length($bar->{asc}[0]);
    $bar->{rep} = $b->{rep};
    $bar->{newline} = $b->{newline} | $b->{newpage};
    $bar->{header} = $b->{header};
    foreach my $n (@{$b->{notes}}) {
      if ($n->{string} ne 'r') {
	my $s = abs($n->{string} - $Nstring);
	my $p = (($n->{pos} / $div) * 2) + 2;
	substr($bar->{asc}[$s], $p, length($n->{fret}), $n->{fret});
      }
    }
    push(@bars, $bar);
  }

  print OFH "  $self->{title}\n\n";
  print OFH "  Key: $self->{key}\n" if ($self->{key} ne '-');
  print OFH "\n";
  print OFH "  Tuning: ".join(' ', @Tuning)."\n\n";
  for(my $bp = 0; $bp < @bars; ) {
    my $last = $bp + 3;
    $last = $#bars if ($last >= @bars);
    foreach my $s (0..$Nstring) {
      print OFH '  ';
      foreach my $bn ($bp..$last) {
	my $barp = $bars[$bn];
	if ($bn == $bp) {
	  if ($s) {
	    print OFH $tune[$s];
	    print OFH '|' if ($barp->{rep} eq 'Start');
	  } else {
	    print OFH ' ';
	  }
	}
	if ($barp->{newline} && $bn != $bp) {
	  $last = $bn - 1;
	  last;
	}
	print OFH $barp->{asc}[$s];
	print OFH '|' if ($s && $barp->{rep} eq 'End');
      }
      print OFH '|' if ($s);
      print OFH "\n";
    }
    print OFH "\n";
    $bp = $last + 1;
  }
  close(OFH);
  message(SMILE, " Done ", 2);
}

1;
