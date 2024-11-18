process PAVE_PON_BUILDER {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/hmftools-pave:1.7_beta--hdfd78af_1' :
        'biocontainers/hmftools-pave:1.7_beta--hdfd78af_1' }"

    input:
    tuple val(meta), path(sample_ids), path(sage_vcf), path(sage_tbi)
    val genome_ver

    output:

    // NOTE(SW): determine the exact output files

    tuple val(meta), path("*.vcf.gz")    , emit: vcf
    tuple val(meta), path("*.vcf.gz.tbi"), emit: index
    path 'versions.yml'                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    pave com.hartwig.hmftools.pave.resources.PonBuilder \\
        -Xmx${Math.round(task.memory.bytes * 0.95)} \\
        ${args} \\
        -sample_id_file ${sample_ids} \\
        -vcf_path ${sage_vcf} \\
        -ref_genome_version ${genome_ver} \\
        -min_samples 3 \\
        -qual_cutoff 100 \\
        -output_dir ./

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pave: \$(pave -version | sed 's/^.* //')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.sample_id}.sage.pave_somatic.vcf.gz{,.tbi}

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}

