//
// PEACH infers germline haplotypes and reports relevant pharmacogenomics
//

import Constants
import Utils

include { PEACH } from '../../../modules/local/peach/main'

workflow PEACH_CALLING {
    take:
    // Sample data
    ch_inputs                 // channel: [mandatory] [ meta ]
    ch_purple                 // channel: [mandatory] [ meta, purple_dir ]

    // Reference data
    peach_haplotypes          // channel: [mandatory] /path/to/peach_haplotypes
    peach_haplotype_functions // channel: [mandatory] /path/to/peach_haplotype_functions
    peach_drug_info           // channel: [mandatory] /path/to/peach_drug_info

    main:
    // Channel for version.yml files
    // channel: [ versions.yml ]
    ch_versions = Channel.empty()

    // Select input sources and sort
    // channel: runnable: [ meta, purple_dir ]
    // channel: skip: [ meta ]
    ch_inputs_sorted = ch_purple
        .map { meta, purple_dir ->
            return [
                meta,
                Utils.selectCurrentOrExisting(purple_dir, meta, Constants.INPUT.PURPLE_DIR),
            ]
        }
        .branch { meta, purple_dir ->
            runnable: purple_dir
            skip: true
                return meta
        }

    // Create process input channel
    // channel: [ meta_peach, purple_germline_smlv_vcf ]
    ch_peach_inputs = ch_inputs_sorted.runnable
        .map { meta, purple_dir ->

            def meta_peach = [
                key: meta.group_id,
                id: meta.group_id,
                sample_id: Utils.getNormalDnaSampleName(meta),
            ]

            def purple_germline_smlv_vcf = file(purple_dir).resolve("${Utils.getTumorDnaSampleName(meta)}.purple.germline.vcf.gz")

            return [meta_peach, purple_germline_smlv_vcf]
        }

    // Run process
    PEACH(
        ch_peach_inputs,
        peach_haplotypes,
        peach_haplotype_functions,
        peach_drug_info,
    )

    ch_versions = ch_versions.mix(PEACH.out.versions)

    emit:
    versions  = ch_versions // channel: [ versions.yml ]
}
