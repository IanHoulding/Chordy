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
use CP::Global qw/:FUNC :OPT :WIN :MEDIA/;
use Tkx;

sub new {
  my($proto,$title) = @_;
  my $class = ref($proto) || $proto;

  my $self = {};
  bless $self, $class;

  $self->{mark} = {};
  my($win,$tf) = popWin(0, $title, Tkx::winfo_rootx($MW) + 10, Tkx::winfo_rooty($MW) + 10);
  $self->{win} = $win;
  $win->g_wm_protocol('WM_DELETE_WINDOW' => sub{$win->g_wm_withdraw()} );

  my $textf = $tf->new_ttk__frame();
  $textf->g_pack(qw/-side top -expand 1 -fill both/);

  $self->{text} = $textf->new_tk__text(
    -font => "Times 13 normal",
    -bg => 'white',
    -wrap => 'word',
    -borderwidth => 2,
    -width => 80,
    -height => 30,
    -undo => 0);
  $self->{text}->g_pack(qw/-side left -expand 1 -fill both/);

  my $scv = $textf->new_ttk__scrollbar(-orient => "vertical", -command => [$self->{text}, "yview"]);
  $scv->g_pack(qw/-side left -expand 1 -fill y/);
  $self->{text}->m_configure(-yscrollcommand => [$scv, 'set']);

  my $bf = $tf->new_ttk__frame();
  $bf->g_pack(qw/-side bottom -fill x/);

  my $bc = $bf->new_ttk__button(-text => "Close", -command => sub{$win->g_wm_withdraw()});
  $bc->g_pack(qw/-side left -padx 30 -pady 4/);

  my $bt = $bf->new_ttk__button(-text => " Top ", -command => sub{$self->{text}->see("1.0")});
  $bt->g_pack(qw/-side right -padx 30 -pady 4/);

  my $textWin = $self->{text};
  my $sz = 13;
  # The following 3 tags control indenting. Indents stay in effect
  # until explicitly ended with an <E> tag OR a Heading tag.
  $textWin->tag_configure('m', -lmargin1 => 24,
			       -lmargin2 => 0);
  $textWin->tag_configure('M', -lmargin1 => 24,
			       -lmargin2 => 24);
  $textWin->tag_configure('E', -lmargin1 => 0,
			       -lmargin2 => 0);

  # Headings
  $textWin->tag_configure('H', -font => "Times ".($sz+5)." bold",
			       -justify => 'center',
			       -foreground => HFG,
			       -background => SELECT);
  # Sub Headings
  $textWin->tag_configure('S', -font => "Arial ".($sz+1)." bold",
			       -lmargin1 => 0,
			       -spacing3 => 4,
			       -underline => 1,
			       -foreground => HFG);
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
  # Bold Italic
  $textWin->tag_configure('I', -font => "Times $sz bold italic");
  # Bold
  $textWin->tag_configure('B', -font => "Times $sz bold");
  # Bold - Red
  $textWin->tag_configure('R', -font => "Times $sz bold",
			       -foreground => RFG);
  # Coloured Backgrounds
  $textWin->tag_configure('Y', -font => "Times $sz bold italic",
			       -background => "$Media->{highlightBG}");
  $textWin->tag_configure('L', -font => "Times $sz normal",
			       -background => "$Media->{commentBG}");
  $textWin->tag_configure('F', -font => "Times $sz normal",
			       -background => "#FF00FF");

  # Images ie Push Buttons
  $textWin->tag_configure('Im', -background => $Opt->{PushBG},
			        -relief => 'solid',
			        -borderwidth => 1,
			        -spacing1 => 0,
			        -spacing3 => 0);
  # Vertical Spacing
  $textWin->tag_configure('V1',  -font => "Times 1 normal");
  $textWin->tag_configure('V5',  -font => "Times 4 normal");
  $textWin->tag_configure('V10', -font => "Times 10 normal");

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
	    #	    $textWin->insert('end', " ", '');
	    if ($htag eq 'H') {
	      $textWin->insert('end', "$hdg\n", [$htag, $toc]);
	    } else {
	      $textWin->insert('end', "$hdg", [$htag, $toc]);
	      $textWin->insert('end', "\n", '');
	    }
	    $textWin->mark_set("TopM", $textWin->index('current')) if ($tname eq "TO");
	  } elsif ($tag eq 'T') { # TAG
	    my $ln = $textWin->index('current');
	    $textWin->mark_set($tagged, $ln);
	    $ln =~ s/\.\d+//;
	    $self->{mark}{$tagged} = $ln;
	  } elsif ($tag eq 'X') { # IMAGE
	    $textWin->insert('end', " ", '');
	    my $pos = $textWin->index('current');
	    $textWin->image_create($pos, -image => $tagged, qw/-align center -padx 2 -pady 2/);
	    $textWin->tag_add('Im', $pos, $textWin->index('current')) if ($tagged !~ /checkbox/);
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
