//
// Prepare reference data as required
//

include { SAMTOOLS_FAIDX         } from '../../modules/nf-core/samtools/faidx/main'
include { SAMTOOLS_DICT          } from '../../modules/nf-core/samtools/dict/main'
include { BWA_INDEX              } from '../../modules/nf-core/bwa/index/main'

include { CUSTOM_EXTRACTTARBALL as DECOMP_BWA_INDEX        } from '../../modules/local/custom/extract_tarball/main'
include { CUSTOM_EXTRACTTARBALL as DECOMP_HMF_DATA         } from '../../modules/local/custom/extract_tarball/main'
include { CUSTOM_EXTRACTTARBALL as DECOMP_VIRUSBREAKEND_DB } from '../../modules/local/custom/extract_tarball/main'
include { GRIDSS_INDEX as GRIDSS_BWA_INDEX_IMAGE           } from '../../modules/local/gridss/index/main'
include { GRIDSS_INDEX as GRIDSS_INDEX                     } from '../../modules/local/gridss/index/main'

workflow PREPARE_REFERENCE {
    take:
        run // map: stages to run

    main:
        // Channel for version.yml files
        ch_versions = Channel.empty()

        //
        // Set reference genome FASTA for consistency
        //
        ch_genome_fasta = file(params.ref_data_genome_fasta)

        //
        // Create .fai and .dict for reference genome if required
        //
        // The fai and dict files should always be present if using a genome preset. These are
        // always created where they are not present without checking processes to run given they
        // are used in numerous processes and have a neglibile cost to generate.
        ch_genome_fai = file(params.ref_data_genome_fai)
        ch_genome_dict = file(params.ref_data_genome_dict)
        if (!params.ref_data_genome_fai) {
            SAMTOOLS_FAIDX([:], ch_genome_fasta)
            ch_genome_fai = SAMTOOLS_FAIDX.out.fai
            ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)
        }
        if (!params.ref_data_genome_dict) {
            SAMTOOLS_DICT([:], ch_genome_fasta)
            ch_genome_dict = SAMTOOLS_DICT.out.dict
            ch_versions = ch_versions.mix(SAMTOOLS_DICT.out.versions)
        }

        //
        // Create BWA index, BWA index image, and GRIDSS index for reference genome if required
        //
        ch_genome_bwa_index = file(params.ref_data_genome_bwa_index)
        ch_genome_bwa_index_image = file(params.ref_data_genome_bwa_index_image)
        ch_genome_gridss_index = file(params.ref_data_genome_gridss_index)
        if (run.gridss || run.virusinterpreter) {
            // NOTE(SW): the BWA index directory can be provided as a compressed tarball
            if (!params.ref_data_genome_bwa_index) {
                BWA_INDEX([[:], ch_genome_fasta])
                ch_genome_bwa_index = BWA_INDEX.out.index.map { it[1] }
                ch_versions = ch_versions.mix(BWA_INDEX.out.versions)
            } else if (params.ref_data_genome_bwa_index.endsWith('.tar.gz')) {
                ch_genome_bwa_index_inputs = [
                    [id: 'bwa_index'],
                    file(params.ref_data_genome_bwa_index),
                ]
                DECOMP_BWA_INDEX(ch_genome_bwa_index_inputs)
                ch_genome_bwa_index = DECOMP_BWA_INDEX.out.dir
            }

            if (!params.ref_data_genome_bwa_index_image) {
                GRIDSS_BWA_INDEX_IMAGE(
                    ch_genome_fasta,
                    ch_genome_fai,
                    ch_genome_dict,
                    ch_genome_bwa_index,
                    [],
                    ['bwa_index_image'],
                )
                ch_genome_bwa_index_image = GRIDSS_BWA_INDEX_IMAGE.out.img
                ch_versions = ch_versions.mix(GRIDSS_BWA_INDEX_IMAGE.out.versions)
            }
            if (!params.ref_data_genome_gridss_index) {
                GRIDSS_INDEX(
                    ch_genome_fasta,
                    ch_genome_fai,
                    ch_genome_dict,
                    ch_genome_bwa_index,
                    ch_genome_bwa_index_image,
                    ['gridss_index'],
                )
                ch_genome_gridss_index = GRIDSS_INDEX.out.index
                ch_versions = ch_versions.mix(GRIDSS_INDEX.out.versions)
            }
        }

        //
        // Set VIRUSBreakend database path / stage, unpack if required
        //
        ch_virusbreakenddb = Channel.empty()
        if (run.virusinterpreter) {
            if (params.ref_data_virusbreakenddb_path.endsWith('.tar.gz')) {
                ch_virusbreakenddb_inputs = [
                    [id: 'virusbreakenddb'],
                    file(params.ref_data_virusbreakenddb_path),
                ]
                DECOMP_VIRUSBREAKEND_DB(ch_virusbreakenddb_inputs)
                ch_virusbreakenddb = DECOMP_VIRUSBREAKEND_DB.out.dir
            } else {
                ch_virusbreakenddb = file(params.ref_data_virusbreakenddb_path)
            }
        }

        //
        // Set HMF reference paths / stage, unpack if required
        //
        if (params.ref_data_hmf_data_path.endsWith('tar.gz')) {
            // Decompress and set paths
            ch_hmf_data_inputs = [
                [id: 'hmf_data'],
                file(params.ref_data_hmf_data_path),
            ]
            DECOMP_HMF_DATA(ch_hmf_data_inputs)

            ch_hmf_data = DECOMP_HMF_DATA.out.dir
                .collect()
                .map { dir_list ->
                    assert dir_list.size() == 1
                    return createHmfDataMap(dir_list[0], false /* params_only */)
                }
        } else if (params.ref_data_hmf_data_path) {
            // If provided as path to directory, set paths
            ch_hmf_data = createHmfDataMap(params.ref_data_hmf_data_path, false /* params_only */)
        } else {
            // If no HMF data bundle is supplied we construct from *only* params
            ch_hmf_data = createHmfDataMap(null, true /* params_only */)
        }

    emit:
        genome_fasta           = ch_genome_fasta                // path: genome_fasta
        genome_fai             = ch_genome_fai                  // path: genome_fai
        genome_dict            = ch_genome_dict                 // path: genome_dict
        genome_bwa_index       = ch_genome_bwa_index            // path: genome_bwa_index
        genome_bwa_index_image = ch_genome_bwa_index_image      // path: genome_bwa_index_image
        genome_gridss_index    = ch_genome_gridss_index         // path: genome_gridss_index
        genome_version         = params.ref_data_genome_version // val:  genome_version

        virusbreakenddb        = ch_virusbreakenddb             // path: VIRUSBreakend database
        hmf_data               = ch_hmf_data                    // map:  HMF data paths

        versions               = ch_versions                    // channel: [versions.yml]
}

def createHmfDataMap(hmf_data_path, params_only) {
    // NOTE(SW): this code provides an explicit mapping between user exposed HMF data params and
    // their corresponding internal representation
    def params_mapping = [
        // AMBER
        heterozygous_sites:           'ref_data_heterozygous_sites',
        // COBALT
        gc_profile:                   'ref_data_gc_profile',
        // CUPPA
        cuppa_resources:              'ref_data_cuppa_resources',
        // SVPREP
        'sv_prep_blocklist':          'ref_data_sv_prep_blocklist',
        // GRIDSS, GRIPSS
        gridss_pon_breakends:         'ref_data_gridss_pon_breakends',
        gridss_pon_breakpoints:       'ref_data_gridss_pon_breakpoints',
        gridss_region_blocklist:      'ref_data_gridss_region_blocklist',
        repeatmasker_annotations:     'ref_data_repeatmasker_annotations',
        // Isofox
        isofox_counts:                'ref_data_isofox_counts',
        isofox_gc_ratios:             'ref_data_isofox_gc_ratios',
        // LILAC
        lilac_resources:              'ref_data_lilac_resources',
        // LINX
        linx_fragile_regions:         'ref_data_linx_fragile_regions',
        linx_lines:                   'ref_data_linx_lines',
        // ORANGE
        cohort_mapping:               'ref_data_cohort_mapping',
        cohort_percentiles:           'ref_data_cohort_percentiles',
        // PEACH
        peach_panel:                  'ref_data_peach_panel',
        // PROTECT
        serve_resources:              'ref_data_serve_resources',
        // SAGE
        clinvar_annotations:          'ref_data_clinvar_annotations',
        sage_blocklist_regions:       'ref_data_sage_blocklist_regions',
        sage_blocklist_sites:         'ref_data_sage_blocklist_sites',
        sage_actionable_panel:        'ref_data_sage_actionable_panel',
        sage_coverage_panel:          'ref_data_sage_coverage_panel',
        sage_highconf_regions:        'ref_data_sage_highconf_regions',
        sage_known_hotspots_germline: 'ref_data_sage_known_hotspots_germline',
        sage_known_hotspots_somatic:  'ref_data_sage_known_hotspots_somatic',
        sage_pon:                     'ref_data_sage_pon',
        // SIGS
        sigs_signatures:              'ref_data_sigs_signatures',
        // Virus Interpreter
        virus_reporting_db:           'ref_data_virus_reporting_db',
        virus_taxonomy_db:            'ref_data_virus_taxonomy_db',
        // Misc
        disease_ontology:             'ref_data_disease_ontology',
        driver_gene_panel:            'ref_data_driver_gene_panel',
        ensembl_data_resources:       'ref_data_ensembl_data_resources',
        gnomad_pon_dir:               'ref_data_gnomad_pon_dir',
        known_fusion_data:            'ref_data_known_fusion_data',
        known_fusions:                'ref_data_known_fusions',
        purple_germline_del:          'ref_data_purple_germline_del',
        segment_mappability:          'ref_data_segment_mappability',
    ]
    params_mapping.collectEntries { k, v ->
        [k, getHmfDataFileObject(v, k, hmf_data_path, params_only)]
    }
}

def getHmfDataFileObject(pk, hk, base_dir, params_only) {
    def hmfdata_paths = params.hmfdata_paths.getAt(params.ref_data_genome_version)
    if (params.containsKey(pk)) {
        return file(params.getAt(pk), checkIfExists: true)
    } else if (params_only) {
        log.error "ERROR: no entry for ${pk} found in params but is required as no HMF data base path provided"
        System.exit(1)
    } else if (!hmfdata_paths.containsKey(hk)) {
        assert false : "bad key for params.hmfdata_paths.${params.genome_version}: ${hk}"
    } else {

      // NOTE(SW): allow paths to optionally set by checking for and returning '[]' values
      def value = hmfdata_paths.getAt(hk)
      if (value == []) {
          return value
      }

      def base_dir_noslash = base_dir.toString().replaceAll('/$', '')
      return file("${base_dir_noslash}/${hmfdata_paths.getAt(hk)}", checkIfExists: true)
    }
}
