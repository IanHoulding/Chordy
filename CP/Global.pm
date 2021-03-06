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
      &read_file &write_file &RevertTo
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
    FUNC  => [qw/&read_file &write_file &RevertTo
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
use CP::Cconst qw/:OS :PATH :BROWSE :SHFL :SMILIE :COLOUR/;
use CP::Cmsg;
use CP::Collection;
use CP::Path;
use CP::Cmnd;
use CP::Opt;
use CP::Media;

our $Version = "4.0";

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
  makeImage("tick", \%XPM);
  makeImage("xtick", \%XPM);
  $Collection = CP::Collection->new();
  $Path = CP::Path->new();
  $Cmnd = CP::Cmnd->new();
  $Opt = CP::Opt->new();
  $Media = CP::Media->new();
  $Swatches = CP::Swatch->new();
  CP::Win::newLook();

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

sub RevertTo {
  my($protab,$fn) = @_;

  my $temp = $Path->{Temp};
  my $rev = [];
  opendir my $dh, "$temp" or return(message(SAD, "Couldn't open directory $temp\n"));
  foreach my $f (grep /^$fn/, readdir $dh) {
    if (-f "$temp/$f" && $f =~ /$fn\.(\d+)$/i) {
      $rev->[$1] = "$f";
    }
  }
  closedir($dh);
  if (@{$rev} == 0) {
    message(SAD, "Sorry - there don't appear to be any older revisions of:\n   $fn.");
    return;
  }    

  my $pop = CP::Pop->new(0, '.rt', $fn);
  return if ($pop eq '');
  my($top,$frm) = ($pop->{top}, $pop->{frame});
  $frm->m_configure( -padding => 0);

  Tkx::ttk__style_configure('Rev.TFrame', -background => $Opt->{ListBG});
  my $tlf = $frm->new_ttk__frame(-style => 'Rev.TFrame', -relief => 'raised', -borderwidth => 2);
  $tlf->g_grid(qw/-row 0 -column 0 -padx 4 -pady 4/);
  my $trf = $frm->new_ttk__frame();
  $trf->g_grid(qw/-row 0 -column 1 -sticky ns -pady 4/, -padx => [4,8]);
  my $sepf = $frm->new_ttk__separator(qw/-orient horizontal/);
  $sepf->g_grid(qw/-row 1 -column 0 -columnspan 2 -sticky we/);
  my $bf = $frm->new_ttk__frame(-padding => [0,4,0,4]);
  $bf->g_grid(qw/-row 2 -column 0 -columnspan 2 -sticky nswe/);

  my $revl = $tlf->new_ttk__label(-text => 'Rev', -background => $Opt->{ListBG});
  $revl->g_grid(qw/-row 0 -column 0/);
  my $modl = $tlf->new_ttk__label(-text => 'Last Modified', -background => $Opt->{ListBG});
  $modl->g_grid(qw/-row 0 -column 2/);

  my $seph = $tlf->new_ttk__separator(qw/-orient horizontal/);
  $seph->g_grid(qw/-row 1 -column 0 -columnspan 3 -sticky we/);

  my $revLB = CP::List->new($tlf,  '', qw/-height 12 -width 4 -selectmode browse -takefocus 1 -relief flat -borderwidth 3/ );
  my $modLB = CP::List->new($tlf, 'e', qw/-height 12 -width 30 -relief flat -borderwidth 3/);
  $modLB->{lb}->configure(-yscrollcommand => [sub{scroll_filelb($revLB, $modLB, @_)}]);
  $modLB->{yscrbar}->m_configure(-command => sub {$revLB->{lb}->yview(@_);$modLB->{lb}->yview(@_);});
  $revLB->{frame}->g_grid(qw/-row 2 -column 0/);
  $modLB->{frame}->g_grid(qw/-row 2 -column 2/);

  my $sepv = $tlf->new_ttk__separator(qw/-orient vertical/);
  $sepv->g_grid(qw/-row 0 -column 1 -rowspan 3 -sticky ns/);

  foreach my $r (0..$#{$rev}) {
    if (defined $rev->[$r]) {
      $revLB->add2a($r);
      $modLB->add2a(my $x = localtime((stat("$temp/$fn.$r"))[9]));
    }
  }

  my $bp = $trf->new_ttk__button(-text => "View PDF", -command => sub{
    my $idx = $modLB->curselection(0);
    if ($idx ne '') {
      my $r = $revLB->get($idx);
      main::viewOnePDF($protab, "$temp", "$fn.$r");
      Tkx::update();
      $top->g_raise();
      $modLB->{lb}->g_focus();
    } } );
  $bp->g_pack(qw/-side top/, -pady => [30,4]);
  my $bv = $trf->new_ttk__button(-text => "View File", -command => sub{
    my $idx = $modLB->curselection(0);
    if ($idx ne '') {
      my $r = $revLB->get($idx);
      viewFile("$temp/$fn.$r");
      Tkx::update();
      $top->g_raise();
      $modLB->{lb}->g_focus();
    } } );
  $bv->g_pack(qw/-side top -pady 4/);
  my $bd = $trf->new_ttk__button(-text => "Delete",
				 -style => 'Red.TButton',
				 -command => sub{buDel($revLB, $modLB, $fn)} );
  $bd->g_pack(qw/-side top -pady 16/);

  my $bc = $bf->new_ttk__button(-text => "Cancel",
				-style => 'Red.TButton',
				-command => sub{$pop->popDestroy();return;} );
  $bc->g_pack(qw/-side left -padx 20/);
  my $br = $bf->new_ttk__button(-text => "Revert", -command => sub{
    my $idx = $modLB->curselection(0);
    if ($idx ne '') {
      my $rev = $revLB->get($idx);
      rename("$temp/$fn.$rev", "$temp/$fn");
      buReorder($fn);
      my $path = ($fn =~ /.pro$/i) ? "Pro" : "Tab";
      backupFile($Path->{$path}, $fn, "$temp/$fn", 1);
      $pop->popDestroy();
    }
				});
  $br->g_pack(qw/-side right -padx 20/);
}

# This method is called when one Listbox is scrolled with the keyboard
# It makes the Scrollbar reflect the change, and scrolls the other lists
sub scroll_filelb {
  my($rlb,$mlb,@args) = @_;

  $mlb->{yscrbar}->set(@args); # tell the Scrollbar what to display
  my($top,$bot) = split(' ', $mlb->{lb}->yview());
  $rlb->{lb}->yview_moveto($top);
}

sub buDel {
  my($rlb,$mlb,$fn) = @_;

  my $idx = $mlb->curselection(0);
  if ($idx ne '') {
    my $tmp = $Path->{Temp};
    my $r = $rlb->get($idx);
    if (msgYesNo("Do you really want to delete backup $fn.$r?") eq "Yes") {
      unlink("$tmp/$fn.$r");
      buReorder($fn);
      my $rev = [];
      opendir my $dh, "$tmp" or return;
      foreach my $f (grep /^$fn/, readdir $dh) {
	if ($f =~ /$fn\.(\d+)$/i) {
	  $rev->[$1] = "$f";
	}
      }
      closedir($dh);
      $rlb->clear();
      $mlb->clear();
      foreach my $r (0..$#{$rev}) {
	if (defined $rev->[$r]) {
	  $rlb->add2a($r);
	  $mlb->add2a(my $x = localtime((stat("$tmp/$fn.$r"))[9]));
	}
      }
    }
  }
}

sub buReorder {
  my($fn) = shift;

  my $tmp = $Path->{Temp};
  opendir my $dh, "$tmp" or return;
  my @rev = ();
  foreach my $f (grep /^$fn/, readdir $dh) {
    if ($f =~ /$fn\.(\d+)$/i) {
      push(@rev, $1);
    }
  }
  closedir($dh);
  my $idx = 1;
  foreach my $r (sort{$a <=> $b} @rev) {
    if ($r != $idx) {
      rename("$tmp/$fn.$r", "$tmp/$fn.$idx");
    }
    $idx++;
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
    -width => 90,
    -height => 30,
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

$XPM{'xtick'} = <<'EOXPM';
/* XPM */
static char *xtick[] = {
"10 10 2 1",
"  c None",
"x c #000000",
"xxxxxxxxxx",
"x        x",
"x        x",
"x        x",
"x        x",
"x        x",
"x        x",
"x        x",
"x        x",
"xxxxxxxxxx"};
EOXPM

$XPM{'tick'} = <<'EOXPM';
/* XPM */
static char *tick[] = {
"10 10 5 1",
" 	c None",
".	c #000000",
"+	c #70C890",
"@	c #31AD31",
"#	c #118611",
"..........",
".      ++.",
".     +#+.",
".+   +## .",
".++ +##  .",
".+#+##   .",
". ###+   .",
". +#+    .",
".  @     .",
".........."};
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
