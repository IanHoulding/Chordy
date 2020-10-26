package CP::Global;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

# All this Package does is define all the globally used variables.

use strict;
use warnings;

BEGIN {
  our @ISA = qw(Exporter);
  our @EXPORT_OK = qw/
      &read_file &write_file
      &syncFiles &setDefaults &readChords &cleanCache &openConfig &backupFile
      &DeleteBackups
      &viewElog &clearElog &viewRelNt &errorPrint &makeImage
      &jobSpawn

      $Version $Parent $Home
      $Collection $Opt $Path $Cmnd $Swatches
      %Fingers $Nstring @Tuning
      @ProFiles
      $AllSets $CurSet
      $MW $KeyLB $FileLB $Media %FontList $ColourEd
      $KeyShift $Scale @Sscale @Fscale
      %EditFont
      %XPM %Images
      /;
  our %EXPORT_TAGS = (
    FUNC  => [qw/&read_file &write_file
	         &syncFiles &setDefaults &readChords &cleanCache &openConfig &backupFile
	         &DeleteBackups
	         &viewElog &clearElog &viewRelNt &errorPrint &makeImage
	         &jobSpawn/],
    VERS  => [qw/$Version/],
    PATH  => [qw/$Parent $Home/],
    OPT   => [qw/$Collection $Opt $Path $Cmnd $Swatches/],
    CHORD => [qw/%Fingers $Nstring @Tuning/],
    WIN   => [qw/$MW $KeyLB $FileLB $Media %FontList $ColourEd/],
    XPM   => [qw/%XPM %Images/],
    PRO   => [qw/@ProFiles/],
    SETL  => [qw/$AllSets $CurSet/],
    SCALE => [qw/$KeyShift $Scale @Sscale @Fscale/],
    MEDIA => [qw/%EditFont/],
      );
  require Exporter;
}

use Tkx;
use File::Path qw(make_path remove_tree);
use CP::Cconst qw/:OS :PATH :SHFL :SMILIE :COLOUR/;
use CP::Cmsg;
use CP::Collection;
use CP::Path;
use CP::Cmnd;
use CP::Opt;
use CP::Media;

#use CP::Cmsg qw/&message &msgYesNo &msgYesNoCan &msgSet &msgYesNoAll/;

our $Version = "3.9";

our($Parent, $Home, $Collection, $Opt, $Path, $Cmnd, $Swatches);
our(%Fingers, $Nstring, @Tuning, $CurSet);
our($MW, $KeyLB, $FileLB, $Media, %FontList, $ColourEd, @ProFiles);
our($KeyShift, $Scale, @Sscale, @Fscale);
our(%EditFont);
our(%XPM, %Images);

Tkx::package_require("img::xpm");

Tkx::eval(<<'EOT');
proc bgerror {msg} {
puts $msg
}
EOT

#OS = Tkx::tk_windowingsystem();   # will return x11, win32 or aqua

sub init {
  $Home = USER;  # Always points to where the Config/Pro/PDF/Tab's live
                 # and can be changed for each Collection.
  ($Parent = USER) =~ s/\/Chordy//;
}

sub read_file {
  my($fn) = shift;

  my $fh;
  my $document = do {
    local $/ = undef;
    open $fh, "<", $fn
	or return(message(SAD, "read_file() could not open:\n   \"$fn\": $!"));
    binmode($fh, ':raw');
    <$fh>;
  };
}

sub write_file {
  my($fn,$txt) = @_;

  if (open(my $fh, ">", $fn)) {
    binmode($fh, ':raw');
    print $fh $txt;
    close $fh;
    return(1);
  } else {
    my $err = $!;
    message(SAD, "write_file could not create:\n   \"$fn\": $err");
    $! = $err;
    return(0);
  }
}

sub jobSpawn {
  my($cstr) = shift;

  if (OS eq 'win32') {
    system($cstr);
  } else {
    $SIG{CHLD} = 'sig_catch';
    my $kidpid = fork;
    if (! defined $kidpid) {
      errorPrint "spawn: fork failed: $!";
    } elsif ($kidpid == 0) {
      exec $cstr;
      warn "spawn: exec of\n   $cstr\nfailed.";   
    } 
    $kidpid;
  }
}

sub sig_catch {
  my($sig) = shift;
  wait if ($sig eq "CHLD");
}

sub syncFiles {
  my($from,$ext) = @_;

  my $pop = CP::Pop->new(0, '.fs', 'Folder Sync');
  return if ($pop eq '');
  my($top,$wt) = ($pop->{top}, $pop->{frame});

  my $tf = $wt->new_ttk__frame();
  $tf->g_grid(qw/-row 0 -column 0 -padx 4 -pady 6 -sticky nsew/);

  my $hl = $wt->new_ttk__separator(-orient => 'horizontal');
  $hl->g_grid(qw/-row 1 -column 0 -sticky ew/);

  my $bf = $wt->new_ttk__frame();
  $bf->g_grid(qw/-row 2 -column 0 -sticky ew -padx 4 -pady 6/);

  my($done,$to);
  my $tll = $tf->new_ttk__label(-text => 'From:');
  $tll->g_grid(qw/-row 0 -column 0/);

  my $tle = $tf->new_ttk__entry(
    -textvariable => \$from,
    -width => 30);
  $tle->g_grid(qw/-row 0 -column 1/);

  my $tlb = $tf->new_ttk__button(
    -text => "Browse ...",
    -command => sub {$from = Tkx::tk___chooseDirectory(
		       -title => "Choose Source Folder",
		       -initialdir => "$Home");
		     $from =~ s/\/$//;
		     $top->g_raise();},
      );
  $tlb->g_grid(qw/-row 0 -column 2 -padx 6/);

  my $trl = $tf->new_ttk__label(-text => '     To:');
  $trl->g_grid(qw/-row 0 -column 3/);

  my $tre = $tf->new_ttk__entry(
    -textvariable => \$to,
    -width => 30);
  $tre->g_grid(qw/-row 0 -column 4/);

  my $trb = $tf->new_ttk__button(
    -text => "Browse ...",
    -command => sub {$to = Tkx::tk___chooseDirectory(
		       -title => "Choose Destination Folder",
		       -initialdir => "$Home");
		     $to =~ s/\/$//;
		     $top->g_raise();},
      );
  $trb->g_grid(qw/-row 0 -column 5 -padx 6/);

  my $what = 1;
  my $tsl = $tf->new_ttk__label(-text => 'Sync:');
  $tsl->g_grid(qw/-row 1 -column 0/);

  my $tsra = $tf->new_ttk__radiobutton(
    -text => "Modified + New Files",
    -variable => \$what,
    -value => 1);
  $tsra->g_grid(qw/-row 1 -column 1/, -pady => [4,0]);

  my $tsrb = $tf->new_ttk__radiobutton(
    -text => "Only New Files",
    -variable => \$what,
    -value => 0);
  $tsrb->g_grid(qw/-row 1 -column 2/, -pady => [4,0]);

  my $cancel = $bf->new_ttk__button(-text => "Cancel", -command => sub{$done = "Cancel";});
  $cancel->g_pack(qw/-side left -padx 40/);

  my $ok = $bf->new_ttk__button(-text => "OK", -command => sub{$done = "OK";});
  $ok->g_pack(qw/-side right -padx 40/);

  $top->g_wm_deiconify();
  $top->g_raise();
  Tkx::vwait(\$done);

  if ($done eq 'OK') {
    if ($to eq '' || $from eq '') {
      message(SAD, 'You must specify both a From and a To folder!');
    } elsif ($to eq $from) {
      message(SAD, 'Source and Destination folders must be different!');
    } else {
      opendir my $dh, "$from" or return(message(SAD, "Couldn't open directory $from"));
      my @fr = grep /.*\.$ext$/, readdir $dh;
      closedir($dh);
      if (@fr == 0) {
	message(SAD, "Folder '$from' contained no ChordPro files!");
      } else {
	$cancel->g_destroy();

	my $lf = $tf->new_ttk__labelframe(-text => " New/Updated files in Folder:  $to ");
	$lf->g_grid(qw/-row 2 -column 0 -columnspan 6 -sticky nsew -pady/ => 4);

	my $txt = $lf->new_tk__text(
	  -font => "\{$EditFont{family}\} $EditFont{size}",
	  -bg => 'white',
	  -spacing1 => 1,
	  -height => 30);
	$txt->g_grid(qw/-row 0 -column 0 -sticky nsew/);

	my $sv = $lf->new_ttk__scrollbar(-orient => "vertical",   -command => [$txt, "yview"]);
	$sv->g_grid(qw/-row 0 -column 1 -sticky wns/);

	my $sh = $lf->new_ttk__scrollbar(-orient => "horizontal", -command => [$txt, "xview"]);
	$sh->g_grid(qw/-row 1 -column 0 -sticky new/);

	$txt->configure(-yscrollcommand => [$sv, 'set']);
	$txt->configure(-xscrollcommand => [$sh, 'set']);

	my $sz = 14;
	$txt->tag_configure('MOD', -font => "\{$EditFont{family}\} $EditFont{size} normal italic");
	if (! -d "$to") {
	  make_path($to, {chmod => 0777});
	}
	foreach my $f (sort @fr) {
	  if (! -e "$to/$f") {
	    my $text = read_file("$from/$f");
	    write_file("$to/$f", $text);
	    $txt->insert('end', "New - $f\n");
	    $txt->see('end');
	    Tkx::update();
	  } elsif  ($what == 1) {
	    # Check modification times
	    my $ft = (stat("$from/$f"))[9];
	    my $tt = (stat("$to/$f"))[9];
	    if ($ft > $tt) {
	      my $text = read_file("$from/$f");
	      write_file("$to/$f", $text);
	      $txt->insert('end', "Mod - $f\n", 'MOD');
	      $txt->see('end');
	      Tkx::update();
	    }
	  }
	}
	$txt->insert('end', "\nDONE\n", 'NEW');
	$txt->see('end');
	Tkx::update();
	Tkx::vwait(\$done);	  
      }
    }
  }
  $pop->popDestroy();
}

#
# Because this is a "work in progress" it's better to set up all
# the defaults and THEN if there's a Config file, zap them with
# the contents. This way, any additions get incorporated into a
# new Config file if saved.
#
sub setDefaults {
  init();                  # sets $Parent and $Home globals to USER/.. and USER
  $Collection = CP::Collection->new();
  $Path = CP::Path->new();
  $Cmnd = CP::Cmnd->new();
  $Opt = CP::Opt->new();
  $Media = CP::Media->new($Opt->{Media});
  $Swatches = CP::Swatch->new();

  # Remove any old versions.
  cleanCache() if (OS eq "win32");

  # Read in Chord Definition file
  readChords();

  # Sharps/Flats are indicated by using a lower case note.
  @Sscale = qw/A a B C c D d E F f G g/;
  @Fscale = qw/a A b B C d D e E F g G/;
  $Scale = ($Opt->{SharpFlat} == FLAT) ? \@Fscale : \@Sscale;
}

sub readChords {
  if (! -e USER."/$Opt->{Instrument}.chd") {
    CP::Chord::makeFile(USER);
  }
  do USER."/$Opt->{Instrument}.chd";
}

sub cleanCache {
  if (exists $ENV{PAR_TEMP}) {
    #
    # Looks like:
    #   C:\Users\Ian\AppData\Local\Temp\par-49616e\cache-d5ebb07d6ac3285b2494a8a7b1752c21df12b996
    #
    my $par = $ENV{PAR_TEMP};
    # Convert Windows to Unix
    $par =~ s/\\/\//g;
    $par =~ s/\/[^\/]+$//;
    opendir DIR, "$par";
    my @cache = (sort {(stat("$par/$a"))[9] <=> (stat("$par/$b"))[9]} (grep /^cache/, readdir DIR));
    closedir DIR;
    #
    # We keep 3 caches which 'should' be chordy, cpgedi and tab
    #
    if (@cache > 3) {
      pop(@cache);pop(@cache);pop(@cache);
      foreach my $f (@cache) {
	remove_tree("$par/$f");
      }
    }
  }
}

sub openConfig {
  my($cfg) = shift;

  ### Bloody Windows!!
  (my $bak = $cfg) =~ s/.cfg$/.bak/;
  if (-e "$bak") {
    unlink("$bak") or errorPrint("Could not unlink '$bak': $!");
  }
  if (-e "$cfg") {
    rename("$cfg", "$bak") or errorPrint("Could not backup '$cfg': $!");
  }
  my $ofh;
  unless (open $ofh, ">$cfg") {
    errorPrint("Couldn't create Config file '$cfg': $!");
    return(0);
  }
  print $ofh "#!/usr/bin/perl\n\n";
  print $ofh "#\n# If you don't know how to program in Perl - LEAVE THIS FILE ALONE!!!\n#\n\n";
  if ($cfg =~ /Option/) {
    print $ofh "\$version = \"$Version\";\n\n";
  }
  $ofh;
}

sub errorPrint {
  my($str) = shift;

  if (defined $MW && Tkx::winfo_exists($MW)) {
    message(SAD, $str);
  } else {
    print localtime."\n  $str\n";
  }
}

# Original file is still where it was.
# Temp file contains all the changes.
# Shuffle all the backups up one number.
# Move the original to backup.1
# Move the Temp file to the original.
#
# $path is a folder containing $fileName
# $tempFile is a complete path/file
sub backupFile {
  my($path,$fileName,$tmpFile,$unlink) = @_;

  my $bi = 1;
  while (-e "$tmpFile.$bi") {
    $bi++;
  }
  # Shuffle .x files up one
  while ($bi != 1) {
    rename("$tmpFile.".($bi-1), "$tmpFile.$bi");
    $bi--;
  }
  # Copy the original to Temp/filename.1
  my $txt = read_file("$path/$fileName");
  if (write_file("$tmpFile.$bi", $txt) != 1) {
    message(SAD, "Failed to backup $fileName into $Path->{Temp}.\nEdited file is in\n    $tmpFile");
  } else {
    # Kill the original and copy the temp file to it's place
    unlink("$path/$fileName");
    my $txt = read_file("$tmpFile");
    if (write_file("$path/$fileName", $txt) == 1) {
      unlink("$tmpFile") if ($unlink);
    } else {
      message(SAD, "Failed to write new copy of $fileName\nSee: $tmpFile");
    }
  }
}

sub DeleteBackups {
  my($ext,$path) = @_;

  if (msgYesNo("Do you really want to delete all '$ext' backups?") eq "Yes") {
    $path = $Path->{Temp} if (! defined $path);
    opendir my $dh, "$path" or return(message(SAD, "Couldn't open directory $path\n"));
    foreach my $f (grep !/^\.\.?$/, readdir $dh) {
      DeleteBackups($ext, "$path/$f") if (-d "$path/$f");
      if (-f "$path/$f" && $f =~ /$ext\.\d+$/i) {
	unlink("$path/$f");
      }
    }
    closedir($dh);
    message(SMILE, " Deleted ", 1);
  }
}

sub DeletePDFBackups {
  if (msgYesNo("Do you really want to delete all temporary PDFs?") eq "Yes") {
    my $path = $Path->{Temp};
    opendir my $dh, "$path" or return(message(SAD, "Couldn't open directory $path\n"));
    foreach my $f (grep !/^\.\.?$/, readdir $dh) {
      unlink("$path/$f") if ($f =~ /\.pdf$/i);
    }
    closedir($dh);
    message(SMILE, " Deleted ", 1);
  }
}

sub makeImage {
  my($img,$set,$force) = @_;

  return '' if (! defined $set->{$img});
  if (! defined $Images{$img} || defined $force) {
    Tkx::image_create_photo($img, -data => $set->{$img}, -format => 'XPM');
    $Images{$img} = $img;
  }
  $img;
}

sub viewElog {
  if (-e ERRLOG) {
    if (-z ERRLOG) {
      message(SMILE, "Error Log is currently empty.");
    } else {
      viewFile(ERRLOG);
    }
  } else {
    message(SAD, "Error Log file does not exist (yet!)");
  }
}

sub viewRelNt {
  my $fn = USER."/Release Notes.txt";
  if (-e $fn) {
    viewFile($fn);
  } else {
    message(SAD, "Could not find $fn");
  }
}

sub viewFile {
  my($fn) = shift;

  my $pop = CP::Pop->new(0, '.vf', $fn);
  return if ($pop eq '');
  my($top,$frm) = ($pop->{top}, $pop->{frame});

  my $tf = $frm->new_ttk__frame();
  $tf->g_pack(qw/-side top -expand 1 -fill both/);

  my $bf = $frm->new_ttk__frame();
  $bf->g_pack(qw/-side bottom -fill x/);

  my $txt = $tf->new_tk__text(
    -font => "\{$EditFont{family}\} $EditFont{size}",
    -relief => 'raised',
    -borderwidth => 2,
    -highlightthickness => 0,
    -selectborderwidth => 0,
    -wrap=> 'none',
    -spacing1 => 6,
    -undo => 0,
    -setgrid => 'true'); # use this for autosizing

  my $sv = $tf->new_ttk__scrollbar(-orient => "vertical",   -command => [$txt, "yview"]);
  my $sh = $tf->new_ttk__scrollbar(-orient => "horizontal", -command => [$txt, "xview"]);

  $txt->configure(-yscrollcommand => [$sv, 'set']);
  $txt->configure(-xscrollcommand => [$sh, 'set']);

  $sh->g_pack(qw/-side bottom -fill x/);
  $txt->g_pack(qw/-side left -expand 1 -fill both/);
  $sv->g_pack(qw/-side left -fill y/);

  my $bp = $bf->new_ttk__button(-text => "Print", -command => sub{printFile($fn)} );
  $bp->g_pack(qw/-side left -padx 40 -pady 8/);
  my $bc = $bf->new_ttk__button(-text => "Close", -command => sub{$pop->popDestroy()});
  $bc->g_pack(qw/-side right -padx 40 -pady 8/);

  open(FH, "<", "$fn");
  while (<FH>) {
    $txt->insert('end', $_);
  }
  close(FH);
  $txt->m_configure(-state => 'disabled');
}

sub printFile {
  my($fn) = shift;

  my $act;
  if ($Cmnd->{Print} ne "") {
    if ($Cmnd->{Print} =~ /(\%file\%)/i) {
      ($act = $Cmnd->{Print}) =~ s/$1/$fn/i;
    } else {
      $act = "$Cmnd->{Print} \"$fn\"";
    }
    spawn($act);
  } else {
    if (OS eq "win32") {
      spawn("notepad.exe /p \"$fn\"");
    } else {
      spawn("lpr $fn");
    }
  }
}

sub clearElog {
  if (msgYesNo("Do you really want to clear the Error Log?") eq "Yes") {
    unlink(ERRLOG);
    open(FH, ">", ERRLOG);
    close(FH);
    message(SMILE, " Done ", -1);
  }
}

###############################
# ARROWS
#
$XPM{'alll'} = <<'EOXPM';
/* XPM */
static char * alll[] = {
"24 14 7 1",
". s None c None",
"x c #600060",	  
"c c #903890",	  
"o c #B058B0",
"a c #000000",
"+ c #909090",
"# c #B0B0B0",
"......c.................",
"....cxx.................",
"..cxxxx.................",
"ocxxxxxxxxxxxxxx........",
"ocxxxxxxxxxxxxxx........",
"..cxxxx.................",
"....cxx......#a#...a+.a+",
"......c......aaa...a+.a+",
"............+a+a+..a+.a+",
"............aa.aa..a+.a+",
"............a+.+a..a+.a+",
"...........+aaaaa+.a+.a+",
"...........aa+.+aa.a+.a+",
"...........aa...aa.a+.a+"};
EOXPM

$XPM{'allr'} = <<'EOXPM';
/* XPM */
static char * allr[] = {
"24 14 7 1",
". s None c None",
"x c #600060",	  
"c c #903890",	  
"o c #B058B0",
"a c #000000",
"+ c #909090",
"# c #B0B0B0",
".................c......",
".................xxc....",
".................xxxxc..",
"........xxxxxxxxxxxxxxco",
"........xxxxxxxxxxxxxxco",
".................xxxxc..",
"..#a#...a+.a+....xxc....",
"..aaa...a+.a+....c......",
".+a+a+..a+.a+...........",
".aa.aa..a+.a+...........",
".a+.+a..a+.a+...........",
"+aaaaa+.a+.a+...........",
"aa+.+aa.a+.a+...........",
"aa...aa.a+.a+..........."};
EOXPM

$XPM{'arru'} = <<'EOXPM';
/* XPM */
static char * arru[] = {
"12 14 4 1",
". s None c None",
"x c #600060",	  
"c c #903890",	  
"o c #B058B0",
".....oo.....", 
".....cc.....", 
"....cxxc....", 
"....xxxx....", 
"...cxxxxc...", 
"...xxxxxx...", 
"..cxxxxxxc..", 
".....xx.....", 
".....xx.....", 
".....xx.....", 
".....xx.....", 
".....xx.....", 
".....xx.....", 
".....xx....."};
EOXPM

$XPM{'arrd'} = <<'EOXPM';
/* XPM */
static char * arrd[] = {
"12 14 4 1",
". s None c None",
"x c #600060",
"c c #903890",
"o c #B058B0",
".....xx.....",
".....xx.....",
".....xx.....",
".....xx.....",
".....xx.....",
".....xx.....",
".....xx.....",
"..cxxxxxxc..",
"...xxxxxx...",
"...cxxxxc...",
"....xxxx....",
"....cxxc....",
".....cc.....",
".....oo....."};
EOXPM

$XPM{'arrr'} = <<'EOXPM';
/* XPM */
static char * arrr[] = {
"24 10 4 1",
". s None c None",
"x c #600060",	  
"c c #903890",	  
"o c #B058B0",
"........................",
"................c.......",
"................xxc.....",
"................xxxxc...",
".......xxxxxxxxxxxxxxco.",
".......xxxxxxxxxxxxxxco.",
"................xxxxc...",
"................xxc.....",
"................c.......",
"........................"};
EOXPM
    
$XPM{'arrl'} = <<'EOXPM';
/* XPM */
static char * arrl[] = {
"24 10 4 1",
". s None c None",
"x c #600060",	  
"c c #903890",	  
"o c #B058B0",
"........................",
".......c................",
".....cxx................",
"...cxxxx................",
".ocxxxxxxxxxxxxxx.......",
".ocxxxxxxxxxxxxxx.......",
"...cxxxx................",
".....cxx................",
".......c................",
"........................"};
EOXPM
    
$XPM{dated} = <<'EOXPM';
/* XPM */
static char *dated[] = {
"13 13 3 1",
"  c None",
"x c #600060",
"c c #90c0c0",
"             ",
"          c  ",
"         cx  ",
"       cxxx  ",
"     cxxxxx  ",
"   cxxxxxxx  ",
" cxxxxxxxxx  ",
"   cxxxxxxx  ",
"     cxxxxx  ",
"       cxxx  ",
"         cx  ",
"          c  ",
"             "};
EOXPM

$XPM{dateu} = <<'EOXPM';
/* XPM */
static char *dateu[] = {
"13 13 3 1",
"  c None",
"x c #600060",
"c c #90c0c0",
"             ",
"  c          ",
"  xc         ",
"  xxxc       ",
"  xxxxxc     ",
"  xxxxxxxc   ",
"  xxxxxxxxxc ",
"  xxxxxxxc   ",
"  xxxxxc     ",
"  xxxc       ",
"  xc         ",
"  c          ",
"             "};
EOXPM

$XPM{timeu} = <<'EOXPM';
/* XPM */
static char *timeu[] = {
"13 13 3 1",
"  c None",
"x c #600060",
"c c #90c0c0",
"             ",
"      c      ",
"      x      ",
"     cxc     ",
"     xxx     ",
"    cxxxc    ",
"    xxxxx    ",
"   cxxxxxc   ",
"   xxxxxxx   ",
"  cxxxxxxxc  ",
" cxxxxxxxxxc ",
"             ",
"             "};
EOXPM

$XPM{timed} = <<'EOXPM';
/* XPM */
static char *timed[] = {
"13 13 3 1",
"  c None",
"x c #600060",
"c c #90c0c0",
"             ",
"             ",
" cxxxxxxxxxc ",
"  cxxxxxxxc  ",
"   xxxxxxx   ",
"   cxxxxxc   ",
"    xxxxx    ",
"    cxxxc    ",
"     xxx     ",
"     cxc     ",
"      x      ",
"      c      ",
"             "};
EOXPM

###############################
# ICONS
#
$XPM{'Cicon'} = <<'EOXPM';
/* XPM */
static char * Cicon[] = {
"32 32 27 1",
". c #f2b813",
"# c #845616",
"a c #714a1e",
"b c #989797",
"c c #edad10",
"d c #45291c",
"e c #8e5f16",
"f c #b4b4b4",
"g c #ffd51c",
"h c #ffce1f",
"i c #3e2118",
"j c #5f5f5f",
"k c #673f1c",
"l c #f9c015",
"m c #ffdd1e",
"n c #ffffff",
"o c #5a5a5a",
"p c #50321d",
"q c #e0a214",
"r c #593c1c",
"s c #ffdc1b",
"t c #664d02",
"u c #936719",
"v c #613e1b",
"w c #512a14",
"x c #ffedb4",
"y c #4b2b19",
"xxxbjxxxbjxxxbxxxxbxxxxbxxxxbxxx",
"xxxbjxxxbjxxxbxxxxbxxxxbxxxxbxxx",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbtttwuktttbttf",
"fttbjtttbjtttbttttbttycmlvttbttf",
"fttbjtttbjtttbttttbtt#shsettbttf",
"fttbjtttbjtttbttttbttdqg.rttbttf",
"fttbjtttbjtttbttttbtttiaptttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"xxxbjxxxbjxxxbxxxxbxxxxbxxxxbxxx",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjttwuktttbttttbttttbttf",
"fttbjtttbjtycmlvttbttttbttttbttf",
"fttbjtttbjt#shsettbttttbttttbttf",
"fttbjtttbjtdqg.rttbttttbttttbttf",
"fttbjtttbjttiaptttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"xxxbjxxxbjxxxbxxxxbxxxxbxxxxbxxx",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjttwuktttbobbobttttbttttbttf",
"fttbjtycmlvttbbnnbbttttbttttbttf",
"fttbjt#shsettbbnnbbttttbttttbttf",
"fttbjtdqg.rttbobbobttttbttttbttf",
"fttbjttiaptttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"xxxbjxxxbjxxxbxxxxbxxxxbxxxxbxxx"};
EOXPM

$XPM{'Eicon'} = <<'EOXPM';
/* XPM */
static char *Eicon[] = {
"32 32 27 1",
". c #f2b813",
"# c #845616",
"a c #714a1e",
"b c #989797",
"c c #edad10",
"d c #45291c",
"e c #8e5f16",
"f c #b4b4b4",
"g c #ffd51c",
"h c #ffce1f",
"i c #3e2118",
"j c #5f5f5f",
"k c #673f1c",
"l c #f9c015",
"m c #ffdd1e",
"n c #ffffff",
"o c #5a5a5a",
"p c #50321d",
"q c #e0a214",
"r c #593c1c",
"s c #ffdc1b",
"t c #664d02",
"u c #936719",
"v c #613e1b",
"w c #512a14",
"x c #ffedb4",
"y c #4b2b19",
"xxxbjxxxbjxxxbxxxxbxxxxbxxxxbxxx",
"xxxbjxxxbjxxxbxxxxbxxxxbxxxxbxxx",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbtttwuktttbttttbttf",
"fttbjtttbjtttbttycmlvttbttttbttf",
"fttbjtttbjtttbtt#shsettbttttbttf",
"fttbjtttbjtttbttdqg.rttbttttbttf",
"fttbjtttbjtttbtttiaptttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"xxxbjxxxbjxxxbxxxxbxxxxbxxxxbxxx",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjttwukttwuktttbttttbttttbttf",
"fttbjtycmlvycmlvttbttttbttttbttf",
"fttbjt#shse#shsettbttttbttttbttf",
"fttbjtdqg.rdqg.rttbttttbttttbttf",
"fttbjttiapttiaptttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"xxxbjxxxbjxxxbxxxxbxxxxbxxxxbxxx",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbobbobttttbttttbttf",
"fttbjtttbjtttbbnnbbttttbttttbttf",
"fttbjtttbjtttbbnnbbttttbttttbttf",
"fttbjtttbjtttbobbobttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"fttbjtttbjtttbttttbttttbttttbttf",
"xxxbjxxxbjxxxbxxxxbxxxxbxxxxbxxx"};
EOXPM

###############################
# BUTTONS
#
$XPM{batchPDF} = <<'EOXPM';
/* XPM */
static char * batchPDF_xpm[] = {
"24 22 7 1",
" 	c None",
"x	c #202020",
"+	c #CCCCCC",
"@	c #888888",
".	c #808080",
"%	c #C0C0C0",
"-	c #F8F8F8",
"  ....................  ",
"  .------------------.  ",
"  .%%%%%%%%%%%%%%%%%%.  ",
"  .xxxx+.xxxxx..xxxxx.  ",
"  .xx@xx-xx@@xx-xx@@@.  ",
"  .xx%xx%xx%%xx%xx%%%.  ",
"  .xx.xx.xx..xx.xxxxx.  ",
"  .xxxx--xx--xx-xx@@@.  ",
"  .xx@@%%xx%%xx%xx%%%.  ",
"  .xx....xx@@xx.xx....  ",
"  .xx----xxxxx--xx---.  ",
"  .%%%%%%%%%%%%%%%%%%.  ",
"  ....................  ",
"  .------------------.  ",
"  .%%%%%%%%%%%%%%%%%%.  ",
"  ....................  ",
"  .------------------.  ",
"  .%%%%%%%%%%%%%%%%%%.  ",
"  ....................  ",
"  .------------------.  ",
"  .%%%%%%%%%%%%%%%%%%.  ",
"   ...................  "};
EOXPM

$XPM{blank} = <<'EOXPM';
/* XPM */
static char *blank[] = {
"10 10 1 1",
"e s None c None",
"eeeeeeeeeee",
"eeeeeeeeeee",
"eeeeeeeeeee",
"eeeeeeeeeee",
"eeeeeeeeeee",
"eeeeeeeeeee",
"eeeeeeeeeee",
"eeeeeeeeeee",
"eeeeeeeeeee",
"eeeeeeeeeee"};
EOXPM

$XPM{checkbox} = <<'EOXPM';
/* XPM */
static char * checkbox_xpm[] = {
"24 14 4 1",
"  c None",
"o c #000000",
". c #A0A0A0",
", c #D0D0D0",
"     oooooooooooooo     ",
"     oo.,,,,,,,,.oo     ",
"     o.o.      .o.o     ",
"     o,.o.    .o.,o     ",
"     o, .o.  .o. ,o     ",
"     o,  .o..o.  ,o     ",
"     o,   .oo.   ,o     ",
"     o,   .oo.   ,o     ",
"     o,  .o..o.  ,o     ",
"     o, .o.  .o. ,o     ",
"     o,.o.    .o.,o     ",
"     o.o.      .o.o     ",
"     oo.,,,,,,,,.oo     ",
"     oooooooooooooo     "};
EOXPM

$XPM{scheckbox} = <<'EOXPM';
/* XPM */
static char * scheckbox_xpm[] = {
"13 9 4 1",
"  c None",
"o c #000000",
". c #A0A0A0",
", c #D0D0D0",
" ooooooooo   ",
" oo.,,,.oo   ",
" o.o. .o.o   ",
" o,.o.o.,o   ",
" o, .o. ,o   ",
" o,.o.o.,o   ",
" o.o. .o.o   ",
" oo.,,,.oo   ",
" ooooooooo   "};
EOXPM

$XPM{'chordL'} = <<'EOXPM';
/* XPM */
static char *chordL_xpm[] = {
"24 22 3 1",
"  c None",
"e c #606060",
"o c #808080",
"      oe                ",
"     eee                ",
"   oeeee                ",
" oeeeeeeeeeeeeeeeee     ",
" oeeeeeeeeeeeeeeeee     ",
"   oeeee                ",
"     eee                ",
"      oe                ",
"                        ",
"        oee  eeo        ",
"       oeo    oeo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oeo    oeo       ",
"        oee  eeo        ",
"                        "};
EOXPM

$XPM{'chordR'} = <<'EOXPM';
/* XPM */
static char *chordR_xpm[] = {
"24 22 3 1",
"  c None",
"e c #606060",
"o c #808080",
"                eo      ",
"                eee     ",
"                eeeeo   ",
"      eeeeeeeeeeeeeeeeo ",
"      eeeeeeeeeeeeeeeeo ",
"                eeeeo   ",
"                eee     ",
"                eo      ",
"                        ",
"        oee  eeo        ",
"       oeo    oeo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oe      eo       ",
"       oeo    oeo       ",
"        oee  eeo        ",
"                        "};
EOXPM

$XPM{'chordU'} = <<'EOXPM';
/* XPM */
static char *chordU_xpm[] = {
"24 22 3 1",
"  c None",
"e c #606060",
"o c #808080",
"                        ",
"                        ",
"     oo                 ",
"     ee                 ",
"    oeeo                ",
"    eeee                ",
"   eeeeee               ",
"  eeeeeeee              ",
" oeeeeeeeeo             ",
"     ee       oee  eeo  ",
"     ee      oeo    oeo ",
"     ee      oe      eo ",
"     ee      oe      eo ",
"     ee      oe      eo ",
"     ee      oe      eo ",
"     ee      oe      eo ",
"     ee      oe      eo ",
"     ee      oe      eo ",
"     ee      oe      eo ",
"             oeo    oeo ",
"              oee  eeo  ",
"                        "};
EOXPM

$XPM{'chordD'} = <<'EOXPM';
/* XPM */
static char *chordD_xpm[] = {
"24 22 3 1",
"  c None",
"e c #606060",
"o c #808080",
"                        ",
"                        ",
"                        ",
"     ee                 ",
"     ee                 ",
"     ee                 ",
"     ee                 ",
"     ee                 ",
"     ee                 ",
"     ee       oee  eeo  ",
"     ee      oeo    oeo ",
"     ee      oe      eo ",
"     ee      oe      eo ",
" oeeeeeeeeo  oe      eo ",
"  eeeeeeee   oe      eo ",
"   eeeeee    oe      eo ",
"    eeee     oe      eo ",
"    oeeo     oe      eo ",
"     ee      oe      eo ",
"     oo      oeo    oeo ",
"              oee  eeo  ",
"                        "};
EOXPM

$XPM{clearlog} = <<'EOXPM';
/* XPM */
static char * clearlog_xpm[] = {
"24 24 10 1",
" 	c None",
".	c #613D00",
"+	c #764B00",
"@	c #432A01",
"#	c #976000",
"$	c #000000",
"%	c #B29055",
"&	c #C87F00",
"*	c #AD6E00",
"=	c #8C5B04",
"                        ",
"                        ",
"            .+.         ",
"   @@      #+++     @@  ",
"   @$@     #+++.   @$@  ",
"    @$@     .+++..@$@   ",
"   ##@$@#####.+++@$@#   ",
"  #%#&@$@&&&&&+.@$@&&#  ",
"  #%#&&@$@&&&&&@$@&&&#  ",
"  #%#***@$@***@$@****#  ",
" #%%%#***@$@+@$@******# ",
" #%%%#####@$@$@######## ",
" #%%%#####+@$@+######## ",
" #%%%#====@$@$@=======# ",
" #%%%#===@$@+@$@======# ",
"  #%#+++@$@+++@$@++++#  ",
"  #%#++@$@+++++@$@+++#  ",
"  .%#.@$@.......@$@...  ",
"   ..@$@.........@$@.   ",
"    @$@           @$@   ",
"   @$@             @$@  ",
"   @@               @@  ",
"                        ",
"                        "};
EOXPM

$XPM{close} = <<'EOXPM';
/* XPM */
static char * C:\tmp\text1_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000300",
"+	c #1A1B14",
"@	c #24251E",
"#	c #3A3D32",
"$	c #555845",
"%	c #6E715C",
"&	c #80836D",
"*	c #8B8D72",
"=	c #9D9F83",
"-	c #9BA090",
";	c #AFB196",
">	c #B1B894",
",	c #BEC5A0",
"'	c #C8CFAA",
")	c #CDD4AF",
"!	c #E4E7D0",
"                        ",
"                        ",
"  .......               ",
" .;!!!!!&#              ",
" .!)))))>@              ",
"@-!''''''$+             ",
"@...................%   ",
"@'''''''''''''''''''.   ",
".'''''''''''''''''''.   ",
".'''''''''''''''''''.   ",
".'''''''''''''''''''.   ",
".''''))))))))))))'',.   ",
".''''))))))))))''',,.   ",
".''''''''''''''',,>>.   ",
".,,,,,,,,,,,,,,,>>;=.   ",
".>>>>>>>>>;;;;;====*.   ",
".==============****%.   ",
".***********&&&%%%%#.   ",
"%...................%   ",
"                        ",
"                        ",
"                        "};
EOXPM

$XPM{colour} = <<'EOXPM';
/* XPM */
static char * colour_xpm[] = {
"56 16 17 1",
" 	c None",
".	c #F800D1",
"+	c #FF156A",
"@	c #A333FF",
"#	c #565BFF",
"$	c #FF571A",
"%	c #3983FE",
"&	c #19A1FF",
"*	c #0FCFFD",
"=	c #FFA400",
"-	c #00F3EA",
";	c #00FCCD",
">	c #33FF9E",
",	c #FDDA02",
"'	c #72FE60",
")	c #BDFE0E",
"!	c #EFF800",
".....@@@@@@@@#####%%&%&****----;>;>'''')))!)!!!!,,,,====",
"..@.@@.@@@#@#@##%%%&&&*&**----;;>>>''')))))!!!!!,,,,,===",
"...@@@@@@@@####%%%%&&****---;;;>>>'''))')!)!!!,,,,==,===",
"..@@.@@@@@#####%%&&&&***----;;>>>'''))))!)!!!,!,,,,=====",
".@@@@@@#@##@#%%%%&&***----;;;;>>'''))')!!!!!!,,,,======$",
"@@.@@@@@###%#%%&&&*-**----;;>>>'''))))))!!!,,,,=,====$==",
"@@@@@@@##@##%%&&&****----;;>>>''')'))!!!!!!,!,,=======$$",
".@@@@@####%%%&&&****----;;;>>'''))))))!!!,,,=,,=,==$==$$",
"@@@#@##@#%%%%&&****----;;>>>''')'))!!!!!!,!,,========$$$",
"@@@@###%#%%&&&**-*---;;;>>>'''))))))!!!,,!=,,=,===$=$$$$",
"@#@#@###%%%&&****----;;>>>''')'))!)!!!!,,,,=======$$$$$$",
"@@#####%%&&&****---;;;;>>''')))))!!!!,!,,=,=,==$==$=$+$+",
"@##@#%%%&&&***-----;;>>>''')'))!)!!!,,,,,=,=====$$$$$$++",
"###%#%%&&&****----;;>>>'''))))!)!!!,!,,,,=====$==$$$$++.",
"#@##%%%&&*&-*----;;;>>'''))'))!!!!!,,,===,=====$$$$$++..",
"##%%%&&&****---;;;>>>'''')))!)!!!!,,,,=,=====$=$$$+$++.."};
EOXPM

$XPM{copy} = <<'EOXPM';
/* XPM */
static char * copy_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000100",
"+	c #595B58",
"@	c #626461",
"#	c #6A6C69",
"$	c #757774",
"%	c #7F817E",
"&	c #818380",
"*	c #8D8F8C",
"=	c #969895",
"-	c #A6A8A5",
";	c #B2B5B1",
">	c #C4C6C3",
",	c #D4D6D3",
"'	c #E7E9E6",
")	c #F6F9F5",
"!	c #FDFFFC",
"                        ",
".............           ",
".;))))))))))>.          ",
".!'''''''''''.          ",
".!=&&*';&'%;'.          ",
".!'''''''''''.          ",
".)@+'#&;'............   ",
".!''''''.;!!!!!!!!!!,.  ",
".)=%%'&%.!!!!!!!!!!!!.  ",
".!''''''.!-**=!>*!*>!.  ",
".)@++'#%.!!!!!!!!!!!!.  ",
".!''''''.!#@!$*>!>*!!.  ",
".)=%&'%%.!!!!!!!!!!!!.  ",
".'''''''.!-**!**>!=*!.  ",
".>''''''.!!!!!!!!!!!!.  ",
" ........!#@@!$*>!>*!.  ",
"        .!!!!!!!!!!!!.  ",
"        .!-**!**>!=*!.  ",
"        .!!!!!!!!!!!!.  ",
"        .,!!!!!!!!!!,.  ",
"        ..............  ",
"                        "};
EOXPM

$XPM{cut} = <<'EOXPM';
/* XPM */
static char * cut_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000100",
"+	c #141614",
"@	c #363633",
"#	c #484A47",
"$	c #5B5955",
"%	c #71706D",
"&	c #7F7E78",
"*	c #8A8C89",
"=	c #A19B97",
"-	c #BBB4AD",
";	c #BAB9B6",
">	c #CCCDC7",
",	c #DEE1DD",
"'	c #EFEAE8",
")	c #EAEDE9",
"!	c #F1F4F0",
"                        ",
"      .        .        ",
"      .        .        ",
"     .>.      .,.       ",
"     .)#      %,.       ",
"     .'&.    .!>.       ",
"     .)-$    %)=.       ",
"      &)&.  .!>#        ",
"      .!-#  #)-.        ",
"       *!%.@)>$         ",
"       .!>@%;-.         ",
"        .';#-.          ",
"         .,=..          ",
"         .+%@.          ",
"     .............      ",
"     . ...  ... ...     ",
"    ..  ..   ..  ..     ",
"    .    .   .    .     ",
"    ..  ..   ..  ..     ",
"     ....     .. .      ",
"     ....     ....      ",
"                        "};
EOXPM

$XPM{delete} = <<'EOXPM';
/* XPM */
static char * delete_xpm[] = {
"24 22 18 1",
" 	c None",
".	c #000100",
"+	c #5F5F57",
"@	c #7E7975",
"#	c #90877B",
"$	c #979792",
"%	c #A29A8D",
"&	c #A7A9A6",
"*	c #BFC1BE",
"=	c #D0D2CF",
"-	c #D7DAD6",
";	c #DEE0DD",
">	c #E6E1E0",
",	c #E3E5E2",
"'	c #E9EBE8",
")	c #F1F4F0",
"!	c #FBFEFB",
"o	c #A00000",
" oo.............     oo ",
" ooo)!!!!!!!!!-+.   ooo ",
"  ooo!!!!!!!!!*=-. ooo  ",
"  .ooo!!!!!!!!*;)$ooo   ",
"  .!ooo!!!!!!!&'!ooo    ",
"  .!!ooo!!!!!!&)ooo&.   ",
"  .!!!ooo!!!!)$ooo....  ",
"  .!!!!ooo))))ooo*$@+.  ",
"  .!!!!)ooo))ooo--=&#.  ",
"  .!!))))oooooo'''=*#.  ",
"  .!))))))oooo''',,=#.  ",
"  .!))))))oooo',,,;>%.  ",
"  .!)))))oooooo,,,;>%.  ",
"  .!)))'ooo''ooo;>;;%.  ",
"  .!'''ooo''''ooo;;-%.  ",
"  .!''ooo,,,,>,ooo--%.  ",
"  .!,ooo,>,>,,;;ooo-%.  ",
"  .!ooo>,;;;;;;;-ooo%.  ",
"  .ooo;;;;;;;;;---ooo.  ",
"  ooo;;;;;;;;------ooo  ",
" ooo%%%%%%%%%%%%%%%%ooo ",
" oo..................oo "};
EOXPM

$XPM{dot} = <<'EOXPM';
/* XPM */
static char *dot[] = {
"9  5  3 1",
"  c None",
"x c #009000",
"c c #80ff80",
"    c    ",
"  cxxxc  ",
" cxxxxxc ",
"  cxxxc  ",
"    c    "};
EOXPM

$XPM{hyphen} = <<'EOXPM';
/* XPM */
static char *hyphen[] = {
"8 2 2 1",
"  c None",
"x c #000000",
"xxxxxxxx",
"xxxxxxxx",
EOXPM

$XPM{exit} = <<'EOXPM';
/* XPM */
static char * exit_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #010400",
"+	c #620001",
"@	c #980501",
"#	c #242C21",
"$	c #772E2B",
"%	c #3C4B37",
"&	c #60625F",
"*	c #DE421D",
"=	c #576D4F",
"-	c #757774",
";	c #EA7860",
">	c #CC8587",
",	c #9EA19E",
"'	c #EFA996",
")	c #BEC1BD",
"!	c #E1E3E0",
"       ................ ",
"       .!),,-&&&#...... ",
"       .!!!)),--#...... ",
"     . .!!!))),,#...... ",
"     ...!!!)))))%...... ",
"     .;.!!!)))))&...... ",
"......;;.!!)))))&...... ",
".';;;;;*;.))))))&...... ",
".'*******;.)))&)&..###. ",
".'********;.))&.&.####. ",
".>@@@@@@@@@+.,.)&#####. ",
".>@@@@@@@@+.,)))&#####. ",
".>@@@@@@@+.)))))&#####. ",
".$+++++@+.))))))&###%%. ",
"......++.)!)))))&##%%%. ",
"     .+.)!!)))))&##%%%. ",
"     ...!!!))),,&##%%%. ",
"     . .!!!)),-##%%%%=. ",
"       .!!),,##%%%====. ",
"       .!)-#%%%=======. ",
"       .,%%===========. ",
"       ................ "};
EOXPM

$XPM{Find} = <<'EOXPM';
/* XPM */
static char * Find_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000300",
"+	c #34342D",
"@	c #484841",
"#	c #696A65",
"$	c #918B80",
"%	c #9A9C99",
"&	c #A49B8F",
"*	c #AFB1AC",
"=	c #B6B29E",
"-	c #C4C7B1",
";	c #C7CAC6",
">	c #D2D4D1",
",	c #D2D6BF",
"'	c #DEE0DC",
")	c #EEF1ED",
"!	c #FCFFFB",
"   .............        ",
"  .>)!!!!!!!!!'#.       ",
"  .)!!!!!!!!!!;>>.      ",
"  .!!!!!!!!!!!;')%.     ",
"  .!!!!!!!!!!!*)!'%.    ",
"  .!!!!!!!!!!!*)!);%.   ",
"  .!!!!*@..@*)%.......  ",
"  .!!!*+&,-$+*)'>*%##.  ",
"  .!!!@&')==$@'''>;*$.  ",
"  .!)).,!-=&&.;'))>;$.  ",
"  .!)).-,==&=.*')''>$.  ",
"  .!))@$==&=;@*>''''$.  ",
"  .!))%+$&=;..*>''''&.  ",
"  .!))'$@..@#..%''''&.  ",
"  .!))';*%%%%...*'''&.  ",
"  .!))'';****#...%''&.  ",
"  .!'''''>;>;;#...;>&.  ",
"  .!'''''''''>;#..*;&.  ",
"  .)'''''''''';**%*;&.  ",
"  .>''''''''''>;***;$.  ",
"  .%&&&&&&&&&&&&$$$$#.  ",
"   ..................   "};
EOXPM

$XPM{FindNext} = <<'EOXPM';
/* XPM */
static char * FindNext_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000300",
"+	c #E20000",
"@	c #323331",
"#	c #484A47",
"$	c #626562",
"%	c #787A77",
"&	c #8A8C89",
"*	c #979996",
"=	c #A1A3A0",
"-	c #A9ABA8",
";	c #BABCB9",
">	c #CCCECB",
",	c #D8DAD7",
"'	c #E2E4E1",
")	c #EDEFEC",
"!	c #FCFEFB",
"   .............        ",
"  .,)!!!!!!!!!,$.       ",
"  .)!!!!!!&..&>,,.      ",
"  .!!!!!!!.++.;,)*.     ",
"  .!!!!!!!.++.-)!'*.    ",
"  .!!!!!!!.++.=)!)>-.   ",
"  .!!!!;#..++.=.......  ",
"  .!!!-@*>.++.)',;-%$.  ",
"  .!!)#*,).++.'',',;&.  ",
"  .!!).>!;.++.,))),>&.  ",
"  .!))&..&.++.&..&),*.  ",
"  .!)).++..++..++.))*.  ",
"  .!)).+++.++.+++.))-.  ",
"  .!))&.++++++++.&))=.  ",
"  .!')'&.++++++.&)))-.  ",
"  .!')''.++++++..-))-.  ",
"  .!''')&.++++.&..''-.  ",
"  .!''')).++++.&..>'=.  ",
"  .''')))&.++.&>;-;'=.  ",
"  .''))))).++.)'>;>,-.  ",
"  .==----=&..&-==*==$.  ",
"   ..................   "};
EOXPM

$XPM{FindPrev} = <<'EOXPM';
/* XPM */
static char * FindPrev_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000200",
"+	c #E20000",
"@	c #313330",
"#	c #474946",
"$	c #6F716E",
"%	c #868885",
"&	c #919390",
"*	c #9C9F9C",
"=	c #A5A7A4",
"-	c #B4B6B3",
";	c #BBBDBA",
">	c #CFD1CE",
",	c #D9DBD8",
"'	c #E0E2DF",
")	c #E8EBE7",
"!	c #FBFDFA",
"   .............        ",
"  .>!!!!!!!$$!>#.       ",
"  .!!!!!!!$..$>>>.      ",
"  .!!!!!!!.++.;>)*.     ",
"  .!!!!!!$.++.$)!>&.    ",
"  .!!!!!!.++++.)!)>=.   ",
"  .!!!!-$.++++.$......  ",
"  .!!!=@.++++++.>-=$$.  ",
"  .!!!#$.++++++.$'>-%.  ",
"  .!!!$.++++++++.$,>&.  ",
"  .!!!.+++.++.+++.),&.  ",
"  .!!!.++..++..++.))*.  ",
"  .!!!$..$.++.$..$))=.  ",
"  .!!)'%#..++..=))))=.  ",
"  .!))'>-=.++...-)))=.  ",
"  .!))),>;.++....=))=.  ",
"  .!)))'',.++.$...>)=.  ",
"  .))'))').++.>%..>,*.  ",
"  .)'))')).++.'>-=-,*.  ",
"  .,'))))).++.),>->,*.  ",
"  .**=**==$..$=**&**$.  ",
"   ..................   "};
EOXPM

$XPM{include} = <<'EOXPM';
/* XPM */
static char * include_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000100",
"+	c #595B58",
"@	c #626461",
"#	c #6A6C69",
"$	c #757774",
"%	c #818380",
"&	c #898B88",
"*	c #8D8F8C",
"=	c #969895",
"-	c #A6A8A5",
";	c #B2B5B1",
">	c #C4C7C3",
",	c #D4D6D3",
"'	c #E7E9E6",
")	c #F6F9F5",
"!	c #FDFFFC",
"                        ",
"     .............      ",
"     .;))))))))))>.     ",
"     .)'''''''''''.     ",
"     .)=%%&';%'%;'.     ",
"     .)'''''''''''.     ",
"     .)@+'#..%'%;'.     ",
"     .)''''..;%'%;.     ",
"     .)=%%....#%;%.     ",
"     .)'''....';%'.     ",
"     '............      ",
"     .;!!......!!,.     ",
"     .!!........!!.     ",
"     .!-**=..*!*>!.     ",
"     .!!!!!..!!!!!.     ",
"     .!#@!$..!>*!!.     ",
"     .!!!!!..!!!!!.     ",
"     .!-**!..>!=*!.     ",
"     .!!!!!..!!!!!.     ",
"     .!#@@!$*>!>*!.     ",
"     .!!!!!!!!!!!!.     ",
"     .!-**!**>!=*!.     "};
EOXPM

$XPM{new} = <<'EOXPM';
/* XPM */
static char * new_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000100",
"+	c #5F5F57",
"@	c #7E7975",
"#	c #90877B",
"$	c #979792",
"%	c #A29A8D",
"&	c #A7A9A6",
"*	c #BFC1BE",
"=	c #D0D2CF",
"-	c #D7DAD6",
";	c #DEE0DD",
">	c #E6E1E0",
",	c #E3E5E2",
"'	c #E9EBE8",
")	c #F1F4F0",
"!	c #FBFEFB",
"   .............        ",
"  .=)!!!!!!!!!-+.       ",
"  .)!!!!!!!!!!*=-.      ",
"  .!!!!!!!!!!!*;)$.     ",
"  .!!!!!!!!!!!&'!;$.    ",
"  .!!!!!!!!!!!&)!)=&.   ",
"  .!!!!!!!!!!)$.......  ",
"  .!!!!!!))))));=*$@+.  ",
"  .!!!!)))))))),--=&#.  ",
"  .!!))))))))))'''=*#.  ",
"  .!))))))))))''',,=#.  ",
"  .!)))))))))'',,,;>%.  ",
"  .!)))))))))'',,,;>%.  ",
"  .!)))''''''',,;>;;%.  ",
"  .!'''''''''',>;;;-%.  ",
"  .!''',,,,,,>,;;;--%.  ",
"  .!,,,,,>,>,,;;;---%.  ",
"  .!,;;>,;;;;;;;----%.  ",
"  .';>;;;;;;;;;-----%.  ",
"  .=;;;;;;;;;------=%.  ",
"  .$%%%%%%%%%%%%%%%%+.  ",
"   ..................   "};
EOXPM

$XPM{open} = <<'EOXPM';
/* XPM */
static char * open_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000300",
"+	c #22221B",
"@	c #3C3B31",
"#	c #4E5345",
"$	c #707361",
"%	c #86886F",
"&	c #999B81",
"*	c #A5A88C",
"=	c #B1B397",
"-	c #B4BB97",
";	c #B7BDAC",
">	c #C4CBA6",
",	c #C6CCBB",
"'	c #CDD4AF",
")	c #D8DDCB",
"!	c #E7EBD9",
"                        ",
"                        ",
"  .......               ",
" .;!!!!!%@              ",
" .!'''''-@              ",
"+&!>>>>>>#+             ",
"+)-------%@........     ",
"+)-*********;;;,,,;.    ",
".)&&&&&&&********&%.    ",
".)%%+.................  ",
".)%@!!!!!!!!!!!!!!!)))+ ",
".)$.!''''''''''''>>>-=+ ",
".)#)!'''''''''''>>>--%. ",
".)+!>>>>>>>>>>>>>---*#. ",
".;$!>>>>>>>->-----**%.  ",
".*)-------====***&&%#.  ",
".&!=********&&&&%%%$.   ",
".!;&&%%%%%%%%%%$$$$@.   ",
" ...................    ",
"                        ",
"                        ",
"                        "};
EOXPM

$XPM{paste} = <<'EOXPM';
/* XPM */
static char * paste_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #010400",
"+	c #28200C",
"@	c #323229",
"#	c #454437",
"$	c #6C6E69",
"%	c #877436",
"&	c #938D74",
"*	c #8D8F8C",
"=	c #A0A29F",
"-	c #A9A385",
";	c #C3BB9B",
">	c #C8CAC7",
",	c #D7CEA7",
"'	c #EBE7D1",
")	c #F6F4E5",
"!	c #FCFEFB",
"       ....             ",
" ......>!!$......       ",
".)))))$!=*$$>))),.      ",
".),,,-#!$$=@&;,,%.      ",
".);;-#!!>>>$@&-;%.      ",
".),,#>=====*##-,%.      ",
".);;&#@@@@@@@&-;%.      ",
".),,,&&&&&&&&;,,%.      ",
".);;;;;&#.....@@+....   ",
".)-----@!!!!!!!!!!!!!.  ",
".),,,,,.!=**=!!>*!*>!.  ",
".);----.!!!!!!!!!!!!!.  ",
".),,,,,#!$$!$**>!>*!!.  ",
".)-----@!!!!!!!!!!!!!.  ",
".),,,,,#!=**!***>!=*!.  ",
".)-----.!!!!!!!!!!!!!.  ",
".),,,,,.!$$!$**>!>*!!.  ",
".)-----@!!!!!!!!!!!!!.  ",
".',,,,,#!=**!***>!=*!.  ",
".,%%%%%+!!!!!!!!!!!!!.  ",
" .......>!!!!!!!!!!!>.  ",
"        .............   "};
EOXPM

$XPM{Redo} = <<'EOXPM';
/* XPM */
static char * redo_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000100",
"+	c #566E2B",
"@	c #6C7A5B",
"#	c #7B993F",
"$	c #85926E",
"%	c #859577",
"&	c #939B8E",
"*	c #8AA858",
"=	c #94A77B",
"-	c #98B274",
";	c #9EB088",
">	c #ADBFA5",
",	c #AFC396",
"'	c #B9D19D",
")	c #C6D8B1",
"!	c #D1E0C2",
"                        ",
"                        ",
"            .           ",
"            ..          ",
"            .&.         ",
"         ....'&.        ",
"        .%>)!''&.       ",
"       .>!!!)'''&.      ",
"      .%!!!)''''';.     ",
"      .>!*######+.      ",
"     .$)*######+.       ",
"     .;-#+...#+.        ",
"     .'##.  .+.         ",
"     .'#..  ..          ",
"     .=*.   .           ",
"     .@-.               ",
"      .,.               ",
"      .@;.              ",
"       .@$.             ",
"        ...             ",
"                        ",
"                        "};
EOXPM

$XPM{Replace} = <<'EOXPM';
/* XPM */
static char * Replace_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000200",
"+	c #546F2B",
"@	c #906301",
"#	c #A88124",
"$	c #9F8B4F",
"%	c #7C9A40",
"&	c #86927D",
"*	c #889971",
"=	c #CF940A",
"-	c #8FAD65",
";	c #ACB373",
">	c #DCAA34",
",	c #D1B562",
"'	c #B3CB9B",
")	c #F0D57E",
"!	c #D3DDB7",
"         ......         ",
"       ..*'''*&..       ",
"      .*'!-%%-;'&.      ",
"     .'!!%%%....**.     ",
"    .*!!-%+..   .*.     ",
"    .'!!%%.      ..     ",
"    .'!'%%.             ",
" ....!''%%....          ",
"  .&''''%%%+.   .       ",
"   .&'''%%+.   .;.      ",
"    .&''%+.   .@)!.     ",
"     .&'+.   .@=))!.    ",
"      .*.   .@==)))!.   ",
"       .   .@===))))!.  ",
"          ....==))).... ",
"             .==))).    ",
"      .     ..==)),.    ",
"     .$.   ..@=>))#.    ",
"     .$,....===)),.     ",
"      .$),>=>>),#.      ",
"       ..$,)),#..       ",
"         .......        "};
EOXPM

$XPM{ReplaceAll} = <<'EOXPM';
/* XPM */
static char * ReplaceAll_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000200",
"+	c #E20000",
"@	c #546F2B",
"#	c #717F5F",
"$	c #9F8B4F",
"%	c #7B993E",
"&	c #8B987C",
"*	c #C0A044",
"=	c #92AD66",
"-	c #D59E22",
";	c #99B674",
">	c #CBB46C",
",	c #ABBB96",
"'	c #C6DAB1",
")	c #EED37D",
"!	c #EFE4B6",
"         ......         ",
"       ..#,''&#..       ",
"      .&,';%%=;,#.      ",
"     .,''%%%....,#.     ",
"    .&@.@%@..   .&.     ",
"    .@.+.@.  @..@.@..@  ",
"    ..+++..  .++. .++.  ",
" ...@.+++.@...++. .++.  ",
"  .&.+++++.@..++. .++.  ",
"   ..+++++.. .++...++.  ",
"   @.++.++.@ .++.!.++.  ",
"   .+++.+++. .++.).++.  ",
"  @.++...++.@.++.).++.  ",
"  .+++++++++..++.).++.  ",
" @.+++...+++.@++.).++.. ",
" .+++.@ @.+++.++.).++.  ",
" .+++..  .+++.++.).++.  ",
" @...@$. @...@..@)@..@  ",
"     .$>....---))*.     ",
"      .$)*----))*.      ",
"       ..$>))>*..       ",
"         .......        "};
EOXPM

$XPM{'save'} = <<'EOXPM';
/* XPM */
static char * save_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000200",
"+	c #31373E",
"@	c #3C4A52",
"#	c #4E4E46",
"$	c #5A6067",
"%	c #4F6A7C",
"&	c #71716E",
"*	c #D0776C",
"=	c #7D9BB1",
"-	c #A19B95",
";	c #9EBDD3",
">	c #ECBDB5",
",	c #AECDE3",
"'	c #CACAC6",
")	c #E5E7E4",
"!	c #FCFFFB",
"                        ",
"  ...................   ",
" .,,&>>>>>>>>>>>>>&,;.  ",
" .,=$*************$=%.  ",
" .,=$*************$=%.  ",
" .,=&!!!!!!!!!!!!!&=%.  ",
" .,=&!!!!!!!!!!!!!&=%.  ",
" .,=&'''''''''''''&=%.  ",
" .,=&!!!!!!!!!!!!!&=%.  ",
" .,=&!!!!!!!!!!!!!&=%.  ",
" .,=&'''''''''''''&=$.  ",
" .,=&!!!!!!!!!!!!!&=$.  ",
" .,==&&&&&&&&&&&&&%=@.  ",
" .,=================@.  ",
" .,===@@$%%$$$$$@@=;@.  ",
" .,==@-'))))'''-$%%,@.  ",
" .,==@')&##'''-'@%%,@.  ",
" .,==@))&##'''''@%%,@.  ",
" .,==+))###'''))@%%,+.  ",
" .===+''###'')))@%%,+.  ",
"  .$%$-'-'''))'-@%%,+.  ",
"   ................+.   "};
EOXPM

$XPM{'saveText'} = <<'EOXPM';
/* XPM */
static char * savetext_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000200",
"+	c #31373E",
"@	c #3C4A52",
"#	c #4E4E46",
"$	c #5A6067",
"%	c #4F6A7C",
"&	c #71716E",
"*	c #D0776C",
"=	c #7D9BB1",
"-	c #A19B95",
";	c #9EBDD3",
">	c #ECBDB5",
",	c #AECDE3",
"'	c #CACAC6",
")	c #E5E7E4",
"!	c #FCFFFB",
"                        ",
"  ...................   ",
" .,,&>>>>>>>>>>>>>&,;.  ",
" .,=$*************$=%.  ",
" .,=$*************$=%.  ",
" .,=&.!!!.!.!!!!!!&=%.  ",
" .,=&...!....!.!..&=%.  ",
" .,=&'''''''''''''&=%.  ",
" .,=&!.!!!!!!..!!!&=%.  ",
" .,=&...!.!....!..&=%.  ",
" .,=&'''''''''''''&=$.  ",
" .,=&...!..!..!!..&=$.  ",
" .,==&&&&&&&&&&&&&%=@.  ",
" .,=================@.  ",
" .,===@@$%%$$$$$@@=;@.  ",
" .,==@-'))))'''-$%%,@.  ",
" .,==@')&##'''-'@%%,@.  ",
" .,==@))&##'''''@%%,@.  ",
" .,==+))###'''))@%%,+.  ",
" .===+''###'')))@%%,+.  ",
"  .$%$-'-'''))'-@%%,+.  ",
"   ................+.   "};
EOXPM

$XPM{'saveAs'} = <<'EOXPM';
/* XPM */
static char * saveAs_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000200",
"+	c #31373E",
"@	c #434B4C",
"#	c #6B5033",
"$	c #546673",
"%	c #6F706D",
"&	c #D67D71",
"*	c #7D9BB1",
"=	c #ABADAA",
"-	c #E5B061",
";	c #F5AF3D",
">	c #AECDE3",
",	c #EFC1B8",
"'	c #CACDC9",
")	c #F8E12B",
"!	c #F1F4F0",
"               ..)      ",
"  .............);....   ",
" .>>%,,,,,,,,.);#.@**.  ",
" .>*$&&&&&&&.);#.#@*$.  ",
" .>*$&&&&&&.);#.##$*$.  ",
" .>*%!!!!!.);#.='!%*$.  ",
" .>*%!!!!.);#.='!!%*$.  ",
" .>*%'''.);#.==='=%*$.  ",
" .>*%!!!.-#.='!!!!%*$.  ",
" .>*%!!.#..='!!!!!%*$.  ",
" .>*%''..===='''''%*$.  ",
" .>*%!!!''!!!!!!!!%*$.  ",
" .>**%%%%%%%%%%%%%$*@.  ",
" .>*****************@.  ",
" .>***@@$$$$$$$$@@*>@.  ",
" .>**@='!!!!'''=$$$>@.  ",
" .>**@'!%@@''=='@$$>@.  ",
" .>**@!!%@@''=''@$$>@.  ",
" .>**+!!@@@'='!!@$$>+.  ",
" .***+''@@@='!!!@$$>+.  ",
"  .$$$==='''!!'=@$$>+.  ",
"   ................+.   "};
EOXPM

$XPM{'saveclose'} = <<'EOXPM';
/* XPM */
static char * saveclose_xpm[] = {
"24 93 17 1",
" 	c None",
".	c #010400",
"+	c #2E302D",
"@	c #3F4341",
"#	c #556775",
"$	c #6F716B",
"%	c #9A8096",
"&	c #CF756C",
"*	c #7D9CB1",
"=	c #9DA082",
"-	c #A8A6A0",
";	c #C6AC78",
">	c #ADCCE3",
",	c #ECBDB5",
"'	c #CAD1AD",
")	c #CECFCC",
"!	c #F8FAF7",
"                        ",
"                        ",
"  ...................   ",
" .>>$,,,,,,,,,,,,,$>>.  ",
" .>*#&&&&&&&&&&&&&#*#.  ",
" .>*#&&&&&&&&&&&&&#*#.  ",
" .>*$!!!!!!!!!!!!!$*#.  ",
" .>*$!!!!!!!!!!!!!$*#.  ",
" .>*$)))))))))))))$*#.  ",
" .>*$!!!!!!!!!!!!!$*#.  ",
" .>*$!!!!!!!!!!!!!$*#.  ",
" .>*$)))))))))))))$*#.  ",
" .>*$!!!!!!!!!!!!!$*#.  ",
" .>**$$$$$$$$$$$$$$*@.  ",
" .>*****************@.  ",
" .>***@@########@@*>@.  ",
" .>**@-)!!!!)))-###>@.  ",
" .>**@)!$@@)))))@##>@.  ",
" .>**@!!$@@)))))@##>@.  ",
" .>**+!!@@@)))!!@##>@.  ",
" .***+))@@@))!!!@##>@.  ",
"  .###-)))))!!))@##>+.  ",
"   ................+.   ",
"                        ",
"                        ",
"                        ",
"           ..           ",
"           ..           ",
"           ..           ",
"           ..           ",
"       ..........       ",
"       ..........       ",
"           ..           ",
"           ..           ",
"           ..           ",
"           ..           ",
"                        ",
"                        ",
"                        ",
"   @@@@  @@@@@  @@@@@   ",
"   @@$@@ @@$$@@ @@$$$   ",
"   @@ @@ @@  @@ @@      ",
"   @@ @@ @@  @@ @@@@@   ",
"   @@@@  @@  @@ @@$$$   ",
"   @@$$  @@  @@ @@      ",
"   @@    @@$$@@ @@      ",
"   @@    @@@@@  @@      ",
"                        ",
" ;;;;;;;;;;;;;;;;;;;;;; ",
" ;%%%%%;%%%%%;%%%%%;%%% ",
" ;%%%%%;%%%%%;%%%%%;%%% ",
" ;;;;;;;;;;;;;;;;;;;;;; ",
" %%%;%%%%%;%%%%%;%%%%%; ",
" %%%;%%%%%;%%%%%;%%%%%; ",
" ;;;;;;;;;;;;;;;;;;;;;; ",
" ;%%%%%;%%%%%%%%%%%;%%% ",
" ;%%%%%;%%%%%%%%%%%;%%% ",
" ;;;;;;;;;;;;;;;;;;;;;; ",
"                        ",
"                        ",
"                        ",
"           ..           ",
"           ..           ",
"           ..           ",
"           ..           ",
"       ..........       ",
"       ..........       ",
"           ..           ",
"           ..           ",
"           ..           ",
"           ..           ",
"                        ",
"                        ",
"                        ",
"   .......              ",
"  .='''''=+             ",
"  .''''''=+             ",
" +-'''''''@+            ",
" +...................$  ",
" +'''''''''''''''''''.  ",
" .'''''''''''''''''''.  ",
" .'''''''''''''''''''.  ",
" .'''''''''''''''''''.  ",
" .'''''''''''''''''''.  ",
" .''''''''''''''''''=.  ",
" .'''''''''''''''''==.  ",
" .'''''''''''''======.  ",
" .===================.  ",
" .==================$.  ",
" .==============$$$$@.  ",
" $...................$  ",
"                        ",
"                        "};
EOXPM

$XPM{'SelectAll'} = <<'EOXPM';
/* XPM */
static char * SelectAll_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #020501",
"+	c #222422",
"@	c #AD0100",
"#	c #373936",
"$	c #666762",
"%	c #898A86",
"&	c #A39A8D",
"*	c #9D9F9C",
"=	c #B1B4B0",
"-	c #D1D3D0",
";	c #DBDDDA",
">	c #E3DEDD",
",	c #E0E3E0",
"'	c #FFDBDC",
")	c #F0F3EF",
"!	c #FBFEFA",
"   ..............+$     ",
"  .-)!!!!!!!!!!!,,-+    ",
"  .)!'''''''''''=,!=#   ",
"  .!!@@@@@@@@@@@*)!)=.  ",
"  .!!'''''''''''*.....  ",
"  .!!@@@@@@@@@@@*=%%$.  ",
"  .!!''''''''''''>-=$.  ",
"  .!!@@@@@@@@@@@@@,-%.  ",
"  .!!'''''''''''''>>%.  ",
"  .!!@@@@@@@@@@@@@>>&.  ",
"  .!)'''''''..'''',>&.  ",
"  .!)@@@@%....@@@@,>&.  ",
"  .!)''%.....=''',,>&.  ",
"  .!)@@@%....=@@,,,;&.  ",
"  .!)'''....=''>,;;;&.  ",
"  .!,@@..=%.=@>,;;;;&.  ",
"  .!,,..,>,%,,,;;;;-&.  ",
"  .!,..=,,,,,,,;;;--&.  ",
"  .)..,;,;,;,;;;;---&.  ",
"  .-.;;;;;;;;;;;;---&.  ",
"  .*&&&&&&&&&&&&&&&&$.  ",
"   ..................   "};
EOXPM

$XPM{'text'} = <<'EOXPM';
/* XPM */
static char * text_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #5A5C59",
"+	c #696B67",
"@	c #727D6C",
"#	c #7F8079",
"$	c #7B856E",
"%	c #888A87",
"&	c #82906F",
"*	c #8A9D71",
"=	c #989A97",
"-	c #8EA872",
";	c #A7A9A6",
">	c #9DBC79",
",	c #BABDBA",
"'	c #A8CE7E",
")	c #B0D985",
"!	c #B6DE83",
"                        ",
"          ;%;           ",
"         +@@@.          ",
"        ;*!!!-=         ",
"        +'!!!)+         ",
"        +!'&!!$;        ",
"       ;*!-.'!-%        ",
"       +'!@%*!).        ",
"      ;@!'+ +!!$;       ",
"      =-!-= +'!>%       ",
"      +'!@; ;*!)+       ",
"     ;@!'+   +!!&;      ",
"     =-!-.###.'!>#      ",
"     +)!'>>>>>!!!+      ",
"    ;$!!!!!!!!!!!&;     ",
"    %-!>......+'!>#     ",
"    .)!&;     =-!!+     ",
"   ,$!!.      ;@!!&;    ",
"   %-!>#       +'!>#    ",
"   ;..+;       ;...=    ",
"                        ",
"                        "};
EOXPM

$XPM{'textbg'} = <<'EOXPM';
/* XPM */
static char * textbg_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #5A5C59",
"+	c #676965",
"@	c #6D716A",
"#	c #787F73",
"$	c #7C886E",
"%	c #888A87",
"&	c #8BA271",
"*	c #A3A5A2",
"=	c #B0B3AF",
"-	c #A0C07B",
";	c #C1BFFE",
">	c #C5C7C4",
",	c #B4DC83",
"'	c #FEC1BD",
")	c #BDFFBF",
"!	c #FDFFFC",
"'))))))))))))))))))))));",
"''))))))))*%*)))))))));;",
"'''))))))@###.)))))));;;",
"''''))))*&,,,&%)))));;;;",
"''''')))@-,,,,+))));;;;;",
"''''''))@,,$,,$*));;;;;;",
"'''''''*&,&.-,&%);;;;;;;",
"'''''''@-,#%&,,.;;;;;;;;",
"''''''*#,,+)@,,$*;;;;;;;",
"''''''*&,&*)@-,-%;;;;;;;",
"''''''+,,#*'*&,,+;;;;;;;",
"'''''*#,,+'!;@,,$*;;;;;;",
"'''''%&,&.###.-,-#;;;;;;",
"'''''+,,,-----,,,+;;;;;;",
"''''*$,,,,,,,,,,,$*;;;;;",
"''''%&,-......@,,-@;;;;;",
"''''.,,$*!!!!!*&,,@;;;;;",
"'''>$,,.!!!!!!*#,,$*;;;;",
"'''%&,-#!!!!!!!+,,-@;;;;",
"'''=..+*!!!!!!!*...*!;;;",
"''!!!!!!!!!!!!!!!!!!!!;;",
"'!!!!!!!!!!!!!!!!!!!!!!;"};
EOXPM

$XPM{'textfg'} = <<'EOXPM';
/* XPM */
static char * C:\tmp\new_xpm[] = {
"24 22 17 1",
"       c None",
".      c #5E6F77",
"+      c #6E6E6B",
"@      c #B7736C",
"#      c #D36C70",
"$      c #818674",
"%      c #A67C70",
"&      c #6C909F",
"*      c #C78970",
"=      c #A5A277",
"-      c #A4A6A3",
";      c #67B9D9",
">      c #99B68B",
",      c #79C0C8",
"'      c #A0BB79",
")      c #7EC2C4",
"!      c #AED684",
"                        ",
"          -$-           ",
"         +%%%+          ",
"        -@###@-         ",
"        %#####%         ",
"        %#####%-        ",
"       -%*@+***$        ",
"       +'=$$===+        ",
"      -$!'$ $''$-       ",
"      ->!>- +'!'$       ",
"      +!!$- ->!!+       ",
"     -$!!+   +!!$-      ",
"     ->!>+$$$+'!'$      ",
"     +>>>>>>>>>>>+      ",
"    -&,),;;,;;,);&-     ",
"    $;;;&.....&;;;+     ",
"    .;;&-     -;;;.     ",
"   -&;;&      -&;;&-    ",
"   $;;;&       .;;&+    ",
"   -..+-       -...-    ",
"                        ",
"                        "};
EOXPM

$XPM{'textsize'} = <<'EOXPM';
/* XPM */
static char * textsize_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #585A57",
"+	c #636663",
"@	c #6D716B",
"#	c #7E8077",
"$	c #7A846D",
"%	c #888A87",
"&	c #829170",
"*	c #82996D",
"=	c #8C9F73",
"-	c #979B96",
";	c #93AE78",
">	c #A9ABA8",
",	c #9EBC79",
"'	c #B7B9B6",
")	c #AED783",
"!	c #B6DE83",
"                        ",
"                        ",
"                        ",
"     @..@               ",
"    >=!!;%              ",
"    @!!!)+              ",
"    #!$=!$              ",
"   -;)+@!;%       %%    ",
"   +!!-@!)+      >**>   ",
"   $!$->=!&'    >$!!$>  ",
"  -;)+  @!,%    %!!!!%  ",
"  +);@  .,!+    +!;;!+  ",
"  $!,====,!&'  >$!%-!$> ",
" %;!!!!!!!!,#  >;!>>!;> ",
" +),+####+)!+' %!!!!!!% ",
" &!&'    -;!&% +!;%%;!+ ",
"%,!+      $!,# $!%  %!$ ",
">..>      %..- >&    &> ",
"                        ",
"                        ",
"                        ",
"                        "};
EOXPM

$XPM{'bracket'} = <<'EOXPM';
/* XPM */
static char * bracket_xpm[] = {
"34 16 16 1",
" 	c None",
"x      c #606060",
".	c #FF004D",
"+	c #FF0099",
"#	c #CC00FF",
"%	c #3300FF",
"&	c #001AFF",
"*	c #0066FF",
"=	c #00B2FF",
">	c #00FF66",
"'	c #33FF00",
")	c #80FF00",
"!	c #CCFF00",
"{	c #FF9900",
"]	c #FF4D00",
"^	c #FF0000",
"  xxxxxx                 xxxxxx  ",
" x......x               x......x ",
" x++++++x               x++++++x ",
" x##x                    xxxx##x ",
" x%%x                       x%%x ",
" x&&x                       x&&x ",
" x**x                       x**x ",
" x==x                       x==x ",
" x>>x                       x>>x ",
" x''x                       x''x ",
" x))x                       x))x ",
" x!!x                       x!!x ",
" x{{xxxx                 xxxx{{x ",
" x]]]]]]x               x]]]]]]x ",
" x^^^^^^x               x^^^^^^x ",
"  xxxxxx                 xxxxxx  "};
EOXPM

$XPM{'bracketsz'} = <<'EOXPM';
/* XPM */
static char * bracketsz_xpm[] = {
"34 16 3 1",
" 	c None",
"x      c #404040",
"o      c #808080",
"  ooooo    ooooo                 ",
" oxxxxx    xxxxxo                ",
" oxxo        oxxo                ",
" oxx          xxo                ",
" oxx          xxo      oxx  xxo  ",
" oxx          xxo     oxoo  ooxo ",
" oxx          xxo     ox      xo ",
" oxx          xxo     ox      xo ",
" oxx          xxo     ox      xo ",
" oxx          xxo     ox      xo ",
" oxx          xxo     ox      xo ",
" oxx          xxo     ox      xo ",
" oxx          xxo     ox      xo ",
" oxxo        oxxo     ox      xo ",
" oxxxxx    xxxxxo     oxoo  ooxo ",
"  ooooo    ooooo       oxx  xxo  "};
EOXPM

$XPM{'bracketoff'} = <<'EOXPM';
/* XPM */
static char * braceoff_xpm[] = {
"34 16 3 1",
" 	c None",
"x      c #404040",
"o      c #808080",
"  ooooo    ooooo                 ",
" oxxxxx    xxxxxo                ",
" oxxo        oxxo                ",
" oxx          xxo                ",
" oxx          xxo        x       ",
" oxx          xxo       xxx      ",
" oxx          xxo      oxxxo     ",
" oxx          xxo     xxxxxxx    ",
" oxx          xxo       oxo      ",
" oxx          xxo       oxo      ",
" oxx          xxo       oxo      ",
" oxx          xxo       oxo      ",
" oxx          xxo       oxo      ",
" oxxo        oxxo       oxo      ",
" oxxxxx    xxxxxo       oxo      ",
"  ooooo    ooooo                 "};
EOXPM

$XPM{'braceclr'} = <<'EOXPM';
/* XPM */
static char * brace_xpm[] = {
"34 16 18 1",
" 	c None",
"x      c #606060",
".	c #0A5200",
"+	c #0C5300",
"@	c #1D7007",
"#	c #86514A",
"$	c #7F4CCC",
"%	c #7A4FCC",
"&	c #C6452D",
"*	c #E64121",
"=	c #5D8000",
"-	c #2D8E15",
";	c #F26F25",
">	c #887EFC",
",	c #60B726",
"'	c #E5BE2C",
")	c #98D3F8",
"!	c #7DE982",
"                                 ",
"    x+..x               x..+x    ",
"    x@@x                 x@@x    ",
"   x--x                   x--x   ",
"   x''x                   x''x   ",
"   x;;x                   x;;x   ",
"  x**x                     x**x  ",
" x&&x                       x&&x ",
"  x##x                     x##x  ",
"   x$%x                   x%$x   ",
"   x>>x                   x>>x   ",
"   x))x                   x))x   ",
"   x!!x                   x!!x   ",
"    x,,x                 x,,x    ",
"    x===x               x===x    ",
"                                 "};
EOXPM

$XPM{'bracesz'} = <<'EOXPM';
/* XPM */
static char * bracesz_xpm[] = {
"34 16 3 1",
" 	c None",
"x      c #404040",
"o      c #808080",
"                                 ",
"    ooxx   xxoo                  ",
"    oxx     xxo                  ",
"   oxx       xxo                 ",
"   oxx       xxo       ox  xo    ",
"   oxx       xxo      ox    xo   ",
"  oxx         xxo     ox    xo   ",
" xxo           oxx    ox    xo   ",
"  oxx         xxo    ox      xo  ",
"   oxx       xxo    xx        xx ",
"   oxx       xxo     ox      xo  ",
"   oxx       xxo      ox    xo   ",
"   oxx       xxo      ox    xo   ",
"    oxx     xxo       ox    xo   ",
"    ooxx   xxoo        ox  xo    ",
"                                 "};
EOXPM

$XPM{'settags'} = <<'EOXPM';
/* XPM */
static char * settags_xpm[] = {
"24 22 4 1",
"  c None",
"x c #404040",
"e c #606060",
"o c #808080",
"                        ",
"    ox  xo              ",
"   ox    xo             ",
"   ox    xo             ",
"   ox    xo             ",
"  ox      xo            ",
" xx        xx           ",
"  ox      xo            ",
"   ox    xo             ",
"   ox    xo   oee  eeo  ",
"   ox    xo  oeo    oeo ",
"    ox  xo   oe      eo ",
"             oe      eo ",
"             oe      eo ",
"             oe      eo ",
"             oe      eo ",
"             oe      eo ",
"             oe      eo ",
"             oe      eo ",
"             oeo    oeo ",
"              oee  eeo  ",
"                        "};
EOXPM

$XPM{'tick'} = <<'EOXPM';
/* XPM */
static char *tick[] = {
"12 14 5 1",
"  c None",
". c #8bc565",
"# c #dfe0de",
"a c #5bb520",
"b c #b7d3a4",
"          bb",
"         .ab",
"        ba. ",
"       #aa  ",
"       .ab  ",
"       a.   ",
"      .ab   ",
" #.b ba.    ",
"baa.#aa     ",
".aaa.a.     ",
"baaaaa      ",
" .aaa.      ",
" baa.       ",
"  ..        "};
EOXPM

$XPM{'Undo'} = <<'EOXPM';
/* XPM */
static char * undo_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000100",
"+	c #906301",
"@	c #996B00",
"#	c #94814B",
"$	c #BA820A",
"%	c #AA9659",
"&	c #B69842",
"*	c #D1950B",
"=	c #D8A72B",
"-	c #BEAF72",
";	c #D4B254",
">	c #CBB46C",
",	c #E0B649",
"'	c #DFC676",
")	c #F0D57E",
"!	c #F0E5B9",
"                        ",
"                        ",
"          .             ",
"         ..             ",
"        .!.             ",
"       .!)....          ",
"      .!))));&.         ",
"     .!)))))));.        ",
"    .-)))))))))&.       ",
"     .@******,)'..      ",
"      .+*******)&.      ",
"       .+*...@*,>.      ",
"        .@. ..$=).      ",
"         ..  ..*).      ",
"          .   .=>.      ",
"              .;%.      ",
"              .'.       ",
"             .>#.       ",
"            .%#.        ",
"             ..         ",
"                        ",
"                        "};
EOXPM

$XPM{'Unselect'} = <<'EOXPM';
/* XPM */
static char * Unselect_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000200",
"+	c #222422",
"@	c #AD0100",
"#	c #373936",
"$	c #666762",
"%	c #797B78",
"&	c #A39A8E",
"*	c #A4A6A3",
"=	c #B2B5B2",
"-	c #D1D3D0",
";	c #DCDFDC",
">	c #E4DEDD",
",	c #FFDBDC",
"'	c #E4E6E3",
")	c #F0F3EF",
"!	c #FBFEFA",
"   ..............+$     ",
"  .-)!!!!!!!!!!!*'-+    ",
"  .)!,,,,,,,,,,,*'!=#   ",
"  .!%.@@@@@@@@@@*)!)*.  ",
"  .!%..,,,,,,,,,......  ",
"  .!!%..@@@@@@@..%%%$.  ",
"  .!!,%..,,,,,..%>-=%.  ",
"  .!!@@%..@@@..%@@'-%.  ",
"  .!!,,,%..,..%,,,>>%.  ",
"  .!!@@@@%...%@@@@>>&.  ",
"  .!),,,,,...,,,,,;>&.  ",
"  .!)@@@@..%..@@@@;>&.  ",
"  .!),,,..%,%..,,;;>&.  ",
"  .!)@@..%@@@%..;;;;&.  ",
"  .!),..%,,,,,%..;;;&.  ",
"  .!'..%@@@@@@>%..;;&.  ",
"  .!%.%'''''';;;%.%-&.  ",
"  .!%%'''';;;;;;;%%-&.  ",
"  .)'''';;;;;;;;;---&.  ",
"  .-';;;;;;;;;;;;---&.  ",
"  .&&&&&&&&&&&&&&&&&$.  ",
"   ..................   "};
EOXPM

$XPM{'makePDF'} = <<'EOXPM';
/* XPM */
static char * makePDF_xpm[] = {
"24 22 6 1",
" 	c None",
".	c #404040",
"+	c #CCCCCC",
"@	c #888888",
"#	c #C8AB7A",
"$	c #988098",
"                        ",
"   ....+ .....  .....   ",
"   ..@.. ..@@.. ..@@@   ",
"   .. .. ..  .. ..      ",
"   .. .. ..  .. .....   ",
"   ....  ..  .. ..@@@   ",
"   ..@@  ..  .. ..      ",
"   ..    ..@@.. ..      ",
"   ..    .....  ..      ",
"                        ",
"                        ",
"                        ",
" ###################### ",
" #$$$$$#$$$$$#$$$$$#$$$ ",
" #$$$$$#$$$$$#$$$$$#$$$ ",
" ###################### ",
" $$$#$$$$$#$$$$$#$$$$$# ",
" $$$#$$$$$#$$$$$#$$$$$# ",
" ###################### ",
" #$$$$$#$$$$$$$$$$$#$$$ ",
" #$$$$$#$$$$$$$$$$$#$$$ ",
" ###################### "};
EOXPM

$XPM{'printPDF'} = <<'EOXPM';
/* XPM */
static char * printPDF_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000200",
"+	c #1F201E",
"@	c #4B4A48",
"#	c #5D5D59",
"$	c #6D6E67",
"%	c #7A7B74",
"&	c #888A86",
"*	c #93948D",
"=	c #A1A3A0",
"-	c #B2B3AD",
";	c #BDBEB6",
">	c #CFD1CE",
",	c #DCDEDB",
"'	c #EAECE9",
")	c #F4F7F3",
"!	c #FCFFFB",
"      &&&&&&&&&&&&      ",
"   ++++>!+++++!!+++++   ",
"   ++#++'++##++,++###   ",
"   ++&++$++#=++,++&     ",
"   ++&++'++''++'+++++   ",
"   ++++&$++&=++&++###   ",
"   ++##!!++!!++!++&     ",
"   ++&!--++##++'++&     ",
"   ++&),,+++++,'++&     ",
"    &&!&$&>$%>&=>-..    ",
"   .!&>===========.%.   ",
"  .!'*@..........%%=-.  ",
" .!!'!!!!!!!!!!!!!!!!'. ",
" .;&')!))))!!)'''''=,-. ",
" .=$);>->->->=>->-,$**. ",
" .*$''))!))))))''''#&*. ",
" .=$##@@@@@@@@@@@@@@%%. ",
" .**&$$#$#####@#####$$. ",
" .%***%%$$$$$$##$$$$$$. ",
"  ....................  ",
"  .*--;;;;;;----***%%.  ",
"   ..................   "};
EOXPM

$XPM{'viewPDF'} = <<'EOXPM';
/* XPM */
static char * viewPDF_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #000300",
"+	c #222422",
"@	c #3F413F",
"#	c #63645E",
"$	c #737572",
"%	c #868885",
"&	c #A29A8E",
"*	c #A0A39F",
"=	c #B4B6B3",
"-	c #D2D4D1",
";	c #DADCD9",
">	c #E5E0DE",
",	c #E0E2DF",
"'	c #E9EBE8",
")	c #F1F3F0",
"!	c #FBFEFA",
"   ..............+#     ",
"  .-)!!!!!!!!!!!,,-+    ",
"  .)!!!!!!!!!!!)='!=@   ",
"  .!!$$**$$$**$$*)!)=.  ",
"  .!!!!!!!!!!!!)*.....  ",
"  $!!$*$$$*$$$$$*=%%#$  ",
"  $@@@@$!@@@@@$)@@@@@$  ",
"  $@@$@@$@@$$@@$@@%%%$  ",
"  $@@!@@)@@))@@)@@>>%$  ",
"  $@@$@@$@@$$@@$@@@@@$  ",
"  $@@@@))@@))@@'@@%%%$  ",
"  $@@%%==@@$$@@$@@,>&.  ",
"  $@@))))@@%%@@,@@,>&.  ",
"  $@@$$*$@@@@@$$@@,,&.  ",
"  $!'''''''''',>,,;;&.  ",
"  .!'$$**$$**$>,,;;;&.  ",
"  .!,,,,,>,>,,,,;;;-&.  ",
"  .!,,,>,,,,,,,;;;--&.  ",
"  .',>,,,,,,,,,;;---&.  ",
"  .-,,,;,;,;,;;;;---&.  ",
"  .&&&&&&&&&&&&&&&&&#.  ",
"   ..................   "};
EOXPM

$XPM{'wrap'} = <<'EOXPM';
/* XPM */
static char * wrap_xpm[] = {
"24 22 7 1",
" 	c None",
".	c #000000",
"+	c #62C95E",
"@	c #51A74F",
"#	c #448C42",
"$	c #2A6D28",
"%	c #010401",
"                        ",
"                        ",
"                        ",
"  ................      ",
"  ++++++++++++++++.     ",
"  @@@@@@@@@@@@@@@@@.    ",
"  ################@+.   ",
"  $$$$$$$$$$$$$$$#@@+.  ",
"  ..............$$#@+.  ",
"                .$$#@.  ",
"            .  .++$#@.  ",
"           .. .++@$$#.  ",
"          .+..+@@#$$.   ",
"         .++++@##$$.    ",
"        .@@@@@#$$$.     ",
"       .######$$$.      ",
"        .$$$$$$%.       ",
"         .$$$$.         ",
"          .$..          ",
"           ..           ",
"            .           ",
"                        "};
EOXPM

$XPM{viewlog} = <<'EOXPM';
/* XPM */
static char * viewlog_xpm[] = {
"24 22 17 1",
" 	c None",
".	c #020501",
"+	c #34342D",
"@	c #623D00",
"#	c #484841",
"$	c #784A00",
"%	c #955E04",
"&	c #6F716E",
"*	c #AF6D01",
"=	c #CA7E02",
"-	c #B19054",
";	c #9C968B",
">	c #AEB0A9",
",	c #BAB9A4",
"'	c #C8CAC7",
")	c #D7D8CA",
"!	c #F3F6F2",
"                        ",
"            @$@         ",
"           %$$$         ",
"           %$$$@        ",
"            @$$$@@      ",
"   %%%%%%%%%%@$$$$%%%   ",
"  %-%==>#..#>=@$$@===%  ",
"  %-%=>+;),;+>=%%====%  ",
"  %-%*#;)!,,;#*******%  ",
" %---%.)!,,;;.********% ",
" %---%.,),,;>.%%%%%%%%% ",
" %---%#;,,;>'#>%%%%%%%% ",
" %---%%+;;>'..>%%%%%%%% ",
" %---%%%#..#&..;%%%%%%% ",
"  %-%$$$$$$$$...>$$$$%  ",
"  %-%$$$$$$$$&...;$$$%  ",
"  @-%@@@@@@@@@&...@@@@  ",
"   @@@@@@@@@@@@&..@@@   ",
"                        ",
"                        ",
"                        ",
"                        "};
EOXPM
    
###############################
## SMILIES
##
$XPM{'quest'} = <<'EOXPM';
/* XPM */
static char *quest[] = {
"36 35 14 1",
"  s None c None",
". c #948f58",
"# c #c7c076",
"a c #fbf66f",
"b c #090d1a",
"c c #5f628a",
"d c #f9faba",
"e c #f9f047",
"f c #d3cfd2",
"g c #aca7bc",
"h c #fffddc",
"i c #2f3e67",
"j c #fffef2",
"k c #ebe8e4",
"                                    ",
"                                    ",
"                                    ",
"            ddddddddddd             ",
"          ddddddddddddddd           ",
"         dddddfggggfddddddd         ",
"        ddddfibbbbbbigddddddd       ",
"       ddddfibbbbbbbbbifdddddd      ",
"      ddddhgbbbbicibbbbifhdddd      ",
"      ddhhhkcbcfjjjfibbbchhhddd     ",
"     ddhhhhjjkjjjjjjfibbbghhhddd    ",
"     dhhhhjjjjjjjjjjjcbbbcjhhhdd    ",
"    hhhhhhjjjjjjjjjjjcbbbcjhhhhdd   ",
"    hhhhhhhjjjjjjjjjjcbbbcjhhhhda   ",
"   ddhhhhhhjjjjjjjjjgibbbgjhhhdaa   ",
"   aadhhhhhhjjjjjjjfibibikhhhdaaad  ",
"  daaadhhhhhhhjjjjgiiiiighhhdaaaed  ",
"  daeaaahhhhhhjkgciiiiigjhhdaaaaed  ",
"  daeaaaadhhhkciiiiiicfjhdaaaaaeed  ",
"  daeaaaaaaddciiiiicghddaaaaaaeeed  ",
"  daeeaaaaaa#iiiic#daaaaaaaaaeeeed  ",
"   aeeeeaaaa#iiicaaaaaaaaaaaeeeee   ",
"   deeeeeaaaaciicaaaaaaaaaaeeeeea   ",
"    eeeeeeeaa#ci.aaaaaaaaeeeeeeed   ",
"    aeeeeeeeeeaaaaaaaaeeeeeeeeea    ",
"    deeeeeeee.c.eeeeeeeeeeeeeee     ",
"     aeeeeee.iii.eeeeeeeeeeeeed     ",
"      aeeeeeciciceeeeeeeeeeeea      ",
"       aeeee.iiiceeeeeeeeeeea       ",
"        deeee....eeeeeeeeeea        ",
"         daeeeeeeeeeeeeeead         ",
"           daeeeeeeeeeaad           ",
"              daaaaadd              ",
"                                    ",
"                                    "};
EOXPM

$XPM{'quiz'} = <<'EOXPM';
/* XPM */
static char *quiz[] = {
"30 29 16 1",
"  s None c None",
". c #f0e21b",
"# c #c5a12b",
"a c #f4ea67",
"b c #f2e5b5",
"c c #e69b21",
"d c #601909",
"e c #f0e58e",
"f c #f9f4d2",
"g c #8e5b2e",
"h c #f4e528",
"i c #f0bf1f",
"j c #ab8760",
"k c #e0b26a",
"l c #f4e43c",
"m c #e6cd2e",
"          bbbbbebbeb          ",
"       fbebbfffffffbeb        ",
"     fbeeggbffffffjjeee       ",
"     eekgjjbffffffjjgjbkb     ",
"    k#ejefffbfffffffbjee#b    ",
"   b#aebeebbbbffffbbbbbeakb   ",
"  f##eeeeebbbbbfbfbbeeeee#k   ",
"  kcaeaeeejdbbbbfkdkeeeeelce  ",
" bccaaaeeegdjbeebgdgeeeealckf ",
" eciaaeeeeddjbeeegdgeeaeaaicb ",
"f#cilaaeekddgeeeegdgeeaaaiice ",
"fccilaaaakgdjeeeegdgeallaiick ",
"bcii.llaaegdkeaaejdjelllliic# ",
"bcii..lllakkaaaaaakallll.iii# ",
"bcii..llllaaaaaaaallllll.iii#f",
"bcci...llllllalllllllll..iii#f",
"fcii.llllmmmlllllllh..lmmiic# ",
" #ciilmm######mhhlllhm##miick ",
" kciim###mmmmm###mmm###miiice ",
" eciicmmll....mm#####ml.iii#b ",
" f#ciillllll.....mmmllliiick  ",
"  eccillllllll.lllllllliiccb  ",
"   kciiiilllllllllllliiiice   ",
"   b#ciiii.llllllll.iiiickf   ",
"    b#ciiiiii.....iiiiic#f    ",
"     b#cciiiiiiiiiiiicckf     ",
"      bk#cciiiiiiiccc#b       ",
"        bk#cccccccc#ef        ",
"           fekkkeeb           "};
EOXPM

$XPM{'sad'} = <<'EOXPM';
/* XPM */
static char *sad[] = {
"30 29 17 1",
"  s None c None",
". c #f9f3d6",
"# c #f4ef84",
"a c #dfa95a",
"b c #e5961f",
"c c #f1b422",
"d c #f0cd1c",
"e c #f7f4b3",
"f c #f4e853",
"g c #936437",
"h c #b08e60",
"i c #ffffff",
"j c #e4c282",
"k c #f2e725",
"l c #b28527",
"m c #66200d",
"n c #eedbb5",
"          njnnnnnnnn          ",
"        nnn...i...nejn.       ",
"       j#jgh......eggjjn.     ",
"     nanhghh......nhggajn     ",
"    na#nhn..e....ee.e#h#aj    ",
"   naj#eeeeeeeeeeeee#ee##bn   ",
"   ab###e#eneeeeeeeee####cb.  ",
"  nbd####ejmjeeeenmhe####fbj  ",
" .abf#####gmgee#ehmgj####fcbn ",
" nbcf#####gmm###ehmmj###ffcbj ",
" jbcd#####gmm####gmmj###ffcba.",
" abcdkk#k#gmg####hmmj##ffkcbb.",
" accdkkkk#hmh####jmg#fffkddcbn",
" bccddkkkk#a####f#aafffkkddcbn",
".bccdkkkkkkkkk#ffffffkkkkddcbn",
".bccdkkkkkkkkkkkkfffkkkkkddcbn",
" accdkkkkkkkkkkkkkkkkkkkkdccb.",
" abcdkkkkkkkkbbbbkkkkfkkkdcbb ",
" jbcdkkkkkkbllllllbkkkkkkccba ",
" .acckkkkbllbkkkkbllbkkkkccbn ",
"  jbcdfkblbkkkkkkkkblbkfdcbb. ",
"  nbcdfblbkkkkkkkkkkblbfccbj  ",
"   jbcclbkfkkkkkkkkfkblccba   ",
"   .abccddkkkkkkkfkkdddcbbn   ",
"    .abccdddkkkkkkdddccbbn    ",
"     .jbbcccddddddccccban     ",
"       nabcccccccccbbbje      ",
"        .jbbbbbbbbbbjn        ",
"           enjaajj.           "};
EOXPM

$XPM{'smile'} = <<'EOXPM';
/* XPM */
static char *smile[] = {
"30 29 17 1",
"  s None c None",
". c #f9f3d6",
"# c #f4ef84",
"a c #dfa95a",
"b c #e5961f",
"c c #f1b422",
"d c #f0cd1c",
"e c #f7f4b3",
"f c #f4e853",
"g c #936437",
"h c #b08e60",
"i c #ffffff",
"j c #e4c282",
"k c #f2e725",
"l c #b28527",
"m c #66200d",
"n c #eedbb5",
"          njnnnnnnnn          ",
"        nnn...i...nejn.       ",
"       j#jgh......eggjjn.     ",
"     nanhghh......nhggajn     ",
"    na#nhn..e....ee.e#h#aj    ",
"   naj#eeeeeeeeeeeee#ee##bn   ",
"   ab###e#eneeeeeeeee####cb.  ",
"  nbd####ejmjeeeenmhe####fbj  ",
" .abf#####gmgee#ehmgj####fcbn ",
" nbcf#####gmm###ehmmj###ffcbj ",
" jbcd#####gmm####gmmj###ffcba.",
" abcdff#f#gmg####hmmj##ffkcbb.",
" accdffff#hmh####jmg#fffkddcbn",
" bccddkfff#a####f#aafffkkddcbn",
".bccdkkkffffff#ffffffkkkkddcbn",
".bccdkkkkkffffffffffkkkkkddcbn",
" accdklkkkkkkkkfkkkkkkklkdccb.",
" abcdklbkkkkkkkkkkkkkfblkdcbb ",
" jbcdkblbkkkkkkkkkkkkblbkccba ",
" .acckkblbkkkkkkkkkkblbkkccbn ",
"  jbcdkkblbkkkkkkkkblbkkdcbb. ",
"  nbcddkkbllbkkkkbllbkkdccbj  ",
"   jbcddkkfbllllllbfkkddcba   ",
"   .abccddkkfbbbbfkkdddcbbn   ",
"    .abccdddkkkkkkdddccbbn    ",
"     .jbbcccddddddccccban     ",
"       nabcccccccccbbbje      ",
"        .jbbbbbbbbbbjn        ",
"           enjaajj.           "};
EOXPM

1;
