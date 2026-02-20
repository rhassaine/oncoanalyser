process VCHORD {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "ghcr.io/rhassaine/v-chord:1.0"

    input:
    tuple val(meta), path(purple_dir)
    path model

    output:
    tuple val(meta), path('vchord/'), emit: vchord_dir
    path 'versions.yml'             , emit: versions
    path '.command.*'               , emit: command_files

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    def xmx_mod = task.ext.xmx_mod ?: 0.95

    def log_level_arg = task.ext.log_level ? "-log_level ${task.ext.log_level}" : ''

    """
    mkdir -p vchord/

    v-chord \\
        -Xmx${Math.round(task.memory.bytes * xmx_mod)} \\
        ${args} \\
        -sample ${meta.sample_id} \\
        -purple_dir ${purple_dir} \\
        -model ${model} \\
        ${log_level_arg} \\
        -output_dir vchord/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vchord: \$(v-chord -version | sed -n '/version/ { s/^.* //p }')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p vchord/

    touch vchord/${meta.sample_id}.vchord.prediction.tsv

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
