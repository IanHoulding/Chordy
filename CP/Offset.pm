package CP::Offset;

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

# These are fixed distances and are common to all Bars:
#   header        space above the top Staff line
#   height        total y distance allocated to a Bar
#   interval      distance from one Note to the next
#   scale         1 for the page view, 3 - 5 for edit view
#   staffHeight   distance between the top and bottom Staff lines
#   staffSpace    distance between each Staff Line
#   width         total x distance allocated to a Bar
#
#   staffX        Always 0
#   staffY        Offset to the top Staff line
#   staff0        Offset to the bottom Staff line (staffY + staffHeight)
#   pos0          x offset of the first Note (interval * 2)

sub new {
  my($proto,$sz) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;
  update($self, $sz);
  return($self);
}

sub update {
  my($self,$sz) = @_;

  foreach my $v (keys %{$sz}) {
    $self->{$v} = $sz->{$v};
  }
}

1;
