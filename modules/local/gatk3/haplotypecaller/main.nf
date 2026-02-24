process GATK3_HAPLOTYPECALLER {
    tag "${meta.id}"
    label 'process_medium'

    container "docker.io/broadinstitute/gatk3:3.8-1"

    input:
    tuple val(meta), path(input), path(input_index)
    path fasta
    path fai
    path("${fasta.baseName}.dict")

    output:
    tuple val(meta), path("*.g.vcf.gz"), path("*.g.vcf.gz.tbi"), emit: vcf
    path 'versions.yml'                                         , emit: versions
    path '.command.*'                                           , emit: command_files

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: [
        '-variant_index_type LINEAR',
        '-variant_index_parameter 128000',
        '-stand_call_conf 15.0',
        '-ERC GVCF',
        '-GQB 5 -GQB 10 -GQB 15 -GQB 20 -GQB 30 -GQB 40 -GQB 50 -GQB 60',
        '--sample_ploidy 2',
    ].join(' ')
    def prefix = task.ext.prefix ?: "${meta.sample_id}"

    def avail_mem = 3072
    if (!task.memory) {
        log.info('[GATK HaplotypeCaller] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.')
    }
    else {
        avail_mem = (task.memory.mega * 0.8).intValue()
    }
    """
    java -Xmx${avail_mem}M -jar /usr/GenomeAnalysisTK.jar \\
        -T HaplotypeCaller \\
        -nct ${task.cpus} \\
        --input_file ${input} \\
        -o ${prefix}.g.vcf.gz \\
        --reference_sequence ${fasta} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gatk3: \$(java -jar /usr/GenomeAnalysisTK.jar --version 2>&1 | head -1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.sample_id}"

    """
    touch ${prefix}.g.vcf.gz
    touch ${prefix}.g.vcf.gz.tbi

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
