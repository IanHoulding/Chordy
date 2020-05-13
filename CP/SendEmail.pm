package CP::SendEmail;

##############################################################################
## sendEmail
## Written by: Brandon Zehm <caspian@dotconf.net>
##
## License:
##  sendEmail (hereafter referred to as "program") is free software;
##  you can redistribute it and/or modify it under the terms of the GNU General
##  Public License as published by the Free Software Foundation; either version
##  2 of the License, or (at your option) any later version.
##  When redistributing modified versions of this source code it is recommended
##  that that this disclaimer and the above coder's names are included in the
##  modified code.
##
## Disclaimer:
##  This program is provided with no warranty of any kind, either expressed or
##  implied.  It is the responsibility of the user (you) to fully research and
##  comprehend the usage of this program.  As with any tool, it can be misused,
##  either intentionally (you're a vandal) or unintentionally (you're a moron).
##  THE AUTHOR(S) IS(ARE) NOT RESPONSIBLE FOR ANYTHING YOU DO WITH THIS PROGRAM
##  or anything that happens because of your use (or misuse) of this program,
##  including but not limited to anything you, your lawyers, or anyone else
##  can dream up.  And now, a relevant quote directly from the GPL:
##
## NO WARRANTY
##
##  11. BECAUSE THE PROGRAM IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
##  FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW.  EXCEPT WHEN
##  OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
##  PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED
##  OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
##  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE ENTIRE RISK AS
##  TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.  SHOULD THE
##  PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
##  REPAIR OR CORRECTION.
##
## MODIFIED Feb 2019 Ian Houlding. Now a module for use in Chordy so we can
##                                 use with either Windows or Mac.
##
##############################################################################
use strict;
use CP::Cconst qw/:OS/;
use Net::SSLeay;
use IO::Socket;
use IO::Socket::SSL;

our $Server = undef;

#############################
##                          ##
##      FUNCTIONS            ##
##                          ##
#############################

sub new {
  my($proto) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;

  $self->{CRLF}        = "\015\012";
  $self->{subject}     = '';
  $self->{header}      = '';
  $self->{message}     = '';
  $self->{from}        = '';
  $self->{to}          = [];
  $self->{cc}          = [];
  $self->{bcc}         = [];
  $self->{attachments} = [];
  $self->{attachments_names} = [];

  $self->{conf} = {
    ## General
    "programName" => $0,                    ## The name of this program
    "version"     => '1.56',                ## The version of this program
    "authorName"  => 'Brandon Zehm',        ## Author's Name
    "authorEmail" => 'caspian@dotconf.net', ## Author's Email Address
    "timezone"    => '+0000',               ## We always use +0000 for the time zone
    "hostname"    => 'changeme',            ## Used in printmsg() for all output
                                            ##  (is updated later in the script).
    "debug"       => 0,                     ## Default debug level
    "error"       => '',                    ## Error messages will often be stored here

    ## Logging
    "stdout"      => 1,
    "logging"     => 0,                     ## True if the printmsg function prints to the log file
    "logFile"     => '',                    ## If specified (via command line -l) this file will be
                                            ##   used for logging.
    ## Network
    "server"      => 'localhost',           ## Default SMTP server
    "port"        => 25,                    ## Default port
    "bindaddr"    => '',                    ## Default local bind address
    "alarm"       => '',                    ## Default timeout for connects and reads,
                                            ##   this gets set from $opt{timeout}
    "tls_client"  => 0,                     ## If TLS is supported by the client (us)
    "tls_server"  => 0,                     ## If TLS is supported by the remote SMTP server

    ## Email
    "delimiter"   => "----MIME delimiter for sendEmail-"  ## MIME Delimiter
                     . rand(1000000),                     ## Add some randomness to the delimiter
    "Message-ID"  => rand(1000000) . "-sendEmail",        ## Message-ID for email header
  };

  $self->{conf}{tls_client} = (defined $IO::Socket::SSL::VERSION) ? 1 : 0;

  ## This hash stores the options passed on the command line via the -o option.
  $self->{opt} = {
    ## Addressing
    "reply-to"             => '',           ## Reply-To field

    ## Message
    "message-file"         => '',           ## File to read message body from
    "message-header"       => '',           ## Additional email header line(s)
    "message-format"       => 'normal',     ## If "raw" is specified the message is sent unmodified
    "message-charset"      => 'iso-8859-1', ## Message character-set
    "message-content-type" => 'auto',       ## auto, text, html or an actual string to put into the
                                            ##   content-type header.
    ## Network
    "timeout"              => 60,           ## Default timeout for connects and reads,
                                            ##   this is copied to $self->{conf}{alarm} later.
    "fqdn"                 => 'changeme',   ## FQDN of this machine, used during SMTP communication
                                            ##   (is updated later in the script).
    ## eSMTP
    "username"             => '',           ## Username used in SMTP Auth
    "password"             => '',           ## Password used in SMTP Auth
    "tls"                  => 'auto',       ## Enable or disable TLS support.  Options: auto, yes, no
  };

  $self->{conf}{programName} =~ s/(.)*[\/,\\]//;

  ## Fixup $self->{conf}{hostname} and $self->{opt}{fqdn}
  if ($self->{opt}{fqdn} eq 'changeme') {
    $self->{opt}{fqdn} = get_hostname(1);
  }
  if ($self->{conf}{hostname} eq 'changeme') {
    $self->{conf}{hostname} = $self->{opt}{fqdn};
    $self->{conf}{hostname} =~ s/\..*//;
  }

  return($self);
}

###############################################################################################
##  Function: processCommandLine ()
##
##  Processes command line storing important data in global vars (usually %conf)
##
###############################################################################################
sub processCommandLine {
  my($self,$ARGS) = @_;
  my $numargv = @{$ARGS};
  return(0) unless ($numargv);
  my $counter = 0;

  for ($counter = 0; $counter < $numargv; $counter++) {
    if ($ARGS->[$counter] eq "") {                      ## Ignore null arguments
      ## Do nothing
    }
    elsif ($ARGS->[$counter] =~ /^-o$/i) {                 ## Options specified with -o ##
      $counter++;
      ## Loop through each option passed after the -o
      while ($ARGS->[$counter] && $ARGS->[$counter] !~ /^-/) {
	if ($ARGS->[$counter] !~ /(\S+)=(\S.*)/) {
	  $self->printmsg("WARNING => Name/Value pair '$ARGS->[$counter]' not properly formatted", 0);
	  $self->printmsg("WARNING => Arguments to -o should be in the form \"name=value\"", 0);
	}
	else {
	  if (exists($self->{opt}{$1})) {
	    if ($1 eq 'message-header') {
	      $self->{opt}{$1} .= $2 . $self->{CRLF};
	    }
	    else {
	      $self->{opt}{$1} = $2;
	    }
	    $self->printmsg("DEBUG => Assigned \$self->{opt}{$1} => $2", 3);
	  }
	  else {
	    $self->printmsg("WARNING => Name/Value pair '$ARGS->[$counter]' will be ignored: unknown key '$1'", 0);
	  }
	}
	$counter++;
      }
      $counter--;
    }
    elsif ($ARGS->[$counter] =~ /^-f$/) {                  ## From ##
      $counter++;
      if ($ARGS->[$counter] && $ARGS->[$counter] !~ /^-/) {
	$self->{from} = $ARGS->[$counter];
      }
      else {
	$self->printmsg("WARNING => The argument after -f was not an email address!", 0);
	$counter--;
      }
    }
    elsif ($ARGS->[$counter] =~ /^-t$/) {                  ## To ##
      $counter++;
      while ($ARGS->[$counter] && ($ARGS->[$counter] !~ /^-/)) {
	if ($ARGS->[$counter] =~ /[;,]/) {
	  push (@{$self->{to}}, split(/[;,]/, $ARGS->[$counter]));
	}
	else {
	  push (@{$self->{to}}, $ARGS->[$counter]);
	}
	$counter++;
      }
      $counter--;
    }
    elsif ($ARGS->[$counter] =~ /^-cc$/) {                 ## Cc ##
      $counter++;
      while ($ARGS->[$counter] && ($ARGS->[$counter] !~ /^-/)) {
	if ($ARGS->[$counter] =~ /[;,]/) {
	  push (@{$self->{cc}}, split(/[;,]/, $ARGS->[$counter]));
	}
	else {
	  push (@{$self->{cc}}, $ARGS->[$counter]);
	}
	$counter++;
      }
      $counter--;
    }
    elsif ($ARGS->[$counter] =~ /^-bcc$/) {                ## Bcc ##
      $counter++;
      while ($ARGS->[$counter] && ($ARGS->[$counter] !~ /^-/)) {
	if ($ARGS->[$counter] =~ /[;,]/) {
	  push (@{$self->{bcc}}, split(/[;,]/, $ARGS->[$counter]));
	}
	else {
	  push (@{$self->{bcc}}, $ARGS->[$counter]);
	}
	$counter++;
      }
      $counter--;
    }
    elsif ($ARGS->[$counter] =~ /^-m$/) {                  ## Message ##
      $counter++;
      $self->{message} = "";
      if ($ARGS->[$counter] && $ARGS->[$counter] !~ /^-/) {
	if (ref($ARGS->[$counter]) eq 'ARRAY') {
	  # We assume that each array element is one line of text.
	  foreach (@{$ARGS->[$counter]}) {
	    $_ =~ s/[\r\n]*$//;
	    $self->{message} .= "$_"."$self->{CRLF}";
	  }
	}
	else {
	  # Assume it's a scalar
	  foreach my $ln (split(/\n|\r\n/, $ARGS->[$counter])) {
	    $self->{message} .= "$ln"."$self->{CRLF}";
	  }
	}
      }
      else {
	$counter--;
      }
    }
    elsif ($ARGS->[$counter] =~ /^-u$/) {                  ## Subject ##
      $counter++;
      $self->{subject} = "";
      while ($ARGS->[$counter] && $ARGS->[$counter] !~ /^-/) {
	if ($self->{subject}) { $self->{subject} .= " "; }
	$self->{subject} .= $ARGS->[$counter];
	$counter++;
      }
      $counter--;
    }
    elsif ($ARGS->[$counter] =~ /^-s$/) {                  ## Server ##
      $counter++;
      if ($ARGS->[$counter] && $ARGS->[$counter] !~ /^-/) {
	$self->{conf}{server} = $ARGS->[$counter];
	if ($self->{conf}{server} =~ /:/) {                ## Port ##
	  ($self->{conf}{server},$self->{conf}{port}) = split(":",$self->{conf}{server});
	}
      }
      else {
	$self->printmsg("WARNING - The argument after -s was not the server!", 0);
	$counter--;
      }
    }
    elsif ($ARGS->[$counter] =~ /^-b$/) {                  ## Bind Address ##
      $counter++;
      if ($ARGS->[$counter] && $ARGS->[$counter] !~ /^-/) {
	$self->{conf}{bindaddr} = $ARGS->[$counter];
      }
      else {
	$self->printmsg("WARNING - The argument after -b was not the bindaddr!", 0);
	$counter--;
      }
    }
    elsif ($ARGS->[$counter] =~ /^-a$/) {                  ## Attachments ##
      $counter++;
      while ($ARGS->[$counter] && ($ARGS->[$counter] !~ /^-/)) {
	push (@{$self->{attachments}},$ARGS->[$counter]);
	$counter++;
      }
      $counter--;
    }
    elsif ($ARGS->[$counter] =~ /^-xu$/) {                  ## AuthSMTP Username ##
      $counter++;
      if ($ARGS->[$counter] && $ARGS->[$counter] !~ /^-/) {
	$self->{opt}{username} = $ARGS->[$counter];
      }
      else {
	$self->printmsg("WARNING => The argument after -xu was not valid username!", 0);
	$counter--;
      }
    }
    elsif ($ARGS->[$counter] =~ /^-xp$/) {                  ## AuthSMTP Password ##
      $counter++;
      if ($ARGS->[$counter] && $ARGS->[$counter] !~ /^-/) {
	$self->{opt}{password} = $ARGS->[$counter];
      }
      else {
	$self->printmsg("WARNING => The argument after -xp was not valid password!", 0);
	$counter--;
      }
    }
    elsif ($ARGS->[$counter] =~ /^-l$/) {                  ## Logging ##
      $counter++;
      $self->{conf}{logging} = 1;
      if ($ARGS->[$counter] && $ARGS->[$counter] !~ /^-/) {
	$self->{conf}{logFile} = $ARGS->[$counter];
      }
      else {
	$self->printmsg("WARNING - The argument after -l was not the log file!", 0);
	$counter--;
      }
    }
    elsif ($ARGS->[$counter] =~ s/^-v+//i) {               ## Verbosity ##
      my $tmp = (length($&) - 1);
      $self->{conf}{debug} += $tmp;
    }
    elsif ($ARGS->[$counter] =~ /^-q$/) {                  ## Quiet ##
      $self->{conf}{stdout} = 0;
    }
    else {
      $self->printmsg("Error: \"$ARGS->[$counter]\" is not a recognized option!", 0);
      help();
    }
  }
  ###################################################
  ##  Verify required variables are set correctly  ##
  ###################################################

  ## Make sure we have something in $self->{conf}{hostname} and $self->{opt}{fqdn}
  if ($self->{opt}{fqdn} =~ /\./) {
    $self->{conf}{hostname} = $self->{opt}{fqdn};
    $self->{conf}{hostname} =~ s/\..*//;
  }

  if (!$self->{conf}{server}) { $self->{conf}{server} = 'localhost'; }
  if (!$self->{conf}{port})   { $self->{conf}{port} = 25; }
  if (!$self->{from}) {
    $self->quit("ERROR => You must specify a 'from' field!  Try --help."); return(1);
  }
  if ( ((scalar(@{$self->{to}})) + (scalar(@{$self->{cc}})) + (scalar(@{$self->{bcc}}))) <= 0) {
    $self->quit("ERROR => You must specify at least one recipient via -t, -cc, or -bcc"); return(1);
  }

  ## Make sure email addresses look OK.
  foreach my $addr (@{$self->{to}}, @{$self->{cc}}, @{$self->{bcc}}, $self->{from}, $self->{opt}{'reply-to'}) {
    if ($addr) {
      if (!$self->returnAddressParts($addr)) {
	$self->printmsg("ERROR => Can't use improperly formatted email address: $addr", 0);
	$self->printmsg("HINT => Try viewing the extended help on addressing with \"--help addressing\"", 1);
	$self->quit(""); return(1);
      }
    }
  }

  ## Make sure all attachments exist.
  foreach my $file (@{$self->{attachments}}) {
    if ( (! -f $file) or (! -r $file) ) {
      $self->printmsg("ERROR => The attachment [$file] doesn't exist!", 0);
      $self->printmsg("HINT => Try specifying the full path to the file or reading extended help with \"--help message\"", 1);
      $self->quit(""); return(1);
    }
  }

  if ($self->{conf}{logging} and (!$self->{conf}{logFile})) {
    $self->quit("ERROR => You used -l to enable logging but didn't specify a log file!"); return(1);
  }

  if ( $self->{opt}{username} ) {
    if (!$self->{opt}{password}) {
      $self->quit("ERROR => A username for SMTP authentication was specified, but no password!");
      return(1);
    }
  }

  ## Validate the TLS setting
  $self->{opt}{tls} = lc($self->{opt}{tls});
  if ($self->{opt}{tls} !~ /^(auto|yes|no)$/) {
    $self->quit("ERROR => Invalid TLS setting ($self->{opt}{tls}). Must be one of auto, yes, or no.");
    return(1);
  }

  ## If TLS is set to "yes", make sure sendEmail loaded the libraries needed.
  if ($self->{opt}{tls} eq 'yes' and $self->{conf}{tls_client} == 0) {
    $self->quit("ERROR => No TLS support!  SendEmail can't load required libraries. (try installing Net::SSLeay and IO::Socket::SSL)");
    return(1);
  }

  ## Return 0 errors
  return(0);
}

## getline($socketRef)
sub getline {
  my($socketRef) = shift;
  local ($/) = "\r\n";
  return $$socketRef->getline();
}

## Receive a (multiline?) SMTP response from ($socketRef)
sub getResponse {
  my($socketRef) = shift;
  my ($tmp, $reply);
  local ($/) = "\r\n";
  return undef unless defined($tmp = getline($socketRef));
  return("getResponse() socket is not open") unless ($Server->opened());
  ## Keep reading lines if it's a multi-line response
  while ($tmp =~ /^\d{3}-/o) {
    $reply .= $tmp;
    return undef unless defined($tmp = getline($socketRef));
  }
  $reply .= $tmp;
  $reply =~ s/\r?\n$//o;
  return $reply;
}

###############################################################################################
##  Function:    SMTPchat ( [string $command] )
##
##  Description: Sends $command to the SMTP server (on self->{Server}) and awaits a successful
##               reply form the server.  If the server returns an error, or does not reply
##               within $self->{conf}{alarm} seconds an error is generated.
##               NOTE: $command is optional, if no command is specified then nothing will
##               be sent to the server, but a valid response is still required from the server.
##
##  Input:       [$command]          A (optional) valid SMTP command (ex. "HELO")
##
##  Output:      Returns zero on success, or non-zero on error.
##               Error messages will be stored in $self->{conf}{error}
##               A copy of the last SMTP response is stored in the global variable
##               $self->{conf}{SMTPchat_response}
##
##  Example:     SMTPchat ("HELO mail.isp.net");
###############################################################################################
sub SMTPchat {
  my($self,$command) = @_;

  if ($command) {
   $self->printmsg("INFO => Sending: '$command'", 1);
  }
  ## Send our command
  if ($command) {
    print $Server "$command$self->{CRLF}";
  }
  ## Read a response from the server
  if (OS ne 'win32') {  ## alarm() doesn't work in win32;
    $SIG{ALRM} = sub { $self->{conf}{error} = "alarm"; $Server->close(); $Server = undef;};
    alarm($self->{conf}{alarm})
  }
  my $result = $self->{conf}{SMTPchat_response} = getResponse(\$Server);
  alarm(0) if (OS ne 'win32');  ## alarm() doesn't work in win32;

  ## Generate an alert if we timed out
  if ($self->{conf}{error} eq "alarm") {
    $self->{conf}{error} = "ERROR => Timeout while reading from $self->{conf}{server}:$self->{conf}{port} There was no response after $self->{conf}{alarm} seconds.";
    return(1);
  }

  ## Make sure the server actually responded
  if (!$result) {
    $self->{conf}{error} = "ERROR => $self->{conf}{server}:$self->{conf}{port} returned a zero byte response to our query.";
    return(2);
  }

  ## Validate the response
  if ($self->evalSMTPresponse($result)) {
    ## conf{error} will already be set here
    return(2);
  }

  ## Print the success messsage
  $self->printmsg($self->{conf}{error}, 1);

  ## Return Success
  return(0);
}

###############################################################################################
##  Function:    evalSMTPresponse (string $self->{message} )
##
##  Description: Searches $self->{message} for either an  SMTP success or error code, and returns
##               0 on success, and the actual error code on error.
##
##  Input:       $self->{message}          Data received from a SMTP server (ex. "220
##
##  Output:      Returns zero on success, or non-zero on error.
##               Error messages will be stored in $self->{conf}{error}
##
##  Example:     SMTPchat ("HELO mail.isp.net");
###############################################################################################
sub evalSMTPresponse {
  my ($self,$message) = @_;

  ## Validate input
  if (!$message) {
    $self->{conf}{error} = "ERROR => No message was passed to evalSMTPresponse().  What happened?";
    return(1)
  }

  $self->printmsg("DEBUG => evalSMTPresponse() - Checking for SMTP success or error status in the message: $message ", 3);

  ## Look for a SMTP success code
  if ($message =~ /^([23]\d\d)/) {
    $self->printmsg("DEBUG => evalSMTPresponse() - Found SMTP success code: $1", 2);
    $self->{conf}{error} = "SUCCESS => Received: \t$message";
    return(0);
  }

  ## Look for a SMTP error code
  if ($message =~ /^([45]\d\d)/) {
    $self->printmsg("DEBUG => evalSMTPresponse() - Found SMTP error code: $1", 2);
    $self->{conf}{error} = "ERROR => Received: \t$message";
    return($1);
  }

  ## If no SMTP codes were found return an error of 1
  $self->{conf}{error} = "ERROR => Received a message with no success or error code. The message received was: $message";
  return(2);
}

#########################################################
# SUB: &return_month(0,1,etc)
#  returns the name of the month that corrosponds
#  with the number.  returns 0 on error.
#########################################################
sub return_month {
  my($x) = shift;
  return(0) if ($x < 0 || $x > 11);
  return((qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/)[$x]);
}

#########################################################
# SUB: &return_day(0,1,etc)
#  returns the name of the day that corrosponds
#  with the number.  returns 0 on error.
#########################################################
sub return_day {
  my($x) = shift;
  return(0) if ($x < 0 || $x > 6);
  return((qw/Sun Mon Tue Wed Thu Fri Sat/)[$x]);
}

###############################################################################################
##  Function:    returnAddressParts(string $address)
##
##  Description: Returns a two element array containing the "Name" and "Address" parts of
##               an email address.
##
## Example:      "Brandon Zehm <caspian@dotconf.net>"
##               would return: ("Brandon Zehm", "caspian@dotconf.net");
##
##               "caspian@dotconf.net"
##               would return: ("caspian@dotconf.net", "caspian@dotconf.net")
###############################################################################################
sub returnAddressParts {
  my($self,$input) = @_;
  my $name = "";
  my $address = "";

  ## Make sure to fail if it looks totally invalid
  if ($input !~ /(\S+\@\S+)/) {
    $self->{conf}{error} = "ERROR => The address [$input] doesn't look like a valid email address, ignoring it";
    return(undef());
  }

  ## Check 1, should find addresses like: "Brandon Zehm <caspian@dotconf.net>"
  elsif ($input =~ /^\s*(\S(.*\S)?)\s*<(\S+\@\S+)>/o) {
    ($name, $address) = ($1, $3);
  }

  ## Otherwise if that failed, just get the address: <caspian@dotconf.net>
  elsif ($input =~ /<(\S+\@\S+)>/o) {
    $name = $address = $1;
  }

  ## Or maybe it was formatted this way: caspian@dotconf.net
  elsif ($input =~ /(\S+\@\S+)/o) {
    $name = $address = $1;
  }

  ## Something stupid happened, just return an error.
  unless ($name and $address) {
    $self->printmsg("ERROR => Couldn't parse the address: $input", 0);
    $self->printmsg("HINT => If you think this should work, consider reporting this as a bug to $self->{conf}{authorEmail}", 1);
    return(undef());
  }

  ## Make sure there aren't invalid characters in the address, and return it.
  my $ctrl        = '\000-\037';
  my $nonASCII    = '\x80-\xff';
  if ($address =~ /[<> ,;:"'\[\]\\$ctrl$nonASCII]/) {
    $self->printmsg("WARNING => The address [$address] seems to contain invalid characters: continuing anyway", 0);
  }
  return($name, $address);
}

###############################################################################################
##  Function:    base64_encode(string $data, bool $chunk)
##
##  Description: Returns $data as a base64 encoded string.
##               If $chunk is true, the encoded data is returned in 76 character long lines
##               with the final \CR\LF removed.
##
##  Note: This is only used from the smtp auth section of code.
##        At some point it would be nice to merge the code that encodes attachments and this.
###############################################################################################
sub base64_encode {
  my $data = $_[0];
  my $chunk = $_[1];
  my $tmp = '';
  my $base64 = '';
  my $CRLF = "\r\n";

  ###################################
  ## Convert binary data to base64 ##
  ###################################
  while ($data =~ s/(.{45})//s) {      ## Get 45 bytes from the binary string
    $tmp = substr(pack('u', $&), 1);   ## Convert the binary to uuencoded text
    chop($tmp);
    $tmp =~ tr|` -_|AA-Za-z0-9+/|;     ## Translate from uuencode to base64
    $base64 .= $tmp;
  }

  ##########################
  ## Encode the leftovers ##
  ##########################
  my $padding = "";
  if ( ($data) and (length($data) > 0) ) {
    $padding = (3 - length($data) % 3) % 3;    ## Set flag if binary data isn't divisible by 3
    $tmp = substr(pack('u', $data), 1);        ## Convert the binary to uuencoded text
    chop($tmp);
    $tmp =~ tr|` -_|AA-Za-z0-9+/|;             ## Translate from uuencode to base64
    $base64 .= $tmp;
  }

  ############################
  ## Fix padding at the end ##
  ############################
  $data = '';
  $base64 =~ s/.{$padding}$/'=' x $padding/e if $padding; ## Fix the end padding if flag (from above) is set
  if ($chunk) {
    while ($base64 =~ s/(.{1,76})//s) {                   ## Put $CRLF after each 76 characters
      $data .= "$1$CRLF";
    }
  }
  else {
    $data = $base64;
  }

  ## Remove any trailing CRLF's
  $data =~ s/(\r|\n)*$//s;
  return($data);
}

#########################################################
# SUB: send_attachment("/path/filename")
# Sends the mime headers and base64 encoded file
# to the email server.
#########################################################
sub send_attachment {
  my ($self,$filename) = @_;                             ## Get filename passed
  my (@fields, $y, $filename_name, $encoding,      ## Local variables
      @attachlines, $content_type);
  my $bin = 1;

  @fields = split(/\/|\\/, $filename);             ## Get the actual filename without the path
  $filename_name = pop(@fields);
  push @{$self->{attachments_names}}, $filename_name;  ## FIXME: This is only used later for putting in the log file

  ##########################
  ## Autodetect Mime Type ##
  ##########################

  if ($filename_name =~ /\.pdf$/i) {
    $content_type = 'application/pdf';
  } else {
    $content_type = 'application/octet-stream';
  }

  ############################
  ## Process the attachment ##
  ############################

  #####################################
  ## Generate and print MIME headers ##
  #####################################

  $y  = "$self->{CRLF}--$self->{conf}{delimiter}$self->{CRLF}";
  $y .= "Content-Type: $content_type;$self->{CRLF}";
  $y .= "        name=\"$filename_name\"$self->{CRLF}";
  $y .= "Content-Transfer-Encoding: base64$self->{CRLF}";
  $y .= "Content-Disposition: attachment; filename=\"$filename_name\"$self->{CRLF}";
  $y .= "$self->{CRLF}";
  print $Server $y;
  
  ###########################################################
  ## Convert the file to base64 and print it to the server ##
  ###########################################################

  open (FILETOATTACH, $filename) || do {
    $self->printmsg("ERROR => Opening the file [$filename] for attachment failed with the error: $!", 0);
    return(1);
  };
  binmode(FILETOATTACH);                 ## Hack to make Win32 work

  my $res = "";
  my $tmp = "";
  my $base64 = "";
  while (<FILETOATTACH>) {               ## Read a line from the (binary) file
    $res .= $_;

    ###################################
    ## Convert binary data to base64 ##
    ###################################
    while ($res =~ s/(.{45})//s) {         ## Get 45 bytes from the binary string
      $tmp = substr(pack('u', $&), 1);   ## Convert the binary to uuencoded text
      chop($tmp);
      $tmp =~ tr|` -_|AA-Za-z0-9+/|;     ## Translate from uuencode to base64
      $base64 .= $tmp;
    }

    ################################
    ## Print chunks to the server ##
    ################################
    while ($base64 =~ s/(.{76})//s) {
      print $Server "$1$self->{CRLF}";
    }

  }

  ###################################
  ## Encode and send the leftovers ##
  ###################################
  my $padding = "";
  if ( ($res) and (length($res) >= 1) ) {
    $padding = (3 - length($res) % 3) % 3;  ## Set flag if binary data isn't divisible by 3
    $res = substr(pack('u', $res), 1);      ## Convert the binary to uuencoded text
    chop($res);
    $res =~ tr|` -_|AA-Za-z0-9+/|;          ## Translate from uuencode to base64
  }

  ############################
  ## Fix padding at the end ##
  ############################
  $res = $base64 . $res;                               ## Get left overs from above
  $res =~ s/.{$padding}$/'=' x $padding/e if $padding; ## Fix the end padding if flag (from above) is set
  if ($res) {
    while ($res =~ s/(.{1,76})//s) {                 ## Send it to the email server.
      print $Server "$1$self->{CRLF}";
    }
  }

  close (FILETOATTACH) || do {
    $self->printmsg("ERROR - Closing the filehandle for file [$filename] failed with the error: $!", 0);
    return(2);
  };

  ## Return 0 errors
  return(0);
}

###############################################################################################
##  Function:    $string = get_hostname (boot $fqdn)
##
##  Description: Tries really hard to returns the short (or FQDN) hostname of the current
##               system.  Uses techniques and code from the  Sys-Hostname module.
##
##  Input:       $fqdn     A true value (1) will cause this function to return a FQDN hostname
##                         rather than a short hostname.
##
##  Output:      Returns a string
###############################################################################################
sub get_hostname {
  ## Assign incoming parameters to variables
  my ( $fqdn ) = @_;
  my $hostname = "";

  ## STEP 1: Get short hostname

  ## Load Sys::Hostname if it's available
  eval { require Sys::Hostname; };
  unless ($@) {
    $hostname = Sys::Hostname::hostname();
  }

  ## If that didn't get us a hostname, try a few other things
  else {
    ## Windows systems
    if (OS ne 'win32') {
      if ($ENV{COMPUTERNAME}) { $hostname = $ENV{COMPUTERNAME}; }
      if (!$hostname) { $hostname = gethostbyname('localhost'); }
      if (!$hostname) { chomp($hostname = `hostname 2> NUL`) };
    }

    ## Unix systems
    else {
      local $ENV{PATH} = '/usr/bin:/bin:/usr/sbin:/sbin';  ## Paranoia

      ## Try the environment first (Help!  What other variables could/should I be checking here?)
      if ($ENV{HOSTNAME}) { $hostname = $ENV{HOSTNAME}; }

      ## Try the hostname command
      eval { local $SIG{__DIE__}; local $SIG{CHLD}; $hostname = `hostname 2>/dev/null`; chomp($hostname); } ||

	  ## Try POSIX::uname(), which strictly can't be expected to be correct
	  eval { local $SIG{__DIE__}; require POSIX; $hostname = (POSIX::uname())[1]; } ||

	  ## Try the uname command
	  eval { local $SIG{__DIE__}; $hostname = `uname -n 2>/dev/null`; chomp($hostname); };

    }

    ## If we can't find anything else, return ""
    if (!$hostname) {
      print "WARNING => No hostname could be determined, please specify one with -o fqdn=FQDN option!\n";
      return("unknown");
    }
  }

  ## Return the short hostname
  unless ($fqdn) {
    $hostname =~ s/\..*//;
    return(lc($hostname));
  }

  ## STEP 2: Determine the FQDN

  ## First, if we already have one return it.
  if ($hostname =~ /\w\.\w/) { return(lc($hostname)); }

  ## Next try using
  eval { $fqdn = (gethostbyname($hostname))[0]; };
  if ($fqdn) { return(lc($fqdn)); }
  return(lc($hostname));
}

###############################################################################################
##  Function:    printmsg (string $message, int $level)
##
##  Description: Handles all messages - printing them to the screen only if the messages
##               $level is >= the global debug level.  If $self->{conf}{logFile} is defined it
##               will also log the message to that file.
##
##  Input:       $message          A message to be printed, logged, etc.
##               $level            The debug level of the message. If
##                                 not defined 0 will be assumed.  0 is
##                                 considered a normal message, 1 and
##                                 higher is considered a debug message.
##
##  Output:      Prints to STDOUT
##
##  Assumptions: $self->{conf}{hostname} should be the name of the computer we're running on.
##               $self->{conf}{stdout} should be set to 1 if you want to print to stdout
##               $self->{conf}{logFile} should be a full path to a log file if you want that
##               $self->{conf}{debug} should be an integer between 0 and 10.
##
##  Example:     printmsg("WARNING: We believe in generic error messages... NOT!", 0);
###############################################################################################
sub printmsg {
  ## Assign incoming parameters to variables
  my ($self,$message,$level) = @_;

  ## Make sure input is sane
  $level = 0 if (!defined($level));
  $message =~ s/\s+$//sgo;
  $message =~ s/\r?\n/, /sgo;

  ## Continue only if the debug level of the program is >= message debug level.
  if ($self->{conf}{debug} >= $level) {

    ## Get the date in the format: Dec  3 11:14:04
    my ($sec, $min, $hour, $mday, $mon) = localtime();
    my $date = sprintf("%s %02d %02d:%02d:%02d", return_month($mon), $mday, $hour, $min, $sec);

    ## Print to STDOUT always if debugging is enabled, or if conf{stdout} is true.
    if ( ($self->{conf}{debug} >= 1) or ($self->{conf}{stdout} == 1) ) {
      print "$date $self->{conf}{hostname} $self->{conf}{programName}\[$$\]: $message\n";
    }

    ## Print to the log file if $self->{conf}{logging} is true
    if ($self->{conf}{logFile}) {
      if ($self->openLogFile($self->{conf}{logFile})) {
	$self->{conf}{logFile} = "";
	$self->printmsg("ERROR => Opening the file [$self->{conf}{logFile}] for appending returned the error: $!", 1);
      }
      else {
	print LOGFILE "$date $self->{conf}{hostname} $self->{conf}{programName}\[$$\]: $message\n";
      }
    }
  }

  ## Return 0 errors
  return(0);
}

###############################################################################################
## FUNCTION:
##   openLogFile ( $filename )
##
##
## DESCRIPTION:
##   Opens the file $filename and attaches it to the filehandle "LOGFILE".  Returns 0 on success
##   and non-zero on failure.  Error codes are listed below, and the error message gets set in
##   global variable $!.
##
##
## Example:
##   openFile ("/var/log/sendEmail.log");
##
###############################################################################################
sub openLogFile {
  ## Get the incoming filename
  my($self,$filename) = @_;

  ## Make sure our file exists, and if the file doesn't exist then create it
  if ( ! -f $filename ) {
    print STDERR "NOTICE: The log file [$filename] does not exist.  Creating it now with mode [0600].\n" if ($self->{conf}{stdout});
    open (LOGFILE, ">>", $filename);
    close LOGFILE;
    chmod (0600, $filename);
  }

  ## Now open the file and attach it to a filehandle
  open (LOGFILE,">>$filename") or return (1);

  ## Put the file into non-buffering mode
  select LOGFILE;
  $| = 1;
  select STDOUT;

  ## Return success
  return(0);
}

###############################################################################################
##  Function:    read_file (string $filename)
##
##  Description: Reads the contents of a file and returns a two part array:
##               ($status, $file-contents)
##               $status is 0 on success, non-zero on error.
##
##  Example:     ($status, $file) = read_file("/etc/passwd");
###############################################################################################
sub read_file {
  my ( $filename ) = @_;

  ## If the value specified is a file, load the file's contents
  if ( (-e $filename and -r $filename) ) {
    my $FILE;
    if(!open($FILE, ' ' . $filename)) {
      return((1, ""));
    }
    my $file = '';
    while (<$FILE>) {
      $file .= $_;
    }
    ## Strip an ending \r\n
    $file =~ s/\r?\n$//os;
  }
  return((1, ""));
}

###############################################################################################
##  Function:    quit (string $message, int $errorLevel)
##
##  Description: Print message if there is one. Used to Exit
##               but now just returns and the caller exits.
##
##  Example:     $self->quit("Exiting program normally", 0);
###############################################################################################
sub quit {
  my ($self,$message) = @_;

  $self->printmsg($message) if ($message);
}

#############################
##                          ##
##      MAIN PROGRAM         ##
##                          ##
#############################

sub send {
  my($self,$args) = @_;

  ## Process Command Line
  return(1) if ($self->processCommandLine($args));
  $self->{conf}{alarm} = $self->{opt}{timeout};

  ## Abort program after $self->{conf}{alarm} seconds to avoid infinite hangs
  alarm($self->{conf}{alarm}) if (OS ne 'win32');  ## alarm() doesn't work in win32

  ###################################################
  ##  Read $self->{message} from STDIN if -m was not used  ##
  ###################################################

  if (!($self->{message}) && $self->{opt}{'message-file'}) {
    ## Read message body from a file specified with -o message-file=
    if (! -e $self->{opt}{'message-file'}) {
      $self->printmsg("ERROR => Message body file specified [$self->{opt}{'message-file'}] does not exist!", 0);
      $self->printmsg("HINT => 1) check spelling of your file; 2) fully qualify the path; 3) doubble quote it", 1);
      $self->quit(""); return(1);
    }
    if (! -r $self->{opt}{'message-file'}) {
      $self->printmsg("ERROR => Message body file specified can not be read due to restricted permissions!", 0);
      $self->printmsg("HINT => Check permissions on file specified to ensure it can be read", 1);
      $self->quit(""); return(1);
    }
    if (!open(MFILE, "< " . $self->{opt}{'message-file'})) {
      $self->printmsg("ERROR => Error opening message body file [$self->{opt}{'message-file'}]: $!", 0);
      $self->quit(""); return(1);
    }
    while (<MFILE>) {
      $self->{message} .= $_;
    }
    close(MFILE);
  }

  ## Replace bare LF's with CRLF's (\012 should always have \015 with it)
  $self->{message} =~ s/(\015)?(\012|$)/\015\012/g;

  ## Replace bare CR's with CRLF's (\015 should always have \012 with it)
  $self->{message} =~ s/(\015)(\012|$)?/\015\012/g;

  ## Check message for bare periods and encode them
  $self->{message} =~ s/(^|$self->{CRLF})(\.{1})($self->{CRLF}|$)/$1.$2$3/g;

  ## Get the current date for the email header
  my ($sec,$min,$hour,$mday,$mon,$year,$day) = gmtime();
  $year += 1900; $mon = return_month($mon); $day = return_day($day);
  my $date = sprintf("%s, %s %s %d %.2d:%.2d:%.2d %s",$day, $mday, $mon, $year, $hour, $min, $sec, $self->{conf}{timezone});

  ##################################
  ##  Connect to the SMTP server  ##
  ##################################
  $self->printmsg("DEBUG => Connecting to $self->{conf}{server}:$self->{conf}{port}", 1);
  $SIG{ALRM} = sub {
    $self->printmsg("ERROR => Timeout while connecting to $self->{conf}{server}:$self->{conf}{port}  There was no response after $self->{conf}{alarm} seconds.", 0);
    $self->printmsg("HINT => Try specifying a different mail relay with the -s option.", 1);
    $self->quit(""); return(1);
  };
  alarm($self->{conf}{alarm}) if (OS ne 'win32');  ## alarm() doesn't work in win32;
  $Server = IO::Socket::INET->new( PeerAddr  => $self->{conf}{server},
					   PeerPort  => $self->{conf}{port},
					   LocalAddr => $self->{conf}{bindaddr},
					   Proto     => 'tcp',
					   Autoflush => 1,
					   timeout   => $self->{conf}{alarm},
      );
  alarm(0) if (OS ne 'win32');  ## alarm() doesn't work in win32;

  ## Make sure we got connected
  if ( (!$Server) or (!$Server->opened()) ) {
    $self->printmsg("ERROR => Connection attempt to $self->{conf}{server}:$self->{conf}{port} failed: $@", 0);
    $self->printmsg("HINT => Try specifying a different mail relay with the -s option.", 1);
    $self->quit(""); return(1);
  }

  ## Save our IP address for later
  $self->{conf}{ip} = $Server->sockhost();
  $self->printmsg("DEBUG => My IP address is: $self->{conf}{ip}", 1);

  #########################
  ##  Do the SMTP Dance  ##
  #########################

  ## Read initial greeting to make sure we're talking to a live SMTP server
  if ($self->SMTPchat()) {
    $self->quit($self->{conf}{error});
    return(1);
  }

  ## We're about to use $self->{opt}{fqdn}, make sure it isn't empty
  if (!$self->{opt}{fqdn}) {
    ## Ok, that means we couldn't get a hostname, how about using the IP address for the HELO instead
    $self->{opt}{fqdn} = "[" . $self->{conf}{ip} . "]";
  }

  ## EHLO
  if ($self->SMTPchat("EHLO $self->{opt}{fqdn}"))   {
    $self->printmsg($self->{conf}{error}, 0);
    $self->printmsg("NOTICE => EHLO command failed, attempting HELO instead");
    if ($self->SMTPchat("HELO $self->{opt}{fqdn}")) {
      $self->quit($self->{conf}{error});
      return(1);
    }
    if ( $self->{opt}{username} and $self->{opt}{password} ) {
      $self->printmsg("WARNING => The mail server does not support SMTP authentication!", 0);
    }
  }
  else {
    ## Determin if the server supports TLS
    if ($self->{conf}{SMTPchat_response} =~ /STARTTLS/) {
      $self->{conf}{tls_server} = 1;
      $self->printmsg("DEBUG => The remote SMTP server supports TLS :)", 2);
    }
    else {
      $self->{conf}{tls_server} = 0;
      $self->printmsg("DEBUG => The remote SMTP server does NOT support TLS :(", 2);
    }

    ## Start TLS if possible
    if ($self->{conf}{tls_server} == 1 and $self->{conf}{tls_client} == 1 and $self->{opt}{tls} =~ /^(yes|auto)$/) {
      $self->printmsg("DEBUG => Starting TLS", 2);
      if ($self->SMTPchat('STARTTLS')) { $self->quit($self->{conf}{error}); return(1); }
#      if (! IO::Socket::SSL->start_SSL($Server, SSL_version => 'SSLv3 TLSv1')) {
      if (! IO::Socket::SSL->start_SSL($Server)) {
	$self->quit("ERROR => TLS setup failed: " . IO::Socket::SSL::errstr());
	return(1);
      }
      $self->printmsg("DEBUG => TLS: Using cipher: ". $Server->get_cipher(), 3);
      $self->printmsg("DEBUG => TLS session initialized :)", 1);
    
      ## Restart our SMTP session
      if ($self->SMTPchat('EHLO ' . $self->{opt}{fqdn})) {
	$self->quit($self->{conf}{error});
	return(1);
      }
    }
    elsif ($self->{opt}{tls} eq 'yes' and $self->{conf}{tls_server} == 0) {
      $self->quit("ERROR => TLS not possible! Remote SMTP server, $self->{conf}{server},  does not support it.");
      return(1);
    }

    ## Do SMTP Auth if required
    if ( $self->{opt}{username} and $self->{opt}{password} ) {
      if ($self->{conf}{SMTPchat_response} !~ /AUTH\s/) {
	$self->printmsg("NOTICE => Authentication not supported by the remote SMTP server!", 0);
      }
      else {
	my $auth_succeeded = 0;
	my $mutual_method = 0;

	# ## SASL CRAM-MD5 authentication method
	# if ($self->{conf}{SMTPchat_response} =~ /\bCRAM-MD5\b/i) {
	#     $self->printmsg("DEBUG => SMTP-AUTH: Using CRAM-MD5 authentication method", 1);
	#     if ($self->SMTPchat('AUTH CRAM-MD5')) { $self->quit($self->{conf}{error}, 1); }
	#
	#     ## FIXME!!
	#
	#     $self->printmsg("DEBUG => User authentication was successful", 1);
	# }

	## SASL LOGIN authentication method
	if ($auth_succeeded == 0 and $self->{conf}{SMTPchat_response} =~ /\bLOGIN\b/i) {
	  $mutual_method = 1;
	  $self->printmsg("DEBUG => SMTP-AUTH: Using LOGIN authentication method", 1);
	  if (!$self->SMTPchat('AUTH LOGIN')) {
	    if (!$self->SMTPchat(base64_encode($self->{opt}{username}))) {
	      if (!$self->SMTPchat(base64_encode($self->{opt}{password}))) {
		$auth_succeeded = 1;
		$self->printmsg("DEBUG => User authentication was successful (Method: LOGIN)", 1);
	      }
	    }
	  }
	  if ($auth_succeeded == 0) {
	    $self->printmsg("DEBUG => SMTP-AUTH: LOGIN authenticaion failed.", 1);
	  }
	}

	## SASL PLAIN authentication method
	if ($auth_succeeded == 0 and $self->{conf}{SMTPchat_response} =~ /\bPLAIN\b/i) {
	  $mutual_method = 1;
	  $self->printmsg("DEBUG => SMTP-AUTH: Using PLAIN authentication method", 1);
	  if ($self->SMTPchat('AUTH PLAIN ' . base64_encode("$self->{opt}{username}\0$self->{opt}{username}\0$self->{opt}{password}"))) {
	    $self->printmsg("DEBUG => SMTP-AUTH: PLAIN authenticaion failed.", 1);
	  }
	  else {
	    $auth_succeeded = 1;
	    $self->printmsg("DEBUG => User authentication was successful (Method: PLAIN)", 1);
	  }
	}

	## If none of the authentication methods supported by sendEmail were supported by the server, let the user know
	if ($mutual_method == 0) {
	  $self->printmsg("WARNING => SMTP-AUTH: No mutually supported authentication methods available", 0);
	}

	## If we didn't get authenticated, log an error message and exit
	if ($auth_succeeded == 0) {
	  $self->quit("ERROR => ERROR => SMTP-AUTH: Authentication to $self->{conf}{server}:$self->{conf}{port} failed."); return(1);
	}
      }
    }
  }

  ## MAIL FROM
  if ($self->SMTPchat('MAIL FROM:<' .($self->returnAddressParts($self->{from}))[1]. '>')) { $self->quit($self->{conf}{error}); return(1); }

  ## RCPT TO
  my $oneRcptAccepted = 0;
  foreach my $rcpt (@{$self->{to}}, @{$self->{cc}}, @{$self->{bcc}}) {
    my ($name, $address) = $self->returnAddressParts($rcpt);
    if ($self->SMTPchat('RCPT TO:<' . $address . '>')) {
      $self->printmsg("WARNING => The recipient <$address> was rejected by the mail server, error follows:", 0);
      $self->{conf}{error} =~ s/^ERROR/WARNING/o;
      $self->printmsg($self->{conf}{error}, 0);
    }
    elsif ($oneRcptAccepted == 0) {
      $oneRcptAccepted = 1;
    }
  }
  ## If no recipients were accepted we need to exit with an error.
  if ($oneRcptAccepted == 0) {
    $self->quit("ERROR => Exiting. No recipients were accepted for delivery by the mail server."); return(1);
  }

  ## DATA
  if ($self->SMTPchat('DATA')) { $self->quit($self->{conf}{error}); return(1); }

  ###############################
  ##  Build and send the body  ##
  ###############################
  $self->printmsg("INFO => Sending message body",1);

  ## If the message-format is raw just send the message as-is.
  if ($self->{opt}{'message-format'} =~ /^raw$/i) {
    print $Server $self->{message};
  }
  ## If the message-format isn't raw, then build and send the message,
  else {
    ## Message-ID: <MessageID>
    if ($self->{opt}{'message-header'} !~ /^Message-ID:/iom) {
      $self->{header} .= 'Message-ID: <' . $self->{conf}{'Message-ID'} . '@' . $self->{conf}{hostname} . '>' . $self->{CRLF};
    }

    ## From: "Name" <address@domain.com> (the pointless test below is just to keep scoping correct)
    if ($self->{from} and $self->{opt}{'message-header'} !~ /^From:/iom) {
      my ($name, $address) = $self->returnAddressParts($self->{from});
      $self->{header} .= 'From: "' . $name . '" <' . $address . '>' . $self->{CRLF};
    }

    ## Reply-To:
    if ($self->{opt}{'reply-to'} and $self->{opt}{'message-header'} !~ /^Reply-To:/iom) {
      my ($name, $address) = $self->returnAddressParts($self->{opt}{'reply-to'});
      $self->{header} .= 'Reply-To: "' . $name . '" <' . $address . '>' . $self->{CRLF};
    }

    ## To: "Name" <address@domain.com>
    if ($self->{opt}{'message-header'} =~ /^To:/iom) {
      ## The user put the To: header in via -o message-header - dont do anything
    }
    elsif (scalar(@{$self->{to}}) > 0) {
      $self->{header} .= "To:";
      for (my $a = 0; $a < scalar(@{$self->{to}}); $a++) {
	my $msg = "";

	my ($name, $address) = $self->returnAddressParts($self->{to}[$a]);
	$msg = " \"$name\" <$address>";
      
	## If we're not on the last address add a comma to the end of the line.
	if (($a + 1) != scalar(@{$self->{to}})) {
	  $msg .= ",";
	}
      
	$self->{header} .= $msg . $self->{CRLF};
      }
    }
    ## We always want a To: line so if the only recipients were bcc'd they don't see who it was sent to
    else {
      $self->{header} .= "To: \"Undisclosed Recipients\" <>$self->{CRLF}";
    }
  
    if (scalar(@{$self->{cc}}) > 0 and $self->{opt}{'message-header'} !~ /^Cc:/iom) {
      $self->{header} .= "Cc:";
      for (my $a = 0; $a < scalar(@{$self->{cc}}); $a++) {
	my $msg = "";
      
	my ($name, $address) = $self->returnAddressParts($self->{cc}[$a]);
	$msg = " \"$name\" <$address>";
      
	## If we're not on the last address add a comma to the end of the line.
	if (($a + 1) != scalar(@{$self->{cc}})) {
	  $msg .= ",";
	}

	$self->{header} .= $msg . $self->{CRLF};
      }
    }
  
    if ($self->{opt}{'message-header'} !~ /^Subject:/iom) {
      $self->{header} .= 'Subject: ' . $self->{subject} . $self->{CRLF};                ## Subject
    }
    if ($self->{opt}{'message-header'} !~ /^Date:/iom) {
      $self->{header} .= 'Date: ' . $date . $self->{CRLF};                         ## Date
    }
    if ($self->{opt}{'message-header'} !~ /^X-Mailer:/iom) {
      $self->{header} .= 'X-Mailer: sendEmail-'.$self->{conf}{version}.$self->{CRLF}; ## X-Mailer
    }
    ## I wonder if I should put this in by default?
    # if ($self->{opt}{'message-header'} !~ /^X-Originating-IP:/iom) {
    #     $self->{header} .= 'X-Originating-IP: ['.$self->{conf}{ip}.']'.$self->{CRLF}; ## X-Originating-IP
    # }
    
    ## Encode all messages with MIME.
    if ($self->{opt}{'message-header'} !~ /^MIME-Version:/iom) {
      $self->{header} .=  "MIME-Version: 1.0$self->{CRLF}";
    }
    if ($self->{opt}{'message-header'} !~ /^Content-Type:/iom) {
      my $content_type = 'multipart/mixed';
      if (scalar(@{$self->{attachments}}) == 0) { $content_type = 'multipart/related'; }
      $self->{header} .= "Content-Type: $content_type; boundary=\"$self->{conf}{delimiter}\"$self->{CRLF}";
    }
  
    ## Send additional message header line(s) if specified
    if ($self->{opt}{'message-header'}) {
      $self->{header} .= $self->{opt}{'message-header'};
    }
  
    ## Send the message header to the server
    print $Server $self->{header} . $self->{CRLF};

    ## Start sending the message body to the server
    print $Server "This is a multi-part message in MIME format. To properly display this message you need a MIME-Version 1.0 compliant Email program.$self->{CRLF}";
    print $Server "$self->{CRLF}";

    ## Send message body
    print $Server "--$self->{conf}{delimiter}$self->{CRLF}";
    ## Send a message content-type header:
    ## If the message contains HTML...
    if ($self->{opt}{'message-content-type'} eq 'html' or ($self->{opt}{'message-content-type'} eq 'auto' and $self->{message} =~ /^\s*(<HTML|<!DOCTYPE)/i) ) {
      $self->printmsg("Setting content-type: text/html", 1);
      print $Server "Content-Type: text/html;$self->{CRLF}";
    }
    ## Otherwise assume it's plain text...
    elsif ($self->{opt}{'message-content-type'} eq 'text' or $self->{opt}{'message-content-type'} eq 'auto') {
      $self->printmsg("Setting content-type: text/plain", 1);
      print $Server "Content-Type: text/plain;$self->{CRLF}";
    }
    ## If they've specified their own content-type string...
    else {
      $self->printmsg("Setting custom content-type: ".$self->{opt}{'message-content-type'}, 1);
      print $Server "Content-Type: ".$self->{opt}{'message-content-type'}.";$self->{CRLF}";
    }
    print $Server "        charset=\"" . $self->{opt}{'message-charset'} . "\"$self->{CRLF}";
    print $Server "Content-Transfer-Encoding: 7bit$self->{CRLF}";
    print $Server $self->{CRLF} . $self->{message};

    ## Send Attachemnts
    if (scalar(@{$self->{attachments}}) > 0) {
      ## Disable the alarm so people on modems can send big attachments
      alarm(0) if (OS ne 'win32');  ## alarm() doesn't work in win32

      ## Send the attachments
      foreach my $filename (@{$self->{attachments}}) {
	## This is check 2, we already checked this above, but just in case...
	if ( ! -f $filename ) {
	  $self->printmsg("ERROR => The file [$filename] doesn't exist!  Email will be sent, but without that attachment.", 0);
	}
	elsif ( ! -r $filename ) {
	  $self->printmsg("ERROR => Couldn't open the file [$filename] for reading: $!   Email will be sent, but without that attachment.", 0);
	}
	else {
	  $self->printmsg("DEBUG => Sending the attachment [$filename]", 1);
	  $self->send_attachment($filename);
	}
      }
    }

    ## End the mime encoded message
    print $Server "$self->{CRLF}--$self->{conf}{delimiter}--$self->{CRLF}";
  }

  ## Tell the server we are done sending the email
  print $Server "$self->{CRLF}.$self->{CRLF}";
  if ($self->SMTPchat()) { $self->quit($self->{conf}{error}); return(1); }

  ####################
  #  We are done!!!  #
  ####################

  ## Disconnect from the server (don't SMTPchat(), it breaks when using TLS)
  print $Server "QUIT$self->{CRLF}";
  close $Server;
  $Server = undef;

  #######################################
  ##  Generate exit message/log entry  ##
  #######################################

  if ($self->{conf}{debug} or $self->{conf}{logging}) {
    $self->printmsg("Generating a detailed exit message", 3);

    ## Put the message together
    my $output = "Email was sent successfully!  From: <" . ($self->returnAddressParts($self->{from}))[1] . "> ";

    if (scalar(@{$self->{to}}) > 0) {
      $output .= "To: ";
      for ($a = 0; $a < scalar(@{$self->{to}}); $a++) {
	$output .= "<" . ($self->returnAddressParts($self->{to}[$a]))[1] . "> ";
      }
    }
    if (scalar(@{$self->{cc}}) > 0) {
      $output .= "Cc: ";
      for ($a = 0; $a < scalar(@{$self->{cc}}); $a++) {
	$output .= "<" . ($self->returnAddressParts($self->{cc}[$a]))[1] . "> ";
      }
    }
    if (scalar(@{$self->{bcc}}) > 0) {
      $output .= "Bcc: ";
      for ($a = 0; $a < scalar(@{$self->{bcc}}); $a++) {
	$output .= "<" . ($self->returnAddressParts($self->{bcc}[$a]))[1] . "> ";
      }
    }
    $output .= "Subject: [$self->{subject}] " if ($self->{subject});
    if (scalar(@{$self->{attachments_names}}) > 0) {
      $output .= "Attachment(s): ";
      foreach(@{$self->{attachments_names}}) {
	$output .= "[$_] ";
      }
    }
    $output .= "Server: [$self->{conf}{server}:$self->{conf}{port}]";

    ######################
    #  Exit the program  #
    ######################

    ## Print / Log the detailed message
    $self->quit($output);
  }
  return(0);
}
1;
