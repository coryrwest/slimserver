package Slim::Buttons::Input::Bar;

# $Id: Bar.pm,v 1.1 2004/08/21 17:42:29 kdf Exp $
# SlimServer Copyright (c) 2001-2004 Sean Adams, Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;

use Slim::Buttons::Common;
use Slim::Utils::Misc;
use Slim::Display::Display;
use Slim::Utils::Strings qw (string);

###########################
#Button mode specific junk#
###########################
my %functions = (
	#change character at cursorPos (both up and down)
	'up' => sub {
			my ($client,$funct,$functarg) = @_;
			changePos($client,1,$funct);
		}
	,'down' => sub {
			my ($client,$funct,$functarg) = @_;
			changePos($client,-1,$funct);
		}
	#call callback procedure
	,'exit' => sub {
			my ($client,$funct,$functarg) = @_;
			if (!defined($functarg) || $functarg eq '') {
				$functarg = 'exit'
			}
			exitInput($client,$functarg);
		}
	,'passback' => sub {
			my ($client,$funct,$functarg) = @_;
			my $parentMode = Slim::Buttons::Common::param($client,'parentMode');
			if (defined($parentMode)) {
				Slim::Hardware::IR::executeButton($client,$client->lastirbutton,$client->lastirtime,$parentMode);
			}
		}
);

sub changePos {
	my ($client, $dir,$funct) = @_;
	my $listRef = Slim::Buttons::Common::param($client,'listRef');
	my $listIndex = Slim::Buttons::Common::param($client,'listIndex');

	if (($listIndex == 0 && $dir < 0) || ($listIndex == (scalar(@$listRef) - 1) && $dir > 0)) {
			#not wrapping and at end of list
			return;
	}
	
	my $accel = 8; # Hz/sec
	my $rate = 50; # Hz
	my $inc = 1;
	my $mid = Slim::Buttons::Common::param($client,'mid')||0;
	my $min = Slim::Buttons::Common::param($client,'min')||0;
	my $max = Slim::Buttons::Common::param($client,'max')||100;
	my $midpoint = ($mid-$min)/($max-$min)*(scalar(@$listRef) - 1);
	my $newposition;
	
	my $cmd;
	if (Slim::Hardware::IR::holdTime($client) > 0) {
		$inc *= Slim::Hardware::IR::repeatCount($client,$rate,$accel);
	}
	
	my $currVal = $listIndex;
	if ($dir == 1) {
		$newposition = $listIndex+$inc;
		if ($currVal < ($midpoint - 1.5) && ($currVal + $inc) >= ($midpoint - 1.5)) {
			# make the midpoint sticky by resetting the start of the hold
			$cmd = $midpoint;
			Slim::Hardware::IR::resetHoldStart($client);
		}
	} else {
		$newposition = $listIndex-$inc;
		if ($currVal > ($midpoint + 1.5) && ($currVal - $inc) <= ($midpoint + 1.5)) {
			# make the midpoint sticky by resetting the start of the hold
			$newposition = $midpoint;
			Slim::Hardware::IR::resetHoldStart($client);
		}
	}

	$newposition = scalar(@$listRef)-1 if $newposition > scalar(@$listRef)-1;
	$newposition = 0 if $newposition < 0;
	my $valueRef = Slim::Buttons::Common::param($client,'valueRef');
	$$valueRef = $listRef->[$newposition];
	Slim::Buttons::Common::param($client,'listIndex',int($newposition));
	my $onChange = Slim::Buttons::Common::param($client,'onChange');
	if (ref($onChange) eq 'CODE') {
		my $onChangeArgs = Slim::Buttons::Common::param($client,'onChangeArgs');
		my @args;
		push @args, $client if $onChangeArgs =~ /c/i;
		push @args, $$valueRef if $onChangeArgs =~ /v/i;
		$onChange->(@args);
	}
	$client->update();
}

sub lines {
	my $client = shift;
	my $value = shift;
	my $header = shift;
	my ($line1, $line2);


	my $valueRef = defined $value ? \$value : Slim::Buttons::Common::param($client,'valueRef');
	
	$line1 = defined $header ? $header : Slim::Buttons::Input::List::getExtVal($client,$$valueRef,undef,'header');
	if (!($client->linesPerScreen() == 1)) {
		my $max = Slim::Buttons::Common::param($client,'max') || 100;
		my $mid = Slim::Buttons::Common::param($client,'mid') || 0;
		my $min = Slim::Buttons::Common::param($client,'min') || 0;

		my $val = int(($$valueRef - $min)*100/($max-$min));
		$line2 = $client->sliderBar($client->displayWidth(), $val,($mid-$min)/($max-$min)*100,1);
	} elsif (!Slim::Buttons::Common::param($client,'barOnDouble')) {
		$line2 = $line1;
	}

	return ($line1,$line2);
}


sub getFunctions {
	return \%functions;
}

sub setMode {
	my $client = shift;
	#my $setMethod = shift;
	#possibly skip the init if we are popping back to this mode
	#if ($setMethod ne 'pop') {
		if (!init($client)) {
			Slim::Buttons::Common::popModeRight($client);
		}
	#}
	$client->lines(\&lines);
}
# set unsupplied parameters to the defaults
# listRef = none # reference to list of internal values, exit mode if not supplied
# header = 'Select item:' # message displayed on top line, can be a scalar, a code ref
	# , or an array ref to a list of scalars or code refs
# headerArgs = CV
# stringHeader = undef # if true, put the value of header through the string function
	# before displaying it.
# headerAddCount = undef # if true add (I of T) to end of header
	# where I is the 1 based index and T is the total # of items
# valueRef =  # reference to value to be selected
# callback = undef # function to call to exit mode
# listIndex = 0 or position of valueRef in listRef
# noWrap = undef # whether or not the list wraps at the ends
# externRef = undef
# externRefArgs = CV
# stringExternRef = undef # same as with stringHeader, but for the value of externRef
# overlayRef = undef
# overlayRefArgs = CV
# onChange = undef
# onChangeArgs = CV

# other parameters used
# isSorted = undef # whether the interal or external list is sorted 
	#(I for internal, E for external, undef or anything else for unsorted)

sub init {
	my $client = shift;
	if (!defined(Slim::Buttons::Common::param($client,'parentMode'))) {
		my $i = -2;
		while ($client->modeStack->[$i] =~ /^INPUT./) { $i--; }
		Slim::Buttons::Common::param($client,'parentMode',$client->modeStack->[$i]);
	}
	if (!defined(Slim::Buttons::Common::param($client,'header'))) {
		Slim::Buttons::Common::param($client,'header','Select item:');
	}
	if (!defined(Slim::Buttons::Common::param($client,'min'))) {
		Slim::Buttons::Common::param($client,'min',0);
	}
	if (!defined(Slim::Buttons::Common::param($client,'mid'))) {
		Slim::Buttons::Common::param($client,'mid',0);
	}	
	if (!defined(Slim::Buttons::Common::param($client,'max'))) {
		Slim::Buttons::Common::param($client,'max',100);
	}
	if (!defined(Slim::Buttons::Common::param($client,'increment'))) {
		Slim::Buttons::Common::param($client,'increment',2.5);
	}
	if (!defined(Slim::Buttons::Common::param($client,'barOnDouble'))) {
		Slim::Buttons::Common::param($client,'barOnDouble',0);
	}


	my $min = Slim::Buttons::Common::param($client,'min');
	my $mid = Slim::Buttons::Common::param($client,'mid');
	my $max = Slim::Buttons::Common::param($client,'max');
	my $step = Slim::Buttons::Common::param($client,'increment');

	my $listRef;
	my $i;
	my $j=0;
	for ($i = $min;$i<=$max;$i=$i + $step) {
		$listRef->[$j] = $i;
		$j++;
	}
	Slim::Buttons::Common::param($client,'listRef',$listRef);
	my $listIndex = Slim::Buttons::Common::param($client,'listIndex');
	my $valueRef = Slim::Buttons::Common::param($client,'valueRef');
	if (!defined($listIndex)) {
		$listIndex = 0;
	} elsif ($listIndex > $#$listRef) {
		$listIndex = $#$listRef;
	}
	while ($listIndex < 0) {
		$listIndex += scalar(@$listRef);
	}
	if (!defined($valueRef)) {
		$$valueRef = $listRef->[$listIndex];
		Slim::Buttons::Common::param($client,'valueRef',$valueRef);
	} elsif (!ref($valueRef)) {
		$$valueRef = $valueRef;
		Slim::Buttons::Common::param($client,'valueRef',$valueRef);
	}
	if ($$valueRef ne $listRef->[$listIndex]) {
		my $newIndex;
		for ($newIndex = 0; $newIndex < scalar(@$listRef); $newIndex++) {
			last if $$valueRef eq $listRef->[$newIndex];
		}
		if ($newIndex < scalar(@$listRef)) {
			$listIndex = $newIndex;
		} else {
			$$valueRef = $listRef->[$listIndex];
		}
	}

	Slim::Buttons::Common::param($client,'listIndex',$listIndex);

	if (!defined(Slim::Buttons::Common::param($client,'onChangeArgs'))) {
		Slim::Buttons::Common::param($client,'onChangeArgs','CV');
	}
	if (!defined(Slim::Buttons::Common::param($client,'headerArgs'))) {
		Slim::Buttons::Common::param($client,'headerArgs','CV');
	}
	return 1;
}

sub exitInput {
	my ($client,$exitType) = @_;
	my $callbackFunct = Slim::Buttons::Common::param($client,'callback');
	if (!defined($callbackFunct) || !(ref($callbackFunct) eq 'CODE')) {
		if ($exitType eq 'right') {
			$client->bumpRight();
		} elsif ($exitType eq 'left') {
			Slim::Buttons::Common::popModeRight($client);
		} else {
			Slim::Buttons::Common::popMode($client);
		}
		return;
	}
	$callbackFunct->(@_);
}

1;
