process PAVE_PON_PANEL_CREATION {
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/hmftools-pave:1.7_beta--hdfd78af_1' :
        'biocontainers/hmftools-pave:1.7_beta--hdfd78af_1' }"

    input:
    tuple path(sample_ids), path(sage_vcf), path(sage_tbi)
    val genome_ver

    output:
    path 'sage.pave_somatic.vcf.gz'
    path 'versions.yml', emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    pave com.hartwig.hmftools.pave.pon_gen.PonBuilder \\
        -Xmx${Math.round(task.memory.bytes * 0.95)} \\
        ${args} \\
        -sample_id_file ${sample_ids} \\
        -vcf_path ${sage_vcf} \\
        -ref_genome_version ${genome_ver} \\
        -output_dir ./

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pave: \$(pave -version | sed 's/^.* //')
    END_VERSIONS
    """

    stub:
    """
    touch sage.pave_somatic.vcf.gz{,.tbi}

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}

