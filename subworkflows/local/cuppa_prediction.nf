//
// CUPPA predicts tissue of origin from molecular profiles
//

import Constants

include { CUPPA } from '../../modules/local/cuppa/main'

workflow CUPPA_PREDICTION {
    take:
        // Sample data
        ch_inputs           // channel: [mandatory] [ meta ]
        ch_isofox           // channel: [optional]  [ meta, isofox_dir ]
        ch_purple           // channel: [optional]  [ meta, purple_dir ]
        ch_linx             // channel: [optional]  [ meta, linx_annotation_dir ]
        ch_virusinterpreter // channel: [optional]  [ meta, virusinterpreter_dir ]

        // Reference data
        genome_version      // channel: [mandatory] genome version
        cuppa_resources     // channel: [mandatory] /path/to/cuppa_resources/

        // Params
        run_config          // channel: [mandatory] run configuration

    main:
        // Channel for version.yml files
        // channel: [ versions.yml ]
        ch_versions = Channel.empty()

        // Select input sources
        // channel: [ meta, isofox_dir ]
        ch_cuppa_inputs_isofox = run_config.stages.isofox ? ch_isofox : WorkflowOncoanalyser.getInput(ch_inputs, Constants.INPUT.ISOFOX_DIR, type: 'optional')

        // channel: [ meta, isofox_dir, purple_dir, linx_annotation_dir, virusinterpreter_dir ]
        ch_cuppa_inputs_source = WorkflowOncoanalyser.groupByMeta(
            ch_cuppa_inputs_isofox,
            run_config.stages.purple ? ch_purple : WorkflowOncoanalyser.getInput(ch_inputs, Constants.INPUT.PURPLE_DIR, type: 'optional'),
            run_config.stages.linx ? ch_linx : WorkflowOncoanalyser.getInput(ch_inputs, Constants.INPUT.LINX_ANNO_DIR_TUMOR, type: 'optional'),
            run_config.stages.virusinterpreter ? ch_virusinterpreter : WorkflowOncoanalyser.getInput(ch_inputs, Constants.INPUT.VIRUSINTERPRETER_TSV, type: 'optional'),
            flatten_mode: 'nonrecursive',
        )

        // Create inputs and create process-specific meta
        // channel: [ meta_cuppa, isofox_dir, purple_dir, linx_annotation_dir, virusinterpreter_dir ]
        ch_cuppa_inputs = ch_cuppa_inputs_source
            .map { data ->
                def meta = data[0]
                def meta_cuppa = [key: meta.id]

                switch (run_config.mode) {
                    case Constants.RunMode.WGS:
                        meta_cuppa.id = meta.getAt(['sample_name', Constants.SampleType.TUMOR, Constants.SequenceType.WGS])
                        break
                    case Constants.RunMode.WTS:
                        meta_cuppa.id = meta.getAt(['sample_name', Constants.SampleType.TUMOR, Constants.SequenceType.WTS])
                        break
                    case Constants.RunMode.WGTS:
                        meta_cuppa.id = meta.getAt(['sample_name', Constants.SampleType.TUMOR, Constants.SequenceType.WGS])
                        meta_cuppa.id_wts = meta.getAt(['sample_name', Constants.SampleType.TUMOR, Constants.SequenceType.WTS])
                        break
                    case Constants.RunMode.PANEL:
                        meta_cuppa.id = meta.getAt(['sample_name', Constants.SampleType.TUMOR, Constants.SequenceType.TARGETTED])
                        break
                    default:
                        assert false
                }

                return [meta_cuppa, *data[1..-1]]
            }

        CUPPA(
            ch_cuppa_inputs,
            genome_version,
            cuppa_resources,
        )

        // Set outputs, restoring original meta
        ch_output = WorkflowOncoanalyser.restoreMeta(CUPPA.out.cuppa_dir, ch_inputs)

    emit:
        cuppa_dir = ch_output           // channel: [ meta, cuppa_dir ]

        versions  = CUPPA.out.versions  // channel: [ versions.yml ]
}
