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
# Authors: Todd Fiala (tfiala@)

use warnings;
use strict;
use Carp;

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
            m/^\s*(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ or croak "Failed to match register line format: $_";
            my $reg_name = $1;
            my $gdb_reg_num = $2;
            my $rel_index = $3; # not sure precisely what this is
                             # TODO look up
            my $byte_offset = $4;
            my $byte_size = $5;

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
                alt_name => $alt_name
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
        my $reg_info_ref = $reg_infos_ref->{$reg_name};
        printf("{ 'name':%-7s, 'set':%d, 'bitsize':%3d, 'offset':%3d, 'encoding':%s, 'format':%s",
               "'" . $reg_info_ref->{name} . "'",
               $reg_info_ref->{set},
               $reg_info_ref->{byte_size} * 8,
               $reg_info_ref->{byte_offset},
               $reg_info_ref->{encoding},
               $reg_info_ref->{format});

        if ($reg_info_ref->{alt_name}) {
            printf(", 'alt-name':'%s' },\n", $reg_info_ref->{alt_name});
        } else {
            printf(" },\n");
        }

        my $next_offset = $reg_info_ref->{byte_offset} +
            $reg_info_ref->{byte_size};
        if ($next_offset > $packet_size) {
            $packet_size = $next_offset;
        }
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
