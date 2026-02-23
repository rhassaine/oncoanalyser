process GATK4_HAPLOTYPECALLER {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gatk4:4.6.1.0--py310hdfd78af_0' :
        'biocontainers/gatk4:4.6.1.0--py310hdfd78af_0' }"

    input:
    tuple val(meta), path(input), path(input_index)
    path fasta
    path fai
    path dict

    output:
    tuple val(meta), path("*.g.vcf.gz"), path("*.g.vcf.gz.tbi"), emit: vcf
    path 'versions.yml'                                         , emit: versions
    path '.command.*'                                           , emit: command_files

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: [
        '-ERC GVCF',
        '-GQB 5 -GQB 10 -GQB 15 -GQB 20 -GQB 30 -GQB 40 -GQB 50 -GQB 60',
        '--standard-min-confidence-threshold-for-calling 15.0',
        '--sample-ploidy 2',
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
    gatk --java-options "-Xmx${avail_mem}M -XX:-UsePerfData" \\
        HaplotypeCaller \\
        --input ${input} \\
        --output ${prefix}.g.vcf.gz \\
        --reference ${fasta} \\
        --native-pair-hmm-threads ${task.cpus} \\
        --tmp-dir . \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gatk4: \$(echo \$(gatk --version 2>&1) | sed 's/^.*(GATK) v//; s/ .*\$//')
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
