//
// Align RNA reads
//

import Constants
import Utils

include { CONCATENATE_FASTQ    } from '../../../modules/local/custom/concatenate_fastq/main'
include { GATK4_MARKDUPLICATES } from '../../../modules/nf-core/gatk4/markduplicates/main'
include { SAMTOOLS_SORT        } from '../../../modules/nf-core/samtools/sort/main'
include { STAR_ALIGN           } from '../../../modules/local/star/align/main'

workflow READ_ALIGNMENT_RNA {
    take:
    // Sample data
    ch_inputs         // channel: [mandatory] [ meta ]

    // Reference data
    genome_star_index // channel: [mandatory] /path/to/genome_star_index/

    main:
    // Channel for version.yml files
    // channel: [ versions.yml ]
    ch_versions = Channel.empty()

    // Sort inputs
    // channel: [ meta ]
    ch_inputs_sorted = ch_inputs
        .branch { meta ->
            def has_existing = Utils.hasExistingInput(meta, Constants.INPUT.BAM_RNA_TUMOR)
            runnable: Utils.hasTumorRnaFastq(meta) && !has_existing
            skip: true
        }




    // TODO(SW): per-case / per-sample conditional branch on FASTQ count > 1
    // TODO(SW): branch-dependent read-group; ±library/lane information
    // TODO(SW): consider whether providing version information for CONCATENATE_FASTQ is useful




    //
    // MODULE: Concatenate FASTQ
    //
    // Create process input channel
    // channel: [ meta_fastq_concat, [fastq_fwd, ...], [fastq_rev, ...] ]
    ch_concatenate_fastq_inputs = ch_inputs_sorted.runnable
        .map { meta ->
            def meta_sample = Utils.getTumorRnaSample(meta)
            def (fastqs_fwd, fastqs_rev) = meta_sample
                .getAt(Constants.FileType.FASTQ)
                .collect { key, fps ->
                    return [fps['fwd'], fps['rev']]
                }
                .sort()
                .transpose()

            def meta_concate_fastq = [
                key: meta.group_id,
                id: "${meta.group_id}_${meta_sample.sample_id}",
            ]

            return [meta_concate_fastq, fastqs_fwd, fastqs_rev]
        }

    // Run process
    CONCATENATE_FASTQ(
        ch_concatenate_fastq_inputs,
    )

    //
    // MODULE: STAR alignment
    //
    // Create process input channel
    // channel: [ meta_star, fastq_fwd, fastq_rev ]
    ch_star_inputs = WorkflowOncoanalyser.restoreMeta(CONCATENATE_FASTQ.out.fastq, ch_inputs)
        .map { meta, fastq_fwd, fastq_rev ->

            def sample_id = Utils.getTumorRnaSampleName(meta)
            def meta_star = [
                key: meta.group_id,
                id: "${meta.group_id}_${sample_id}",
                sample_id: sample_id,
                read_group: sample_id,
            ]

            return [meta_star, fastq_fwd, fastq_rev]
        }

    // Run process
    STAR_ALIGN(
        ch_star_inputs,
        genome_star_index,
    )

    ch_versions = ch_versions.mix(STAR_ALIGN.out.versions)

    //
    // MODULE: SAMtools sort
    //
    // Create process input channel
    // channel: [ meta_sort, bam ]
    ch_sort_inputs = STAR_ALIGN.out.bam
        .map { meta_star, bam ->

            def meta_sort = [
                key: meta_star.group_id,
                id: meta_star.id,
                prefix: meta_star.read_group,
            ]

            return [meta_sort, bam]
        }

    // Run process
    SAMTOOLS_SORT(
        ch_sort_inputs,
    )

    ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions)

    //
    // MODULE: GATK4 markduplicates
    //
    // Create process input channel
    // channel: [ meta_markdups, bam ]
    ch_markdups_inputs = WorkflowOncoanalyser.restoreMeta(SAMTOOLS_SORT.out.bam, ch_inputs)
        .map { meta, bam ->
            def meta_markdups = [
                key: meta.group_id,
                id: meta.group_id,
                sample_id: Utils.getTumorRnaSampleName(meta),
            ]
            return [meta_markdups, bam]
        }

    // Run process
    GATK4_MARKDUPLICATES(
        ch_markdups_inputs,
        [],
        [],
    )

    ch_versions = ch_versions.mix(GATK4_MARKDUPLICATES.out.versions)

    // Combine BAMs and BAIs
    // channel: [ meta, bam, bai ]
    ch_bams_ready = WorkflowOncoanalyser.groupByMeta(
        WorkflowOncoanalyser.restoreMeta(GATK4_MARKDUPLICATES.out.bam, ch_inputs),
        WorkflowOncoanalyser.restoreMeta(GATK4_MARKDUPLICATES.out.bai, ch_inputs),
    )

    // Set outputs
    // channel: [ meta, bam, bai ]
    ch_bam_out = Channel.empty()
        .mix(
            ch_bams_ready,
            ch_inputs_sorted.skip.map { meta -> [meta, [], []] },
        )

    emit:
    rna_tumor = ch_bam_out  // channel: [ meta, bam, bai ]

    versions  = ch_versions // channel: [ versions.yml ]
}
