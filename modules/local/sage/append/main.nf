process SAGE_APPEND {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/hmftools-sage:4.0_beta--hdfd78af_3' :
        'biocontainers/hmftools-sage:4.0_beta--hdfd78af_3' }"

    input:
    tuple val(meta), path(vcf), path(bams), path(bais)
    path genome_fasta
    val genome_ver
    path genome_fai
    path genome_dict

    output:
    tuple val(meta), path('sage_append'), emit: sage_append_dir
    path 'versions.yml'                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    mkdir -p sage_append/

    sage \\
        -Xmx${Math.round(task.memory.bytes * 0.95)} \\
        com.hartwig.hmftools.sage.append.SageAppendApplication \\
        ${args} \\
        -input_vcf ${vcf} \\
        -reference ${meta.reference_ids.join(',')} \\
        -reference_bam ${bams.join(',')} \\
        -ref_genome ${genome_fasta} \\
        -ref_genome_version ${genome_ver} \\
        -write_frag_lengths \\
        -threads ${task.cpus} \\
        -output_vcf sage_append/${meta.sample_id}.sage.append.vcf.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sage: \$(sage -version | sed 's/^.* //')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p sage_append/

    touch sage_append/${meta.sample_id}.frag_lengths.tsv.gz
    touch sage_append/${meta.sample_id}.sage.append.vcf.gz
    touch sage_append/${meta.sample_id}.sage.append.vcf.gz.tbi
    touch sage_append/${meta.sample_id}_query.sage.bqr.tsv

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
