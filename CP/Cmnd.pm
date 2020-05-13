package CP::Cmnd;

# This file is part of Chordy.
#
###############################################################################
# Copyright (c) 2018 Ian Houlding
# All rights reserved.
# This program is free software.
# You can redistribute it and/or modify it under the same terms as Perl itself.
###############################################################################

use strict;

use CP::Cconst qw/:OS :PATH/;
use CP::Global qw/:FUNC :OPT/;

sub new {
  my($proto) = @_;
  my $class = ref($proto) || $proto;

  my $self = {};
  bless $self, $class;
  default($self);

  if (-e "$Path->{Command}") {
    load($self);
  } else {
    save($self);
  }
  errorPrint("  No PDF viewer found\n") if ($self->{Acro} eq '');

  return($self);
}

sub default {
  my($self) = shift;

  if (OS eq 'aqua') {
    $self->{Print} = "lp -s -o media=a4";
    chomp($self->{Mail});
    $self->{Acro} = "open -a Preview";
    $self->{Mail} = "osascript";
  } elsif (OS eq 'x11') {
    $self->{Print} = "lp -s -o media=a4";
    open WH, "-|", 'which', 'acroread';
    chomp($self->{Acro} = <WH>);
    close WH;
    open WH, "-|", 'which', 'sendmail';
    chomp($self->{Mail} = <WH>);
    close WH;
  } elsif (OS eq "win32") {
    my $PROG = PROG;
    $self->{Mail} = "\"$PROG/sendEmail.exe\"" if (-e "$PROG/sendEmail.exe");
    $self->{Acro} = $self->{Print} = "";
    if (-e "$PROG/SumatraPDF.exe") {
      $self->{Print} = "\"$PROG/SumatraPDF.exe\" -print-to-default";
      $self->{Acro} = "\"$PROG/SumatraPDF.exe\"";
    }
  }
}

sub load {
  my($self) = shift;

  if (-e "$Path->{Command}") {
    our %opts;
    do "$Path->{Command}";
    #
    # Now merge the file options into our hash.
    #
    foreach my $o (keys %opts) {
      $self->{$o} = $opts{$o} if ($opts{$o} ne '');
    }
    undef %opts;
  }
}

sub save {
  my($self) = shift;

  my $OFH = openConfig("$Path->{Command}");
  return(0) if ($OFH == 0);

  print $OFH "\%opts = (\n";

  foreach my $k (keys %{$self}) {
    (my $cmnd = $self->{$k}) =~ s/\"/\\"/g;
    print $OFH "  $k => \"$cmnd\",\n";
  }

  printf $OFH ");\n1;\n";

  close($OFH);
}

1;
