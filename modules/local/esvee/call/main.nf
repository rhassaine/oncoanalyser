process ESVEE_CALL {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/hmftools-esvee:1.0_beta--hdfd78af_3' :
        'biocontainers/hmftools-esvee:1.0_beta--hdfd78af_3' }"

    input:
    tuple val(meta), path(ref_depth_vcf), path(fragment_lengths_tsv)
    path genome_fasta
    val genome_ver
    path pon_breakends
    path pon_breakpoints
    path known_fusions
    path repeatmasker_annotations

    output:
    tuple val(meta), path("caller/"), emit: caller_dir
    tuple val(meta), path("caller/${meta.tumor_id}.esvee.unfiltered.vcf.gz"), path("caller/${meta.tumor_id}.esvee.unfiltered.vcf.gz.tbi"), emit: unfiltered_vcf
    tuple val(meta), path("caller/${meta.tumor_id}.esvee.somatic.vcf.gz"),    path("caller/${meta.tumor_id}.esvee.somatic.vcf.gz.tbi"),    emit: somatic_vcf
    tuple val(meta), path("caller/${meta.tumor_id}.esvee.germline.vcf.gz"),   path("caller/${meta.tumor_id}.esvee.germline.vcf.gz.tbi"),   emit: germline_vcf, optional: true
    path 'versions.yml', emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    def reference_arg = meta.normal_id != null ? "-reference ${meta.normal_id}" : ""

    """
    mkdir -p caller/

    # ESVEE expects the fragment_lengths.tsv file to be present in the output directory
    ln -sf ../${fragment_lengths_tsv} caller/

    esvee com.hartwig.hmftools.esvee.caller.CallerApplication \\
        -Xmx${Math.round(task.memory.bytes * 0.95)} \\
        ${args} \\
        -sample ${meta.tumor_id} \\
        ${reference_arg} \\
        -input_vcf ${ref_depth_vcf} \\
        -ref_genome_version ${genome_ver} \\
        -known_hotspot_file ${known_fusions} \\
        -pon_sgl_file ${pon_breakends} \\
        -pon_sv_file ${pon_breakpoints} \\
        -repeat_mask_file ${repeatmasker_annotations} \\
        -output_dir caller/ \\
        -log_debug

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        esvee: \$(esvee -version | grep -m1 'Esvee version' | sed 's/^.* //')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p caller/

    vcf_template='##fileformat=VCFv4.1
    ##contig=<ID=.>
    #CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO
    .	.	.	.	.	.	.
    '

    echo \${vcf_template} | gzip -c > caller/${meta.tumor_id}.esvee.unfiltered.vcf.gz
    echo \${vcf_template} | gzip -c > caller/${meta.tumor_id}.esvee.somatic.vcf.gz
    echo \${vcf_template} | gzip -c > caller/${meta.tumor_id}.esvee.germline.vcf.gz

    touch caller/${meta.tumor_id}.esvee.unfiltered.vcf.gz.tbi
    touch caller/${meta.tumor_id}.esvee.somatic.vcf.gz.tbi
    touch caller/${meta.tumor_id}.esvee.germline.vcf.gz.tbi

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
