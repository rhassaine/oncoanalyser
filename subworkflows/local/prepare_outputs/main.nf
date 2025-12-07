//
// Prepare results to be published by entry workflow output block
//


workflow PREPARE_OUTPUTS_WGTS {
    main:
    ch_results = channel.empty()
        .mix(
            channel.topic('amber_dir').map { meta, fp ->                    return ["${meta.key}/${fp.name}", fp] },
            channel.topic('bamtools_metrics_dir').map { meta, fp ->         return ["${meta.key}/bamtools/${meta.sample_id}", fp] },
            channel.topic('chord_dir').map { meta, fp ->                    return ["${meta.key}/${fp.name}", fp] },
            channel.topic('cider_results').map { meta, fp ->                return ["${meta.key}/cider/${meta.sample_id}/", fp] },
            channel.topic('cobalt_dir').map { meta, fp ->                   return ["${meta.key}/${fp.name}", fp] },
            channel.topic('cuppa_dir').map { meta, fp ->                    return ["${meta.key}/${fp.name}", fp] },
            channel.topic('esvee_dir').map { meta, fp ->                    return ["${meta.key}/${fp.name}", fp] },
            channel.topic('gatk4_markduplicates_bam').map { meta, fp ->     return ["${meta.key}/alignments/rna/${fp.name}", fp] },
            channel.topic('gatk4_markduplicates_bai').map { meta, fp ->     return ["${meta.key}/alignments/rna/${fp.name}", fp] },
            channel.topic('isofox_dir').map { meta, fp ->                   return ["${meta.key}/${fp.name}", fp] },
            channel.topic('lilac_dir').map { meta, fp ->                    return ["${meta.key}/${fp.name}", fp] },
            channel.topic('linx_germline_annotation_dir').map { meta, fp -> return ["${meta.key}/linx/germline_annotations", fp] },
            channel.topic('linx_somatic_annotation_dir').map { meta, fp ->  return ["${meta.key}/linx/somatic_annotations", fp] },
            channel.topic('linx_visualiser_plots').map { meta, fp ->        return ["${meta.key}/linx/somatic_plots", fp] },
            channel.topic('linxreport_html').map { meta, fp ->              return ["${meta.key}/linx/${fp.name}", fp] },
            channel.topic('neo_annotated_fusions_tsv').map { meta, fp ->    return ["${meta.key}/neo/annotated_fusions/${fp.name}", fp] },
            channel.topic('neo_finder_dir').map { meta, fp ->               return ["${meta.key}/neo/finder", fp] },
            channel.topic('neo_scorer_dir').map { meta, fp ->               return ["${meta.key}/neo/scorer", fp] },
            channel.topic('orange_pdf').map { meta, fp ->                   return ["${meta.key}/orange/${fp.name}", fp] },
            channel.topic('orange_json').map { meta, fp ->                  return ["${meta.key}/orange/${fp.name}", fp] },
            channel.topic('pave_germline_vcf').map { meta, fp ->            return ["${meta.key}/pave/${fp.name}", fp] },
            channel.topic('pave_germline_index').map { meta, fp ->          return ["${meta.key}/pave/${fp.name}", fp] },
            channel.topic('pave_somatic_vcf').map { meta, fp ->             return ["${meta.key}/pave/${fp.name}", fp] },
            channel.topic('pave_somatic_index').map { meta, fp ->           return ["${meta.key}/pave/${fp.name}", fp] },
            channel.topic('peach_dir').map { meta, fp ->                    return ["${meta.key}/${fp.name}", fp] },
            channel.topic('purple_dir').map { meta, fp ->                   return ["${meta.key}/${fp.name}", fp] },
            //channel.topic('redux_bam').flatMap { def meta = it[0];          return ["${meta.key}/alignments/dna/", it[1..-1]] },
            channel.topic('redux_dup_freq_tsv').map { meta, fp ->           return ["${meta.key}/alignments/dna/", fp] },
            channel.topic('redux_jitter_tsv').map { meta, fp ->             return ["${meta.key}/alignments/dna/", fp] },
            channel.topic('redux_ms_tsv').map { meta, fp ->                 return ["${meta.key}/alignments/dna/", fp] },
            //channel.topic('sage_append_dir').map { meta, fp ->              return ["${meta.key}/${fp.name}", fp] },
            //channel.topic('sage_germline_dir').map { meta, fp ->            return ["${meta.key}/sage/germline", fp] },
            //channel.topic('sage_somatic_dir').map { meta, fp ->             return ["${meta.key}/sage/somatic", fp] },
            //channel.topic('sigs_dir').map { meta, fp ->                     return ["${meta.key}/${fp.name}", fp] },
            //channel.topic('teal_prep_tumor_bam').map { def meta = it[0];    return ["${meta.key}/teal/", it[1..-1]] },
            //channel.topic('teal_prep_normal_bam').map { def meta = it[0];   return ["${meta.key}/teal/", it[1..-1]] },
            //channel.topic('virusbreakend_tsv').map { meta, fp ->            return ["${meta.key}/virusbreakend/${fp.name}", fp] },
            //channel.topic('virusbreakend_vcf').map { meta, fp ->            return ["${meta.key}/virusbreakend/${fp.name}", fp] },
            //channel.topic('virusinterpreter_dir').map { meta, fp ->         return ["${meta.key}/${fp.name}", fp] },
        )

    emit:
    results = ch_results
}
