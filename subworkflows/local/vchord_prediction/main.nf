//
// V-CHORD predicts HR deficiency status using CNN on PURPLE CIRCOS plots
//

import Constants
import Utils

include { VCHORD } from '../../../modules/local/vchord/main'

workflow VCHORD_PREDICTION {
    take:
    // Sample data
    ch_inputs      // channel: [mandatory] [ meta ]
    ch_purple      // channel: [mandatory] [ meta, purple_dir ]

    // Reference data
    vchord_model   // channel: [mandatory] /path/to/vchord_model

    main:
    // Channel for version.yml files
    // channel: [ versions.yml ]
    ch_versions = Channel.empty()

    // Select input sources
    // channel: [ meta, purple_dir ]
    ch_inputs_selected = ch_purple
        .map { meta, purple_dir ->
            return [meta, Utils.selectCurrentOrExisting(purple_dir, meta, Constants.INPUT.PURPLE_DIR)]
        }

    // Sort inputs
    // channel: runnable: [ meta, purple_dir ]
    // channel: skip: [ meta ]
    ch_inputs_sorted = ch_inputs_selected
        .branch { meta, purple_dir ->

            def has_dna = Utils.hasTumorDna(meta)

            def has_existing = Utils.hasExistingInput(meta, Constants.INPUT.VCHORD_DIR)

            runnable: has_dna && purple_dir && !has_existing
            skip: true
                return meta
        }

    // Create process input channel
    // channel: [ meta_vchord, purple_dir ]
    ch_vchord_inputs = ch_inputs_sorted.runnable
        .map { meta, purple_dir ->

            def tumor_id = Utils.getTumorDnaSampleName(meta)

            def meta_vchord = [
                key: meta.group_id,
                id: meta.group_id,
                sample_id: tumor_id,
            ]

            return [meta_vchord, purple_dir]
        }

    // Run process
    VCHORD(
        ch_vchord_inputs,
        vchord_model,
    )

    ch_versions = ch_versions.mix(VCHORD.out.versions)

    // Set outputs, restoring original meta
    // channel: [ meta, vchord_dir ]
    ch_outputs = Channel.empty()
        .mix(
            WorkflowOncoanalyser.restoreMeta(VCHORD.out.vchord_dir, ch_inputs),
            ch_inputs_sorted.skip.map { meta -> [meta, []] },
        )

    emit:
    vchord_dir = ch_outputs  // channel: [ meta, vchord_dir ]

    versions  = ch_versions  // channel: [ versions.yml ]
}
