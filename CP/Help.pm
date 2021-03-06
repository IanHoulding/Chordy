package CP::Help;

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

use CP::Cconst qw/:COLOUR/;
use CP::Global qw/:FUNC :OPT :WIN :MEDIA :XPM/;
use Tkx;

sub new {
  my($proto,$title) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;

  $self->{mark} = {};
  my $pop = CP::Pop->new(0, '.hp', $title, -1, -1);
  return('') if ($pop eq '');
  my($win,$tf) = ($pop->{top}, $pop->{frame});

  $self->{win} = $win;
  $win->g_wm_protocol('WM_DELETE_WINDOW' => sub{$pop->popDestroy()} );

  my $textf = $tf->new_ttk__frame();
  $textf->g_pack(qw/-side top -expand 1 -fill both/);

  my $sz = 13;
  $self->{text} = $textf->new_tk__text(
    -font => "Times $sz normal",
    -bg => 'white',
    -wrap => 'word',
    -borderwidth => 2,
    -width => 80,
    -height => 45,
    -padx => 4,
    -undo => 0);
  $self->{text}->g_pack(qw/-side left -expand 1 -fill both/);

  my $scv = $textf->new_ttk__scrollbar(-orient => "vertical", -command => [$self->{text}, "yview"]);
  $scv->g_pack(qw/-side left -expand 1 -fill y/);
  $self->{text}->m_configure(-yscrollcommand => [$scv, 'set']);

  my $bf = $tf->new_ttk__frame();
  $bf->g_pack(qw/-side bottom -fill x/);

  my $bc = $bf->new_ttk__button(-text => "Close", -command => sub{$pop->popDestroy()});
  $bc->g_pack(qw/-side left -padx 30 -pady 4/);

  my $bt = $bf->new_ttk__button(-text => " Top ", -command => sub{$self->{text}->see("1.0")});
  $bt->g_pack(qw/-side right -padx 30 -pady 4/);

  my $textWin = $self->{text};
  # The following 3 tags control indenting. Indents stay in effect
  # until explicitly ended with an <E> tag OR a Heading tag.
  $textWin->tag_configure('M', -lmargin1 => 20,
			       -lmargin2 => 10);
  $textWin->tag_configure('E', -lmargin1 => 0,
			       -lmargin2 => 0);

  # Headings
  $textWin->tag_configure('H', -font => "Times ".($sz+5)." bold",
			       -justify => 'center',
			       -foreground => HFG,
			       -background => SELECT);
  $textWin->tag_configure('h', -font => "Times ".($sz+4)." bold",
			       -foreground => HFG,
			       -background => SELECT);
  # Sub Headings
  $textWin->tag_configure('S', -font => "Arial ".($sz+1)." bold",
			       -lmargin1 => 0,
			       -spacing3 => 4,
			       -underline => 1,
			       -foreground => BLACK); #HFG);
  $textWin->tag_configure('N', -font => "Arial ".($sz-1)." bold",
			       -lmargin1 => 0,
			       -spacing1 => 3,
			       -spacing3 => 2,
			       -underline => 0,
			       -foreground => BLACK);
  $textWin->tag_configure('s', -font => "Arial ".($sz-1)." bold",
			       -lmargin1 => 0,
			       -foreground => HFG);
  # Text Push Buttons
  $textWin->tag_configure('P', -font => "Arial ".($sz-2)." bold",
			       -lmargin1 => 0,
			       -foreground => $Opt->{PushFG},
			       -background => $Opt->{PushBG},
			       -relief => 'raised',
			       -borderwidth => 2,
			       -spacing1 => 3,
			       -spacing3 => 2);
  # Fixed width Tags
  $textWin->tag_configure('C', -font => "Courier ".$sz." bold");
  $textWin->tag_configure('c', -font => "Courier ".($sz-2)." bold");
  $textWin->tag_configure('U', -font => "Courier ".($sz-3)." bold",
			       -offset => int($sz/3));
  # Link
  $textWin->tag_configure('K', -font => "Times $sz bold",
			       -foreground => HFG);
  # Bold Italic
  $textWin->tag_configure('I', -font => "Times $sz bold italic");
  # Bold
  $textWin->tag_configure('B', -font => "Times $sz bold");
  # Bold - Red
  $textWin->tag_configure('R', -font => "Times $sz bold",
			       -foreground => RFG);
  # Coloured Backgrounds
  $textWin->tag_configure('Y', -font => "Times $sz bold italic",
			       -background => "$Opt->{BGHighlight}");
  $textWin->tag_configure('L', -font => "Times $sz normal",
			       -background => "$Opt->{BGComment}");
  $textWin->tag_configure('F', -font => "Times $sz normal",
			       -background => "#FF00FF");

  # Images ie Push Buttons
  $textWin->tag_configure('Im', -background => $Opt->{PushBG},
			        -relief => 'solid',
			        -borderwidth => 1,
			        -spacing1 => 0,
			        -spacing3 => 0);
  # Horizontal line: <l height width #colour>
#  $textWin->tag_configure('l', -font => "Times 1 normal",
#			       -background => BLACK);

  # Vertical Spacing
  foreach my $sz (1..10) {
    $textWin->tag_configure("V$sz",  -font => "Times $sz normal");
  }
  $self->{text}->configure(-state => 'disabled');
  $self;
}

sub show {
  my($self) = shift;

  $self->{win}->g_wm_deiconify();
  $self->{win}->g_raise();
  Tkx::update();
}

sub add  {
  my($self, $help) = @_;

  $self->{text}->configure(-state => 'normal');
  my $textWin = $self->{text};
  my $tagidx = 1;
  my $indent = 'E';
  foreach (@{$help}) {
    my @txt = split('', $_);
    my $text = '';
    while (@txt) {
      my $c = shift(@txt);
      if ($c eq '<') {
	my $tag = shift(@txt);
	$c = shift(@txt);
	if ($c eq '>') { # Indent Tag
	  $indent = $tag;
	} elsif ($c eq ' ' || $c =~ /\d/) {
	  my $tagged = ($c =~ /\d/) ? $c : '';
	  while (@txt && ($c = shift(@txt)) ne '>') { $tagged .= $c; }
	  if ($text ne '') {
	    $textWin->insert('end', $text, [$indent]);
	    $text = '';
	  }
	  if ($tag eq 'O') { # TOC
	    #    +-------tagged-------+
	    # <O TO:H:Table Of Contents>
	    my($tname,$htag,$hdg) = split(':', $tagged, 3);
	    $hdg =~ s/\{\{\{/<<</g;
	    $hdg =~ s/\}\}\}/>>>/g;
	    my $toc = "TOC$tname";
	    $textWin->tag_configure($toc);
	    if ($tname ne 'TO') {
	      $textWin->tag_bind($toc, "<ButtonRelease-1>",
				 sub {
				   $textWin->yview($self->{mark}{$tname});
				   $textWin->yview_scroll(-2, 'units');
				 });
	    }
	    # Setup Bindings to change cursor when over that line
	    $textWin->tag_bind($toc, "<Enter>", sub { $textWin->configure(-cursor => 'hand2') });
	    $textWin->tag_bind($toc, "<Leave>", sub { $textWin->configure(-cursor => 'xterm') });
	    $indent = 'E' if ($htag =~ /H|S|s|P/);
	    if ($htag eq 'H') {
	      $textWin->insert('end', "$hdg\n", [$htag, $toc]);
	    } else {
	      $textWin->insert('end', "$hdg", [$htag, $toc]);
	      $textWin->insert('end', "\n", '') if ($htag =~ /h|S|s|P/);
	    }
	    $textWin->mark_set("TopM", $textWin->index('current')) if ($tname eq "TO");
	  } elsif ($tag eq 'T') { # TAG
	    my $ln = $textWin->index('current');
	    $textWin->mark_set($tagged, $ln);
	    $ln =~ s/\.\d+//;
	    $self->{mark}{$tagged} = $ln - 2;
	  } elsif ($tag eq 'X') { # IMAGE
	    $textWin->insert('end', " ", '');
	    my $pos = $textWin->index('current');
	    makeImage($tagged, \%XPM);
	    $textWin->image_create($pos, -image => $tagged, qw/-align center -padx 2 -pady 2/);
	    $textWin->tag_add('Im', $pos, $textWin->index('current')) if ($tagged !~ /checkbox/);
	  } elsif ($tag eq 'x') { # IMAGE with no decoration
	    my $pos = $textWin->index('current');
	    makeImage($tagged, \%XPM);
	    $textWin->image_create($pos, -image => $tagged, qw/-align center/);
	  } elsif ($tag eq 'V') { # Line Space
	    if ($tagged =~ /([^#]+)(#[\dA-Fa-f]{6})?/) {
	      $tag .= $1;
	      if (defined $2) {
		my $clr = $2;
		(my $sz = $tag) =~ s/V//;
		$tag .= $tagidx++;
		$textWin->tag_configure($tag, -font => "Times $sz normal", -background => $clr);
	      }
	    }
	    $textWin->insert('end', "\n", [$tag]);
	  } elsif ($tag eq 'l') { # Line
	    my($h,$w,$clr) = ($tagged =~ /(\d+)*\s*(\d+)*\s*(#......)*/);
	    $h = 1 if (!defined $h);
	    $w = 250 if (!defined $w);
	    $clr = BLACK if (!defined $clr);
	    Tkx::ttk__style_configure('L.TFrame', -background => $clr);
	    my $fr = $textWin->new_ttk__frame(-width => $w,
					      -height => $h,
					      -style => 'L.TFrame'); 
	    $textWin->window_create('end', -align => 'center', -window => $fr);
	    $textWin->insert('end', "\n");
	  } else {
	    $tagged =~ s/\{\{\{/<<</g;
	    $tagged =~ s/\}\}\}/>>>/g;
	    $textWin->insert('end', $tagged, [$tag,$indent]);
	  }
	} else {
	  $textWin->insert('end', "<$tag$c", [$indent]);
	}
      } else {
	$text .= $c;
      }
    }
    $textWin->insert('end', "$text\n", [$indent]) if ($text ne '');
  }
  $self->{text}->configure(-state => 'disabled');
}

1;
