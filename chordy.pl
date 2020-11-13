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
use warnings;

use Tkx;
use File::Path qw(make_path);

use CP::Cconst qw(:OS :PATH :LENGTH :PDF :MUSIC :TEXT :SHFL :INDEX :BROWSE :SMILIE :COLOUR);
use CP::Global qw/:FUNC :PATH :OPT :CHORD :WIN :PRO :SETL :MEDIA :SCALE :XPM/;

use CP::Win;
use CP::Pop qw/:POP :MENU/;
use CP::Chordy;
use CP::CPmenu;
use CP::List;
use CP::Pro qw/$LenError/;
use CP::Collection;
use CP::Path;
use CP::Cmnd;
use CP::Opt;
use CP::Media;
use CP::Swatch;
use CP::Cmsg;
use CP::Fonts qw/&fontSetup/;
use CP::Browser;
use CP::CHedit qw(&CHedit);
use CP::Editor;
use CP::CPmail qw(&cpmail);

# We have 3 basic paths:
# 1) Prog   where the executables live
# 2) User   where configs common to all Collections live
#              Colour, Fontlist, Chord & Media definitions, etc
# 3) Home   where the current Collection's specific configs live
#
# Each "Collection" is basically a Folder that contains
# Pro, Tab, PDF and Temp subfolders and (on Windows) is initially set to
#    C:/Users/<UserName>/Chordy
# and on Mac/Unix
#    ~/Chordy
# So this is where all the defaults are obtained from.
# Any other Collection Folders are also home to their own variants of Options,
# Swatches, Setlists, etc.
#
my $PDFtrans;

use Getopt::Std;
our($opt_d);
getopts('d');

make_path(USER, {chmod => 0777}) if (! -d USER);

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

##########################################
#### Define a whole bunch of defaults ####

setDefaults();
fontSetup();
CP::Win::init();

makeImage("Cicon", \%XPM);
$MW->g_wm_iconphoto("Cicon");
$MW->g_wm_protocol('WM_DELETE_WINDOW' => sub{$MW->g_destroy()}); 
CP::Win::title();

CP::Chordy->new();
CP::CPmenu->new();

$MW->g_wm_deiconify();
$MW->g_raise();
Tkx::MainLoop();

sub impProFile {
  my $types = [
    ['ChordPro Files', '.pro'],
    ['All Files',      '*'],
      ];
  my $f = Tkx::tk___getOpenFile(
    -initialdir => "$Home",
    -filetypes => $types,
    -defaultextension => '.pro',
    -multiple => 1);
  if ($f ne '') {
    my @F = Tkx::SplitList($f);
    (my $p = $F[0]) =~ s/(.*)\/.*$/$1/;
    message(SMILE, "Imported", 1) if (copyFiles(\@F, $p, $Path->{Pro}));
  }
}

sub expFile {
  my($path,$ext,$just1) = @_;

  if (@{$FileLB->{array}}) {
    my $idx = (defined $just1) ? $FileLB->curselection(0) : -1;
    if (defined $just1 && $idx eq '') {
      message(SAD, "Please select a file to export.");
      return;
    }
    if ($ext eq '.pro') {
      my $exp = '';
      my @lst = ('All', @{$Collection->list()}, 'SeP', 'FOLDER');
      popMenu(\$exp, sub{}, \@lst);
      return if ($exp eq '');
      if ($exp ne 'FOLDER') {
	if ($exp eq 'All') {
	  shift(@lst); # Remove 'All'.
	} else {
	  @lst = ($exp);
	}
	my @toExp = ($idx >= 0) ? ($FileLB->{array}[$idx]): @{$FileLB->{array}};
	my $all = 0;
	foreach my $col (@lst) {
	  last if ($col eq 'SeP');
	  my $dest = $Collection->path($col)."/$col/Pro";
	  foreach (@toExp) {
	    (my $fn = $_) =~ s/.*\///;
	    if (-e "$dest/$fn") {
	      if ($all == 0) {
		my $ans = msgYesNoAll("The file: \"$fn\"\nalready exists in:\n   \"$dest\"\nDo you want to overwrite it?");
		next if ($ans eq "No");
		$all++ if ($ans eq "All");
	      }
	      unlink("$dest/$fn");
	    }
	    my $txt = read_file("$path/$fn");
	    write_file("$dest/$fn", $txt);
	  }
	}
	message(SMILE, ' Done ', 1);
	return;
      }
    }
    my $dest = Tkx::tk___chooseDirectory(
      -title => "Choose Destination Folder",
      -initialdir => "$Home",);
    $dest =~ s/\/$//;
    if ($dest ne '') {
      if ($dest eq $path) {
	message(QUIZ, "Destination Folder cannot be\n\"$path\"\nPlease try again!");
	return;
      }
      expPP($path, $dest, $ext, $idx);
    }
  } else {
    message(SAD, "You have to have one or more files listed\nbefore you can export anything.");
  }
}

sub expPP {
  my($path,$dest,$ext,$idx) = @_;

  if (! -e $dest) {
    make_path($dest, {chmod => 0777});
  }
  my @toExp = ($idx >= 0) ? ($FileLB->{array}[$idx]): @{$FileLB->{array}};
  my @list = my @notEx = ();
  foreach my $fn (@toExp) {
    $fn =~ s/.pro$/$ext/i;
    if (! -e "$path/$fn") {
      push(@notEx, $fn);
    } else {
      push(@list, $fn);
    }
  }
  if (@list && copyFiles(\@list, $path, $dest) && @notEx == 0) {
    my $f = (@list > 1) ? "All Files" : "File";
    message(SMILE, "$f Exported to $dest", 1);
  } else {
    if (@list == 0) {
      message(SAD, "No files found to Export", 1);
    } else {
      my $msg = "The following file(s) were Exported:\n   ".join("\n   ", @list);
      message(SAD, "$msg\n\nThe following file(s) were not Exported (did not exist):\n   ".join("\n   ", @notEx));
    }
  }
}

sub mailFile {
  my($path,$ext,$just1) = @_;

  if (@{$FileLB->{array}}) {
    my $idx = $FileLB->curselection(0);
    if (defined $just1 && $idx eq '') {
      message(SAD, "Please select a file to mail.");
      return;
    }
    my @toMail = (defined $just1) ? ($FileLB->{array}[$idx]): @{$FileLB->{array}};
    my @list = my @notMail = ();
    foreach my $fn (@toMail) {
      $fn =~ s/.pro$/$ext/i;
      if (! -e "$path/$fn") {
	push(@notMail, $fn);
      } else {
	push(@list, $fn);
      }
    }
    if (@list == 0) {
      message(SAD, "No files found to Mail", 1);
    } elsif (cpmail($path, \@list) && @notMail) {
      my $msg = "The following file(s) were Mailed:\n   ".join("\n   ", @list);
      message(SAD, "$msg\n\nThe following file(s) were not Mailed (did not exist):\n   ".join("\n   ", @notMail));
    }
  }
}

sub copyFiles {
  my($ref,$src,$dest) = @_;

  my $all = 0;
  my $cnt = 0;
  foreach (@$ref) {
    (my $fn = $_) =~ s/.*\///;
    if (-e "$dest/$fn") {
      if ($all == 0) {
	my $ans = msgYesNoAll("The file: \"$fn\"\nalready exists in:\n   \"$dest\"\nDo you want to overwrite it?");
	next if ($ans eq "No");
	$all++ if ($ans eq "All");
      }
      unlink("$dest/$fn");
    }
    my $txt = read_file("$src/$fn");
    if (write_file("$dest/$fn", $txt) == 1) {
      $cnt++;
    }
  }
  $cnt;
}
  
sub useBold {
  $Opt->{UseBold} ^= 1;
  my $w = ($Opt->{UseBold}) ? 'bold' : 'normal';
  Tkx::font_configure('TkDefaultFont', -weight => $w);
  Tkx::font_configure('STkDefaultFont', -weight => $w);
  # This causes the complete app to be redrawn.
  Tkx::event_generate($MW, '<<ThemeChanged>>');
}

sub editArticles {
  my $done;
  my $pop = CP::Pop->new(0, '.ea', 'Edit Articles');
  return if ($pop eq '');
  my($top,$fr) = ($pop->{top}, $pop->{frame});

  my $tf = $fr->new_ttk__frame();
  $tf->g_grid(qw/-row 0 -column 0 -padx 4 -pady 6 -sticky nsew/);

  my $hl = $fr->new_ttk__separator(-orient => 'horizontal');
  $hl->g_grid(qw/-row 1 -column 0 -sticky ew/);

  my $bf = $fr->new_ttk__frame();
  $bf->g_grid(qw/-row 2 -column 0 -sticky ew -padx 4/, -pady => [6,2]);

  my $fl = $tf->new_ttk__label(-text => 'Articles ( | separated list) ');
  $fl->g_grid(qw/-row 0 -column 0/);
  my $arts = $Opt->{Articles};
  my $fe = $tf->new_ttk__entry(
    -width => 20,
    -textvariable => \$arts);
  $fe->g_grid(qw/-row 0 -column 1 -padx 4 -pady 2/);

  my $cancel = $bf->new_ttk__button(-text => "Cancel", -command => sub{$done = "Cancel";});
  $cancel->g_pack(qw/-side left -padx 40/);

  my $ok = $bf->new_ttk__button(-text => "OK", -command => sub{$done = "OK";});
  $ok->g_pack(qw/-side right -padx 40/);

  $top->g_wm_deiconify();
  $top->g_raise();
  $fe->g_focus;
  Tkx::vwait(\$done);

  if ($done eq 'OK') {
    $Opt->{Articles} = $arts;
  }
  $pop->popDestroy();
}

sub saveMed {
  message(SMILE, "Media Config Saved", 1) if ($Media->save());
}

sub loadMed {
  message(SMILE, " Done ", 1) if ($Media->load());
}

sub resetMed {
  $Media->default();
  message(SMILE, "Done - but not saved (yet).");
}

sub editMed {
  CP::Editor::Edit($Path->{Media}, 1);
}

sub saveCmnd {
  message(SMILE, "Commands Saved", 1) if ($Cmnd->save());
}

sub loadCmnd {
  message(SMILE, " Done ", 1) if ($Cmnd->load());
}

sub resetCmnd {
  $Cmnd->default();
  message(SMILE, "Done - but not saved (yet).");
}

sub selectFiles {
  my($what) = shift;

  $Path->{Pro} = "$Home" if ("$Path->{Pro}" eq "");
  my @files = CP::Browser->new($MW, $what, $Path->{Pro}, '.pro');
  showSelection(\@files) if (@files);
}

sub showSelection {
  selectClear();
  my $idx = 0;
  foreach my $x (@{$_[0]}) {
    if ($x =~ /\.pro$/i) {
      my $ref = CP::Pro->new($x);
      $ProFiles[$idx++] = $ref;
      $KeyLB->add2a("$ref->{key}");
      $FileLB->add2a($ref->{name});
    }
  }
  $FileLB->set(0);
}

sub selectClear {
  @ProFiles = ();
  $KeyLB->clear();
  $FileLB->clear();
}

sub newProFile {
  my $fn = "";
  my $ans = msgSet("Enter a name for the new file", \$fn);
  return if ($ans eq "Cancel");
  if ($fn eq "") {
    message(QUIZ, "How about a file name then?");
    return;
  }
  (my $title = $fn) =~ s/\.pro$//;
  $fn = "$title.pro";
  my $fileName = "$Path->{Pro}/$fn";
  if (-e "$fileName") {
    $ans = msgYesNo("$fn already exists.\nDo you want to continue and edit it?");
    return if ($ans eq "No");
  } else {
    open OFH, ">", "$fileName";
    print OFH "{title:$title}\n";
    close OFH;
  }
  my $tempfn = CP::Editor::Edit($fileName);
  if ($tempfn eq "$fn" && -s "$fileName") {
    selectClear();
    my $ref = CP::Pro->new("$fn");
    $ProFiles[0] = $ref;
    $KeyLB->add2a("$ref->{key}");
    $FileLB->add2a($ref->{name});
    $FileLB->set(0);
  }
}

sub clonePro {
  if ((my $idx = selectPro("cloning")) >= 0) {
    $ProFiles[$idx]->clone($idx);
  }
}

sub editPro {
  if ((my $idx = selectPro("editing")) >= 0) {
    $ProFiles[$idx]->edit($idx);
  }
}

sub deletePro {
  if ((my $idx = selectPro("deleting")) >= 0) {
    $ProFiles[$idx]->delete($idx);
  }
}

sub renamePro {
  if ((my $idx = selectPro("renaming")) >= 0) {
    $ProFiles[$idx]->rename($idx);
  }
}

sub selectPro {
  my($msg) = shift;
  my $idx = $FileLB->curselection(0);
  if ($idx eq '' || @ProFiles == 0 || $ProFiles[$idx]->{name} eq "") {
    message(SAD, "There doesn't seem to be a file selected for $msg!");
    $idx = -1;
  }
  return($idx);
}

sub transposeOne {
  if ($#ProFiles < 0) {
    message(QUIZ, "Can't do anything without a ChordPro file.");
    return;
  }
  if ($Opt->{Transpose} eq "-") {
    message(QUIZ, "Hmmm ... If you want to Transpose some\nfiles you have to tell me what key!");
    $PDFtrans = 0;
    return;
  } else {
    my $idx = $FileLB->curselection(0);
    if ($idx eq '') {
      message(SAD, "There doesn't seem to be a file selected for Transposing!");
    } else {
      if ($ProFiles[$idx]->transpose($idx)) {
	$ProFiles[$idx] = CP::Pro->new($ProFiles[$idx]->{name});
	$KeyLB->{array}[$idx] = "$ProFiles[$idx]->{key}";
	$KeyLB->a2tcl();
      }
      $Opt->{Transpose} = '-';
    }
  }
}

sub Main {
  my($chordy,$oneorall) = @_;

  if ($#ProFiles < 0) {
    message(QUIZ, "Can't do anything without a ChordPro file.");
    return;
  }
  $LenError = 0;
  if (($Opt->{PDFview} | $Opt->{PDFmake} | $Opt->{PDFprint}) == 0) {
    message(QUIZ, "Hmmm ... Might help if you gave me something to do!");
    return;
  }
  my $tmpMedia = '';
  my $tmpView = 0;
  if ($Opt->{PDFprint}) {
    if ($Opt->{PrintMedia} ne $Opt->{Media}) {
      my $ans = msgYesNoCan("Your Printer page size is different to your Media page size.\nDo you want to see a preview of the Printer page?");
      if ($ans eq 'Yes') {
	$tmpView = $Opt->{PDFview};
	$Opt->{PDFview} = 1;
	$tmpMedia = $Opt->{Media};
	$Opt->{Media} = $Opt->{PrintMedia};
	$Media = $Media->change($Opt->{Media});
	$Opt->{PDFprint} = 69;
      } elsif ($ans eq 'Cancel') {
	return;
      }
    }
  }
  if ($oneorall == SINGLE) {
    ### Handle one single ChordPro file
    my $idx = $FileLB->curselection(0);
    if ($idx ne '') {
      my($pdf,$name) = makeOnePDF($ProFiles[$idx], undef, undef, $chordy->{ProgLab});
      $pdf->close();
      actionPDF($chordy, "$Path->{Temp}/$name", $name);
    } else {
      message(SAD, "You don't appear to have selected a ChordPro file.");
      return;
    }
  } else {
    if ($Opt->{Transpose} ne "-") {
      my $msg = "This will Transpose ALL files to the key of $Opt->{Transpose}.\nDo you want to continue?";
      if (msgYesNo($msg) eq 'No') {
	return;
      }
    }

    my $maxi = $#ProFiles;
    # Do them in reverse order if printing AND we're not creating a single PDF
    my @pfn = ($Opt->{PDFprint} && $Opt->{OnePDFfile} == MULTIPLE) ? reverse(0..$maxi) : (0..$maxi);
    #
    # We do one monster PDF - or - We do lots of individual PDFs
    #
    if ($Opt->{OnePDFfile} == SINGLE) {
      ### One monster PDF
      if (! defined $CurSet || $CurSet eq "") {
	my $ans = msgSet("You need to provide a name for the PDF File:",\$CurSet);
	if ($ans eq "Cancel" || $CurSet eq "") {
	  return;
	}
      }
      progressEnable($chordy);
      my $PdfFileName = "$CurSet.pdf";
      my $pdf = undef;
      foreach my $idx (@pfn) {
	($pdf,$PdfFileName) = makeOnePDF($ProFiles[$idx], $PdfFileName, $pdf, $chordy->{ProgLab});
	if ($chordy->{ProgCan}) {
	  $pdf->close();
	  progressDisable($chordy);
	  return;
	}
	Tkx::after(500); # Give user a chance to hit Cancel!
      }
      $pdf->close();
      actionPDF($chordy, "$Path->{Temp}/$PdfFileName", "$PdfFileName");
    } else {
      ### Action each PDF independantly
      progressEnable($chordy);
      foreach my $idx (@pfn) {
	if ($chordy->{ProgCan}) {
	  progressDisable($chordy);
	  return;
	}
	my($pdf,$name) = makeOnePDF($ProFiles[$idx], undef, undef, $chordy->{ProgLab});
	$pdf->close();
	if ($chordy->{ProgCan} || actionPDF($chordy, "$Path->{Temp}/$name", $name) < 0) {
	  progressDisable($chordy);
	  return;
	}
      }
    }
  }
  progressDisable($chordy);
  if ($tmpMedia ne '') {
    $Opt->{PDFview} = $tmpView;
    $Opt->{Media} = $tmpMedia;
    $Media = $Media->change($Opt->{Media});
  }
  # $LenError is set in CP::Pro::makePDF()
  if ($LenError) {
    if ($Opt->{NoWarn} == 0) {
      message(SAD, "One or more lines were reduced in size to fit on their page.\nSee the error log for specific details.");
    }
    $LenError = 0;
  } else {
    message(SMILE, ' Done ', 1) if ($PDFtrans || $oneorall == MULTIPLE);
  }
  $PDFtrans = 0;
}

sub progressEnable {
  my($chdy) = shift;

  $chdy->{ProgFrm}->g_grid(qw/-row 1 -columnspan 3 -sticky ew -padx 16/, -pady => [4,0]);
  $chdy->{ProgCan} = 0;
}

sub progressDisable {
  my($chdy) = shift;

  $chdy->{ProgFrm}->g_grid_forget();
  $chdy->{ProgCan} = 0;
}

sub makeOnePDF {
  my($pro,$name,$pdf,$label) = @_;

  $label->m_configure(-text => $pro->{name});
  Tkx::update();
  if (! defined $name) {
    ($name = $pro->{name}) =~ s/\.pro$//i;
    $name .= '.pdf';
  }
  my $tmpPDF = "$Path->{Temp}/$name";

  if (! defined $pdf) {
    unlink("$tmpPDF") if (-e "$tmpPDF");
    $pdf = CP::CPpdf->new($pro, $tmpPDF);
  }

  my $tmpCapo = $pro->{capo};
  $pro->{capo} = $Opt->{Capo} if ($Opt->{Capo} ne "No");

  $pro->makePDF($pdf);

  $pro->{capo} = $tmpCapo;
  ($pdf, $name);
}

sub actionPDF {
  my($chordy,$tmpPDF,$PDFfileName) = @_;

  my $Pact = "";
  if ($Opt->{PDFview}) {
    Tkx::update();
    my $ret = PDFview($chordy, $tmpPDF);
    return($ret) if ($ret <= 0);
  }
  if ($Opt->{PDFprint}) {
    return if (PDFprint($tmpPDF) == 0);
  }
  if ($Opt->{PDFmake}) {
    unlink("$Path->{PDF}/$PDFfileName") if (-e "$Path->{PDF}/$PDFfileName");
    my $txt = read_file("$tmpPDF");
    write_file("$Path->{PDF}/$PDFfileName", $txt);
    if ($Opt->{PDFpath} ne '' && $Opt->{PDFpath} ne $Path->{PDF}) {
      write_file("$Opt->{PDFpath}/$PDFfileName", $txt);
    }
    (my $name = $PDFfileName) =~ s/\.pdf$/.pro/;
    $Opt->add2recent($name,'RecentPro',\&CP::CPmenu::refreshRcnt);
  }
}

sub PDFview {
  my($chordy, $tmpPDF) = @_;

  my $Pact = "";
  if ($Cmnd->{Acro} ne "") {
    if ($Cmnd->{Acro} =~ /(\%file\%)/i) {
      ($Pact = $Cmnd->{Acro}) =~ s/$1/\"$tmpPDF\"/i;
    } else {
      $Pact = "$Cmnd->{Acro} \"$tmpPDF\"";
    }
  } else {
    message(SAD, "You need to have a PDF viewer installed\nto be able to view (and possibly print)\nthe PDF file just created.\nSee the 'Commands' entry under the 'Misc' menu.");
    return(0);
  }
  jobSpawn($Pact) if ($Pact ne "");
  Tkx::update();
  if ($Opt->{PDFprint} == 69) {
    if ($chordy->{ProgCan} == 0) {
      my $ans = msgYesNoCan("Do you want to continue and print the PDF?");
      return(0) if ($ans eq 'No');
      return(-1) if ($ans eq 'Cancel');
    } else {
      return(-1);
    }
  }
  1;
}

sub PDFprint {
  my($tmpPDF) = shift;

  my $Pact = "";
  if ($Cmnd->{Print} ne "") {
    if ($Cmnd->{Print} =~ /(\%file\%)/i) {
      ($Pact = $Cmnd->{Print}) =~ s/$1/\"$tmpPDF\"/i;
    } else {
      $Pact = "$Cmnd->{Print} \"$tmpPDF\"";
    }
  } else {
    message(SAD, "You need to have a PDF print capable command installed\nto be able to print the PDF file just created.\nSee the 'Commands' entry under the 'Misc' menu.");
    return(0);
  }
  jobSpawn($Pact) if ($Pact ne "");
  1;
}
