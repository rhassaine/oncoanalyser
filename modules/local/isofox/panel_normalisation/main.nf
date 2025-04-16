process ISOFOX_PANEL_NORMALISATION {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/hmftools-isofox:1.7.1--hdfd78af_0' :
        'biocontainers/hmftools-isofox:1.7.1--hdfd78af_0' }"

    input:
    tuple val(meta), path(sample_data), path(isofox_dirs)
    path gene_ids
    path gene_dist_file


    output:




    // NOTE(SW): this should be changed so that genome_ver is encoded in filename for consistency



    tuple val(meta), path('panel_gene_normalisation.csv'), emit: tmp_normalisation
    path 'versions.yml'                                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    mkdir -p isofox__prepared/
    for fp in \$(find ${isofox_dirs} -name '*.gene_data.csv'); do ln -s ../\${fp} isofox__prepared/; done

    isofox com.hartwig.hmftools.isofox.cohort.CohortAnalyser \\
        -Xmx${Math.round(task.memory.bytes * 0.95)} \\
        ${args} \\
        -sample_data_file ${sample_data} \\
        -root_data_dir isofox__prepared/ \\
        -analysis_types panel_tpm_normalisation \\
        -gene_id_file ${gene_id_file} \\
        -gene_dist_file ${gene_dist_file}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        isofox: \$(isofox -version | sed 's/^.* //')
    END_VERSIONS
    """

    stub:
    """
    touch panel_gene_normalisation.csv

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
