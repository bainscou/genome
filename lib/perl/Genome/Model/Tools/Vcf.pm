package Genome::Model::Tools::Vcf;

use strict;
use warnings;

use Genome;

#This is the variable to change if you wish to change the version of all vcf files being created
# 4 was incremented from 3: because of a bug in VcfFilter.pm. When filtered twice, FT fields were being wiped out rather than propagated from "FILTER".
# 5 was incremented from 4: Varscan now rounds tumor vaq to the nearest integer value so it agrees with the header type field
# 6 was incremented from 5: some TCGA-compliance format, fix VcfFilter bug to mis-treat some samtools mpileup indel
# 7 was incremented from 6: more TCGA-compliance format, add TCGA format output of snv and indel to streka tool, add fix to Varscan Somatic snv vcf
# 8 was incremented from 7: When combining vcfs in DV2, keep the original per-detector sample columns. We will now have one column per sample and detector plus a per-sample consensus column.

my $VCF_VERSION = "8";

class Genome::Model::Tools::Vcf {
    is => ['Command'],
    has => [
        vcf_version => {
            is => 'Text',
            default => $VCF_VERSION,
        },
    ],
};

sub get_vcf_version {
    return $VCF_VERSION;
}

sub help_brief {
    "Tools and scripts to create and manipulate VCF files."
}

sub help_detail {
    return <<EOS
Tools and scripts to create and manipulate VCF files.
EOS
}

1;
