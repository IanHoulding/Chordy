package CP::Fonts;

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
use CP::Cconst qw/:PATH :COLOUR :SMILIE/;
use CP::Global qw/:FUNC :VERS :OPT :WIN :MEDIA/;
use CP::List;
use CP::Pop qw/:POP :MENU/;
# The only reason this lot is explicitly listed is because using
# "pp" to create an executable seems to loose track of them :(
use Font::TTF::Font;
use Font::TTF::Name;
use Font::TTF::DSIG;
use Font::TTF::EBDT;
use Font::TTF::EBLC;
use Font::TTF::GPOS;
use Font::TTF::GDEF;
use Font::TTF::GSUB;
use Font::TTF::LTSH;
use Font::TTF::OS_2;
use Font::TTF::PCLT;
use Font::TTF::Cmap;
use Font::TTF::Cvt_;
use Font::TTF::Fpgm;
use Font::TTF::Glyf;
use Font::TTF::Hdmx;
use Font::TTF::Head;
use Font::TTF::Hhea;
use Font::TTF::Vhea;
use Font::TTF::Vmtx;
use Font::TTF::Hmtx;
use Font::TTF::Kern;
use Font::TTF::Loca;
use Font::TTF::Maxp;
use Font::TTF::Post;
use Font::TTF::Prep;
use Font::TTF::Mort;
use Font::TTF::GrFeat;
use Font::TTF::Glat;
use Font::TTF::Gloc;
use Font::TTF::Silf;
use Font::TTF::Sill;
use Font::TTF::Feat;
use Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/&fontPick &fontSetup/;

our($Fontlb,$FontCan,$Sample);

our $Ffamily = '';
our $Fsize = 0;
our $Fweight = '';
our $Fslant = '';
our $Fcolor = '';
our $Fmono = 0;

my $Done;

sub new {
  my($title) = shift;

  my $pop = CP::Pop->new(0, '.fe', $title);
  return if ($pop eq '');
  my($top,$fr) = ($pop->{top}, $pop->{frame});
  $top->g_wm_protocol('WM_DELETE_WINDOW' => sub{$Done = 'Cancel';});
  
  my $ftop = $fr->new_ttk__frame(qw/-borderwidth 1 -relief solid/);
  $ftop->g_pack(qw/-side top -expand 1 -fill x/);

  my $fmid = $fr->new_ttk__frame(qw/-borderwidth 2 -relief raised/);
  $fmid->g_pack(qw/-side top -expand 1 -fill x/);

  my $fbot = $fr->new_ttk__frame();
  $fbot->g_pack(qw/-side top -expand 1 -fill x/);

  $FontCan = $ftop->new_tk__canvas(qw/-height 90 -width 200/);
  $FontCan->g_pack(qw/-side left -expand 1 -fill x/);

  my $l1 = $fmid->new_ttk__label(-text => "Font Family:");
  $l1->g_grid(qw/-row 0 -column 0 -padx 20/);

  $Fontlb = CP::List->new(
    $fmid,
    'e',
    -height => 24,
    -width => 25,
    -selectmode => 'browse',
    -takefocus => 1);
  $Fontlb->{frame}->g_grid(qw/-row 1 -column 0 -stick e/, -padx => "20 0", -pady => "0 20");
  listFill();
  $Fontlb->bind('<<ListboxSelect>>' => \&checkFont);
  
  my $midr = $fmid->new_ttk__frame();
  $midr->g_grid(qw/-row 1 -column 2 -sticky ns/);
 
  $Fweight = 'normal';
  my $ch1 = $midr->new_ttk__checkbutton(-style => 'My.TCheckbutton',
					-compound => 'left',
					-image => ['xtick', 'selected', 'tick'],
					-text => 'Bold',
					-variable => \$Fweight,
					-onvalue => 'bold',
					-offvalue => 'normal',
					-command => \&showSample);
  $ch1->g_grid(qw/-row 0 -column 0 -sticky nw/, -padx => 20, -pady => "20 5");

  my $ch1a = $midr->new_ttk__checkbutton(-style => 'My.TCheckbutton',
					 -compound => 'left',
					 -image => ['xtick', 'selected', 'tick'], 
					 -text => 'Heavy',
					 -variable => \$Fweight,
					 -onvalue => 'heavy',
					 -offvalue => 'normal',
					 -command => \&showSample);
  $ch1a->g_grid(qw/-row 1 -column 0 -sticky nw/, -padx => 20, -pady => 5);

  $Fslant = 'roman';
  my $ch2 = $midr->new_ttk__checkbutton(-style => 'My.TCheckbutton',
					-compound => 'left',
					-image => ['xtick', 'selected', 'tick'], 
					-text => 'Italic',
					-variable => \$Fslant,
					-onvalue => 'italic',
					-offvalue => 'roman',
					-command => \&showSample);
  $ch2->g_grid(qw/-row 2 -column 0 -sticky nw -padx 20 -pady 5/);

  my $ch3 = $midr->new_ttk__checkbutton(-style => 'My.TCheckbutton',
					-compound => 'left',
					-image => ['xtick', 'selected', 'tick'], 
					-text => 'Fixed Width',
					-variable => \$Fmono,
					-onvalue => 1,
					-offvalue => 0,
					-command => \&listFill);
  $ch3->g_grid(qw/-row 3 -column 0 -sticky nw -padx 20 -pady 25/);

  my $b1 = $fbot->new_ttk__button(
    -text => "Cancel",
    -command => sub{$Done = "Cancel";});
  $b1->g_grid(qw/-row 0 -column 0 -sticky w -padx 20 -pady 4/);
  my $bt = $fbot->new_ttk__button(
    -text => "OK",
    -command => sub{$Done = "OK";});
  $bt->g_grid(qw/-row 0 -column 1 -sticky e -padx 20 -pady 4/);

  Tkx::update();

  $Sample = $FontCan->m_create_text(
    (Tkx::winfo_width($FontCan) / 2)." ".(Tkx::winfo_height($FontCan) / 2),
    -text => "A B C D E F G\nSharps # - Flats b\n12345 11 15 19",
    -anchor => 'center',
    -justify => 'center');

  $pop;
}

sub listFill {
  $Fontlb->clear();
  foreach my $f (sort keys %FontList) {
    if ($Fmono) {
      $Fontlb->add2a($f) if ($FontList{$f}{fixed});
    } else {
      $Fontlb->add2a($f) if ($f !~ /^\@/);
    }
  }
}

sub checkFont {
  my $idx = $Fontlb->curselection(0);
  $Ffamily = $Fontlb->{array}[$idx];
  showSample($FontList{$Ffamily});
}

sub showSample {
  my $wt = ($Fweight eq 'heavy') ? 'bold' : $Fweight;
  $FontCan->m_itemconfigure(
    $Sample,
    -font => "{$Ffamily} $Fsize $wt $Fslant",
    -fill => $Fcolor);
}

sub fontPick {
  my($font,$fg,$bg,$title) = @_;

  return if ((my $pop = new($title)) eq '');

  $Ffamily = $font->{family};
  $Fsize   = $font->{size};
  $Fweight = $font->{weight};
  $Fslant  = $font->{slant};
  $Fcolor  = $fg;
  $FontCan->m_configure(-background => $bg);
  my $i = 0;
  foreach my $f (@{$Fontlb->{array}}) {
    if ($f eq $Ffamily) {
      $Fontlb->focus();
      $Fontlb->set($i);
      last;
    }
    $i++;
  }
  if ($i > $#{$Fontlb->{array}}) {
    $Ffamily = $Fontlb->{array}[0];
  }
  showSample();

  $pop->{top}->g_raise;
  Tkx::vwait(\$Done);

  if ($Done eq "OK") {
    $font->{family} = $Ffamily;
    $font->{size}   = $Fsize;
    $font->{weight} = $Fweight;
    $font->{slant}  = $Fslant;
  }

  $pop->popDestroy();
  $Done;
}

sub getFont {
  my($pdf,$fam,$wt) = @_;

  if (! defined $FontList{"$fam"}) {
    $fam = 'Times New Roman';
    errorPrint("Font '$fam' not found.\nSubstituting 'Times New Roman'");
  }
  my $path = $FontList{"$fam"}{Path};
  my $pfp = $pdf->ttfont($path.'/'.$FontList{"$fam"}{Regular});
  if ($wt ne 'Regular') {
    my %opts = ();
    if ($wt =~ /(Bold|Heavy)/) {
      $opts{'-bold'} = $Opt->{$1};
    }
    if ($wt =~ /Italic/) {
      $opts{'-oblique'} = $Opt->{Italic};
    }
    $pfp = $pdf->synfont($pfp, %opts);
  }
  $pfp;
}

# Unfortunately we need to build a font list as the PDF
# font handler needs a file name AND path!
sub fontSetup {

  my $uf = USER."/FontList";
  if (-e $uf) {
    our $version = "";
    require $uf;
    build() if ($version ne $Version);
    return;
  }
  my $build = 0;
  if (! defined $FontList{'Arial'}) {
    $build++;
  } else {
    # Check to see if font has moved.
    foreach my $dir (split(',', $Path->{Font})) {
      if (-f "$dir/Arial.ttf" && $FontList{'Arial'}{Path} ne $dir) {
	# ALL OS flavours have the Arial font (somewhere!)
	$build++;
      }
    }
  }
  build() if ($build);
}

sub build {
  %FontList = ();
  foreach my $dir (split(',', $Path->{Font})) {
    if (! -d $dir) {
      message(SAD, "Something's gone badly wrong.\nThe built-in Font folder:\n  $dir\ndoes not seem to exist.\nPlease report this to ian\@houlding.me.uk and include:\n  Operating System - MacOS, Windows etc.\n  OS Version\n  Chordy Version ($Version)\nThank you.");
      exit(1);
    }
    scan($dir, 0) or die "No True Type fonts found in $dir\n";
  }
#  foreach my $k (keys %FontList) {
#    my $ref = \%{$FontList{$k}};
#    $ref->{Bold} = "" if (! exists $ref->{Bold});
#    $ref->{Italic} = "" if (! exists $ref->{Italic});
#    $ref->{BoldItalic} = "" if (! exists $ref->{BoldItalic});
#  }
  saveFL();
}

sub saveFL {
  open OFH, ">", USER."/FontList";
  print OFH "\$version = \"$Version\";\n";
  print OFH "\%FontList = (\n";
  foreach my $k (sort keys %FontList) {
    if ($k =~ /[a-z]/i) {
      print OFH "  \"$k\" => {\n";
      foreach my $s (sort keys %{$FontList{$k}}) {
	if ($s eq 'fixed') {
	  print OFH "    $s => ".$FontList{$k}{$s}.",\n";
	} else {
	  print OFH "    $s => \"".$FontList{$k}{$s}."\",\n";
	}
      }
      print OFH "  },\n";
    }
  }
  print OFH ");\n1;\n";
  close(OFH);
}

# Recursive scan for TTF font files.
sub scan {
  my($path,$cnt) = @_;
  opendir my $dh, "$path" or die "scan() couldn't open directory: '$path'\n";
  foreach my $f (grep /\.ttf$/i, readdir $dh) {
    if (-d "$path/$f") {
      $cnt = scan("$path/$f",$cnt);
    }
    else {
      if (-f "$path/$f" && $f =~ /.ttf$/i) {
	my $fnt = Font::TTF::Font->open("$path/$f");
	# See http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-chapter08
	my $ps = $fnt->{post}->read;
	my $tab = $fnt->{name}->read;
	my $fam = $tab->find_name(1);
	my $stl = $tab->find_name(2);
	if ($stl =~ /regular|book/i) {
	  $FontList{"$fam"}{Path} = $path;
	  my $fp = \%{$FontList{"$fam"}};
	  $fp->{fixed} |= $ps->{isFixedPitch};
	  $fp->{Regular} = "$f";
	  $cnt++;
	}
	$fnt->release();
      }
    }
  }
  closedir($dh);
  $cnt;
}

sub OLDscan {
  my($path,$cnt) = @_;
  opendir my $dh, "$path" or die "scan() couldn't open directory: '$path'\n";
  foreach my $f (grep /\.ttf$/i, readdir $dh) {
    if (-d "$path/$f") {
      $cnt = scan("$path/$f",$cnt);
    }
    else {
      if (-f "$path/$f" && $f =~ /.ttf$/i) {
	my $fnt = Font::TTF::Font->open("$path/$f");
	# See http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-chapter08
	my $ps = $fnt->{post}->read;
	my $tab = $fnt->{name}->read;
	my $fam = $tab->find_name(1);
	my $stl = $tab->find_name(2);
	$FontList{"$fam"}{Path} = $path;
	my $fp = \%{$FontList{"$fam"}};
	$fp->{fixed} |= $ps->{isFixedPitch};
	if ($stl =~ /^bold$/i) {
	  $fp->{Bold} = "$f";
	  $cnt++;
	}
	elsif ($stl =~ /^black$/i && !defined $fp->{"Bold"}) {
	  $fp->{Bold} = "$f";
	  $cnt++;
	}
	elsif ($stl =~ /^italic$/i) {
	  $fp->{Italic} = "$f";
	  $cnt++;
	}
	elsif ($stl =~ /^oblique$/i && !defined $fp->{"Italic"}) {
	  $fp->{Italic} = "$f";
	  $cnt++;
	}
	elsif ($stl =~ /bold/i && $stl =~ /italic/i) {
	  $fp->{BoldItalic} = "$f";
	  $cnt++;
	}
	elsif ($stl =~ /bold/i && $stl =~ /oblique/i && !defined $fp->{"BoldItalic"}) {
	  $fp->{BoldItalic} = "$f";
	  $cnt++;
	}
	else {
	  $fp->{Regular} = "$f";
	  $cnt++;
	}
	$fnt->release();
      }
    }
  }
  closedir($dh);
  $cnt;
}

sub fonts {
  my($frame,$list) = @_;

  ($frame->new_ttk__label(qw/-text Size/))->g_grid(qw/-row 0 -column 3 -padx 8 -pady 0/);
  ($frame->new_ttk__label(qw/-text Bold/))->g_grid(qw/-row 0 -column 4 -padx 4 -pady 0/);
  ($frame->new_ttk__label(qw/-text Heavy/))->g_grid(qw/-row 0 -column 5 -padx 0 -pady 0/);
  ($frame->new_ttk__label(qw/-text Italic/))->g_grid(qw/-row 0 -column 6 -padx 4 -pady 0/);

  # There are a couple of exceptions :-(
  my $row = 1;
  foreach my $f (@{$list}) {
    my $fp = ($f eq 'Editor') ? \%EditFont : $Media->{"$f"};
    FontS($frame, $row++, $f, $fp);
  }
  my $attr = $frame->new_ttk__labelframe(-text => " Font Attributes ", -padding => [4,2,0,4]);
  $attr->g_grid(-row => $row, -column => 2, -columnspan => 5, -pady => [4,0], -sticky => 'we');

  my $col = 0;
  foreach my $m (['Bold',   1, 8],
		 ['Heavy',  1, 8],
		 ['Italic', -20, 20], ) {
    my($lab,$frst,$last) = @{$m};
    $a = $attr->new_ttk__label(-text => "$lab", -anchor => 'e');

    $b = $attr->new_ttk__spinbox(
      -textvariable => \$Opt->{"$lab"},
      -from => $frst,
      -to => $last,
      -wrap => 1,
      -width => ($lab eq 'Italic') ? 3 : 2,
      -state => 'readonly',
      -command => sub{$Opt->saveOne("$lab");});
    $a->g_grid(qw/-row 0 -sticky e/, -column => $col++, -padx => [4,2]);
    $b->g_grid(qw/-row 0 -sticky w/, -column => $col++, -padx => [0,20]);
  }
}

sub FontS {
  my($frame,$r,$title,$fp) = @_;

  my $tlab = ($title eq 'SNotes') ? 'Small Notes' : $title;
  my $ttl = $frame->new_ttk__label(-text => "$tlab");

  my $fg = $Opt->{"FG$title"};
  my $bg = bgSet($title);

  Tkx::ttk__style_configure("$title.FG.TButton", -background => $fg);
  my $clr = $frame->new_ttk__button(
    -image => 'blank',
    -style => "$title.FG.TButton");
  $clr->m_configure(-command => sub{pickFG($title, $fp, $Opt->{"FG$title"}, bgSet($title));});

  my $wt = ($fp->{weight} eq 'heavy') ? 'bold' : $fp->{weight};
  Tkx::ttk__style_configure("$title.Font.TLabel",
			    -foreground => $fg,
			    -background => $bg,
			    -font => "{$fp->{family}} $fp->{size} $wt $fp->{slant}");
  my $lab = $frame->new_ttk__label(
    -width => 20,
    -textvariable => \$fp->{family},
    -style => "$title.Font.TLabel",
      );

  my $siz = popButton($frame,
		      \$fp->{size},
		      sub{labUpdate($lab, $fp)},
		      [qw( 5  6  7  8  9 10 11 12 13 14 15 16 17 18 19
		          20 21 22 23 24 25 26 27 28 29 30 33 34 36 40)],
		      -width => 3,
		      -style => 'Menu.TButton',
      );

  my($wtb,$wth);
  $wtb = $frame->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				      -compound => 'left',
				      -image => ['xtick', 'selected', 'tick'], 
				      -variable => \$fp->{weight},
				      -onvalue => 'bold',
				      -offvalue => 'normal',
				      -command => sub{labUpdate($lab, $fp)});

  $wth = $frame->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				      -compound => 'left',
				      -image => ['xtick', 'selected', 'tick'], 
				      -variable => \$fp->{weight},
				      -onvalue => 'heavy',
				      -offvalue => 'normal',
				      -command => sub{labUpdate($lab, $fp)});

  my $ita = $frame->new_ttk__checkbutton(-style => 'My.TCheckbutton',
					 -compound => 'left',
					 -image => ['xtick', 'selected', 'tick'],
					 -variable => \$fp->{slant},
					 -onvalue => 'italic',
					 -offvalue => 'roman',
					 -command => sub{labUpdate($lab, $fp)});

  my $but = $frame->new_ttk__button(
    -text => 'Choose ...',
    -command => sub{
      fontPick($fp, $fg, $bg, "$title Font");
      labUpdate($lab,$fp);
    });
  
  $ttl->g_grid(-row => $r, qw/-column 0 -sticky e  -pady 2/, -padx => [4,0]);
  $clr->g_grid(-row => $r, qw/-column 1 -sticky we -pady 2/, -padx => 4);
  $lab->g_grid(-row => $r, qw/-column 2 -sticky we -pady 2/, -padx => [2,4]);
  $siz->g_grid(-row => $r, qw/-column 3 -pady 2/);
  $wtb->g_grid(-row => $r, qw/-column 4 -pady 2/);
  $wth->g_grid(-row => $r, qw/-column 5 -pady 2/);
  $ita->g_grid(-row => $r, qw/-column 6 -pady 2/);
  $but->g_grid(-row => $r, qw/-column 7 -sticky w -padx 2 -pady 2/);
}

sub bgSet {
  my($title) = shift;

  my $bg = WHITE;
  if ($title =~ /Chord|Lyric/) {
    $bg = $Opt->{BGVerse};
  } elsif ($title =~ /Comment|Editor|Highlight|Tab|Title/) {
    $bg = $Opt->{"BG$title"};
  }
  $bg;
}

sub pickFG {
  my($title,$fontp,$fg,$bg) = @_;

  CP::FgBgEd->new("$title Font");
  my $save = 0;
  my $bdr = '';
  my $op = FOREGRND;
  $op |= BACKGRND if ($title =~ /Com|Hig|Tab|Tit|Cho|Lyr/);
  if ($title =~ /Com|Hig/) {
    $op |= BORDER;
    $bdr = ($title =~ /^Com/) ? $Opt->{CborderColour} : $Opt->{HborderColour};
  }
  ($fg,$bg) = $ColourEd->Show($fg, $bg, $bdr, $op);
  if ($fg ne '') {
    $Opt->{'FG'.$title} = $fg;
    Tkx::ttk__style_configure("$title.Font.TLabel", -foreground => $fg);
    Tkx::ttk__style_configure("$title.FG.TButton", -background => $fg);
    $save++;
  }
  if ($bg ne '' && ($op & BACKGRND)) {
    Tkx::ttk__style_configure("$title.Font.TLabel", -background => $bg);
    Tkx::ttk__style_configure("$title.BG.TButton",  -background => $bg);
    if ($title =~ /Cho|Lyr/) {
      my $t = ($title =~ /Cho/) ? 'Lyric' : 'Chord';
      Tkx::ttk__style_configure("$t.Font.TLabel", -background => $bg);
      Tkx::ttk__style_configure("Verse.BG.TButton", -background => $bg);
      $Opt->{BGVerse} = $bg;
    } else {
      $Opt->{'BG'.$title} = $bg;
    }
    $save++;
  }
  $Media->save() if ($save);
}

sub labUpdate {
  my($lab,$fp) = @_;

  my $wt = ($fp->{weight} eq 'heavy') ? 'bold' : $fp->{weight};
  $lab->m_configure(-font => "{$fp->{family}} $fp->{size} $wt $fp->{slant}");
  $Media->save();
}

1;
