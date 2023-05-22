process LILAC {
    tag "${meta.id}"
    label 'process_medium'

    container 'docker.io/scwatts/lilac:1.4.2--0'

    input:
    tuple val(meta), path(normal_wgs_bam), path(normal_wgs_bai), path(tumor_bam), path(tumor_bai), path(tumor_wts_bam), path(tumor_wts_bai), path(gene_cn), path(smlv_vcf)
    path genome_fasta
    val genome_ver
    path lilac_resources, stageAs: 'lilac_resources'

    output:
    tuple val(meta), path('lilac/'), emit: lilac_dir
    path 'versions.yml'            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def sample_name = getSampleName(meta, tumor_bam, normal_wgs_bam)

    def normal_bam_arg = normal_wgs_bam ? "-reference_bam ${normal_wgs_bam}" : ''
    def tumor_bam_arg = tumor_bam ? "-tumor_bam ${tumor_bam}" : ''
    def tumor_wts_bam_arg = tumor_wts_bam ? "-rna_bam ${tumor_wts_bam}" : ''

    def gene_cn_arg = gene_cn ? "-gene_copy_number ${gene_cn}" : ''
    def smlv_vcf_arg = smlv_vcf ? "-somatic_vcf ${smlv_vcf}" : ''

    """
    java \\
        -Xmx${Math.round(task.memory.bytes * 0.95)} \\
        -jar ${task.ext.jarPath} \\
            ${args} \\
            -sample ${sample_name} \\
            ${normal_bam_arg} \\
            ${tumor_bam_arg} \\
            ${tumor_wts_bam_arg} \\
            ${smlv_vcf_arg} \\
            ${gene_cn_arg} \\
            -ref_genome ${genome_fasta} \\
            -ref_genome_version ${genome_ver} \\
            -resource_dir ${lilac_resources} \\
            -threads ${task.cpus} \\
            -output_dir lilac/

    # NOTE(SW): hard coded since there is no reliable way to obtain version information.
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        lilac: 1.4.2
    END_VERSIONS
    """

    stub:
    """
    mkdir -p lilac/
    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}

def getSampleName(meta, tumor_bam, normal_bam) {
    if (tumor_bam) {
        return meta.tumor_id
    } else if (normal_bam) {
        return meta.normal_id
    } else {
        Sys.exit(1)
    }
}
