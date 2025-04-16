process COBALT_PANEL_NORMALISATION {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/hmftools-cobalt:2.0_beta--hdfd78af_0' :
        'biocontainers/hmftools-cobalt:2.0_beta--hdfd78af_0' }"

    input:
    tuple val(meta), path(sample_ids), path(amber_dir), path(cobalt_dir)
    val genome_ver
    path gc_profile
    path target_region_bed

    output:
    tuple val(meta), path('*tsv'), emit: cobalt_normalisation
    path 'versions.yml'          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    cobalt com.hartwig.hmftools.cobalt.norm.NormalisationFileBuilder \\
        -Xmx${Math.round(task.memory.bytes * 0.95)} \\
        ${args} \\
        -sample_id_file ${sample_ids} \\
        -amber_dir ${amber_dir} \\
        -cobalt_dir ${cobalt_dir} \\
        -ref_genome_version ${genome_ver} \\
        -gc_profile ${gc_profile} \\
        -target_regions_bed ${target_region_bed} \\
        -threads ${task.cpus} \\
        -output_file target_regions.cobalt_normalisation.${genome_ver}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cobalt: \$(cobalt -version | sed 's/^.* //')
    END_VERSIONS
    """

    stub:
    """
    touch target_regions.cobalt_normalisation.${genome_ver}.tsv

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
