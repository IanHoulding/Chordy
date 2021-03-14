package CP::Collection;

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
use CP::Cconst qw/:OS :PATH :SMILIE :COLOUR/;
use CP::Global qw/:PATH :FUNC :WIN :OPT :PRO :MEDIA :SETL/;
use CP::Pop qw/:POP :MENU/;
use File::Path qw(make_path remove_tree);
use CP::Cmsg;

#
# A 'Collection' is a very simple Object and
# is a HASH of 'name/path' key/data pairs stored in Chordy.cfg
#
# Our $CurrentCollection keeps track of the currently selected Collection.
#
our %All;

our $CurrentCollection = '';

sub new {
  my($proto,$name) = @_;
  my $class = ref($proto) || $proto;

  my $self = {};
  bless $self, $class;

  if ($CurrentCollection eq '') {
    if (-e USER."/Chordy.cfg") {
      load();
    } else {
      $CurrentCollection = 'Chordy';
      %All = ( Chordy => $Parent );
      save();
    }
  }
  if (defined $name && defined $All{$name}) {
    $CurrentCollection = $name;
  }
  $self->{name} = $CurrentCollection;
  $self->{path} = $All{$CurrentCollection};
  $self->{fullPath} = $self->{path}.'/'.$CurrentCollection;
  return($self);
}

sub load {
  our $which;
  our %coll;
  do USER."/Chordy.cfg";
  $CurrentCollection = $which;
  #
  # Now read the file options into our hash.
  #
  foreach my $c (keys %coll) {
    $All{$c} = $coll{$c};
  }
  $Parent = $All{$which};
  $Home = "$Parent/$which";
  undef %coll;
}

sub save {
  my $OFH = openConfig(USER."/Chordy.cfg");
  return(0) if ($OFH == 0);

  my $current =  $CurrentCollection;
  print $OFH "\$which = '$CurrentCollection';\n";
  print $OFH "\%coll = (\n";

  foreach my $c (sort keys %All) {
    print $OFH "  '$c' => '$All{$c}',\n";
  }

  printf $OFH ");\n1;\n";

  close($OFH);
}

sub path {
  my($self,$name) = @_;

  $All{$name};
}

sub list {
  my $list = [];
  foreach my $k (sort keys %All) {
    push(@{$list}, $k) if ($k ne $CurrentCollection);
  }
  $list;
}

sub listAll {
  my $list = [sort keys %All];
}

sub change {
  my($self,$name) = @_;

  if (defined $All{$name}) {
    $CurrentCollection = $name;
    $self->{name} = $name;
    $self->{path} = $Parent = $All{$name};
    $self->{fullPath} = $Home = "$Parent/$name";
    $Path->change($Home);
    $Opt->load();
    $Media = $Media->change($Opt->{Media});
    $Swatches->load();
    CP::Win::newLook();
    if (defined $MW && Tkx::winfo_exists($MW) && defined $AllSets) {
      $AllSets->change();
    }
    save($self);
  }
}

sub add {
  my($self,$name) = @_;

  if ($name eq "") {
    message(SAD, "Can't add a new Collection without a name!");
    return(0);
  } else {
    my $path = Tkx::tk___chooseDirectory(
      -initialdir => "$Home",
      -title => "Select parent folder you want\nthe Collection to be in:");
    if (defined $path) {
      $path =~ s/\/$//;
      my $err = 0;
      my $dir = "$path/$name";
      make_path($dir, {chmod => 0777, error => \$err}) if ($dir ne USER);
      if ($err && @$err) {
	my($file, $message) = %{$err->[0]};
	errorPrint("Problem creating folder '$file':\n   $message\n");
	message(SAD, "Failed to make path:\n$dir\n\n(See error log for details)");
      } else {
	foreach my $d (qw/PDF Pro Tab Temp/) {
	  make_path("$dir/$d", {chmod => 0777}) if (! -d "$dir/$d");
	}
	foreach my $f (qw/Option.cfg SetList.cfg SMTP.cfg Swatch.cfg/) {
	  if (-e "$Home/$f" && ! -e "$dir/$f") { # The 2nd test applies when recreating
	    my $txt = read_file("$Home/$f");     # a previously existing Collection.
	    write_file("$dir/$f", $txt);
	  }
	}
	$All{$name} = $path;
#	change($self, $name);
	return(1);
      }
    }
  }
  return(0);
}

sub reName {
  my($self,$name) = @_;

  if ($name eq "") {
    message(SAD, "Can't rename a Collection without a name!");
    return(0);
  } else {
    if (exists $All{$name}) {
      message(SAD, "Sorry, that Collection already exists!");
      return(0);
    }
    if ($name eq 'Chordy') {
      message(SAD, "Sorry, the one Collection you CAN'T rename is Chordy!");
      return(0);
    }
    rename("$Home", "$Parent/$name");
    # $Parent doesn't change.
    $All{$name} = $Parent;
    delete $All{$CurrentCollection};
    change($self, $name);
    CP::Chordy::showCollChange();
  }
  return(1);
}

sub _delete {
  my($name,$delFF) = @_;

  if (scalar keys %All == 1) {
    message(SAD, "You can't delete the ONLY Collection!");
  } else {
    my $msg = "Are you sure you want to delete Collection:\n   $name";
    $msg .= "\nand ALL its associated files?" if ($delFF);
    if (msgYesNo($msg) eq 'Yes') {
      if ($delFF) {
	if ($name eq 'Chordy') {
	  # Special case - just clean up the folder but leave the
	  # "Global" config files
	  remove_tree(USER."/PDF", {keep_root => 1});
	  remove_tree(USER."/Pro", {keep_root => 1});
	  remove_tree(USER."/Tab", {keep_root => 1});
	  remove_tree(USER."/Temp", {keep_root => 1});
	  unlink glob USER."/SetList*";
	  unlink glob USER."/*.bak";
	} else {
	  remove_tree("$All{$name}/$name");
	}
      }
      delete $All{$name};
    }
  }
}

sub _move {
  my($self,$del) = @_;

  my $path = $self->{path};
  my $name = $self->{name};
  my $pop = CP::Pop->new(1, '.mv', '');
  return if ($pop eq '');
  my($top,$wt) = ($pop->{top}, $pop->{frame});

  my $tf = $wt->new_ttk__frame();
  $tf->g_grid(qw/-row 0 -column 0 -sticky nsew -padx 4 -pady 6/);

  my $hl = $wt->new_ttk__separator(-orient => 'horizontal');
  $hl->g_grid(qw/-row 1 -column 0 -sticky ew/);

  my $bf = $wt->new_ttk__frame();
  $bf->g_grid(qw/-row 2 -column 0 -sticky ew -padx 4 -pady 6/);

  my($done,$to);
  my $fl = $tf->new_ttk__label(-text => 'From:');
  $fl->g_grid(qw/-row 0 -column 0 -sticky e/, -pady => [0,4]);

  my $from = "$path/$name";
  my $fe = $tf->new_ttk__entry(
    -textvariable => \$from,
    -state => 'disabled',
    -width => 50);
  $fe->g_grid(qw/-row 0 -column 1 -sticky w/, -pady => [0,4]);

  my $tl = $tf->new_ttk__label(-text => 'To:');
  $tl->g_grid(qw/-row 1 -column 0 -sticky e/, -pady => [0,4]);

  my $te = $tf->new_ttk__entry(
    -textvariable => \$to,
    -width => 50);
  $te->g_grid(qw/-row 1 -column 1 -sticky w/, -pady => [0,4]);

  my $tb = $tf->new_ttk__button(
    -text => "Browse ...",
    -command => sub {
      $to = Tkx::tk___chooseDirectory(
	-title => "Choose Destination Folder",
	-initialdir => "$Home");
      $to =~ s/\/$//;
      $top->g_raise();
    });
  $tb->g_grid(qw/-row 1 -column 2 -sticky w -padx 6/, -pady => [0,4]);

  my $cancel = $bf->new_ttk__button(-text => "Cancel", -command => sub{$done = "Cancel";});
  $cancel->g_grid(qw/-row 0 -column 0 -padx 60/);

  my $ok = $bf->new_ttk__button(-text => "Go", -command => sub{$done = "GO";});
  $ok->g_grid(qw/-row 0 -column 1 -padx 60/);

  $top->g_raise();
  Tkx::vwait(\$done);

  if ($done eq 'GO') {
    if (defined $to && $to ne '') {
      $cancel->g_destroy();
      $ok->m_configure(-text => 'OK');
      $to =~ s/\/$//;
      my $lf = $tf->new_ttk__labelframe(-text => " Folders and Files moved ");
      $lf->g_grid(qw/-row 2 -column 0 -columnspan 3 -sticky nsew -pady/ => [0,4]);

      my $txt = $lf->new_tk__text(
	-font => "\{$EditFont{family}\} $EditFont{size}",
	-bg => 'white',
	-borderwidth => 2,
	-highlightthickness => 1,
	-height => 30);
      $txt->g_grid(qw/-row 0 -column 0 -sticky nsew/, -pady => [0,4]);

      my $scv = $lf->new_ttk__scrollbar(-orient => "vertical", -command => [$txt, "yview"]);
      $scv->g_grid(qw/-row 0 -column 1 -sticky nsw/);

      my $sch = $lf->new_ttk__scrollbar(-orient => "horizontal", -command => [$txt, "xview"]);
      $sch->g_grid(qw/-row 1 -column 0 -columnspan 2 -sticky new/);

      $txt->configure(-yscrollcommand => [$scv, 'set']);
      $txt->configure(-xscrollcommand => [$sch, 'set']);

      my $sz = 12;
      $txt->tag_configure('DIR',  -font => "\{$EditFont{family}\} $sz bold");
      $txt->tag_configure('FILE', -font => "\{$EditFont{family}\} $sz");
      if (! -d "$to/$name") {
	make_path("$to/$name", {chmod => 0777});
      }
      if (rmove($txt, "$path/$name", "$to/$name", '')) {
	remove_tree("$path/$name") if ($del);
	$All{$name} = $to;
	change($self, $name);
      }
      $txt->insert('end', "\nDONE\n", 'DIR');
      $txt->see('end');
      Tkx::update();
    }
    Tkx::vwait(\$done);
  }
  $pop->popDestroy();
}

sub rmove {
  my($rotxt,$src,$dst,$ind) = @_;

  opendir my $dh, "$src" or die "rmove() couldn't open folder: '$src'\n";
  $rotxt->configure(-state => 'normal');
  $rotxt->insert('end', $ind.$dst."\n", 'DIR');
  $rotxt->yview('end');
  Tkx::update();
  my $ret = 1;
  foreach my $f (grep !/^\.\.?$/, readdir $dh) {
    if (-d "$src/$f") {
      make_path("$dst/$f", {chmod => 0777}) if (! -d "$dst/$f");
      $ret = rmove("$src/$f", "$dst/$f", $rotxt, '  '.$ind);
    } else {
      my $txt = read_file("$src/$f");
      if (! defined $txt) {
	errorPrint("CP::Collection::rmove failed to read in '$src/$f'\n");
	$ret = 0;
      }
      if (write_file("$dst/$f", $txt) == 0) {
	errorPrint("CP::Collection::rmove failed to write '$dst/$f'\n");
	$ret = 0;
      }
      $rotxt->insert('end', $ind."  $dst/$f\n", 'FILE');
      $rotxt->yview('end');
      Tkx::update();
    }
    last if ($ret == 0);
  }
  $rotxt->configure(-state => 'disabled');
  $ret;
}

sub edit {
  my($self) = shift;

  my $pop = CP::Pop->new(0, '.ec', 'Edit Collection');
  return if ($pop eq '');
  my($top,$wt) = ($pop->{top}, $pop->{frame});
  $wt->m_configure(-padding => [0,0,0,0]);

  my $tf = $wt->new_ttk__frame(-padding => [4,4,4,4]);
  $tf->g_pack(qw/-side top -fill x/);

  my $sepa = $wt->new_ttk__separator(qw/-orient horizontal/);
  $sepa->g_pack(qw/-side top -fill x/, -pady => [4,8]);

  my $mf = $wt->new_ttk__frame();
  $mf->g_pack(qw/-side top -fill x/);

  my $sepb = $wt->new_ttk__separator(qw/-orient horizontal/);
  $sepb->g_pack(qw/-side top -fill x/, -pady => [8,2]);

  my $bf = $wt->new_ttk__frame();
  $bf->g_pack(qw/-side top -fill x/);

  my($a,$b,$c,$ca,$cb,$d,$e,$f,$g,$h,$i,$j);

  my $orgcol = $self->{name};
  my $delFF = 0;
  my $newColl = $self->{name};
  my $newPath = $self->{path};
  my $PDFpath = $Opt->{PDFpath};
  my $newName = '';
  $a = $tf->new_ttk__label(-text => "Collection",);
  $b = popButton($tf,
		 \$newColl,
		 sub{
		   if ($newColl ne $self->{name} && defined $All{$newColl}) {
		     $newPath = $All{$newColl};
		     $PDFpath = commonPDF("$newPath/$newColl/Option.cfg");
		     $top->g_raise();
		   }
		 },
		 sub{listAll()},
		 -width => 20,
		 -style => 'Menu.TButton',
      );

  $c = $tf->new_ttk__button(-text => 'Delete',
			    -command => sub{_delete($newColl, $delFF);
					    if ($newColl eq $orgcol) {
					      my $l = listAll();
					      my $nc = shift(@{$l});
					      change($self, $nc);
					      CP::Chordy::showCollChange();
					      $newColl = $orgcol = $nc;
					      $PDFpath = $Opt->{PDFpath};
					    }
					    $top->g_raise();}
                           );
  $ca = $tf->new_ttk__button(-text => 'Move',
			     -command => sub{_move($self,$delFF);$top->g_raise();}
                            );
  $cb = $tf->new_ttk__checkbutton(-style => 'My.TCheckbutton',
				  -compound => 'left',
				  -image => ['xtick', 'selected', 'tick'],
				  -text => " Delete all\n Folders/Files",
				  -variable => \$delFF);
  $d = $tf->new_ttk__label(-text => "Path");
  $e = $tf->new_ttk__label(-textvariable => \$newPath, -width => 50);

  $a->g_grid(qw/-row 0 -column 0 -sticky e/);
  $b->g_grid(qw/-row 0 -column 1 -sticky w -padx 4/);
  $c->g_grid(qw/-row 0 -column 2 -padx 10/);
  $ca->g_grid(qw/-row 0 -column 3 -padx 5/);
  $cb->g_grid(qw/-row 0 -column 4 -padx 5/);
  $d->g_grid(qw/-row 1 -column 0 -sticky e/, -pady => 4);
  $e->g_grid(qw/-row 1 -column 1 -columnspan 4 -sticky w -padx 4 -pady 4/);

  $g = $tf->new_ttk__label(-text => "New Name");
  $h = $tf->new_ttk__entry(-width => 40,
			   -textvariable => \$newName);
  $i = $tf->new_ttk__button(-text => 'New',
			    -command => sub{
			      if (add($self, $newName)) {
				message(SMILE, "Collection \"$newName\" created.", 1);
				save();
#				main::selectClear();
			      }
			      $newName = "";
			      $top->g_raise();
			    });
  $j = $tf->new_ttk__button(-text => 'Rename',
			    -command => sub{
			      if ($newColl ne $orgcol) {
				if ($newName ne '') {
				  rename("$newPath/$newColl", "$newPath/$newName");
				  delete($All{$newColl});
				  $All{$newName} = $newPath;
				  $newColl = $newName;
				  save();
				} else {
				  message(SAD, "Can't rename a Collection without a name!");
				}
			      } else {
				if (reName($self, $newName)) {
				  $newColl = $orgcol = $newName;
				}
			      }
			      $top->g_raise();
			    });

  $g->g_grid(qw/-row 3 -column 0 -sticky e/);
  $h->g_grid(qw/-row 3 -column 1 -sticky w -padx 4/);
  $i->g_grid(qw/-row 3 -column 2 -padx 5/);
  $j->g_grid(qw/-row 3 -column 3 -padx 5/);

  $a = $mf->new_ttk__label(-text => "Common PDF Path");
  $b = $mf->new_ttk__entry(qw/-width 40 -textvariable/ => \$PDFpath);
  $c = $mf->new_ttk__button(
    -text => "Browse ...",
    -command => sub{
      my $dir = Tkx::tk___chooseDirectory(
	-title => "Choose Common Folder",
	-initialdir => "$Home");
      $dir =~ s/\/$//;
      if ($dir ne '') {
	$PDFpath = $dir;
      }
      $wt->g_focus();
    },
      );
  $d = $mf->new_ttk__button(
    -text => "Set",
    -width => 6,
    -style =>'Green.TButton',
    -command => sub{my $orgopt = $Path->{Option};
		    $Path->{Option} = "$newPath/$newColl/Option.cfg";
		    our($version,%opts);
		    do "$Path->{Option}";
		    $opts{PDFpath} = $PDFpath;
		    CP::Opt::save(\%opts);
		    $Path->{Option} = $orgopt;}, );

  $a->g_grid(qw/-row 0 -column 0 -sticky e -padx 4/);
  $b->g_grid(qw/-row 0 -column 1 -sticky w/);
  $c->g_grid(qw/-row 0 -column 2 -padx 16/);
  $d->g_grid(qw/-row 0 -column 3/);

  my $Done = '';

  my $ok = $bf->new_ttk__button(
    -text => "Close",
    -command => sub{$Done = "OK";});
  $ok->g_pack(-side => 'top', -pady => [4,8]);

  Tkx::vwait(\$Done);

  $pop->popDestroy();
}

sub commonPDF {
  my($path) = shift;

  if (-e $path) {
    our($version,%opts);
    do "$path";
    return(defined $opts{PDFpath} ? $opts{PDFpath} : '');
  }
  return('');
}

1;
