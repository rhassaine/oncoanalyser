//
// HEALTHCHECKER validates sample quality metrics
//

import Constants
import Utils

include { SAMTOOLS_FLAGSTAT as SAMTOOLS_FLAGSTAT_TUMOR  } from '../../../modules/local/samtools_flagstat/main'
include { SAMTOOLS_FLAGSTAT as SAMTOOLS_FLAGSTAT_NORMAL } from '../../../modules/local/samtools_flagstat/main'
include { HEALTHCHECKER                                 } from '../../../modules/local/healthchecker/main'

workflow HEALTHCHECKER_QC {
    take:
    // Sample data
    ch_inputs              // channel: [mandatory] [ meta ]
    ch_tumor_bam           // channel: [mandatory] [ meta, bam, bai ]
    ch_normal_bam          // channel: [mandatory] [ meta, bam, bai ]
    ch_bamtools_somatic    // channel: [mandatory] [ meta, metrics_dir ]
    ch_bamtools_germline   // channel: [mandatory] [ meta, metrics_dir ]
    ch_purple              // channel: [mandatory] [ meta, purple_dir ]

    main:
    // Channel for version.yml files
    // channel: [ versions.yml ]
    ch_versions = Channel.empty()

    // Select BAM input sources
    // channel: [ meta, tumor_bam, tumor_bai ]
    ch_tumor_bam_selected = ch_tumor_bam
        .map { meta, bam, bai ->
            return [
                meta,
                Utils.selectCurrentOrExisting(bam, meta, Constants.INPUT.BAM_REDUX_DNA_TUMOR),
                bai ?: Utils.getInput(meta, Constants.INPUT.BAI_DNA_TUMOR),
            ]
        }

    // channel: [ meta, normal_bam, normal_bai ]
    ch_normal_bam_selected = ch_normal_bam
        .map { meta, bam, bai ->
            return [
                meta,
                Utils.selectCurrentOrExisting(bam, meta, Constants.INPUT.BAM_REDUX_DNA_NORMAL),
                bai ?: Utils.getInput(meta, Constants.INPUT.BAI_DNA_NORMAL),
            ]
        }

    // Select other input sources
    // channel: [ meta, purple_dir ]
    ch_purple_selected = ch_purple
        .map { meta, purple_dir ->
            return [meta, Utils.selectCurrentOrExisting(purple_dir, meta, Constants.INPUT.PURPLE_DIR)]
        }

    // channel: [ meta, bamtools_tumor_dir ]
    ch_bamtools_somatic_selected = ch_bamtools_somatic
        .map { meta, metrics_dir ->
            return [meta, Utils.selectCurrentOrExisting(metrics_dir, meta, Constants.INPUT.BAMTOOLS_DIR_TUMOR)]
        }

    // channel: [ meta, bamtools_normal_dir ]
    ch_bamtools_germline_selected = ch_bamtools_germline
        .map { meta, metrics_dir ->
            return [meta, Utils.selectCurrentOrExisting(metrics_dir, meta, Constants.INPUT.BAMTOOLS_DIR_NORMAL)]
        }

    // Group all inputs to determine runnability
    // channel: [ meta, tumor_bam, tumor_bai, normal_bam, normal_bai, bamtools_tumor, bamtools_normal, purple_dir ]
    ch_inputs_grouped = WorkflowOncoanalyser.groupByMeta(
        ch_tumor_bam_selected,
        ch_normal_bam_selected,
        ch_bamtools_somatic_selected,
        ch_bamtools_germline_selected,
        ch_purple_selected,
    )

    // Sort inputs
    // channel: runnable: [ meta, tumor_bam, tumor_bai, normal_bam, normal_bai, bamtools_tumor, bamtools_normal, purple_dir ]
    // channel: skip: [ meta ]
    ch_inputs_sorted = ch_inputs_grouped
        .branch { d ->

            def meta = d[0]
            def tumor_bam = d[1]
            def normal_bam = d[3]
            def bamtools_tumor = d[5]
            def bamtools_normal = d[6]
            def purple_dir = d[7]

            def has_tumor_dna = Utils.hasTumorDna(meta)
            def has_normal_dna = Utils.hasNormalDna(meta)
            def has_existing = Utils.hasExistingInput(meta, Constants.INPUT.HEALTHCHECKER_DIR)

            runnable: has_tumor_dna && has_normal_dna && tumor_bam && normal_bam && bamtools_tumor && bamtools_normal && purple_dir && !has_existing
            skip: true
                return meta
        }

    // Run SAMTOOLS_FLAGSTAT on tumor BAM
    // channel: [ meta_flagstat, bam, bai ]
    ch_flagstat_tumor_inputs = ch_inputs_sorted.runnable
        .map { d ->

            def meta = d[0]
            def tumor_bam = d[1]
            def tumor_bai = d[2]
            def tumor_id = Utils.getTumorDnaSampleName(meta)

            def meta_flagstat = [
                key: meta.group_id,
                id: "${meta.group_id}_${tumor_id}",
                sample_id: tumor_id,
            ]

            return [meta_flagstat, tumor_bam, tumor_bai]
        }

    SAMTOOLS_FLAGSTAT_TUMOR(ch_flagstat_tumor_inputs)
    ch_versions = ch_versions.mix(SAMTOOLS_FLAGSTAT_TUMOR.out.versions)

    // Run SAMTOOLS_FLAGSTAT on normal BAM
    // channel: [ meta_flagstat, bam, bai ]
    ch_flagstat_normal_inputs = ch_inputs_sorted.runnable
        .map { d ->

            def meta = d[0]
            def normal_bam = d[3]
            def normal_bai = d[4]
            def normal_id = Utils.getNormalDnaSampleName(meta)

            def meta_flagstat = [
                key: meta.group_id,
                id: "${meta.group_id}_${normal_id}",
                sample_id: normal_id,
            ]

            return [meta_flagstat, normal_bam, normal_bai]
        }

    SAMTOOLS_FLAGSTAT_NORMAL(ch_flagstat_normal_inputs)
    ch_versions = ch_versions.mix(SAMTOOLS_FLAGSTAT_NORMAL.out.versions)

    // Restore meta for flagstat outputs
    // channel: [ meta, tumor_flagstat ]
    ch_tumor_flagstat = WorkflowOncoanalyser.restoreMeta(SAMTOOLS_FLAGSTAT_TUMOR.out.flagstat, ch_inputs)
    // channel: [ meta, normal_flagstat ]
    ch_normal_flagstat = WorkflowOncoanalyser.restoreMeta(SAMTOOLS_FLAGSTAT_NORMAL.out.flagstat, ch_inputs)

    // Group all inputs for HEALTHCHECKER
    // channel: [ meta, tumor_flagstat, normal_flagstat, bamtools_tumor, bamtools_normal, purple_dir ]
    ch_healthchecker_grouped = WorkflowOncoanalyser.groupByMeta(
        ch_tumor_flagstat,
        ch_normal_flagstat,
        ch_bamtools_somatic_selected,
        ch_bamtools_germline_selected,
        ch_purple_selected,
    )

    // Create process input channel
    // channel: [ meta_hc, tumor_flagstat, ref_flagstat, tumor_metrics, ref_metrics, purple_dir ]
    ch_healthchecker_inputs = ch_healthchecker_grouped
        .filter { d ->
            def tumor_flagstat = d[1]
            def normal_flagstat = d[2]
            def bamtools_tumor = d[3]
            def bamtools_normal = d[4]
            def purple_dir = d[5]
            tumor_flagstat && normal_flagstat && bamtools_tumor && bamtools_normal && purple_dir
        }
        .map { d ->

            def meta = d[0]
            def tumor_flagstat = d[1]
            def normal_flagstat = d[2]
            def bamtools_tumor = d[3]
            def bamtools_normal = d[4]
            def purple_dir = d[5]

            def tumor_id = Utils.getTumorDnaSampleName(meta)
            def normal_id = Utils.getNormalDnaSampleName(meta)

            def meta_hc = [
                key: meta.group_id,
                id: meta.group_id,
                tumor_id: tumor_id,
                normal_id: normal_id,
            ]

            return [meta_hc, tumor_flagstat, normal_flagstat, bamtools_tumor, bamtools_normal, purple_dir]
        }

    // Run process
    HEALTHCHECKER(ch_healthchecker_inputs)

    ch_versions = ch_versions.mix(HEALTHCHECKER.out.versions)

    // Set outputs, restoring original meta
    // channel: [ meta, healthchecker_dir ]
    ch_outputs = Channel.empty()
        .mix(
            WorkflowOncoanalyser.restoreMeta(HEALTHCHECKER.out.healthchecker_dir, ch_inputs),
            ch_inputs_sorted.skip.map { meta -> [meta, []] },
        )

    emit:
    healthchecker_dir = ch_outputs  // channel: [ meta, healthchecker_dir ]

    versions = ch_versions          // channel: [ versions.yml ]
}
