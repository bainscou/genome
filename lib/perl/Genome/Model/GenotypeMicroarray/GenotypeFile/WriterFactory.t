#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
};

use above 'Genome';

use Test::More;

use_ok('Genome::Model::GenotypeMicroarray::GenotypeFile::WriterFactory') or die;

use_ok('Genome::Utility::IO::SeparatedValueWriter') or die;

no warnings;
*Genome::Utility::IO::SeparatedValueWriter::create = sub{ my ($c, %p) = @_; return bless(\%p, $c); };
use warnings;

## TEST ERRORS ##
# Invalid format
ok(!Genome::Model::GenotypeMicroarray::GenotypeFile::WriterFactory->build_writer('format=vcf'), 'failed to create writer w/ invalid format');

# Dup key
ok(!Genome::Model::GenotypeMicroarray::GenotypeFile::WriterFactory->build_writer('format=vcf:format=vcf'), 'failed to create writer w/ dup key');

## TEST DEFAULTS ##
# No config
my $writer = Genome::Model::GenotypeMicroarray::GenotypeFile::WriterFactory->build_writer();
isa_ok($writer, 'Genome::Utility::IO::SeparatedValueWriter');
is($writer->output, '-', 'output is STDOUT');
is($writer->separator, "\t", 'separator is TAB');
is_deeply($writer->headers, [qw/ chromosome position alleles /], 'headers are correct');
ok($writer->print_headers, 'print_headers is true');
is($writer->in_place_of_null_value, "NA", 'in_place_of_null_value is NA');

# File w/o key specified
$writer = Genome::Model::GenotypeMicroarray::GenotypeFile::WriterFactory->build_writer();
isa_ok($writer, 'Genome::Utility::IO::SeparatedValueWriter');
is($writer->output, '-', 'output is STDOUT');
is($writer->separator, "\t", 'separator is TAB');
is_deeply($writer->headers, [qw/ chromosome position alleles /], 'headers are correct');
ok($writer->print_headers, 'print_headers is true');
is($writer->in_place_of_null_value, "NA", 'in_place_of_null_value is NA');

# File specified
$writer = Genome::Model::GenotypeMicroarray::GenotypeFile::WriterFactory->build_writer('output=FILE');
isa_ok($writer, 'Genome::Utility::IO::SeparatedValueWriter');
is($writer->output, 'FILE', 'output is FILE');
is($writer->separator, "\t", 'separator is TAB');
is_deeply($writer->headers, [qw/ chromosome position alleles /], 'headers are correct');
ok($writer->print_headers, 'print_headers is true');
is($writer->in_place_of_null_value, "NA", 'in_place_of_null_value is NA');

# Everything specified
$writer = Genome::Model::GenotypeMicroarray::GenotypeFile::WriterFactory->build_writer('output=FILE:format=csv:separator=,:headers=chromosome,allele1:print_headers=0:in_place_of_null_value=NULL');
isa_ok($writer, 'Genome::Utility::IO::SeparatedValueWriter');
is($writer->output, 'FILE', 'output is FILE');
is($writer->separator, ',', 'separator is comma');
is_deeply($writer->headers, [qw/ chromosome allele1 /], 'headers are correct');
ok($writer->print_headers, 'print_headers is false');
is($writer->in_place_of_null_value, "NULL", 'in_place_of_null_value is NULL');

done_testing();
