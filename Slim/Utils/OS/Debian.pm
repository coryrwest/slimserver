package Slim::Utils::OS::Debian;

# Squeezebox Server Copyright 2001-2009 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License, 
# version 2.

use strict;
use FindBin qw($Bin);

use base qw(Slim::Utils::OS::Linux);

sub initDetails {
	my $class = shift;

	$class->{osDetails} = $class->SUPER::initDetails();

	# package specific addition to @INC to cater for plugin locations
	$class->{osDetails}->{isDebian} = 1 ;

	unshift @INC, '/usr/share/squeezebox';
	unshift @INC, '/usr/share/squeezebox/CPAN';
	
	# Bug 2659 - maybe. Remove old versions of modules that are now in the $Bin/lib/ tree.
	unlink("$Bin/CPAN/MP3/Info.pm");
	unlink("$Bin/CPAN/DBIx/ContextualFetch.pm");

	return $class->{osDetails};
}

=head2 dirsFor( $dir )

Return OS Specific directories.

Argument $dir is a string to indicate which of the Squeezebox Server directories we
need information for.

=cut

sub dirsFor {
	my ($class, $dir) = @_;

	my @dirs = ();
	
	if ($dir =~ /^(?:oldprefs|updates)$/) {

		push @dirs, $class->SUPER::dirsFor($dir);

	} elsif ($dir =~ /^(?:Firmware|Graphics|HTML|IR|MySQL|SQL|lib|Bin)$/) {

		push @dirs, "/usr/share/squeezebox/$dir";

	} elsif ($dir eq 'Plugins') {
			
		push @dirs, $class->SUPER::dirsFor($dir);
		push @dirs, "/usr/share/perl5/Slim/Plugin", "/usr/share/squeezebox/Plugins";
		
	} elsif ($dir =~ /^(?:strings|revision)$/) {

		push @dirs, "/usr/share/squeezebox";

	} elsif ($dir eq 'libpath') {

		push @dirs, "/usr/share/squeezebox";

	# Because we use the system MySQL, we need to point to the right
	# directory for the errmsg. files. Default to english.
	} elsif ($dir eq 'mysql-language') {

		push @dirs, "/usr/share/mysql/english";

	} elsif ($dir =~ /^(?:types|convert)$/) {

		push @dirs, "/etc/squeezebox";

	} elsif ($dir =~ /^(?:prefs)$/) {

		push @dirs, $::prefsdir || "/var/lib/squeezebox/prefs";

	} elsif ($dir eq 'log') {

		push @dirs, $::logdir || "/var/log/squeezebox";

	} elsif ($dir eq 'cache') {

		push @dirs, $::cachedir || "/var/lib/squeezebox/cache";

	} elsif ($dir =~ /^(?:music|playlists)$/) {

		push @dirs, '';

	} else {

		warn "dirsFor: Didn't find a match request: [$dir]\n";
	}

	return wantarray() ? @dirs : $dirs[0];
}

# Bug 9488, always decode on Ubuntu/Debian
sub decodeExternalHelperPath {
	return Slim::Utils::Unicode::utf8decode_locale($_[1]);
}

sub scanner {
	return '/usr/sbin/squeezebox-scanner';
}


1;