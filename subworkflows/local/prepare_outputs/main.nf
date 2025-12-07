//
// Prepare results to be published by entry workflow output block
//


workflow PREPARE_OUTPUTS_WGTS {
    main:
    ch_results = channel.empty()
        .mix(
            channel.topic('amber_dir').map { meta, d ->                    return ["${meta.key}/${d.name}", d] },
            channel.topic('bamtools_metrics_dir').map { meta, d ->         return ["${meta.key}/bamtools/${meta.sample_id}", d] },
            channel.topic('chord_dir').map { meta, d ->                    return ["${meta.key}/${d.name}", d] },
            channel.topic('cider_results').map { meta, d ->                return ["${meta.key}/cider/${meta.sample_id}/", d] },
            channel.topic('cobalt_dir').map { meta, d ->                   return ["${meta.key}/${d.name}", d] },
            channel.topic('cuppa_dir').map { meta, d ->                    return ["${meta.key}/${d.name}", d] },
            channel.topic('esvee_dir').map { meta, d ->                    return ["${meta.key}/${d.name}", d] },
            channel.topic('gatk4_markduplicates_bam').map { meta, d ->     return ["${meta.key}/alignments/rna/${d.name}", d] },
            channel.topic('gatk4_markduplicates_bai').map { meta, d ->     return ["${meta.key}/alignments/rna/${d.name}", d] },
            channel.topic('isofox_dir').map { meta, d ->                   return ["${meta.key}/${d.name}", d] },
            channel.topic('lilac_dir').map { meta, d ->                    return ["${meta.key}/${d.name}", d] },
            channel.topic('linx_germline_annotation_dir').map { meta, d -> return ["${meta.key}/linx/germline_annotations", d] },
            channel.topic('linx_somatic_annotation_dir').map { meta, d ->  return ["${meta.key}/linx/somatic_annotations", d] },
            channel.topic('linx_visualiser_plots').map { meta, d ->        return ["${meta.key}/linx/somatic_plots", d] },
            channel.topic('linxreport_html').map { meta, d ->              return ["${meta.key}/linx/${d.name}", d] },
            channel.topic('neo_annotated_fusions_tsv').map { meta, d ->    return ["${meta.key}/neo/annotated_fusions/${d.name}", d] },
            channel.topic('neo_finder_dir').map { meta, d ->               return ["${meta.key}/neo/finder", d] },
            channel.topic('neo_scorer_dir').map { meta, d ->               return ["${meta.key}/neo/scorer", d] },
            channel.topic('orange_pdf').map { meta, d ->                   return ["${meta.key}/orange/${d.name}", d] },
            channel.topic('orange_json').map { meta, d ->                  return ["${meta.key}/orange/${d.name}", d] },
            channel.topic('pave_germline_vcf').map { meta, d ->            return ["${meta.key}/pave/${d.name}", d] },
            channel.topic('pave_germline_index').map { meta, d ->          return ["${meta.key}/pave/${d.name}", d] },
            channel.topic('pave_somatic_vcf').map { meta, d ->             return ["${meta.key}/pave/${d.name}", d] },
            channel.topic('pave_somatic_index').map { meta, d ->           return ["${meta.key}/pave/${d.name}", d] },
            channel.topic('peach_dir').map { meta, d ->                    return ["${meta.key}/${d.name}", d] },
            channel.topic('purple_dir').map { meta, d ->                   return ["${meta.key}/${d.name}", d] },
            //channel.topic('redux_bam').flatMap { def meta = it[0];         return ["${meta.key}/alignments/dna/", it[1..-1]] },
            channel.topic('redux_dup_freq_tsv').map { meta, d ->           return ["${meta.key}/alignments/dna/", d] },
            channel.topic('redux_jitter_tsv').map { meta, d ->             return ["${meta.key}/alignments/dna/", d] },
            channel.topic('redux_ms_tsv').map { meta, d ->                 return ["${meta.key}/alignments/dna/", d] },
            channel.topic('sage_append_dir').map { meta, d ->              return ["${meta.key}/${d.name}", d] },
            channel.topic('sage_germline_dir').map { meta, d ->            return ["${meta.key}/sage/germline", d] },
            channel.topic('sage_somatic_dir').map { meta, d ->             return ["${meta.key}/sage/somatic", d] },
            channel.topic('sigs_dir').map { meta, d ->                     return ["${meta.key}/${d.name}", d] },
            channel.topic('teal_prep_tumor_bam').map { def meta = it[0];   return ["${meta.key}/teal/"] + it[1..-1] },
            channel.topic('teal_prep_normal_bam').map { def meta = it[0];  return ["${meta.key}/teal/"] + it[1..-1] },
            channel.topic('virusbreakend_tsv').map { meta, d ->            return ["${meta.key}/virusbreakend/${d.name}", d] },
            channel.topic('virusbreakend_vcf').map { meta, d ->            return ["${meta.key}/virusbreakend/${d.name}", d] },
            channel.topic('virusinterpreter_dir').map { meta, d ->         return ["${meta.key}/${d.name}", d] },
        )
        .flatMap { meta, d -> return d instanceof List ? d.collect { [meta, it] } : [[meta, d]] }

    emit:
    results = ch_results
}
