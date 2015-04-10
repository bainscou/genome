#!/usr/bin/env genome-perl

use strict;
use warnings;

use Genome;
use Test::More tests => 4;

use File::Spec qw();
use File::Temp qw();
use Test::Fatal qw(exception);
use YAML::Syck qw();

use_ok('Genome::ConfigSpec');

subtest 'new_from_file: basic' => sub {
    plan tests => 5;

    my %data = (
        type => 'Str',
        env => 'XGENOME_FOO',
        validators => [qw(numeric positive)],
        default_value => 1,
    );
    my ($input_fh, $input_file, $input_filename) = setup_yaml_file({ %data });

    my $spec = Genome::ConfigSpec->new_from_file($input_file);
    is($spec->type, $data{type}, 'type matches');
    is($spec->key, $input_filename, 'key matches');
    is($spec->env, $data{env}, 'env matches');
    is($spec->default_value, $data{default_value}, 'default_value matches');
    is(scalar(@{$spec->validators}), scalar(@{$data{validators}}), q(validators' count matches));
};

subtest 'new_from_file: sticky' => sub {
    plan tests => 3;
    {
        my ($input_fh, $input_file, $input_filename) = setup_yaml_file({
            type => 'Str',
        });
        my $spec = Genome::ConfigSpec->new_from_file($input_file);
        ok(!$spec->sticky, 'no sticky key results in non-sticky spec')
    } {
        my ($input_fh, $input_file, $input_filename) = setup_yaml_file({
            type => 'Str',
            sticky => 0,
        });
        my $spec = Genome::ConfigSpec->new_from_file($input_file);
        ok(!$spec->sticky, 'sticky set to zero results in non-sticky spec')
    } {
        my ($input_fh, $input_file, $input_filename) = setup_yaml_file({
            type => 'Str',
            sticky => 1,
        });
        my $spec = Genome::ConfigSpec->new_from_file($input_file);
        ok($spec->sticky, 'sticky set to one results in sticky spec')
    }
};

subtest 'new_from_file: non-existant validator' => sub {
    plan tests => 1;

    my %data = (
        type => 'Str',
        env => 'XGENOME_FOO',
        validators => [qw(numeric zzzzzzz)],
        default_value => 1,
    );
    my ($input_fh, $input_file, $input_filename) = setup_yaml_file({ %data });
    my $ex = exception { Genome::ConfigSpec->new_from_file($input_file) };
    like($ex, qr/failed to load validator/, 'failed to load validator');
};

sub setup_yaml_file {
    my $data = shift;

    my $fh = File::Temp->new();
    my $file = $fh->filename;
    my $filename = (File::Spec->splitpath($file))[2];

    $fh->print(YAML::Syck::Dump($data));
    $fh->flush();

    return ($fh, $file, $filename);
}
