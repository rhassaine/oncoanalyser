process SAMTOOLS_FLAGSTAT {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.21--h50ea8bc_0' :
        'biocontainers/samtools:1.21--h50ea8bc_0' }"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("${meta.sample_id}.flagstat"), emit: flagstat
    path 'versions.yml'                                , emit: versions
    path '.command.*'                                  , emit: command_files

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    samtools \\
        flagstat \\
        ${args} \\
        -@ ${task.cpus} \\
        ${bam} \\
        > ${meta.sample_id}.flagstat

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.sample_id}.flagstat

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
