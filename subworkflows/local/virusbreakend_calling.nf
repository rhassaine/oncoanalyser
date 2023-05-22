//
// XXX
//
import Constants
import Utils

include { VIRUSBREAKEND    } from '../../modules/local/virusbreakend/main'
include { VIRUSINTERPRETER } from '../../modules/local/virusinterpreter/main'

workflow VIRUSBREAKEND_CALLING {
    take:
        // Sample data
        ch_inputs
        ch_purple
        ch_bamtools_somatic

        // Reference data
        ref_data_genome_fasta
        ref_data_genome_fai
        ref_data_genome_dict
        ref_data_genome_bwa_index
        ref_data_genome_bwa_index_image
        ref_data_genome_gridss_index
        ref_data_virusbreakenddb
        ref_data_virus_taxonomy_db
        ref_data_virus_reporting_db

        // Params
        gridss_config
        run_config

    main:
        // Channel for version.yml files
        ch_versions = Channel.empty()

        // VIRUSBreakend
        // Create inputs and create process-specific meta
        // channel: [val(meta_virus), tumor_bam]
        ch_virusbreakend_inputs = ch_inputs
            .map { meta ->
                def meta_virus = [
                    key: meta.id,
                    id: meta.id,
                ]
                return [meta_virus, Utils.getTumorBam(meta, run_config.mode)]
            }

        // Run process
        VIRUSBREAKEND(
            ch_virusbreakend_inputs,
            gridss_config,
            ref_data_genome_fasta,
            ref_data_genome_fai,
            ref_data_genome_dict,
            ref_data_genome_bwa_index,
            ref_data_genome_bwa_index_image,
            ref_data_genome_gridss_index,
            ref_data_virusbreakenddb,
        )

        // Create inputs and create process-specific meta
        if (run_config.stages.purple) {
            ch_virusinterpreter_inputs_purple = ch_purple
        } else {
            ch_virusinterpreter_inputs_purple = WorkflowOncoanalyser.getInput(ch_inputs, Constants.INPUT.PURPLE_DIR)
        }

        // channel: [val(meta), purple_qc, wgs_metrics]
        ch_virusinterpreter_inputs_purple_files = ch_virusinterpreter_inputs_purple
            .filter { it[0] != Constants.PLACEHOLDER_META }
            .map { meta, purple_dir ->
                def tumor_id = Utils.getTumorSampleName(meta, run_config.mode)
                def purple_purity = file(purple_dir).resolve("${tumor_id}.purple.purity.tsv")
                def purple_qc = file(purple_dir).resolve("${tumor_id}.purple.qc")

                // Require both purity and QC files from the PURPLE directory
                if (!purple_purity.exists() || !purple_qc.exists()) {
                    return Constants.PLACEHOLDER_META
                }
                return [meta, purple_purity, purple_qc]
            }
            .filter { it != Constants.PLACEHOLDER_META }

        // channel: [val(meta), virus_tsv, purple_purity, purple_qc, wgs_metrics]
        ch_virusinterpreter_inputs_full = WorkflowOncoanalyser.groupByMeta(
            WorkflowOncoanalyser.restoreMeta(VIRUSBREAKEND.out.tsv, ch_inputs),
            ch_virusinterpreter_inputs_purple_files,
            run_config.stages.bamtools ? ch_bamtools_somatic : WorkflowOncoanalyser.getInput(ch_inputs, Constants.INPUT.INPUT_BAMTOOLS_TUMOR),
        )

        // Virus Interpreter
        // Create inputs and create process-specific meta
        // channel: [val(meta_virus), virus_tsv, purple_purity, purple_qc, wgs_metrics]
        ch_virusinterpreter_inputs = ch_virusinterpreter_inputs_full
            .map {
                def meta = it[0]
                def meta_virus = [
                    key: meta.id,
                    id: Utils.getTumorSampleName(meta, run_config.mode),
                ]
                return [meta_virus, *it[1..-1]]
            }

        // Run process
        VIRUSINTERPRETER(
            ch_virusinterpreter_inputs,
            ref_data_virus_taxonomy_db,
            ref_data_virus_reporting_db,
        )

        // Set outputs, restoring original meta
        ch_outputs = WorkflowOncoanalyser.restoreMeta(VIRUSINTERPRETER.out.virusinterpreter, ch_inputs)
        ch_versions = ch_versions.mix(
            VIRUSINTERPRETER.out.versions,
            VIRUSBREAKEND.out.versions,
        )

    emit:
        virusinterpreter = ch_outputs  // channel: [val(meta), virusinterpreter]

        versions         = ch_versions // channel: [versions.yml]
}
