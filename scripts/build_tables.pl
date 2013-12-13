#!/usr/bin/env perl
package build_tables;

# Generates register name to gdb register numbers from gdbserver
# output from this command from within gdb:
#
# (gdb) maint print raw-registers
#
# Also generates register name to GCC DWARF regnum info.
#
# Call with:
#   perl build_tables.py {raw-registers-output-file} \
#     {path-to-ARM_DWARF_Registers.h}
#
# Any register aliases should be declared in the hash table at
# the top of the file.  Missing aliases will be flagged.
#
# Authors: Todd Fiala (tfiala@)
#          Steve Pucci (spucci@)

use warnings;
use strict;
use Carp;
use POSIX;

# Register aliases declarations.
# The keys are the prefixes for (cooked) registers which are aliased to some other registers.
# The values are the prefixes for the equivalent register sets.
my %register_aliases = (
    "q" => "d",
    "s" => "d"
);

# Sizes (in bytes) of registers with given prefix, determined as part of the first pass
my %register_sizes_by_prefix;

sub parse_raw_registers_output {
    my ($raw_filename) = @_;
    my %gdb_reg_num;
    my %gdb_reg_infos;

    open my ($fh), '<', $raw_filename or
        croak "Failed to open file $raw_filename for reading: $?";

    while (<$fh>) {
        if (m/^\s*#/) {
            # skip comments
        } elsif (m/^\s*Name/) {
            # skip column labels
        } elsif (m/^\s*''/) {
            # skip non-registers
        } else {
            m/^\s*(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)(\s+(\S+))?/ or croak "Failed to match register line format: $_";
            my $reg_name = $1;
            my $gdb_reg_num = $2;
            my $rel_index = $3; # not sure precisely what this is
                             # TODO look up
            my $byte_offset = $4;
            my $byte_size = $5;
            my $raw_value = $8;

            my $prefix;  # e.g., "q"
            my $index;   # e.g., "15"
            if ($reg_name =~ /^([a-z]+)(\d+)$/) {
                $prefix = $1;
                $index = $2;
                my $existing_size = $register_sizes_by_prefix{$prefix};
                if (defined $existing_size) {
                    $existing_size == $byte_size
                        or croak "Registers with same prefix ($prefix) have different sizes " .
                                 "($existing_size and $byte_size (for $reg_name))";
                } else {
                    $register_sizes_by_prefix{$prefix} = $byte_size;
                }
            }

            if ((defined $raw_value) && ($raw_value eq "<cooked>")) {
                defined $prefix
                    or croak "Cooked value register with unexpected name pattern (expected letter(s)+number): $reg_name";
                defined ($register_aliases{$prefix})
                    or croak "Cooked value register with prefix '$prefix' has no alias definition\n";
            }

            # determine register set - right now using rollover of gdb
            # maintenance Rel field to do this, might be totally wrong.
            my $reg_set;
            if ($reg_name =~ m/^[sq]/) {
                $reg_set = 1;
            } else {
                $reg_set = 0;
            }

            # determine register format
            my $reg_format;
            my $reg_encoding;
            if ($reg_name =~ m/^q/) {
                # neon q registers
                $reg_format = 'eFormatVectorOfUInt8';
                $reg_encoding = 'eEncodingVector';
            } elsif ($reg_name =~ m/^d/) {
                # neon d registers
                $reg_format = 'eFormatFloat';
                $reg_encoding = 'eEncodingIEEE754';
            } elsif ($reg_name =~ m/^s[^p]/) {
                $reg_format = 'eFormatFloat';
                $reg_encoding = 'eEncodingIEEE754';
            } else {
                $reg_format = 'eFormatHex';
                $reg_encoding = 'eEncodingUint';
            }

            my $alt_name;

            $gdb_reg_num{$reg_name} = $gdb_reg_num;
            $gdb_reg_infos{$reg_name} = {
                name => $reg_name,
                set => $reg_set,
                byte_offset => $byte_offset,
                byte_size => $byte_size,
                format => $reg_format,
                encoding => $reg_encoding,
                alt_name => $alt_name,
                prefix => $prefix,
                index => $index
            }
        }
    }

    close($fh) or croak "Failed to close file: $?";

    return (\%gdb_reg_num,\%gdb_reg_infos);
}

sub maybe_add_register {
    my ($gdb_regnum_ref, $dwarf_regnum_ref, $regname, $enum_counter_ref) = @_;

    # assign the reg name if gdb knows about it
    if (exists $gdb_regnum_ref->{$regname}) {
        $dwarf_regnum_ref->{$regname} = $$enum_counter_ref;
        printf("Setting %s to %d\n", $regname, $$enum_counter_ref);
    } else {
        printf("[Skipping %s with value %d]\n", $regname, $$enum_counter_ref);
    }


    # increment the enum counter
    ++$$enum_counter_ref;
    printf("[enum counter after: %d]\n", $$enum_counter_ref);

    return;
}

sub parse_dwarf_registers_header {
    my ($gdb_regnum_ref, $header_filename) = @_;
    my %dwarf_regnum;

    open my ($fh), '<', $header_filename or
        croak "Failed to open file $header_filename for reading: $?";

    my $enum_counter = 0;

    while (<$fh>) {
        if (m/dwarf_([^,\s]+)\s*=\s*(\d+)/) {
            # reset the enum counter to the value provided
            $enum_counter = $2;
            maybe_add_register($gdb_regnum_ref, \%dwarf_regnum, $1, \$enum_counter);
        } elsif (m/dwarf_([^,\s]+)/) {
            maybe_add_register($gdb_regnum_ref, \%dwarf_regnum, $1, \$enum_counter);
        }
    }

    close($fh) or croak "Failed to close file: $?";

    return \%dwarf_regnum;
}

sub print_reg_infos {
    my ($reg_infos_ref) = @_;
    my $packet_size = 0;

    print "arm_register_infos = [\n";
    foreach my $reg_name (sort { $reg_infos_ref->{$a}{byte_offset} <=>
                                $reg_infos_ref->{$b}{byte_offset} }
                     keys %$reg_infos_ref) {
        my $is_aliased = 0;
        my $reg_info_ref = $reg_infos_ref->{$reg_name};
#       printf("{ 'name':%-7s, 'set':%d, 'bitsize':%3d, 'offset':%3d, 'encoding':%s, 'format':%s",
        printf("{ 'name':%-7s, 'set':%d, 'bitsize':%3d, 'encoding':%s, 'format':%s",
               "'" . $reg_info_ref->{name} . "'",
               $reg_info_ref->{set},
               $reg_info_ref->{byte_size} * 8,
#               $reg_info_ref->{byte_offset},
               $reg_info_ref->{encoding},
               $reg_info_ref->{format});

        if ($reg_info_ref->{alt_name}) {
            printf(", 'alt-name':'%s'", $reg_info_ref->{alt_name});
        }

        my $prefix = $reg_info_ref->{prefix};
        if (defined $prefix) {
            my $aliasee = $register_aliases{$prefix};
            if (defined $aliasee) {
                $is_aliased = 1;
                my $aliasee_size = $register_sizes_by_prefix{$aliasee};
                defined $aliasee_size
                    or croak "No size defined for prefix '$aliasee', the aliasee for prefix '$prefix', " .
                             "implying no definition for any such '$aliasee' register appeared\n ";
                my $my_size = $reg_info_ref->{byte_size};
                my $my_size_in_bits = $my_size * 8;
                my $my_index = $reg_info_ref->{index};
                if ($my_size == $aliasee_size) {  # The easy case
                    croak "This script can't (yet) handle equal size register aliases (e.g., '$prefix' => '$aliasee');"
                            #   Presumably either a trivial slice or a trivial composite definition would work.
                } elsif ($my_size < $aliasee_size) {  # I'm smaller, so I'm a slice of the other register
                    # s3 => d1
                    # 'slice' : 'd1[15:8]'
                    my $size_factor = sprintf("%d", $aliasee_size / $my_size);  # Round.  e.g., 2
                    $my_size * $size_factor == $aliasee_size
                        or croak "Register alias ('$prefix' => '$aliasee') isn't an integer multiple.";

                    # Calculate which register is to be aliased
                    my $aliasee_index = POSIX::floor($my_index / $size_factor);
                            # e.g., 3 -> 1  N.B.: Depends on byte ordering in register context buffer

                    # Calculate offset within that register:
                    # First determine the "remainder" from the previous calculation.  This will
                    #   return the offset in units of my register size:
                    my $aliasee_slice_offset = $my_index - ($size_factor * $aliasee_index);
                    my $aliasee_slice_offset_bits = $aliasee_slice_offset * $my_size * 8;
                    printf(", 'slice' : '%s%d[%d:%d]'",
                           $aliasee,
                           $aliasee_index,
                           $aliasee_slice_offset_bits + $my_size_in_bits - 1,
                           $aliasee_slice_offset_bits);
                } else {  # I'm bigger, so I'm the composite of multiple other registers
                    # q1 => d2, d3
                    # q2 => d4, d5
                    # 'composite' : [ d2, d3 ]
                    my $size_factor = sprintf("%d", $my_size / $aliasee_size);  # Round.  e.g., 2
                    $aliasee_size * $size_factor == $my_size
                        or croak "Register alias ('$prefix' => '$aliasee') isn't an integer multiple.";
                    my $first_aliasee_index = $my_index * $size_factor;
                    printf(", 'composite' : [ ");
                    for (my $i = $size_factor - 1; $i >= 0; $i--) {  # NB This ordering should be MSB->LSB
                        if ($i != $size_factor - 1) {
                            printf(", ");
                        }
                        printf("$aliasee%d", $i + $first_aliasee_index);
                    }
                    printf(" ]");
                }
            }
        }

        if (! $is_aliased) {
            my $next_offset = $reg_info_ref->{byte_offset} +
                $reg_info_ref->{byte_size};
            if ($next_offset > $packet_size) {
                $packet_size = $next_offset;
            }
        }

        printf(" },\n");

    }

    print "];\n\n";
    print "packet_size = $packet_size\n";

    return;
}

scalar(@ARGV) == 2 or croak "Usage: $0 {gdb-raw-registers-file} {ARM_DWARF_Registers_h-file}";

my ($gdb_regnum_ref, $reg_infos) = parse_raw_registers_output($ARGV[0]);
my $dwarf_regnum_ref = parse_dwarf_registers_header($gdb_regnum_ref, $ARGV[1]);

print "name_to_gcc_dwarf_regnum = {\n";
foreach my $reg (sort { $dwarf_regnum_ref->{$a} <=> $dwarf_regnum_ref->{$b} } keys %$dwarf_regnum_ref) {
    printf("    %-7s : %3d,\n", "'" . $reg . "'", $dwarf_regnum_ref->{$reg});
}
print "};\n\n";

print "name_to_gdb_regnum = {\n";
foreach my $reg (sort { $gdb_regnum_ref->{$a} <=> $gdb_regnum_ref->{$b} } keys %$gdb_regnum_ref) {
    printf("    %-7s : %3d,\n", "'" . $reg . "'", $gdb_regnum_ref->{$reg});
}
print "};\n\n";

print_reg_infos($reg_infos);

1;
