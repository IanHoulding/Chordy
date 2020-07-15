package CP::Cmsg;

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

BEGIN {
  our @ISA = qw(Exporter);
  our @EXPORT = qw(&message &msgYesNo &msgYesNoCan &msgSet &msgYesNoAll);
  require Exporter;
}

use Tkx;
use CP::Global qw/:FUNC :WIN :XPM/;
use CP::Cconst qw/:SMILIE :COLOUR/;
use CP::Pop qw/:POP/;

my $Init = 0;
my @Smilies;
my $Mfont = "MsgFont";

our $Xpos = -1;
our $Ypos = -1;

sub init {
  if ($Xpos < 0 && $Ypos < 0) {
    my($rx,$ry) = (Tkx::winfo_rootx($MW), Tkx::winfo_rooty($MW));
    my($wx,$wy) = (Tkx::winfo_reqwidth($MW), Tkx::winfo_reqheight($MW));
    ($Xpos,$Ypos) = (Tkx::winfo_pointerx($MW), Tkx::winfo_pointery($MW));
    $Xpos = $rx if ($Xpos < $rx || $Xpos > ($rx + $wx));
    $Ypos = $ry if ($Ypos < $ry || $Ypos > ($ry + $wy));
  } else {
    $Xpos += 11;
    $Ypos += 6;
  }
  my $pop = CP::Pop->new(0, '.mg', ' ', $Xpos, $Ypos);
  if ($pop ne '') {
    if ($Init == 0) {
      #
      # Create all images on first call.
      #
      my %list = (Tkx::SplitList(Tkx::font_actual("TkHeadingFont")));
      $list{'-size'} = 12;
      $list{'-weight'} = 'bold';
      Tkx::font_create($Mfont, %list);
      $Smilies[SMILE] = makeImage("smile", \%XPM);
      $Smilies[QUIZ]  = makeImage("quiz", \%XPM);
      $Smilies[SAD]   = makeImage("sad", \%XPM);
      $Smilies[QUEST] = makeImage("quest", \%XPM);
      $Init = 1;
    }
    $pop->{frame}->m_configure(qw/-style Pop.TFrame/);
    $Xpos = $Ypos = -1;
  }
  $pop;
}

sub position {
  $Xpos = shift;
  $Ypos = shift;
}

sub message {
  my($img,$txt,$delay) = @_;

  if (defined $MW && Tkx::winfo_exists($MW)) {
    my $done = '';
    return if ((my $pop = init()) eq '');
    my($top,$msgf) = ($pop->{top}, $pop->{frame});
    my $pic = $msgf->new_ttk__label(-image => $Smilies[$img], -style => 'Pop.TLabel');
    $pic->g_grid(qw/-row 0 -column 0 -padx 10 -pady 5/);
    my $lab = $msgf->new_ttk__label(
      -text => "$txt",
      -style => 'Pop.TLabel',
      -anchor => 'w',
      -font => $Mfont);
    $lab->g_grid(qw/-row 0 -column 1 -padx 10 -pady 5/);

    if (defined $delay) {
      $top->g_wm_overrideredirect(1);
      topUp($pop);
      if ($delay > 0) {
	sleep($delay);
      } elsif ($delay < 0) {
	foreach my $n (0..5) {
	  $lab->m_configure(-foreground => ($n & 1) ? 'darkred' : 'red');
	  Tkx::update();
	  Tkx::after(300);
	}
      }
      topDown($pop, '', \$done);
    } else {
      my $fb = $msgf->new_ttk__button(
	-text => "  Continue  ",
	-command => sub{topDown($pop, 'done', \$done);});
      $fb->g_grid(qw/-row 1 -columnspan 2 -padx 10 -pady 5/);
      $fb->g_focus();
      topUp($pop,\$done);
    }
  } else {
    errorPrint "$txt";
  }
  return('');
}

# Essentially duplicates messageBox Yes/No but allows us
# to colour it consistently and position it sensibly
sub msgYesNo {
  my($txt,$yes,$no) = @_;

  my $done = '';
  if (defined $MW && Tkx::winfo_exists($MW)) {
    return('No') if ((my $pop = init()) eq '');
    my($top,$msgf) = ($pop->{top}, $pop->{frame});

    my $tf = $msgf->new_ttk__frame(
      -relief => 'raised',
      -style => 'Pop.TFrame',
      -padding => [4,4,4,4]);
    $tf->g_grid(qw/-row 0 -column 0 -sticky nsew/);

    my $a = $tf->new_ttk__label(
      -image => $Smilies[QUEST],
      -style => 'Pop.TLabel');
    my $b = $tf->new_ttk__label(
      -text => "$txt",
      -font => $Mfont,
      -style => 'Pop.TLabel');

    $a->g_grid(qw/-row 0 -column 0 -padx 10 -pady 5/);
    $b->g_grid(qw/-row 0 -column 1 -padx 10 -pady 5/);

    my $bfr = $msgf->new_ttk__frame(-style => 'Pop.TFrame', -padding => [4,4,4,4]);
    $bfr->g_grid(qw/-row 1 -column 0 -sticky we/);

    $a = $bfr->new_ttk__button(-text => (defined $yes) ? $yes : ' Yes ',
			       -command => sub{topDown($pop,'Yes',\$done);});
    $b = $bfr->new_ttk__button(-text => (defined $no) ? $no : ' No ',
			       -command => sub{topDown($pop,'No',\$done);});

    $a->g_pack(qw/-side right -padx 30/);
    $b->g_pack(qw/-side left -padx 30/);

    $a->g_focus();
    topUp($pop,\$done);
  } else {
    errorPrint($txt);
    $done = (defined $no) ? $no : 'No';
  }
  $done;
}

sub msgYesNoCan {
  my($txt,$yes,$no) = @_;

  my $done = '';
  if (defined $MW && Tkx::winfo_exists($MW)) {
    return('Cancel') if ((my $pop = init()) eq '');
    my($top,$msgf) = ($pop->{top}, $pop->{frame});

    my $tf = $msgf->new_ttk__frame(-relief => 'raised', -style => 'Pop.TFrame', -padding => [4,4,4,4]);
    $tf->g_grid(qw/-row 0 -column 0 -sticky nsew/);

    my $a = $tf->new_ttk__label(-image => $Smilies[QUEST], -style => 'Pop.TLabel');
    my $b = $tf->new_ttk__label(
      -text => "$txt",
      -font => $Mfont,
      -style => 'Pop.TLabel');

    $a->g_grid(qw/-row 0 -column 0 -padx 10 -pady 5/);
    $b->g_grid(qw/-row 0 -column 1 -padx 10 -pady 5/);

    my $bfr = $msgf->new_ttk__frame(-style => 'Pop.TFrame', -padding => [4,4,4,4]);
    $bfr->g_grid(qw/-row 1 -column 0 -sticky we/);
    $a = $bfr->new_ttk__button(-text => " Cancel ",
			       -command => sub{topDown($pop,'Cancel',\$done);});
    $b = $bfr->new_ttk__button(-text => (defined $no) ? $no : ' No ',
			       -command => sub{topDown($pop,'No',\$done);});
    my $c = $bfr->new_ttk__button(-text => (defined $yes) ? $yes : ' Yes ',
				  -command => sub{topDown($pop,'Yes',\$done);});

    $a->g_pack(qw/-side left -padx 30/);
    $c->g_pack(qw/-side right -padx 30/);
    $b->g_pack(qw/-side right/);

    $c->g_focus();
    topUp($pop,\$done);
  } else {
    errorPrint($txt);
    $done = 'Cancel';
  }
  $done;
}

# Another variant with a checkbox
sub msgYesNoAll {
  my($txt) = @_;

  my $done = "";
  if (defined $MW && Tkx::winfo_exists($MW)) {
    return('No') if ((my $pop = init()) eq '');
    my($top,$msgf) = ($pop->{top}, $pop->{frame});

    my $tf = $msgf->new_ttk__frame(-relief => 'raised', -style => 'Pop.TFrame', -padding => [4,4,4,4]);
    $tf->g_grid(qw/-row 0 -column 0 -sticky nsew/);

    my $a = $tf->new_ttk__label(-image => $Smilies[QUEST], -style => 'Pop.TLabel');
    my $b = $tf->new_ttk__label(
      -text => "$txt",
      -font => $Mfont,
      -style => 'Pop.TLabel');

    $a->g_grid(qw/-row 0 -column 0 -padx 10 -pady 5/);
    $b->g_grid(qw/-row 0 -column 1 -padx 10 -pady 5/);

    my $bfr = $msgf->new_ttk__frame(-style => 'Pop.TFrame', -padding => [4,4,4,4]);
    $bfr->g_grid(qw/-row 1 -column 0 -sticky we/);
    my $chk = 0;
    my $c = $bfr->new_ttk__button(-text => ' Yes ', -command => sub{topDown($pop,'Yes',\$done);});
    my $d = $bfr->new_ttk__checkbutton(
      -text => "Apply to all",
      -variable => \$chk,
      -style => 'Pop.TCheckbutton');
    my $e = $bfr->new_ttk__button(-text => ' No ',  -command => sub{topDown($pop,'No',\$done);});

    $c->g_pack(qw/-side right/, -padx => [30,10]);
    $d->g_pack(qw/-side right/);
    $e->g_pack(qw/-side left/, -padx => [0,30]);

    $c->g_focus();
    topUp($pop,\$done);
    $done = "All" if ($done eq "Yes" && $chk == 1);
  } else {
    errorPrint($txt);
    $done = 'No';
  }
  $done;
}

#
# Similar to msgYesNo but asks for a file name.
#
sub msgSet {
  my($txt,$var) = @_;

  my $done = "";
  if (defined $MW && Tkx::winfo_exists($MW)) {
    return('Cancel') if ((my $pop = init()) eq '');
    my($top,$msgf) = ($pop->{top}, $pop->{frame});

    my $tf = $msgf->new_ttk__frame(-relief => 'raised', -style => 'Pop.TFrame', -padding => [4,4,4,4]);
    $tf->g_grid(qw/-row 0 -column 0 -sticky nsew/);

    my $a = $tf->new_ttk__label(-image => $Smilies[QUEST], -style => 'Pop.TLabel');
    my $b = $tf->new_ttk__label(
      -text => "$txt",
      -font => $Mfont,
      -style => 'Pop.TLabel');
    my $ent = $tf->new_ttk__entry(
      -width => 35,
      -textvariable => $var,
      -takefocus => 1);

    $a->g_grid(qw/-row 0 -column 0 -padx 10 -pady 5 -rowspan 2/);
    $b->g_grid(qw/-row 0 -column 1 -padx 10 -pady 5/);
    $ent->g_grid(qw/-row 1 -column 1 -padx 10 -ipady 1/);

    my $bfr = $msgf->new_ttk__frame(-style => 'Pop.TFrame', -padding => [4,4,4,4]);
    $bfr->g_grid(qw/-row 1 -column 0 -sticky we/);

    $a = $bfr->new_ttk__button(-text => ' Cancel ', -command => sub{topDown($pop,'Cancel',\$done);});
    $b = $bfr->new_ttk__button(-text => ' OK ', -command => sub{topDown($pop,'OK',\$done);});

    $a->g_pack(qw/-side left -padx 30/);
    $b->g_pack(qw/-side right -padx 30/);

    $ent->g_focus();
    topUp($pop,\$done);
  } else {
    errorPrint($txt);
    $done = 'Cancel';
  }
  $done;
}

sub topUp {
  my($pop,$var) = @_;

  Tkx::update();
  $pop->{top}->g_raise();
  if (defined $var) {
    Tkx::vwait($var);
    $pop->destroy();
  }
}

sub topDown {
  my($pop,$val,$var) = @_;

  $pop->destroy();
  $$var = $val;
}

1;
