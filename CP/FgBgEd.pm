package CP::FgBgEd;

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

use POSIX;

use CP::Global qw/:FUNC :OPT :WIN :XPM/;
use CP::Cconst qw/:COLOUR :SMILIE/;
use CP::Pop qw/:POP/;
use CP::Cmsg;
use CP::List;
use CP::Swatch;
use Tkx;

our(@LclSwtch,%Names,%Hexs,%Colour);

sub new {
  my($proto) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};

  my $pop = CP::Pop->new(0, '.ce', 'Colour Editor', -1, -1);
  return if ($pop eq '');
  my($FBE,$fr) = ($pop->{top}, $pop->{frame});

  makeImage("colour", \%XPM);
  $FBE->g_wm_protocol('WM_DELETE_WINDOW', sub{$pop->destroy();$self->{'done'} = 'Cancel';});
  $FBE->g_wm_withdraw();

  foreach my $c (keys %Colour) {
    if ($c =~ /^[A-Z]/) {
      $Names{"$c"} = $Colour{$c};
      $Hexs{"$Colour{$c}"} = $c;
    }
  }
  my $top = $fr->new_ttk__frame(-relief => 'raised', -padding => [4,4,4,4]);
  $top->g_pack(qw/-side top -expand 1 -fill both/);

  my $bot = $fr->new_ttk__frame(-padding => [4,8,4,8]);
  $bot->g_pack(qw/-side bottom -fill x/);

  my $hl = $fr->new_ttk__separator(-orient => 'horizontal');
  $hl->g_pack(qw/-side bottom -expand 1 -fill x/);
  
  my %mid_pack = (qw/-side left -padx 8 -pady 8 -fill y/);

  my $left = $top->new_ttk__frame();
  $left->g_pack(%mid_pack);

  my $middle = $top->new_ttk__frame();
  $middle->g_pack(%mid_pack);

  my $right = $top->new_ttk__frame();
  $right->g_pack(%mid_pack);

  my $names = CP::List->new(
    $left, 'e',
    -width           => 20,
    -height          => 20,
    -relief          => 'sunken',
    -borderwidth     => 2,
    -exportselection => 0);
  $names->bind('<<ListboxSelect>>' => sub {lbcolor($self,$names)});
  $names->{frame}->g_pack(qw/-side left -fill y/);

  foreach (sort {lc($a) cmp lc($b)} keys %Names) {
    $names->add2a($_);
  }

  # Create the three scales for editing the color,
  # and the entry for typing in a color value.

  my(@mid);
  $mid[0] = $middle->new_ttk__frame();
  $mid[0]->g_pack(qw/-pady 0.25c/);

  $self->{scale} = []; # an array of hashes
  my @RGB = (qw/Red Green Blue/);
  my $row = 0;
  foreach my $i (0..2) {
    my $sc = $self->{scale}[$i] = {};

    $sc->{sca} = $mid[0]->new_ttk__scale(
      -from    => 0,
      -to      => 255,
      -length  => '8c',
      -orient  => 'horizontal',
      -style   => "$RGB[$i].Horizontal.TScale",
      -command => sub{scale_changed($self,$i)});
    $sc->{sca}->g_grid(qw/-column 0 -columnspan 3 -sticky w/, -row => $row++);

    my $l = $mid[0]->new_ttk__label(-text => "$RGB[$i]:");
    $l->g_grid(qw/-column 0 -sticky e/, -row => $row, -padx => [0,4], -pady => [0,4]);

    $sc->{val} = $mid[0]->new_ttk__label(qw/-width 3 -anchor e/);
    $sc->{val}->g_grid(qw/-column 1 -sticky w/, -row => $row++, -pady => [0,4]);
  }

  $mid[1] = $middle->new_ttk__frame();
  $mid[1]->g_pack(qw/-fill x/, -pady => [0,8]);

  my $nameLabel = $mid[1]->new_ttk__label(-text => 'Name: ');
  $nameLabel->g_pack(qw/-side left -expand 0/);

  $self->{Entry} = '';
  my $name = $mid[1]->new_ttk__entry(
    -textvariable => \$self->{Entry},
    -width => 25,
    -font => 'Courier 11 bold');
  $name->g_pack(qw/-side left/);
  $name->g_bind('<Return>' => sub{color($self,$self->{Entry})});
  $name->g_bind('<Tab>' => sub{color($self,$self->{Entry})});

  $mid[2] = $middle->new_ttk__frame();
  $mid[2]->g_pack();

  my($r,$c) = (0,0);
  foreach my $chc (qw/verse chorus bridge tab highlight comment/) { 
    my $uc = ucfirst($chc);
    my $b = $mid[2]->new_ttk__button(
      -text => $uc,
      -style => "$uc.BG.TButton",
      -command => sub {color($self, $Media->{"${chc}BG"})});
    $b->g_grid(-row => $r, -column => $c++, -padx => 4, -pady => [2,4]);
    if ($chc eq 'tab') {
      $r++;
      $c = 1;
    }
  }

  # Personal Colour Swatches

  $mid[3] = $middle->new_ttk__labelframe(
    -borderwidth => 2,
    -relief => 'sunken',
    -text => ' My Colours ');
  $mid[3]->g_pack(-pady => [4,0]);

  my $mysw = $mid[3]->new_ttk__frame(-padding => [4,0,4,4]);
  $mysw->g_pack(qw/-pady 4/);

  my $idx = 0;
  $self->{SwIdx} = 0;
  my $stdbd = Tkx::ttk__style_lookup("TButton", "-background");
  foreach my $row (0..1) {
    foreach my $col (0..7) {
      my $i = $idx++;
      Tkx::ttk__style_configure("SW$i.TButton", -relief => 'raised');
      Tkx::ttk__style_configure("SW$i.TButton", -bordercolor => $stdbd);
      my $clr = $mysw->new_ttk__button(
	-image => 'blank',
	-style => "SW$i.TButton",
	-command => sub {setmc($self, $i, $stdbd)});
      $clr->g_grid(-row => $row, -column => $col, -padx => 4, -pady => [($row*4),4]);
    }
  }
  my $sc = $mid[3]->new_ttk__button(-text => "Set Colour", -command => sub{setSwatch($self)});
  $sc->g_pack(-pady => [0,8]);

  # Create the color display swatch on the right side of the window.

  $self->{helpl} = '';
  my $help_label = $right->new_ttk__label(
    -textvariable => \$self->{helpl},
    -font    => 'Times 12 bold',
    -justify => 'center');
  $help_label->g_pack(qw/-side top/);

  $self->{help} = '';
  my $help = $right->new_ttk__label(
    -textvariable => \$self->{help},
    -font       => 'Times 12',
    -justify    => 'center',
    -wraplength => '2.5i');
  $help->g_pack(qw/-side top/);

  Tkx::ttk__style_configure('Sw.TLabel',
			    -selectborderwidth  => 0, -borderwidth => 1,
			    -highlightthickness => 0, -bordercolor => BLACK,
			    -relief     => 'ridge',   -padding     => [20,10,20,10],
			    -foreground => BLACK, -background  => WHITE);

  my $swatch = $right->new_ttk__label(
    -text    => BLACK,
    -font    => 'Courier 18 bold',
    -justify => 'center',
    -style   => 'Sw.TLabel');
  $swatch->g_pack(qw/-side top -pady 4/);
  $self->{swatch} = $swatch;

  $self->{fgbg} = '-foreground';

  my $fg = $right->new_ttk__radiobutton(
    -text => 'Set Foreground colour',
    -variable => \$self->{fgbg},
    -value => '-foreground',
    -command => sub{color($self,Tkx::ttk__style_lookup('Sw.TLabel', -foreground));});
  $fg->g_pack(qw/-side top/);

  my $bg = $right->new_ttk__radiobutton(
    -text => 'Set Background colour',
    -variable => \$self->{fgbg},
    -value => '-background',
    -command => sub{color($self,Tkx::ttk__style_lookup('Sw.TLabel', -background));});
  $bg->g_pack(qw/-side top/);

  my $lt = $right->new_ttk__button(
    -text => "Lighten",
    -command => sub {
      my($clr) = Tkx::ttk__style_lookup('Sw.TLabel', $self->{fgbg});
      color($self, lighten($clr));
    });
  $lt->g_pack(qw/-side top -pady 8/);

  my $dk = $right->new_ttk__button(
    -text => "Darken",
    -command => sub {
      my $clr = Tkx::ttk__style_lookup('Sw.TLabel', $self->{fgbg});
      color($self, darken($clr));
    });
  $dk->g_pack(qw/-side top -pady 8/);

  my $ok = $bot->new_ttk__button(-text => ' OK ', -command => sub{$self->{'done'} = 'OK'});
  $ok->g_pack(qw/-side right -padx 40/);

  my $cancel = $bot->new_ttk__button(-text => 'Cancel', -command => sub{$self->{'done'} = 'Cancel'});
  $cancel->g_pack(qw/-side left -padx 40/);

  $self->{toplevel} = $FBE;
  $self->{name} = $name;
  $self->{Red} = 0;
  $self->{Green} = 0;
  $self->{Blue} = 0;
  $self->{updating} = 0;
  $self->{pending} = 0;

  bless $self, $class;
  return($self);
}

sub title {
  my($self,$title) = @_;

  $self->{toplevel}->g_wm_title($title);
}

sub setmc {
  my($self,$idx,$bdclr) = @_;

  Tkx::ttk__style_configure("SW$self->{SwIdx}.TButton", -relief => 'raised');
  Tkx::ttk__style_configure("SW$self->{SwIdx}.TButton", -bordercolor => $bdclr);
  color($self, $LclSwtch[$idx]);
  Tkx::ttk__style_configure("SW$idx.TButton", -relief => 'solid');
  Tkx::ttk__style_configure("SW$idx.TButton", -bordercolor => DGREY);
  $self->{SwIdx} = $idx;
}

sub setSwatch {
  my($self) = shift;

  my $colour = $self->{Entry};
  if ($colour !~ /^#/) {
    $colour = (defined $Names{$colour}) ? $Names{$colour} : '';
  }
  if ($colour ne '') {
    my $idx = $self->{SwIdx};
    $LclSwtch[$idx] = $colour;
    Tkx::ttk__style_configure("SW$idx.TButton", -background => $colour);
  }
}

sub lighten {
  my($clr,$pcnt) = @_;

  if ($clr =~ /^#(..)(..)(..)/) {
    my @rgb = (hex($1),hex($2),hex($3),);
    $pcnt = 3 if (! defined $pcnt);
    foreach my $c (0..2) {
      $rgb[$c] += POSIX::ceil((256 - $rgb[$c]) * $pcnt / 100);
      $rgb[$c] = 255 if ($rgb[$c] > 255);
    }
    $clr = sprintf("#%02x%02x%02x", $rgb[0], $rgb[1], $rgb[2]);
  }
  $clr;
}

sub darken {
  my($clr,$pcnt) = @_;

  if ($clr =~ /^#(..)(..)(..)/) {
    my @rgb = (hex($1),hex($2),hex($3),);
    $pcnt = 3 if (! defined $pcnt);
    foreach my $c (0..2) {
      $rgb[$c] -= POSIX::ceil((256 - $rgb[$c]) * $pcnt / 100);
      $rgb[$c] = 0 if ($rgb[$c] < 0);
    }
    $clr = sprintf("#%02x%02x%02x", $rgb[0], $rgb[1], $rgb[2]);
  }
  $clr;
}

sub Hex
{
  my $w = shift;
  my @rgb = (@_ == 3) ? @_ : $w->rgb(@_);
  if (@_ != 3) {
    foreach (0..2) { $rgb[$_] >>= 8; }
  }
  sprintf('#%02x%02x%02x',@rgb)
}

sub fgcolor {
  my ($self,$name) = @_;

  if (defined $name) {
    if ($name ne '') {
      my $tmp = $self->{fgbg};
      $self->{fgbg} = '-foreground';
      color($self, $name);
      $self->{fgbg} = $tmp;
    }
  }
}

sub bgcolor {
  my ($self,$name) = @_;

  if (defined $name) {
    if ($name ne '') {
      my $tmp = $self->{fgbg};
      $self->{fgbg} = '-background';
      color($self, $name);
      $self->{fgbg} = $tmp;
    }
  }
}

sub lbcolor {
  my($self,$names) = @_;
  if (scalar keys(%Names) > 0) {
    my $i = $names->curselection(0);
    color($self, $names->get($i));
    $names->focus();
  }
}

# Given a colour:
#   set the individual component colours
#   adjust the scales to their correct position
#   set the fore/back-ground colours in the swatch.
#
sub color {
  my($self,$colour) = @_;

  if (@_ > 1 && defined($colour) && length($colour)) {
    if ($colour eq 'cancel') {
      $self->{'color'} = undef;
    } else {
      my $hex;
      if ($colour !~ /^#/) {
	$hex = (defined $Names{$colour}) ? $Names{$colour} : '';
      } else {
	$hex = $colour;
	$colour = $Hexs{$hex} if (defined $Hexs{$hex})
      }
      if ($hex =~ /#(..)(..)(..)/) {
	$self->{'Red'} = hex($1);
	$self->{'Green'} = hex($2);
	$self->{'Blue'} = hex($3);
	$self->{'color'} = $hex;
	$self->{'Entry'} = $colour;
	Tkx::after_idle(sub{set_scales($self)}) unless ($self->{pending}++);
	Tkx::ttk__style_configure('Sw.TLabel', $self->{fgbg} => $hex);
	$self->{swatch}->m_configure(-text => $hex);
      } else {
	message(SAD, "Colour Editor:\n   syntax error in color name \"$colour\"");
      }
    }
  }
}

# The procedure below is invoked when one of the scales is adjusted.
# It propagates color information from the current scale readings to
# everywhere else that it is used.
#
sub scale_changed {
  my($self,$idx) = @_;

  return if $self->{updating};

  my($red,$green,$blue,$hex);

  my $sc = $self->{scale}[0];
  $red = int($sc->{sca}->m_get);
  $hex = sprintf('#%02x0000', $red);
  Tkx::ttk__style_configure("Red.Horizontal.TScale", -troughcolor => $hex);

  $sc = $self->{scale}[1];
  $green = int($sc->{sca}->m_get);
  $hex = sprintf('#00%02x00', $green);
  Tkx::ttk__style_configure("Green.Horizontal.TScale", -troughcolor => $hex);

  $sc = $self->{scale}[2];
  $blue = int($sc->{sca}->m_get);
  $hex = sprintf('#0000%02x', $blue);
  Tkx::ttk__style_configure("Blue.Horizontal.TScale", -troughcolor => $hex);

  $self->{Red} = $red;
  $self->{Green} = $green;
  $self->{Blue} = $blue;

  color($self, sprintf('#%02x%02x%02x', $red, $green, $blue));
  Tkx::update_idletasks();
}

# The procedure below is invoked to update the scales from the current red,
# green, and blue intensities.  It's invoked after a named color value has
# been loaded.
#
sub set_scales {
  my($self) = shift;

  $self->{pending} = 0;
  $self->{updating} = 1;

  my @clr = (qw/Red Green Blue/);
  foreach my $i (0..2) {
    my $sc = $self->{scale}[$i];
    my $v = int($self->{$clr[$i]});
    $sc->{sca}->m_set($v);
    scale_colour($self, $i, $v);
    $sc->{val}->m_configure(-text => $v);
  }

  $self->{updating} = 0;
}

sub scale_colour {
  my($self,$idx,$val) = @_;

  my @clr = (qw/Red Green Blue/);
  my @fmt = ('#%02x0000', '#00%02x00', '#0000%02x');
  my $sc = $self->{scale}[$idx];
  my $hex = sprintf($fmt[$idx], $val);
  Tkx::ttk__style_configure("$clr[$idx].Horizontal.TScale", -troughcolor => $hex);
}

my $nofgbghelp = "You can manipulate the %s colour to help determine the %s to use but it will not be used when you click on 'OK'.";

sub Show {
  my($self,$fg,$bg,$op) = @_;

  @LclSwtch = @{$Swatches};
  my $stdbd = Tkx::ttk__style_lookup("TButton", "-background");
  foreach my $i (0..15) {
    Tkx::ttk__style_configure("SW$i.TButton",
			      -background => $LclSwtch[$i],
			      -relief => 'raised',
			      -bordercolor => $stdbd);
  }
  $self->{'SwIdx'} = -1;
  bgcolor($self, ($bg eq '') ? WHITE : $bg);
  fgcolor($self, ($fg eq '') ? BLACK : $fg);
  my($label,$txt);
  if ($op & FOREGRND) {
    if ($op & BACKGRND) {
      $label = "ForeGround & BackGround mode.";
      $txt = "Make any adjustments to both the foreground and background colours and then click on OK.";
    } else {
      $label = "ForeGround only mode.";
      $txt = sprintf("$nofgbghelp", "background", "foreground");
    }
    $self->{fgbg} = '-foreground';
  } elsif ($op & BACKGRND) {
    $label = "BackGround only mode.";
    $txt = sprintf("$nofgbghelp", "foreground", "background");
    bgcolor($self, Tkx::ttk__style_lookup('Sw.TLabel', -background));
    $self->{fgbg} = '-background';
  } else {
    $label = "Something appears to be wrong!";
    $txt = "Neither the ForeGround nor the BackGround have been selected.";
  }
  $self->{helpl} = $label;
  $self->{help} = $txt;

  $self->{toplevel}->g_wm_deiconify();
  $self->{toplevel}->g_raise();
  Tkx::update();

  Tkx::vwait(\$self->{'done'});

  if ($self->{'done'} eq 'OK') {
    $fg  = Tkx::ttk__style_lookup('Sw.TLabel', -foreground);
    $bg  = Tkx::ttk__style_lookup('Sw.TLabel', -background);
    $Swatches->set(@LclSwtch);
    $Swatches->save();
  } else {
    $fg = $bg = '';
  }
  $self->{toplevel}->g_wm_withdraw();
  return($fg,$bg);
}

%Colour = (
  'Air Force blue'	=> '#5D8AA8',
  'Alice blue'		=> '#F0F8FF',
  'Alizarin'		=> '#E32636',
  'Almond'		=> '#EFDECD',
  'Amaranth'		=> '#E52B50',
  'Amber'		=> '#FFBF00',
  'American rose'	=> '#FF033E',
  'Amethyst'		=> '#9966CC',
  'Anti-flash white'	=> '#F2F3F4',
  'Antique brass'	=> '#CD9575',
  'Antique fuchsia'	=> '#915C83',
  'Antique white'	=> '#FAEBD7',
  'Ao'			=> '#008000',
  'Apple green'		=> '#8DB600',
  'Apricot'		=> '#FBCEB1',
  'Aqua'		=> '#00FFFF',
  'Aquamarine'		=> '#7FFFD0',
  'Army green'		=> '#4B5320',
  'Arsenic'		=> '#3B444B',
  'Arylide yellow'	=> '#E9D66B',
  'Ash grey'		=> '#B2BEB5',
  'Asparagus'		=> '#87A96B',
  'Atomic tangerine'	=> '#FF9966',
  'Auburn'		=> '#6D351A',
  'Aureolin'		=> '#FDEE00',
  'AuroMetalSaurus'	=> '#6E7F80',
  'Awesome'		=> '#FF2052',
  'Azure'		=> '#007FFF',
  'Azure mist'		=> '#F0FFFF',
  'Baby blue'		=> '#89CFF0',
  'Baby blue eyes'	=> '#A1CAF1',
  'Baby pink'		=> '#F4C2C2',
  'Ball Blue'		=> '#21ABCD',
  'Banana Mania'	=> '#FAE7B5',
  'Banana Yellow'	=> '#FFE135',
  'Battleship grey'	=> '#848482',
  'Bazaar'		=> '#98777B',
  'Beau blue'		=> '#BCD4E6',
  'Beaver'		=> '#9F8170',
  'Beige'		=> '#F5F5DC',
  'Bisque'		=> '#FFE4C4',
  'Bistre'		=> '#3D2B1F',
  'Bittersweet'		=> '#FE6F5E',
  'Black'		=> '#000000',
  'Blanched Almond'	=> '#FFEBCD',
  'Bleu de France'	=> '#318CE7',
  'Blizzard Blue'	=> '#ACE5EE',
  'Blond'		=> '#FAF0BE',
  'Blue'		=> '#0000FF',
  'Blue Munsell'	=> '#0093AF',
  'Blue NCS'		=> '#0087BD',
  'Blue pigment'	=> '#333399',
  'Blue RYB'		=> '#0247FE',
  'Blue Bell'		=> '#A2A2D0',
  'Blue Gray'		=> '#6699CC',
  'Blue-green'		=> '#00DDDD',
  'Blue-violet'		=> '#8A2BE2',
  'Blush'		=> '#DE5D83',
  'Bole'		=> '#79443B',
  'Bondi blue'		=> '#0095B6',
  'Boston Uni Red'	=> '#CC0000',
  'Brandeis blue'	=> '#0070FF',
  'Brass'		=> '#B5A642',
  'Brick red'		=> '#CB4154',
  'Bright cerulean'	=> '#1DACD6',
  'Bright green'	=> '#66FF00',
  'Bright lavender'	=> '#BF94E4',
  'Bright maroon'	=> '#C32148',
  'Bright pink'		=> '#FF007F',
  'Bright turquoise'	=> '#08E8DE',
  'Bright ube'		=> '#D19FE8',
  'Brilliant lavender'	=> '#F4BBFF',
  'Brilliant rose'	=> '#FF55A3',
  'Brink pink'		=> '#FB607F',
  'British racing green'=> '#004225',
  'Bronze'		=> '#CD7F32',
  'Brown'		=> '#964B00',
  'Brown web'		=> '#A52A2A',
  'Bubble gum'		=> '#FFC1CC',
  'Bubbles'		=> '#E7FEFF',
  'Buff'		=> '#F0DC82',
  'Bulgarian rose'	=> '#480607',
  'Burgundy'		=> '#800020',
  'Burlywood'		=> '#DEB887',
  'Burnt orange'	=> '#CC5500',
  'Burnt sienna'	=> '#E97451',
  'Burnt umber'		=> '#8A3324',
  'Byzantine'		=> '#BD33A4',
  'Byzantium'		=> '#702963',
  'Cadet'		=> '#536872',
  'Cadet blue'		=> '#5F9EA0',
  'Cadet grey'		=> '#91A3B0',
  'Cadmium Green'	=> '#006B3C',
  'Cadmium Orange'	=> '#ED872D',
  'Cadmium Red'		=> '#E30022',
  'Cadmium Yellow'	=> '#FFF600',
  'Cambridge Blue'	=> '#A3C1AD',
  'Camel'		=> '#C19A6B',
  'Camouflage green'	=> '#78866B',
  'Canary yellow'	=> '#FFEF00',
  'Candy apple red'	=> '#FF0800',
  'Candy pink'		=> '#E4717A',
  'Capri'		=> '#00BFFF',
  'Caput mortuum'	=> '#592720',
  'Cardinal'		=> '#C41E3A',
  'Caribbean green'	=> '#00CC99',
  'Carmine'		=> '#960018',
  'Carmine pink'	=> '#EB4C42',
  'Carmine red'		=> '#FF0038',
  'Carnation pink'	=> '#FFA6C9',
  'Carnelian'		=> '#B31B1B',
  'Carolina blue'	=> '#99BADD',
  'Carrot orange'	=> '#ED9121',
  'Ceil'		=> '#92A1CF',
  'Celadon'		=> '#ACE1AF',
  'Celestial blue'	=> '#4997D0',
  'Cerise'		=> '#DE3163',
  'Cerise pink'		=> '#EC3B83',
  'Cerulean'		=> '#007BA7',
  'Cerulean blue'	=> '#2A52BE',
  'Chamoisee'		=> '#A0785A',
  'Champagne'		=> '#F7E7CE',
  'Charcoal'		=> '#36454F',
  'Chartreuse'		=> '#DFFF00',
  'Chartreuse web'	=> '#7FFF00',
  'Cherry blossom pink'	=> '#FFB7C5',
  'Chestnut'		=> '#CD5C5C',
  'Chocolate'		=> '#7B3F00',
  'Chocolate web'	=> '#D2691E',
  'Chrome yellow'	=> '#FFA700',
  'Cinereous'		=> '#98817B',
  'Cinnabar'		=> '#E34234',
  'Cinnamon'		=> '#D2691E',
  'Citrine'		=> '#E4D00A',
  'Classic rose'	=> '#FBCCE7',
  'Cobalt'		=> '#0047AB',
  'Cocoa brown'		=> '#D2691E',
  'Columbia blue'	=> '#9BDDFF',
  'Cool black'		=> '#002E63',
  'Cool grey'		=> '#8C92AC',
  'Copper'		=> '#B87333',
  'Copper rose'		=> '#996666',
  'Coquelicot'		=> '#FF3800',
  'Coral'		=> '#FF7F50',
  'Coral pink'		=> '#F88379',
  'Coral red'		=> '#FF4040',
  'Cordovan'		=> '#893F45',
  'Corn'		=> '#FBEC5D',
  'Cornell Red'		=> '#B31B1B',
  'Cornflower blue'	=> '#6495ED',
  'Cornsilk'		=> '#FFF8DC',
  'Cosmic latte'	=> '#FFF8E7',
  'Cotton candy'	=> '#FFBCD9',
  'Cream'		=> '#FFFDD0',
  'Crimson'		=> '#DC143C',
  'Crimson glory'	=> '#BE0032',
  'Cyan'		=> '#00FFFF',
  'Daffodil'		=> '#FFFF31',
  'Dandelion'		=> '#F0E130',
  'Dark blue'		=> '#00008B',
  'Dark brown'		=> '#654321',
  'Dark byzantium'	=> '#5D3954',
  'Dark candy apple red'=> '#A40000',
  'Dark cerulean'	=> '#08457E',
  'Dark champagne'	=> '#C2B280',
  'Dark chestnut'	=> '#986960',
  'Dark coral'		=> '#CD5B45',
  'Dark cyan'		=> '#008B8B',
  'Dark electric blue'	=> '#536878',
  'Dark goldenrod'	=> '#B8860B',
  'Dark gray'		=> '#A9A9A9',
  'Dark green'		=> '#013220',
  'Dark jungle green'	=> '#1A2421',
  'Dark khaki'		=> '#BDB76B',
  'Dark lava'		=> '#483C32',
  'Dark lavender'	=> '#734F96',
  'Dark magenta'	=> '#8B008B',
  'Dark midnight blue'	=> '#003366',
  'Dark olive green'	=> '#556B2F',
  'Dark orange'		=> '#FF8C00',
  'Dark orchid'		=> '#9932CC',
  'Dark pastel blue'	=> '#779ECB',
  'Dark pastel green'	=> '#03C03C',
  'Dark pastel purple'	=> '#966FD6',
  'Dark pastel red'	=> '#C23B22',
  'Dark pink'		=> '#E75480',
  'Dark powder blue'	=> '#003399',
  'Dark raspberry'	=> '#872657',
  'Dark red'		=> '#8B0000',
  'Dark salmon'		=> '#E9967A',
  'Dark scarlet'	=> '#560319',
  'Dark sea green'	=> '#8FBC8F',
  'Dark sienna'		=> '#3C1414',
  'Dark slate blue'	=> '#483D8B',
  'Dark slate gray'	=> '#2F4F4F',
  'Dark spring green'	=> '#177245',
  'Dark tan'		=> '#918151',
  'Dark tangerine'	=> '#FFA812',
  'Dark taupe'		=> '#483C32',
  'Dark terra cotta'	=> '#CC4E5C',
  'Dark turquoise'	=> '#00CED1',
  'Dark violet'		=> '#9400D3',
  'Dartmouth green'	=> '#00693E',
  "Davy's grey"		=> '#555555',
  'Debian red'		=> '#D70A53',
  'Deep carmine'	=> '#A9203E',
  'Deep carmine pink'	=> '#EF3038',
  'Deep carrot orange'	=> '#E9692C',
  'Deep cerise'		=> '#DA3287',
  'Deep champagne'	=> '#FAD6A5',
  'Deep chestnut'	=> '#B94E48',
  'Deep fuchsia'	=> '#C154C1',
  'Deep jungle green'	=> '#004B49',
  'Deep lilac'		=> '#9955BB',
  'Deep magenta'	=> '#CC00CC',
  'Deep peach'		=> '#FFCBA4',
  'Deep pink'		=> '#FF1493',
  'Deep saffron'	=> '#FF9933',
  'Deep sky blue'	=> '#00BFFF',
  'Denim'		=> '#1560BD',
  'Desert'		=> '#C19A6B',
  'Desert sand'		=> '#EDC9AF',
  'Dim gray'		=> '#696969',
  'Dodger blue'		=> '#1E90FF',
  'Dogwood rose'	=> '#D71868',
  'Dollar bill'		=> '#85BB65',
  'Drab'		=> '#967117',
  'Duke blue'		=> '#00009C',
  'Earth yellow'	=> '#E1A95F',
  'Ecru'		=> '#C2B280',
  'Eggplant'		=> '#614051',
  'Eggshell'		=> '#F0EAD6',
  'Egyptian blue'	=> '#1034A6',
  'Electric blue'	=> '#7DF9FF',
  'Electric crimson'	=> '#FF003F',
  'Electric cyan'	=> '#00FFFF',
  'Electric green'	=> '#00FF00',
  'Electric indigo'	=> '#6F00FF',
  'Electric lavender'	=> '#F4BBFF',
  'Electric lime'	=> '#CCFF00',
  'Electric purple'	=> '#BF00FF',
  'Electric ultramarine'=> '#3F00FF',
  'Electric violet'	=> '#8F00FF',
  'Electric Yellow'	=> '#FFFF00',
  'Emerald'		=> '#50C878',
  'Eton blue'		=> '#96C8A2',
  'Fallow'		=> '#C19A6B',
  'Falu red'		=> '#801818',
  'Fandango'		=> '#B53389',
  'Fashion fuchsia'	=> '#F400A1',
  'Fawn'		=> '#E5AA70',
  'Feldgrau'		=> '#4D5D53',
  'Fern green'		=> '#4F7942',
  'Ferrari Red'		=> '#FF2800',
  'Field drab'		=> '#6C541E',
  'Firebrick'		=> '#B22222',
  'Fire engine red'	=> '#CE2029',
  'Flame'		=> '#E25822',
  'Flamingo pink'	=> '#FC8EAC',
  'Flavescent'		=> '#F7E98E',
  'Flax'		=> '#EEDC82',
  'Floral white'	=> '#FFFAF0',
  'Fluorescent orange'	=> '#FFBF00',
  'Fluorescent pink'	=> '#FF1493',
  'Fluorescent yellow'	=> '#CCFF00',
  'Folly'		=> '#FF004F',
  'Forest green'	=> '#014421',
  'Forest green web'	=> '#228B22',
  'French beige'	=> '#A67B5B',
  'French blue'		=> '#0072BB',
  'French lilac'	=> '#86608E',
  'French rose'		=> '#F64A8A',
  'Fuchsia'		=> '#FF00FF',
  'Fuchsia pink'	=> '#FF77FF',
  'Fulvous'		=> '#E48400',
  'Fuzzy Wuzzy'		=> '#CC6666',
  'Gainsboro'		=> '#DCDCDC',
  'Gamboge'		=> '#E49B0F',
  'Ghost white'		=> '#F8F8FF',
  'Ginger'		=> '#B06500',
  'Glaucous'		=> '#6082B6',
  'Gold metallic'	=> '#D4AF37',
  'Gold web'		=> '#FFD700',
  'Golden brown'	=> '#996515',
  'Golden poppy'	=> '#FCC200',
  'Golden yellow'	=> '#FFDF00',
  'Goldenrod'		=> '#DAA520',
  'Granny Smith Apple'	=> '#A8E4A0',
  'Gray'		=> '#808080',
  'Gray HTML'		=> '#7F7F7F',
  'Gray X11'		=> '#BEBEBE',
  'Gray-asparagus'	=> '#465945',
  'Green X11'		=> '#00FF00',
  'Green HTML'		=> '#008000',
  'Green Munsell'	=> '#00A877',
  'Green NCS'		=> '#009F6B',
  'Green pigment'	=> '#00A550',
  'Green RYB'		=> '#66B032',
  'Green-yellow'	=> '#ADFF2F',
  'Grullo'		=> '#A99A86',
  'Guppie green'	=> '#00FF7F',
  'Halaya ube'		=> '#663854',
  'Han blue'		=> '#446CCF',
  'Han purple'		=> '#5218FA',
  'Hansa yellow'	=> '#E9D66B',
  'Harlequin'		=> '#3FFF00',
  'Harvard crimson'	=> '#C90016',
  'Harvest Gold'	=> '#DA9100',
  'Heart Gold'		=> '#808000',
  'Heliotrope'		=> '#DF73FF',
  'Hollywood cerise'	=> '#F400A1',
  'Honeydew'		=> '#F0FFF0',
  "Hooker's green"	=> '#007000',
  'Hot magenta'		=> '#FF1DCE',
  'Hot pink'		=> '#FF69B4',
  'Hunter green'	=> '#355E3B',
  'Iceberg'		=> '#71A6D2',
  'Icterine'		=> '#FCF75E',
  'Inchworm'		=> '#B2EC5D',
  'India green'		=> '#138808',
  'Indian red'		=> '#CD5C5C',
  'Indian yellow'	=> '#E3A857',
  'Indigo dye'		=> '#00416A',
  'Indigo web'		=> '#4B0082',
  'Internat Klein Blue'	=> '#002FA7',
  'Internat orange'	=> '#FF4F00',
  'Iris'		=> '#5A4FCF',
  'Isabelline'		=> '#F4F0EC',
  'Islamic green'	=> '#009000',
  'Ivory'		=> '#FFFFF0',
  'Jade'		=> '#00A86B',
  'Jasper'		=> '#D73B3E',
  'Jazzberry jam'	=> '#A50B5E',
  'Jonquil'		=> '#FADA5E',
  'June bud'		=> '#BDDA57',
  'Jungle green'	=> '#29AB87',
  'Kelly green'		=> '#4CBB17',
  'Khaki'		=> '#C3B091',
  'Light khaki'		=> '#F0E68C',
  'La Salle Green'	=> '#087830',
  'Languid lavender'	=> '#D6CADD',
  'Lapis lazuli'	=> '#26619C',
  'Laser Lemon'		=> '#FEFE22',
  'Lava'		=> '#CF1020',
  'Lavender floral'	=> '#B57EDC',
  'Lavender web'	=> '#E6E6FA',
  'Lavender blue'	=> '#CCCCFF',
  'Lavender blush'	=> '#FFF0F5',
  'Lavender gray'	=> '#C4C3D0',
  'Lavender indigo'	=> '#9457EB',
  'Lavender magenta'	=> '#EE82EE',
  'Lavender mist'	=> '#E6E6FA',
  'Lavender pink'	=> '#FBAED2',
  'Lavender purple'	=> '#967BB6',
  'Lavender rose'	=> '#FBA0E3',
  'Lawn green'		=> '#7CFC00',
  'Lemon'		=> '#FFF700',
  'Lemon chiffon'	=> '#FFFACD',
  'Light apricot'	=> '#FDD5B1',
  'Light blue'		=> '#ADD8E6',
  'Light brown'		=> '#B5651D',
  'Light carmine pink'	=> '#E66771',
  'Light coral'		=> '#F08080',
  'Light cornflower blue'	=> '#93CCEA',
  'Light cyan'		=> '#E0FFFF',
  'Light fuchsia pink'	=> '#F984EF',
  'Light goldenrod yellow'	=> '#FAFAD2',
  'Light gray'		=> '#D3D3D3',
  'Light green'		=> '#90EE90',
  'Light khaki'		=> '#F0E68C',
  'Light mauve'		=> '#DCD0FF',
  'Light pastel purple'	=> '#B19CD9',
  'Light pink'		=> '#FFB6C1',
  'Light salmon'	=> '#FFA07A',
  'Light salmon pink'	=> '#FF9999',
  'Light sea green'	=> '#20B2AA',
  'Light sky blue'	=> '#87CEEB',
  'Light slate gray'	=> '#778899',
  'Light taupe'		=> '#B38B6D',
  'Light Thulian pink'	=> '#E68FAC',
  'Light yellow'	=> '#FFFFED',
  'Lilac'		=> '#C8A2C8',
  'Lime'		=> '#BFFF00',
  'Lime web'		=> '#00FF00',
  'Lime green'		=> '#32CD32',
  'Lincoln green'	=> '#195905',
  'Linen'		=> '#FAF0E6',
  'Liver'		=> '#534B4F',
  'Lust'		=> '#E62020',
  'Macaroni and Cheese'	=> '#FFBD88',
  'Magenta'		=> '#FF00FF',
  'Magenta dye'		=> '#CA1F7B',
  'Magenta'		=> '#FF0090',
  'Magic mint'		=> '#AAF0D1',
  'Magnolia'		=> '#F8F4FF',
  'Mahogany'		=> '#C04000',
  'Maize'		=> '#FBEC5D',
  'Majorelle Blue'	=> '#6050DC',
  'Malachite'		=> '#0BDA51',
  'Manatee'		=> '#979AAA',
  'Mango Tango'		=> '#FF8243',
  'Maroon HTML'		=> '#800000',
  'Maroon X11'		=> '#B03060',
  'Mauve'		=> '#E0B0FF',
  'Mauve taupe'		=> '#915F6D',
  'Mauvelous'		=> '#EF98AA',
  'Maya blue'		=> '#73C2FB',
  'Meat brown'		=> '#E5B73B',
  'Medium aquamarine'	=> '#66DDAA',
  'Medium blue'		=> '#0000CD',
  'Medium candy apple red'	=> '#E2062C',
  'Medium carmine'	=> '#AF4035',
  'Medium champagne'	=> '#F3E5AB',
  'Medium electric blue'=> '#035096',
  'Medium jungle green'	=> '#1C352D',
  'Medium lavender magenta'	=> '#DDA0DD',
  'Medium orchid'	=> '#BA55D3',
  'Medium Persian blue'	=> '#0067A5',
  'Medium purple'	=> '#9370DB',
  'Medium red-violet'	=> '#BB3385',
  'Medium sea green'	=> '#3CB371',
  'Medium slate blue'	=> '#7B68EE',
  'Medium spring bud'	=> '#C9DC87',
  'Medium spring green'	=> '#00FA9A',
  'Medium taupe'	=> '#674C47',
  'Medium teal blue'	=> '#0054B4',
  'Medium turquoise'	=> '#48D1CC',
  'Medium violet-red'	=> '#C71585',
  'Melon'		=> '#FDBCB4',
  'Midnight blue'	=> '#191970',
  'Midnight green'	=> '#004953',
  'Mikado yellow'	=> '#FFC40C',
  'Mint'		=> '#3EB489',
  'Mint cream'		=> '#F5FFFA',
  'Mint green'		=> '#98FF98',
  'Misty rose'		=> '#FFE4E1',
  'Moccasin'		=> '#FAEBD7',
  'Mode beige'		=> '#967117',
  'Moonstone blue'	=> '#73A9C2',
  'Mordant red'		=> '#AE0C00',
  'Moss green'		=> '#ADDFAD',
  'Mountain Meadow'	=> '#30BA8F',
  'Mountbatten pink'	=> '#997A8D',
  'Mulberry'		=> '#C54B8C',
  'Mustard'		=> '#FFDB58',
  'Myrtle'		=> '#21421E',
  'MSU Green'		=> '#18453B',
  'Nadeshiko pink'	=> '#F6ADC6',
  'Napier green'	=> '#2A8000',
  'Naples yellow'	=> '#FADA5E',
  'Navajo white'	=> '#FFDEAD',
  'Navy blue'		=> '#000080',
  'Neon Carrot'		=> '#FFA343',
  'Neon fuchsia'	=> '#FE59C2',
  'Neon green'		=> '#39FF14',
  'Non-photo blue'	=> '#A4DDED',
  'Ocean Boat Blue'	=> '#0077BE',
  'Ochre'		=> '#CC7722',
  'Office green'	=> '#008000',
  'Old gold'		=> '#CFB53B',
  'Old lace'		=> '#FDF5E6',
  'Old lavender'	=> '#796878',
  'Old mauve'		=> '#673147',
  'Old rose'		=> '#C08081',
  'Olive'		=> '#808000',
  'Olive Drab web'	=> '#6B8E23',
  'Olive Drab'		=> '#3C341F',
  'Olivine'		=> '#9AB973',
  'Onyx'		=> '#0F0F0F',
  'Opera mauve'		=> '#B784A7',
  'Orange'		=> '#FF7F00',
  'Orange RYB'		=> '#FB9902',
  'Orange web'		=> '#FFA500',
  'Orange peel'		=> '#FF9F00',
  'Orange-red'		=> '#FF4500',
  'Orchid'		=> '#DA70D6',
  'Otter brown'		=> '#654321',
  'Outer Space'		=> '#414A4C',
  'Outrageous Orange'	=> '#FF6E4A',
  'Oxford Blue'		=> '#002147',
  'OU Crimson Red'	=> '#990000',
  'Pakistan green'	=> '#006600',
  'Palatinate blue'	=> '#273BE2',
  'Palatinate purple'	=> '#682860',
  'Pale aqua'		=> '#BCD4E6',
  'Pale blue'		=> '#AFEEEE',
  'Pale brown'		=> '#987654',
  'Pale carmine'	=> '#AF4035',
  'Pale cerulean'	=> '#9BC4E2',
  'Pale chestnut'	=> '#DDADAF',
  'Pale copper'		=> '#DA8A67',
  'Pale cornflower blue'=> '#ABCDEF',
  'Pale gold'		=> '#E6BE8A',
  'Pale goldenrod'	=> '#EEE8AA',
  'Pale green'		=> '#98FB98',
  'Pale magenta'	=> '#F984E5',
  'Pale pink'		=> '#FADADD',
  'Pale plum'		=> '#DDA0DD',
  'Pale red-violet'	=> '#DB7093',
  'Pale robin egg blue'	=> '#96DED1',
  'Pale silver'		=> '#C9C0BB',
  'Pale spring bud'	=> '#ECEBBD',
  'Pale taupe'		=> '#BC987E',
  'Pale violet-red'	=> '#DB7093',
  'Pansy purple'	=> '#78184A',
  'Papaya whip'		=> '#FFEFD5',
  'Paris Green'		=> '#50C878',
  'Pastel blue'		=> '#AEC6CF',
  'Pastel brown'	=> '#836953',
  'Pastel gray'		=> '#CFCFC4',
  'Pastel green'	=> '#77DD77',
  'Pastel magenta'	=> '#F49AC2',
  'Pastel orange'	=> '#FFB347',
  'Pastel pink'		=> '#FFD1DC',
  'Pastel purple'	=> '#B39EB5',
  'Pastel red'		=> '#FF6961',
  'Pastel violet'	=> '#CB99C9',
  'Pastel yellow'	=> '#FDFD96',
  'Patriarch'		=> '#800080',
  "Payne's grey"	=> '#40404F',
  'Peach'		=> '#FFE5B4',
  'Peach-orange'	=> '#FFCC99',
  'Peach puff'		=> '#FFDAB9',
  'Peach-yellow'	=> '#FADFAD',
  'Pear'		=> '#D1E231',
  'Pearl'		=> '#F0EAD6',
  'Peridot'		=> '#E6E200',
  'Periwinkle'		=> '#CCCCFF',
  'Persian blue'	=> '#1C39BB',
  'Persian green'	=> '#00A693',
  'Persian indigo'	=> '#32127A',
  'Persian orange'	=> '#D99058',
  'Peru'		=> '#CD853F',
  'Persian pink'	=> '#F77FBE',
  'Persian plum'	=> '#701C1C',
  'Persian red'		=> '#CC3333',
  'Persian rose'	=> '#FE28A2',
  'Persimmon'		=> '#EC5800',
  'Phlox'		=> '#DF00FF',
  'Phthalo blue'	=> '#000F89',
  'Phthalo green'	=> '#123524',
  'Piggy pink'		=> '#FDDDE6',
  'Pine green'		=> '#01796F',
  'Pink'		=> '#FFC0CB',
  'Pink-orange'		=> '#FF9966',
  'Pink pearl'		=> '#E7ACCF',
  'Pink Sherbet'	=> '#F78FA7',
  'Pistachio'		=> '#93C572',
  'Platinum'		=> '#E5E4E2',
  'Plum'		=> '#8E4585',
  'Plum web'		=> '#DDA0DD',
  'Pomona green'	=> '#1E4D2B',
  'Portland Orange'	=> '#FF5A36',
  'Powder blue'		=> '#B0E0E6',
  'Princeton orange'	=> '#FF8F00',
  'Prune'		=> '#701C1C',
  'Prussian blue'	=> '#003153',
  'Psychedelic purple'	=> '#DF00FF',
  'Puce'		=> '#CC8899',
  'Pumpkin'		=> '#FF7518',
  'Purple HTML'		=> '#800080',
  'Purple Munsell'	=> '#9F00C5',
  'Purple X11'		=> '#A020F0',
  'Purple Heart'	=> '#69359C',
  'Purple mountain majesty'	=> '#9678B6',
  'Purple pizzazz'	=> '#FE4EDA',
  'Purple taupe'	=> '#50404D',
  'Radical Red'		=> '#FF355E',
  'Raspberry'		=> '#E30B5D',
  'Raspberry glace'	=> '#915F6D',
  'Raspberry pink'	=> '#E25098',
  'Raspberry rose'	=> '#B3446C',
  'Raw umber'		=> '#826644',
  'Razzle dazzle rose'	=> '#FF33CC',
  'Razzmatazz'		=> '#E3256B',
  'Red'			=> '#FF0000',
  'Red Munsell'		=> '#F2003C',
  'Red NCS'		=> '#C40233',
  'Red pigment'		=> '#ED1C24',
  'Red RYB'		=> '#FE2712',
  'Red-brown'		=> '#A52A2A',
  'Red-violet'		=> '#C71585',
  'Redwood'		=> '#AB4E52',
  'Regalia'		=> '#522D80',
  'Rich black'		=> '#004040',
  'Rich brilliant lavender'	=> '#F1A7FE',
  'Rich carmine'	=> '#D70040',
  'Rich electric blue'	=> '#0892D0',
  'Rich lavender'	=> '#A76BCF',
  'Rich lilac'		=> '#B666D2',
  'Rich maroon'		=> '#B03060',
  'Rifle green'		=> '#414833',
  'Robin egg blue'	=> '#00CCCC',
  'Rose'		=> '#FF007F',
  'Rose bonbon'		=> '#F9429E',
  'Rose ebony'		=> '#674846',
  'Rose gold'		=> '#B76E79',
  'Rose madder'		=> '#E32636',
  'Rose pink'		=> '#FF66CC',
  'Rose quartz'		=> '#AA98A9',
  'Rose taupe'		=> '#905D5D',
  'Rose vale'		=> '#AB4E52',
  'Rosewood'		=> '#65000B',
  'Rosso corsa'		=> '#D40000',
  'Rosy brown'		=> '#BC8F8F',
  'Royal azure'		=> '#0038A8',
  'Royal blue'		=> '#002366',
  'Royal blue web'	=> '#4169E1',
  'Royal fuchsia'	=> '#CA2C92',
  'Royal purple'	=> '#7851A9',
  'Ruby'		=> '#E0115F',
  'Ruddy'		=> '#FF0028',
  'Ruddy brown'		=> '#BB6528',
  'Ruddy pink'		=> '#E18E96',
  'Rufous'		=> '#A81C07',
  'Russet'		=> '#80461B',
  'Rust'		=> '#B7410E',
  'Sacramento State green'	=> '#00563F',
  'Saddle brown'	=> '#8B4513',
  'Safety orange'	=> '#FF6700',
  'Saffron'		=> '#F4C430',
  "St. Patrick's blue"	=> '#23297A',
  'Salmon'		=> '#FF8C69',
  'Salmon pink'		=> '#FF91A4',
  'Sand'		=> '#C2B280',
  'Sand dune'		=> '#967117',
  'Sandstorm'		=> '#ECD540',
  'Sandy brown'		=> '#F4A460',
  'Sandy taupe'		=> '#967117',
  'Sangria'		=> '#92000A',
  'Sap green'		=> '#507D2A',
  'Sapphire'		=> '#082567',
  'Satin sheen gold'	=> '#CBA135',
  'Scarlet'		=> '#FF2000',
  'School bus yellow'	=> '#FFD800',
  'Screamin green'	=> '#76FF7A',
  'Sea green'		=> '#2E8B57',
  'Seal brown'		=> '#321414',
  'Seashell'		=> '#FFF5EE',
  'Selective yellow'	=> '#FFBA00',
  'Sepia'		=> '#704214',
  'Shadow'		=> '#8A795D',
  'Shamrock green'	=> '#009E60',
  'Shocking pink'	=> '#FC0FC0',
  'Sienna'		=> '#882D17',
  'Silver'		=> '#C0C0C0',
  'Sinopia'		=> '#CB410B',
  'Skobeloff'		=> '#007474',
  'Sky blue'		=> '#87CEEB',
  'Sky magenta'		=> '#CF71AF',
  'Slate blue'		=> '#6A5ACD',
  'Slate gray'		=> '#708090',
  'Smalt'		=> '#003399',
  'Smokey topaz'	=> '#933D41',
  'Smoky black'		=> '#100C08',
  'Snow'		=> '#FFFAFA',
  'Spiro Disco Ball'	=> '#0FC0FC',
  'Splashed white'	=> '#FEFDFF',
  'Spring bud'		=> '#A7FC00',
  'Spring green'	=> '#00FF7F',
  'Steel blue'		=> '#4682B4',
  'Stil de grain yellow'=> '#FADA5E',
  'Straw'		=> '#E4D96F',
  'Sunglow'		=> '#FFCC33',
  'Sunset'		=> '#FAD6A5',
  'Tan'			=> '#D2B48C',
  'Tangelo'		=> '#F94D00',
  'Tangerine'		=> '#F28500',
  'Tangerine yellow'	=> '#FFCC00',
  'Taupe'		=> '#483C32',
  'Taupe gray'		=> '#8B8589',
  'Tawny'		=> '#CD5700',
  'Tea green'		=> '#D0F0C0',
  'Tea rose (orange)'	=> '#F88379',
  'Tea rose (rose)'	=> '#F4C2C2',
  'Teal'		=> '#008080',
  'Teal blue'		=> '#367588',
  'Teal green'		=> '#006D5B',
  'Terra cotta'		=> '#E2725B',
  'Thistle'		=> '#D8BFD8',
  'Thulian pink'	=> '#DE6FA1',
  'Tickle Me Pink'	=> '#FC89AC',
  'Tiffany Blue'	=> '#0ABAB5',
  "Tiger's eye" 	=> '#E08D3C',
  'Timberwolf'		=> '#DBD7D2',
  'Titanium yellow'	=> '#EEE600',
  'Tomato'		=> '#FF6347',
  'Toolbox'		=> '#746CC0',
  'Tractor red'		=> '#FD0E35',
  'Trolley Grey'	=> '#808080',
  'Tropical rain forest'=> '#00755E',
  'True Blue'		=> '#0073CF',
  'Tufts Blue'		=> '#417DC1',
  'Tumbleweed'		=> '#DEAA88',
  'Turkish rose'	=> '#B57281',
  'Turquoise'		=> '#30D5C8',
  'Turquoise blue'	=> '#00FFEF',
  'Turquoise green'	=> '#A0D6B4',
  'Tuscan red'		=> '#823535',
  'Twilight lavender'	=> '#8A496B',
  'Tyrian purple'	=> '#66023C',
  'UA blue'		=> '#0033AA',
  'UA red'		=> '#D9004C',
  'Ube'			=> '#8878C3',
  'UCLA Blue'		=> '#536895',
  'UCLA Gold'		=> '#FFB300',
  'UFO Green'		=> '#3CD070',
  'Ultramarine'		=> '#120A8F',
  'Ultramarine blue'	=> '#4166F5',
  'Ultra pink'		=> '#FF6FFF',
  'Umber'		=> '#635147',
  'United Nations blue'	=> '#5B92E5',
  'Unmellow Yellow'	=> '#FFFF66',
  'UP Forest green'	=> '#014421',
  'UP Maroon'		=> '#7B1113',
  'Upsdell red'		=> '#AE2029',
  'Urobilin'		=> '#E1AD21',
  'USC Cardinal'	=> '#990000',
  'USC Gold'		=> '#FFCC00',
  'Utah Crimson'	=> '#D3003F',
  'Vanilla'		=> '#F3E5AB',
  'Vegas gold'		=> '#C5B358',
  'Venetian red'	=> '#C80815',
  'Verdigris'		=> '#43B3AE',
  'Vermilion'		=> '#E34234',
  'Veronica'		=> '#A020F0',
  'Violet'		=> '#8F00FF',
  'Violet RYB'		=> '#8601AF',
  'Violet web'		=> '#EE82EE',
  'Viridian'		=> '#40826D',
  'Vivid auburn'	=> '#922724',
  'Vivid burgundy'	=> '#9F1D35',
  'Vivid cerise'	=> '#DA1D81',
  'Vivid tangerine'	=> '#FFA089',
  'Vivid violet'	=> '#9F00FF',
  'Warm black'		=> '#004242',
  'Wenge'		=> '#645452',
  'Wheat'		=> '#F5DEB3',
  'White'		=> '#FFFFFF',
  'White smoke'		=> '#F5F5F5',
  'Wild blue yonder'	=> '#A2ADD0',
  'Wild Strawberry'	=> '#FF43A4',
  'Wild Watermelon'	=> '#FC6C85',
  'Wisteria'		=> '#C9A0DC',
  'Xanadu'		=> '#738678',
  'Yale Blue'		=> '#0F4D92',
  'Yellow'		=> '#FFFF00',
  'Yellow Munsell'	=> '#EFCC00',
  'Yellow NCS'		=> '#FFD300',
  'Yellow process'	=> '#FFEF00',
  'Yellow RYB'		=> '#FEFE33',
  'Yellow-green'	=> '#9ACD32',
  'Zaffre'		=> '#0014A8',
  'Zinnwaldite brown'	=> '#2C1608',
);

1;
