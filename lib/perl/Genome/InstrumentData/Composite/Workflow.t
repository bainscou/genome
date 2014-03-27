#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT}               = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
}

use Test::More;
use above "Genome";

use Genome::Utility::Test;
use Genome::Test::Factory::InstrumentData::Solexa;
use Genome::Test::Factory::Model::ImportedVariationList;
use Genome::Test::Factory::Model::ImportedReferenceSequence;
use Genome::Test::Factory::Build;

my $TEST_DATA_VERSION = 1;

my $pkg = 'Genome::InstrumentData::Composite::Workflow';
use_ok($pkg) or die('test cannot continue');

my $data_dir = Genome::Utility::Test->data_dir_ok($pkg, $TEST_DATA_VERSION);
my $tmp_dir = Genome::Sys->create_temp_directory();
for my $file (qw/all_sequences.fa all_sequences.dict 9999.bam 9999.bam.bai indels.hq.vcf/) {
    Genome::Sys->create_symlink(File::Spec->join($data_dir,$file), File::Spec->join($tmp_dir, $file));
}

my $instrument_data_1 = Genome::Test::Factory::InstrumentData::Solexa->setup_object(
    flow_cell_id => '12345ABXX',
    lane => '1',
    subset_name => '1',
    run_name => 'example',
    id => '-23',
);
my $instrument_data_2 = Genome::Test::Factory::InstrumentData::Solexa->setup_object(
    library_id => $instrument_data_1->library_id,
    flow_cell_id => '12345ABXX',
    lane => '2',
    subset_name => '2',
    run_name => 'example',
    id => '-24',
);

my @two_instrument_data = ($instrument_data_1, $instrument_data_2);

my $ref = Genome::Model::Build::ReferenceSequence->get_by_name('GRCh37-lite-build37');

my %params_for_result = (
    aligner_name => 'bwa',
    aligner_version => '0.5.9',
    aligner_params => '-t 4 -q 5::',
    samtools_version => 'r599',
    picard_version => '1.29',
    reference_build_id => $ref->id,
);

my @results;
for my $i (@two_instrument_data) {
    my $r = Genome::InstrumentData::AlignmentResult::Bwa->__define__(
        %params_for_result,
        instrument_data_id => $i->id,
    );
    $r->lookup_hash($r->calculate_lookup_hash());
    push @results, $r;
}


my $sample_2 = Genome::Sample->create(
    name => 'sample2',
    id => '-101',
);

my $instrument_data_3 = Genome::InstrumentData::Solexa->__define__(
        flow_cell_id => '12345ABXX',
        lane => '3',
        subset_name => '3',
        run_name => 'example',
        id => '-28',
        sample => $sample_2,
    );
my $result_3 = Genome::InstrumentData::AlignmentResult::Bwa->__define__(
    %params_for_result,
    instrument_data_id => $instrument_data_3->id,
);
$result_3->lookup_hash($result_3->calculate_lookup_hash());
my @one_instrument_data = ($instrument_data_3);
my $merge_result_one_inst_data = construct_merge_result(@one_instrument_data);

subtest 'simple alignments' => sub {
    my $log_directory = Genome::Sys->create_temp_directory();
    my $ad = Genome::InstrumentData::Composite::Workflow->create(
        inputs => {
            inst => \@two_instrument_data,
            ref => $ref,
            force_fragment => 0,
        },
        strategy => 'inst aligned to ref using bwa 0.5.9 [-t 4 -q 5::] api v1',
        log_directory => $log_directory,
    );
    isa_ok(
        $ad,
        'Genome::InstrumentData::Composite::Workflow',
        'created dispatcher for simple alignments'
    );


    ok($ad->execute, 'executed dispatcher for simple alignments');

    my @ad_result_ids = $ad->_result_ids;
    my @ad_results = Genome::SoftwareResult->get(\@ad_result_ids);
    is_deeply([sort @results], [sort @ad_results], 'found expected alignment results');
};

my $merge_result_two_inst_data = construct_merge_result(@two_instrument_data);

subtest 'simple alignments with merge' => sub {
    my $ad2 = Genome::InstrumentData::Composite::Workflow->create(
        inputs => {
            inst => \@two_instrument_data,
            ref => $ref,
            force_fragment => 0,
        },
        strategy => 'inst aligned to ref using bwa 0.5.9 [-t 4 -q 5::] then merged using picard 1.29 then deduplicated using picard 1.29 api v1',
    );
    isa_ok(
        $ad2,
        'Genome::InstrumentData::Composite::Workflow',
        'created dispatcher for simple alignments with merge'
    );

    ok($ad2->execute, 'executed dispatcher for simple alignments with merge');
    my @ad2_result_ids = $ad2->_result_ids;
    my @ad2_results = Genome::SoftwareResult->get(\@ad2_result_ids);
    is_deeply([sort @results, $merge_result_two_inst_data], [sort @ad2_results], 'found expected alignment and merge results');
};

my @three_instrument_data = (@two_instrument_data, @one_instrument_data);
push @results, $result_3;

subtest "simple alignments of different samples with merge" => sub {
    my $ad3 = Genome::InstrumentData::Composite::Workflow->create(
        inputs => {
            inst => \@three_instrument_data,
            ref => $ref,
            force_fragment => 0,
        },
        strategy => 'inst aligned to ref using bwa 0.5.9 [-t 4 -q 5::] then merged using picard 1.29 then deduplicated using picard 1.29 api v1',
    );
    isa_ok(
        $ad3,
        'Genome::InstrumentData::Composite::Workflow',
        'created dispatcher for simple alignments of different samples with merge'
    );

    ok($ad3->execute, 'executed dispatcher for simple alignments of different samples with merge');
    my @ad3_result_ids = $ad3->_result_ids;
    my @ad3_results = Genome::SoftwareResult->get(\@ad3_result_ids);
    is_deeply([sort @results, $merge_result_two_inst_data, $merge_result_one_inst_data], [sort @ad3_results], 'found expected alignment and merge results');
};

subtest "simple alignments of different samples with merge and gatk refine" => sub {
    my $ref_model = Genome::Test::Factory::Model::ImportedReferenceSequence->setup_object();
    my $ref_refine = Genome::Model::Build::ImportedReferenceSequence->__define__(
        model => $ref_model,
        name => 'Test Ref Build v1',
        data_directory => $tmp_dir,
        fasta_file => File::Spec->join($tmp_dir, 'all_sequences.fa'),
    );

    $params_for_result{reference_build_id} = $ref_refine->id;
    my $merge_result_refine_one_inst_data = construct_merge_result(@one_instrument_data);
    my $merge_result_refine_two_inst_data = construct_merge_result(@two_instrument_data);
    Sub::Install::reinstall_sub({
        into => 'Genome::InstrumentData::AlignmentResult::Merged',
        as => 'bam_path',
        code => sub { File::Spec->join($tmp_dir, '9999.bam') },
    });

    my $aligner_index = Genome::Model::Build::ReferenceSequence::AlignerIndex->__define__(
        'aligner_version' => '0.5.9',
        'aligner_name' => 'bwa',
        'aligner_params' => '',
        'reference_build' => $ref_refine,
    );

    my @alignment_results;
    for my $instrument_data_id (qw/-23 -24 -28/) {
        my $alignment_result = Genome::InstrumentData::AlignmentResult->__define__(
            'reference_build_id' => $ref_refine->id,
            'samtools_version' => 'r599',
            'aligner_params' => '-t 4 -q 5::',
            'aligner_name' => 'bwa',
            'aligner_version' => '0.5.9',
            'picard_version' => '1.29',
            'instrument_data_id' => $instrument_data_id,
        );
        push @alignment_results, $alignment_result;
    }
    Sub::Install::reinstall_sub({
        into => 'Genome::SoftwareResult',
        as => '_faster_get',
        code => sub { my $class = shift; $class->get(@_) },
    });

    my $indel_result = Genome::Model::Tools::DetectVariants2::Result::Manual->__define__(
        id => 9997,
        output_dir => $tmp_dir,
        original_file_path => File::Spec->join($tmp_dir, 'indels.hq.vcf'),
    );
    my $variation_list_build = Genome::Model::Build::ImportedVariationList->__define__(
        id => 9998,
        indel_result => $indel_result,
    );
    ok($variation_list_build, "created ImportedVariationList build");

    my $ad4 = Genome::InstrumentData::Composite::Workflow->create(
        inputs => {
            inst => \@three_instrument_data,
            ref => $ref_refine,
            force_fragment => 0,
            variant_list => [$variation_list_build],
        },
        strategy => '
            inst aligned to ref using bwa 0.5.9 [-t 4 -q 5::]
            then merged using picard 1.29
            then deduplicated using picard 1.29
            then refined to variant_list using gatk-best-practices 2.4 [-et NO_ET]
            api v1
        ',
    );
    isa_ok(
        $ad4,
        'Genome::InstrumentData::Composite::Workflow',
        'created dispatcher for simple alignments of different samples with merge and gatk refine'
    );

    ok($ad4->execute, 'executed dispatcher for simple alignments of different samples with merge and gatk refine');
    my @ad4_result_ids = $ad4->_result_ids;
    my @ad4_results = Genome::SoftwareResult->get(\@ad4_result_ids);
    my @gatk_results = Genome::InstrumentData::Gatk::BaseRecalibratorBamResult->get(reference_fasta => $ref_refine->fasta_file);
    is_deeply([sort @alignment_results, $merge_result_refine_one_inst_data, $merge_result_refine_two_inst_data, @gatk_results], [sort @ad4_results], 'found expected alignment and gatk results');
};

sub construct_merge_result {
    my @id = @_;

    my $merge_result = Genome::InstrumentData::AlignmentResult::Merged->__define__(
        %params_for_result,
        merger_name => 'picard',
        merger_version => '1.29',
        duplication_handler_name => 'picard',
        duplication_handler_version => '1.29',
    );
    for my $i (0..$#id) {
        $merge_result->add_input(
            name => 'instrument_data_id-' . $i,
            value_id => $id[$i]->id,
        );
    }
    $merge_result->add_param(
        name => 'instrument_data_id_count',
        value_id=> scalar(@id),
    );
    $merge_result->add_param(
        name => 'instrument_data_id_md5',
        value_id => Genome::Sys->md5sum_data(join(':', sort(map($_->id, @id))))
    );

    $merge_result->add_param(
        name => 'filter_name_count',
        value_id => 0,
    );
    $merge_result->add_param(
        name => 'instrument_data_segment_count',
        value_id => 0,
    );
    $merge_result->lookup_hash($merge_result->calculate_lookup_hash());

    return $merge_result;
}

done_testing();
