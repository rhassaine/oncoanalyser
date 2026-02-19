process HEALTHCHECKER {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container 'TODO_HEALTHCHECKER_IMAGE:TAG'

    input:
    tuple val(meta), path(tumor_flagstat), path(ref_flagstat), path(tumor_metrics_dir, stageAs: 'tumor_metrics'), path(ref_metrics_dir, stageAs: 'ref_metrics'), path(purple_dir)

    output:
    tuple val(meta), path('health_checker/'), emit: healthchecker_dir
    path 'versions.yml'                     , emit: versions
    path '.command.*'                       , emit: command_files

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    def xmx_mod = task.ext.xmx_mod ?: 0.95

    def log_level_arg = task.ext.log_level ? "-log_level ${task.ext.log_level}" : ''

    """
    mkdir -p health_checker/

    health-checker \\
        -Xmx${Math.round(task.memory.bytes * xmx_mod)} \\
        ${args} \\
        -tumor ${meta.tumor_id} \\
        -reference ${meta.normal_id} \\
        -tum_flagstat_file ${tumor_flagstat} \\
        -ref_flagstat_file ${ref_flagstat} \\
        -tum_wgs_metrics_file tumor_metrics/${meta.tumor_id}.bam_metric.summary.tsv \\
        -ref_wgs_metrics_file ref_metrics/${meta.normal_id}.bam_metric.summary.tsv \\
        -purple_dir ${purple_dir} \\
        ${log_level_arg} \\
        -output_dir health_checker/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        health-checker: \$(health-checker -version | sed -n '/version/ { s/^.* //p }')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p health_checker/

    touch health_checker/${meta.tumor_id}.health_check.tsv

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
