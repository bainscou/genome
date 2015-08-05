use strict;
use warnings;

BEGIN {
    $ENV{NO_LSF}                         = 1;
    $ENV{UR_DBI_NO_COMMIT}               = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use above 'Genome';
use Genome::SoftwareResult;

use Test::More;
use Test::Exception;
use File::Compare qw(compare);
use File::Basename qw(basename);
use Genome::Utility::Test qw(compare_ok);
use Genome::File::Vcf::Differ;
use Genome::Test::Factory::SoftwareResult::User;
use Genome::Test::Data qw(get_test_file);


	my $test_dir = __FILE__.".d";
	
	my $version = '0.0.3a-gms';

	my $output = Genome::Sys->create_temp_directory();
        
	my $reference_fasta = get_test_file('NA12878', 'human_g1k_v37_20_42220611-42542245.fasta');
	my $bam = get_test_file('NA12878', 'NA12878.20slice.30X.aligned.bam');
	my $bam2 = get_test_file('NA12878', 'NA12878.20slice.30X.aligned.bam');
	my $split_bam = get_test_file('NA12878','NA12878.20slice.30X.splitters.bam');
	my $discordant_bam = get_test_file('NA12878','NA12878.20slice.30X.discordants.bam');

 
	my $pkg2 = 'Genome::Model::Tools::DetectVariants2::SpeedseqSv';
	
	my $refbuild_id = 101947881;
	my $result_users = Genome::Test::Factory::SoftwareResult::User->setup_user_hash(reference_sequence_build_id => $refbuild_id,);

	my $params = "-R:$reference_fasta,-g,-d,-o:Hello";


my $command2 = $pkg2->create(
	output_directory => $output,
	reference_build_id => $refbuild_id,
	result_users => $result_users,	
	aligned_reads_input => $bam,
	params => $params,
	control_aligned_reads_input => $bam2,
	version => $version,
);

ok($command2->execute, 'Executed `gmt detect-variants2 Speedseq` command');


my $differ = Genome::File::Vcf::Differ->new("$output/svs.hq.sv.vcf.gz", "$test_dir/svs.hq.sv.vcf.gz");
	my $diff = $differ->diff;
	is($diff, undef, "Found No differences between $output/svs.hq.sv.vcf.gz and (expected) $test_dir/svs.hq.sv.vcf.gz") ||
	diag $diff->to_string;


compare_ok("$output/svs.hq.sv.NA12878.20slice.30X.aligned.bam.readdepth.bed","$test_dir/svs.hq.sv.NA12878.20slice.30X.aligned.bam.readdepth.bed");
compare_ok("$output/svs.hq.sv.NA12878.20slice.30X.aligned.bam.readdepth.txt","$test_dir/svs.hq.sv.NA12878.20slice.30X.aligned.bam.readdepth.txt");

my $commandDie = $pkg2->create(
        output_directory => $output,
        reference_build_id => $refbuild_id,
        result_users => $result_users,
        aligned_reads_input => "Bad.bam",
        params => $params,
        control_aligned_reads_input => $bam2,
	version => $version,
);

dies_ok( sub {$commandDie->execute}, "Executing a command that I expect to fail");

done_testing();
