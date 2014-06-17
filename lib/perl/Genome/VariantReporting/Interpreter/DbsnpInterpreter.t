#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Test::Exception;
use Genome::File::Vcf::Entry;

my $pkg = 'Genome::VariantReporting::Interpreter::DbsnpInterpreter';
use_ok($pkg);
my $factory = Genome::VariantReporting::Factory->create();
isa_ok($factory->get_class('interpreters', $pkg->name), $pkg);

subtest "entry with caf" => sub {
    my $interpreter = $pkg->create();
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected = (
        C => {
            allele_frequency => "0.01",
        }
    );
    my $entry = create_entry("[0.9,0.01,0.09]");
    is_deeply({$interpreter->interpret_entry($entry, ['C'])}, \%expected, "Entry interpreted correctly");

    %expected = (
        C => {
            allele_frequency => "0.01",
        },
        G => {
            allele_frequency => "0.09",
        },
    );
    is_deeply({$interpreter->interpret_entry($entry, ['C', 'G'])}, \%expected, "Entry interpreted correctly");
};

subtest "entry without caf" => sub {
    my $interpreter = $pkg->create();
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my $expected = {
        C => {
            allele_frequency => undef,
        },
    };

    my $entry = create_entry();
    is_deeply({$interpreter->interpret_entry($entry, ['C'])}, $expected, "Entry interpreted correctly");
};

done_testing;

sub create_vcf_header {
    my $header_txt = <<EOS;
##fileformat=VCFv4.1
##INFO=<ID=CAF,Number=.,Type=Float,Description="Info field A">
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO
EOS
    my @lines = split("\n", $header_txt);
    my $header = Genome::File::Vcf::Header->create(lines => \@lines);
    return $header
}

sub create_entry {
    my $caf = shift;
    my @fields = (
        '1',            # CHROM
        10,             # POS
        '.',            # ID
        'A',            # REF
        'C,G',            # ALT
        '10.3',         # QUAL
        '.',         # FILTER
    );

    if ($caf) {
        push @fields, "CAF=$caf";
    }

    my $entry_txt = join("\t", @fields);
    my $entry = Genome::File::Vcf::Entry->new(create_vcf_header(), $entry_txt);
    return $entry;
}
