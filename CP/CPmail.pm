package CP::CPmail;

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
  our @EXPORT = qw(cpmail);
  require Exporter;
}

use Tkx;
use Crypt::RC4;
use MIME::Base64;
use CP::Cconst qw/:OS :SMILIE :COLOUR/;
use CP::Global qw/:FUNC :PATH :WIN :OPT :MEDIA :XPM/;
use CP::Cmsg;
use CP::SendEmail;

sub cpmail {
  my($path,$files) = @_;

  if (OS eq 'aqua' && $Cmnd->{Mail} ne 'osascript') {
    message(SAD, "Sorry, only know how to send Mail using\n  osascript and the Mail.app");
    return(0);
  }

  my $pop = CP::Pop->new(0, '.ma', 'Mailer', -1, -1);
  return if ($pop eq '');
  my($top,$wt) = ($pop->{top}, $pop->{frame});

  my $done;
  my $type = ($files->[0] =~ /.pro$/i) ? 'ChordPro' : 'PDF';
  my $SMTP = {
    to => '',
    tos => {},
    from => '',
    subject => "$type File(s)",
    server => '',
    port => 25,
    security => 'None',
    username => '',
    password => '',
  };
  if (-e "$Path->{SMTP}") {
    our %smtp;
    do "$Path->{SMTP}";
    foreach my $k (keys %smtp) {
      if ($k eq 'tos') {
	foreach my $t (keys %{$smtp{$k}}) {
	  $SMTP->{$k}{$t} = $smtp{$k}{$t};
	}
      } else {
	$SMTP->{$k} = $smtp{$k};
      }
    }
    if ($SMTP->{password} ne '') {
      my $key = get_key();
      my $decoded = decode_base64($SMTP->{password});
      $SMTP->{password} = RC4($key, $decoded);
    }
  }

  if ($SMTP->{server} eq '') {
    if (get_smtp($SMTP) == 0) {
      $pop->popDestroy();
      return(0);
    }
    save_smtp($SMTP);
  }

  if ($SMTP->{server} eq '') {
    message(SAD, "You need a Mail Server to send the mail to!");
    popDestroy($top);
    return(0);
  }

  my $lab = $wt->new_ttk__label(
    -text => "All the files listed below will be mailed as attachments.");
  $lab->g_pack(qw/-side top/);

  my $tf = $wt->new_ttk__frame();
  $tf->g_pack(qw/-side top -anchor nw -pady 8/);

  my $tol = $tf->new_ttk__label(-text => 'To:');
  $tol->g_grid(qw/-row 0 -column 0 -sticky e/, -pady => [0,2]);

  my @tos = ();
  foreach (keys %{$SMTP->{tos}}) {
    $tos[$SMTP->{tos}{$_}] = $_;
  }
  $SMTP->{to} = $tos[0];
  my $toe = $tf->new_ttk__combobox(
    -width => 30,
    -textvariable => \$SMTP->{to},
    -values => \@tos,
      );
  $toe->g_grid(qw/-row 0 -column 1 -sticky w -padx 4/, -pady => [0,2]);

  if ($SMTP->{from} eq '') {
    $SMTP->{from} = $SMTP->{username};
  }
  my $froml = $tf->new_ttk__label(-text => 'From:');
  $froml->g_grid(qw/-row 1 -column 0 -sticky e -pady 2/);

  my $frome = $tf->new_ttk__entry(-textvariable => \$SMTP->{from}, -width => 30);
  $frome->g_grid(qw/-row 1 -column 1 -sticky w -padx 4 -pady 2/);

  my $subjl = $tf->new_ttk__label(-text => 'Subject:');
  $subjl->g_grid(qw/-row 2 -column 0 -sticky e/, -pady => [2,0]);

  my $subje = $tf->new_ttk__entry(-textvariable => \$SMTP->{subject}, -width => 30);
  $subje->g_grid(qw/-row 2 -column 1 -sticky w -padx 4/, -pady => [2,0]);

  ######

  my $lf = $wt->new_ttk__labelframe(-text => ' Message ');
  $lf->g_pack(qw/-side top/);

  my $text = $lf->new_tk__text(
    -font => "\{$EditFont{family}\} $EditFont{size}",
    -bg => 'white',
    -borderwidth => 2,
    -highlightthickness => 1,
    -width => 60,
    -height => 24);
  $text->g_grid(qw/-row 0 -column 0 -sticky nsew/);

  my $scv = $lf->new_ttk__scrollbar(-orient => "vertical", -command => [$text, "yview"]);
  $scv->g_grid(qw/-row 0 -column 1 -sticky nsw/);

  my $sch = $lf->new_ttk__scrollbar(-orient => "horizontal", -command => [$text, "xview"]);
  $sch->g_grid(qw/-row 1 -column 0 -sticky new/);

  $text->configure(-yscrollcommand => [$scv, 'set']);
  $text->configure(-xscrollcommand => [$sch, 'set']);

  my $plrl = (@{$files} > 1) ? "files are" : "file is";
  $text->insert('end', "The following $plrl attached:\n    ".join("\n    ",@{$files}));

  ######

  my $bf = $wt->new_ttk__frame();
  $bf->g_pack(qw/-side top -expand 1 -fill both/, -pady => [4,0]);

  my $bc = $bf->new_ttk__button(-text => "Cancel", -command => sub{$done = "Cancel";});
  $bc->g_grid(qw/-row 0 -column 0 -sticky w -padx 30 -pady 4/);

  my $be = $bf->new_ttk__button(-text => "Edit Mail Server", -command => sub{get_smtp($SMTP)});
  $be->g_grid(qw/-row 0 -column 1 -pady 4/);

  my $bo = $bf->new_ttk__button(-text => "OK", -command => sub{$done = "OK";});
  $bo->g_grid(qw/-row 0 -column 2 -sticky e -padx 30 -pady 4/);

  $bf->g_grid_columnconfigure(1, -weight => 1);

  Tkx::update();
  $top->g_raise();

  Tkx::vwait(\$done);
  my $ret = 0;
  if ($done eq 'OK') {
    if ($SMTP->{to} eq '' || $SMTP->{from} eq '') {
      message(SAD, "You need to supply 'To:' AND 'From:' entries!");
    } else {
      my $body = '';
      my $txt = $text->get('1.0', 'end');
      if ($txt ne '') {
	$body = "$Home/body.txt";
	unless (open OFH, ">$body") {
	  errorPrint("Couldn't create Mail Body file '$body': $!");
	  $SMTP = {};
	  $pop->popDestroy();
	  return($ret);
	}
	print OFH $txt;
	close OFH;
      }
      if (send_mail($SMTP, $body, $path, $files) == 0) {
	message(SMILE, "Mail sent.", 1);
	save_smtp($SMTP);
	$ret++;
      } else {
	message(SAD, "Failed to send mail to:\n'$SMTP->{to}'", 1);
      }
      $SMTP = {};
    }
  }
  $pop->popDestroy();
  $ret;
}

sub get_smtp {
  my($SMTP) = shift;

  my $pop = CP::Pop->new(0, '.ms', 'Mailer', -1, -1);
  return if ($pop eq '');
  my($top,$wt) = ($pop->{top}, $pop->{frame});

  my $done = '';

  my $tf = $wt->new_ttk__frame(qw/-relief raised -borderwidth 2/);
  $tf->g_pack(qw/-side top -expand 1 -fill x/, -pady => [0,2]);

  my $bf = $wt->new_ttk__frame(-padding => [4,4,4,4]);
  $bf->g_pack(qw/-side top -expand 1 -fill x/);

  my $la = $tf->new_ttk__label(
    -text => "All the information required here should be\nobtainable from your email Account settings\nfor the Outgoing mail Server.");
  $la->g_grid(qw/-row 0 -column 0 -columnspan 2 -sticky w -padx 10/, -pady => 4);
###
  my $lb = $tf->new_ttk__label(-text => 'Mail Server:');
  $lb->g_grid(qw/-row 1 -column 0 -sticky e/, -pady => [0,2]);

  my $eb = $tf->new_ttk__entry(
    -width => 30,
    -textvariable => \$SMTP->{server});
  $eb->g_grid(qw/-row 1 -column 1 -sticky w/, -pady => 2);
###
  my $lc = $tf->new_ttk__label(-text => 'Mail Port:');
  $lc->g_grid(qw/-row 2 -column 0 -sticky e/, -pady => 2);

  my $ec = $tf->new_ttk__entry(
    -width => 30,
    -textvariable => \$SMTP->{port});
  $ec->g_grid(qw/-row 2 -column 1 -sticky w/, -pady => 2);
####
  my $ld = $tf->new_ttk__label(-text => 'Security:');
  $ld->g_grid(qw/-row 3 -column 0 -sticky e/, -pady => 2);

  my $swid = $tf->new_ttk__button(
    -textvariable => \$SMTP->{security},
    -width => 10,
    -style => 'Menu.TButton',
    -command => sub{popMenu(\$SMTP->{security}, undef, [qw/None Password TLS STARTTLS/]);
    });
  $swid->g_grid(qw/-row 3 -column 1 -sticky w/, -pady => 2);
####
  my $le = $tf->new_ttk__label(-text => 'User Name:');
  $ld->g_grid(qw/-row 4 -column 0 -sticky e/, -pady => 2);

  my $ed = $tf->new_ttk__entry(
    -width => 30,
    -textvariable => \$SMTP->{username});
  $ed->g_grid(qw/-row 4 -column 1 -sticky w/, -pady => 2);
####
  my $lf = $tf->new_ttk__label(-text => 'Password:');
  $lf->g_grid(qw/-row 5 -column 0 -sticky e/, -pady => [2,4]);

  my $ef = $tf->new_ttk__entry(
    -width => 30,
    -show => '*',
    -textvariable => \$SMTP->{password});
  $ef->g_grid(qw/-row 5 -column 1 -sticky w/, -pady => [2,4]);
####
  my $can = $bf->new_ttk__button(
    -text => "Cancel",
    -style => 'Red.TButton',
    -command => sub{$done = "Cancel";});
  $can->g_pack(qw/-side left -padx 30/);

  my $ok = $bf->new_ttk__button(
    -text => "OK",
    -style => 'Green.TButton',
    -command => sub{$done = "OK";});
  $ok->g_pack(qw/-side right -padx 30/);

  Tkx::vwait(\$done);
  $pop->popDestroy();
  if ($done eq "OK") {
    if ($SMTP->{server} ne '' && $SMTP->{username} ne '') {
      save_smtp($SMTP);
    }
    return(1);
  }
  return(0);
}

sub get_key {
  CORE::state $SN = '';

  return($SN) if ($SN ne '');
  if (OS eq 'win32') {
    Win32::SetChildShowWindow(0) if defined &Win32::SetChildShowWindow;
    my @k = qx(wmic os GET SerialNumber);
    Win32::SetChildShowWindow(1) if defined &Win32::SetChildShowWindow;
    foreach my $sn (@k) {
      if ($sn =~ /^[0-9A-Z]{5}-[0-9A-Z]{5}-.*/) {
	($SN = $sn) =~ s/[-\s\r\n]//g;
	return($SN);
      }
    }
  } elsif (OS eq 'aqua') {
    my $k = `ioreg -d 2 -k IOPlatformUUID | grep IOPlatformUUID`;
    if ($k =~ /.*(\"[-0-9A-Z]*\")/) {
      ($SN = $1) =~ s/-//g;
      return($SN);
    }
  }
  return(undef);
}

sub save_smtp {
  my($SMTP) = shift;

  my $ofh = openConfig($Path->{SMTP});
  if ($ofh == 0) {
    errorPrint("Failed to open '$Path->{SMTP}': $@");
    return(0);
  }
  my $pass = '';
  if ($SMTP->{password} ne '') {
    my $encrypted = RC4(get_key(), $SMTP->{password});
    $pass = encode_base64($encrypted);
    chomp($pass);
  }
  print $ofh "\%smtp = (\n  to => '',\n  tos => {\n";
  my $tos = $SMTP->{tos}{$SMTP->{to}};
  if (!defined $tos || $tos != 0) {
    $tos = 9 if (!defined $tos);
    foreach my $t (keys %{$SMTP->{tos}}) {
      $SMTP->{tos}{$t}++ if ($SMTP->{tos}{$t} < $tos);
    }
    $SMTP->{tos}{$SMTP->{to}} = 0;
  }
  foreach my $t (keys %{$SMTP->{tos}}) {
    print $ofh "    '$t' => $SMTP->{tos}{$t},\n" if ($SMTP->{tos}{$t} < 9);
  }
  print $ofh "  },\n";
  print $ofh <<EOT;
  from => '$SMTP->{from}',
  subject => '$SMTP->{subject}',
  server => '$SMTP->{server}',
  port => $SMTP->{port},
  security => '$SMTP->{security}',
  username => '$SMTP->{username}',
  password => '$pass',
  debug => $SMTP->{debug},
);
1;
EOT
  close($ofh);    
}

sub send_mail {
  my($SMTP,$body,$path,$files) = @_;

  my @cmndArgs = ("-q");
#  $push(@cmndArgs, "-l", "D:/Chordy/sendmail.log");
  push(@cmndArgs, "-f", $SMTP->{from}) if ($SMTP->{from} ne '');
  push(@cmndArgs, "-t", $SMTP->{to})   if ($SMTP->{to} ne '');
  push(@cmndArgs, "-u", "ChordPro Files(s)");
  push(@cmndArgs, "-s", "$SMTP->{server}:$SMTP->{port}");
  if ($SMTP->{security} ne 'None') {
    if ($SMTP->{security} eq 'TLS' || $SMTP->{security} eq 'STARTTLS') {
      push(@cmndArgs, "-o", "tls=yes");
    }
    push(@cmndArgs, "-xu", $SMTP->{username}) if ($SMTP->{username} ne '');
    push(@cmndArgs, "-xp", $SMTP->{password}) if ($SMTP->{password} ne '');
  }
  push(@cmndArgs, "-o", "message-file=$body") if ($body ne '');
  if (@{$files}) {
    push(@cmndArgs, "-a");
    foreach my $f (@{$files}) {
      push(@cmndArgs, "$path/$f");
    }
  }
  my $email = CP::SendEmail->new();
  my $ret = $email->send(\@cmndArgs);
  unlink("$body") if (-e "$body");
  $ret;
}

1;
