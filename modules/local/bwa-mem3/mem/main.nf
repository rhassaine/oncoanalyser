process BWAMEM3_ALIGN {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    // Seqera community image built from bioconda bwa-mem3 0.15.0, sambamba 1.0.1 and samtools 1.21 on htslib 1.24
    // (bwa-mem3 0.15.0 is built against htslib 1.24), pinned by digest. bioconda no longer resolves samtools 1.21 with
    // htslib 1.24, so a rebuild needs samtools 1.24 (as in environment.yml)
    container 'community.wave.seqera.io/library/bwa-mem3_sambamba_samtools:96175df3ef699161@sha256:8fdaaffe877a774673b8a8517ba36c6c1ded33830d24b8c64f8f395b79acb063'

    input:
    tuple val(meta), path(reads_fwd), path(reads_rev)
    path genome_fasta
    path genome_bwamem2_index

    output:
    tuple val(meta), path('*.bam'), path('*.bai')            , topic: bwamem2_align_bam
    tuple val(meta), val('bwamem3_align'), path('.command.*'), topic: command_files
    path 'versions.yml'                                      , topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def args3 = task.ext.args3 ?: ''

    def output_fn = meta.split ? "${meta.split}.${meta.output_file_id}.bam" : "${meta.output_file_id}.bam"

    // bwa-mem3 in bwa-mem2 compatibility mode: reads the bwa-mem2 index and writes the same records as bwa-mem2
    """
    ln -fs \$(find -L ${genome_bwamem2_index} -type f) ./

    bwa-mem3 mem \\
        --compat=bwa-mem2 \\
        ${args} \\
        -Y \\
        -K 100000000 \\
        -R '${meta.rg_line}' \\
        -t ${task.cpus} \\
        ${genome_fasta} \\
        ${reads_fwd} \\
        ${reads_rev} | \\
        \\
        sambamba view \\
            ${args2} \\
            --sam-input \\
            --format bam \\
            --compression-level 0 \\
            --nthreads ${task.cpus} \\
            /dev/stdin | \\
        \\
        sambamba sort \\
            ${args3} \\
            --nthreads ${task.cpus} \\
            --out ${output_fn} \\
            /dev/stdin

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bwa-mem3: \$(bwa-mem3 version 2>&1 | head -n1)
        samtools: \$(samtools --version | sed -n '/^samtools / { s/^.* //p }')
        sambamba: \$(sambamba --version 2>&1 | sed -n '/^sambamba / { s/^.* //p }' | head -n1)
    END_VERSIONS
    """

    stub:
    def output_fn = meta.split ? "${meta.split}.${meta.output_file_id}.bam" : "${meta.output_file_id}.bam"

    """
    touch ${output_fn}
    touch ${output_fn}.bai

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
