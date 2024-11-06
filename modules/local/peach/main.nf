process PEACH {
    tag "${meta.id}"
    label 'process_single'

    container 'docker.io/scwatts/peach:2.0--0'

    input:
    tuple val(meta), path(germline_vcf)
    path haplotypes
    path haplotype_functions
    path drug_info

    output:
    tuple val(meta), path('peach/'), emit: peach_dir
    path 'versions.yml'            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    java \\
        -Xmx${Math.round(task.memory.bytes * 0.95)} \\
        -jar /opt/peach/peach.jar \\
            ${args} \\
            -sample_name ${meta.sample_id} \\
            -vcf_file ${germline_vcf} \\
            -haplotypes_file ${haplotypes} \\
            -function_file ${haplotype_functions} \\
            -drugs_file ${drug_info} \\
            -output_dir peach/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        peach: \$(java -jar /opt/peach/peach.jar -version | sed 's/^.* //')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p peach/

    touch peach/${meta.tumor_id}.peach.events.tsv
    touch peach/${meta.tumor_id}.peach.gene.events.tsv
    touch peach/${meta.tumor_id}.peach.haplotypes.all.tsv
    touch peach/${meta.tumor_id}.peach.haplotypes.best.tsv
    touch peach/${meta.tumor_id}.peach.qc.tsv

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
