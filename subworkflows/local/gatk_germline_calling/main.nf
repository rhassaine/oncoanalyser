//
// GATK_GERMLINE_CALLING runs GATK HaplotypeCaller on the normal/reference sample
//

import Constants
import Utils

include { GATK3_HAPLOTYPECALLER } from '../../../modules/local/gatk3/haplotypecaller/main'

workflow GATK_GERMLINE_CALLING {
    take:
    // Sample data
    ch_inputs      // channel: [mandatory] [ meta ]
    ch_normal_bam  // channel: [mandatory] [ meta, bam, bai ]
    genome_fasta   // channel: [mandatory] /path/to/genome_fasta
    genome_fai     // channel: [mandatory] /path/to/genome_fai
    genome_dict    // channel: [mandatory] /path/to/genome_dict

    main:
    // Channel for version.yml files
    // channel: [ versions.yml ]
    ch_versions = Channel.empty()

    // Select input sources
    // channel: [ meta, normal_bam, normal_bai ]
    ch_inputs_selected = ch_normal_bam
        .map { meta, bam, bai ->
            return [
                meta,
                Utils.selectCurrentOrExisting(bam, meta, Constants.INPUT.BAM_REDUX_DNA_NORMAL),
                bai ?: Utils.getInput(meta, Constants.INPUT.BAI_DNA_NORMAL),
            ]
        }

    // Sort inputs
    // channel: runnable: [ meta, normal_bam, normal_bai ]
    // channel: skip: [ meta ]
    ch_inputs_sorted = ch_inputs_selected
        .branch { meta, normal_bam, normal_bai ->

            def has_normal_dna = Utils.hasNormalDna(meta)
            def has_existing = Utils.hasExistingInput(meta, Constants.INPUT.GATK_GERMLINE_VCF)

            runnable: has_normal_dna && normal_bam && !has_existing
            skip: true
                return meta
        }

    // Create process input channel
    // channel: [ meta_gatk, normal_bam, normal_bai ]
    ch_gatk_inputs = ch_inputs_sorted.runnable
        .map { meta, normal_bam, normal_bai ->

            def normal_id = Utils.getNormalDnaSampleName(meta)

            def meta_gatk = [
                key: meta.group_id,
                id: meta.group_id,
                sample_id: normal_id,
            ]

            return [meta_gatk, normal_bam, normal_bai]
        }

    // Run process
    GATK3_HAPLOTYPECALLER(
        ch_gatk_inputs,
        genome_fasta,
        genome_fai,
        genome_dict,
    )

    ch_versions = ch_versions.mix(GATK3_HAPLOTYPECALLER.out.versions)

    // Set outputs, restoring original meta
    // channel: [ meta, vcf, tbi ]
    ch_outputs = Channel.empty()
        .mix(
            WorkflowOncoanalyser.restoreMeta(GATK3_HAPLOTYPECALLER.out.vcf, ch_inputs),
            ch_inputs_sorted.skip.map { meta -> [meta, [], []] },
        )

    emit:
    germline_vcf = ch_outputs  // channel: [ meta, vcf, tbi ]

    versions     = ch_versions // channel: [ versions.yml ]
}
