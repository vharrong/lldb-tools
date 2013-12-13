#!/usr/bin/env perl

# This script performs Run Length Decoding on a packet encoded in the gdbserver RLE protocol.
# This script is not particularly useful but I used it to be able to track the register-info
# packet from gdbserver to lldb to ensure I was looking at exactly the right data.

use strict;
use warnings;

my $inp = 'fcf*"a8e3cebe10*"0f*"ffc08a3c710*"00d48a3c71fc0*"088b3c71140*"d8c3cf411ce5cebea8e3cebe88e3cebeebc5114054470b4010* e20b80*"120*"8e0**360*"5c0*"750*"e0968e762e0069006e007000750074006d006500740068006f0064002e006c006100740*}0*>10*+70*H800040*;40*780*230*"030003030303070707072f0*"30*(10*"010*"010*"010* 80b30* 80b60* 40*)10*!60';

my $inpLength = length $inp;

print "Input length $inpLength\n";

my @inpChars = unpack 'a'x$inpLength, $inp;

my $out = "";

my $lastChar;
for (my $i = 0; $i < $inpLength; ) {
    my $c1 = $inpChars[$i++];
    if ($c1 eq "#") {
        die;  # Illegal unless escaped or indicating start of checksum
    }
    if ($c1 eq "}") {
        # Escape character
        my $c2 = $inpChars[$i++] ^ 0x20;
        $out .= $c2;
        $lastChar = $c2;
        next;
    }
    if ($c1 eq "*") {
        my $c2 = $inpChars[$i++];
        my $count = ord($c2) - 29;
        defined $lastChar
            or die;
        $out .= ($lastChar x $count);
    } else {
        $out .= $c1;
        $lastChar = $c1;
    }
}

my $outLength = length $out;

print "Output length $outLength\n";

print "$out\n";

# Output: 'fcffffffa8e3cebe10000000ffffffffc08a3c7100000000d48a3c71fc000000088b3c7114000000d8c3cf411ce5cebea8e3cebe88e3cebeebc5114054470b4010000e20b8000000120000008e00000000000000360000005c00000075000000e0968e762e0069006e007000750074006d006500740068006f0064002e006c006100740000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000007000000000000000000000000000000000000000000008000400000000000000000000000000000004000000000000000000000000000800000000000000000000003000000030003030303070707072f00000030000000000001000000010000000100000001000080b3000080b600004000000000000010000060'
