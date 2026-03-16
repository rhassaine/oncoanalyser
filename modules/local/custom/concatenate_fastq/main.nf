process CONCATENATE_FASTQ {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'quay.io/nf-core/ubuntu:20.04' }"

    input:
    tuple val(meta), path(reads_fwd), path(reads_rev)

    output:
    tuple val(meta), path('*_R1.fastq.gz'), path('*_R2.fastq.gz'), emit: fastq
    path '.command.*'                                            , emit: command_files

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    cat ${reads_fwd} > ${meta.id}_R1.fastq.gz
    cat ${reads_rev} > ${meta.id}_R2.fastq.gz
    """

    stub:
    """
    touch ${meta.id}_R{1,2}.fastq.gz
    """
}
