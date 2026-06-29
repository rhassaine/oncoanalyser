//
// Align DNA reads
//

include { BWAMEM2_ALIGN                             } from '../../../modules/local/bwa-mem2/mem/main'
include { PARABRICKS_FQ2BAM                         } from '../../../modules/nf-core/parabricks/fq2bam/main'
include { FASTQ_TOOLS as UMI_PROCESSING_FASTQ_TOOLS } from '../../../modules/local/fastqtools/main'
include { FASTP as UMI_PROCESSING_FASTP             } from '../../../modules/local/fastp/main'
include { FASTP as FASTQ_SPLITTING                  } from '../../../modules/local/fastp/main'

workflow READ_ALIGNMENT_DNA {
      take:
      // Sample data
      ch_inputs            // channel: [mandatory] [ meta ]

      // Reference data
      genome_fasta         // channel: [mandatory] /path/to/genome_fasta
      genome_bwamem2_index // channel: [mandatory] /path/to/genome_bwa-mem2_index_dir/
      genome_bwa_index     // channel: [optional]  /path/to/genome_bwa_index_dir/ (parabricks only)
      known_umis           // channel: [mandatory] /path/to/known_umis_file

      // Params
      max_fastq_records        // numeric: [optional]  max number of FASTQ records per split
      fastp_umi_enabled        // boolean: [mandatory] enable fastp UMI processing
      fastp_umi_location       //  string: [optional]  fastp UMI location argument (--umi_loc)
      fastp_umi_length         // numeric: [optional]  fastp UMI length argument (--umi_len)
      fastp_umi_skip           // numeric: [optional]  fastp UMI skip argument (--umi_skip)
      fastq_tools_umi_enabled  // boolean: [mandatory] enable fastq-tools UMI processing
      fastq_tools_umi_delim    // boolean: [optional]  fastq-tools -umi_delim argument
      dna_aligner              //  string: [mandatory] aligner to use ('bwamem2' or 'parabricks')

      main:
      // Channel for version.yml files
      // channel: [ versions.yml ]
      ch_versions = Channel.empty()

      // Sort inputs, separate by tumor and normal
      // channel: [ meta ]
      ch_inputs_tumor_sorted = ch_inputs
          .branch { meta ->
              def has_existing = sample.Inputs.hasExisting(meta, sample.FileKey.BAM_DNA_TUMOR)
              runnable: sample.Inputs.hasTumorDnaFastq(meta) && !has_existing
              skip: true
          }

      ch_inputs_normal_sorted = ch_inputs
          .branch { meta ->
              def has_existing = sample.Inputs.hasExisting(meta, sample.FileKey.BAM_DNA_NORMAL)
              runnable: sample.Inputs.hasNormalDnaFastq(meta) && !has_existing
              skip: true
          }

      ch_inputs_donor_sorted = ch_inputs
          .branch { meta ->
              def has_existing = sample.Inputs.hasExisting(meta, sample.FileKey.BAM_DNA_DONOR)
              runnable: sample.Inputs.hasDonorDnaFastq(meta) && !has_existing
              skip: true
          }

      // Create FASTQ input channel
      // channel: [ meta_fastq, fastq_fwd, fastq_rev ]
      ch_fastq_inputs = Channel.empty()
          .mix(
              ch_inputs_tumor_sorted.runnable.map { meta -> [meta, sample.Inputs.getTumorDnaSample(meta), 'tumor'] },
              ch_inputs_normal_sorted.runnable.map { meta -> [meta, sample.Inputs.getNormalDnaSample(meta), 'normal'] },
              ch_inputs_donor_sorted.runnable.map { meta -> [meta, sample.Inputs.getDonorDnaSample(meta), 'donor'] },
          )
          .flatMap { meta, meta_sample, sample_type ->
              meta_sample
                  .getAt(samplesheet.FileType.FASTQ)
                  .collect { key, fps ->
                      def (library_id, lane) = key

                      def sample_id = meta_sample.getOrDefault('longitudinal_sample_id',meta_sample['sample_id'])

                      def meta_fastq = [
                          key: meta.group_id,
                          id: "${meta.group_id}_${sample_id}",
                          sample_id: sample_id,
                          library_id: library_id,
                          lane: lane,
                          sample_type: sample_type,
                      ]

                      return [meta_fastq, fps['fwd'], fps['rev']]
                  }
          }

      //
      // UMI processing
      //
      // channel: [ meta_fastq, fastq_fwd, fastq_rev ]
      ch_fastqs_umi_processed = Channel.empty()

      if (fastp_umi_enabled) {

          UMI_PROCESSING_FASTP(
              ch_fastq_inputs,
              -1, // max_fastq_records
              fastp_umi_location,
              fastp_umi_length,
              fastp_umi_skip,
          )

          ch_fastqs_umi_processed = UMI_PROCESSING_FASTP.out.fastq

      } else if (fastq_tools_umi_enabled) {

          UMI_PROCESSING_FASTQ_TOOLS(
              ch_fastq_inputs,
              fastq_tools_umi_delim,
              known_umis,
          )

          ch_fastqs_umi_processed = UMI_PROCESSING_FASTQ_TOOLS.out.fastq

      } else {

          ch_fastqs_umi_processed = ch_fastq_inputs

      }

      //
      // Split FASTQ into chunks if requested for distributed processing
      //
      // channel: [ meta_fastq_ready, fastq_fwd, fastq_rev ]
      ch_fastqs_ready = Channel.empty()

      if (max_fastq_records > 0) {

          FASTQ_SPLITTING(
              ch_fastqs_umi_processed,
              max_fastq_records,
              "", // fastp_umi_location
              0,  // fastp_umi_length
              -1, // fastp_umi_skip
          )

          ch_fastqs_ready = FASTQ_SPLITTING.out.fastq
              .flatMap { meta_fastq, reads_fwd, reads_rev ->

                  def data = [reads_fwd, reads_rev]
                      .transpose()
                      .collect { fwd, rev ->

                          def split_fwd = fwd.name.replaceAll('\\..+$', '')
                          def split_rev = rev.name.replaceAll('\\..+$', '')

                          assert split_fwd == split_rev

                          // NOTE(SW): split allows meta_fastq_ready to be unique, which is required during reunite below
                          def meta_fastq_ready = [
                              *:meta_fastq,
                              id: "${meta_fastq.id}_${split_fwd}",
                              split: split_fwd,
                          ]

                          return [meta_fastq_ready, fwd, rev]
                      }

                  return data
              }

      } else {

          ch_fastqs_ready = ch_fastqs_umi_processed
              .map { meta_fastq, fastq_fwd, fastq_rev ->

                  def meta_fastq_ready = [
                      *:meta_fastq,
                      split: null,
                  ]

                  return [meta_fastq_ready, fastq_fwd, fastq_rev]
              }

      }

      //
      // MODULE: Aligner
      //
      // Create process input channel
      // channel: [ meta_aligner, fastq_fwd, fastq_rev ]
      ch_aligner_inputs = ch_fastqs_ready
          .map { meta_fastq_ready, fastq_fwd, fastq_rev ->

              def meta_aligner = [
                  *:meta_fastq_ready,
                  read_group: "${meta_fastq_ready.sample_id}.${meta_fastq_ready.library_id}.${meta_fastq_ready.lane}",
              ]

              return [meta_aligner, fastq_fwd, fastq_rev]
          }

      // channel: [ meta_aligner, bam, bai ]
      ch_aligner_bam_out = Channel.empty()

      if (dna_aligner == 'parabricks') {

          // Group all lanes per sample into a single PARABRICKS_FQ2BAM call.
          // pbrun fq2bam accepts multiple --in-fq pairs and aligns them in parallel
          // on the GPU, so one task per sample is both correct and faster than
          // one task per lane. The grouping key is (key, sample_type) so tumor and
          // normal are kept separate.
          ch_parabricks_inputs = ch_aligner_inputs
              .map { meta, fwd, rev ->
                  def group_key = [key: meta.key, sample_type: meta.sample_type]
                  [group_key, meta, fwd, rev]
              }
              .groupTuple()
              .map { group_key, metas, fwds, revs ->
                  // Use the first lane's meta as the representative; read_group will
                  // be set per-lane via ext.args in modules.config.
                  def meta_rep = metas[0]
                  def reads = [fwds, revs].transpose().collect { fwd, rev -> [fwd, rev] }.flatten()
                  [meta_rep, reads]
              }

          PARABRICKS_FQ2BAM(
              ch_parabricks_inputs,
              genome_fasta.map { f -> [[id: 'genome'], f] },
              genome_bwa_index.map { i -> [[id: 'genome'], i] },
              [[id: 'no_intervals'], []],
              [[id: 'no_known_sites'], []],
              'bam',
          )

          ch_aligner_bam_out = PARABRICKS_FQ2BAM.out.bam
              .join(PARABRICKS_FQ2BAM.out.bai)

      } else {

          BWAMEM2_ALIGN(
              ch_aligner_inputs,
              genome_fasta,
              genome_bwamem2_index,
          )

          ch_versions = ch_versions.mix(BWAMEM2_ALIGN.out.versions)
          ch_aligner_bam_out = BWAMEM2_ALIGN.out.bam

      }

      // Reunite BAMs
      // First, count expected BAMs per sample for non-blocking groupTuple op.
      // Parabricks merges all lanes into one BAM per task, so group_size=1.
      // bwa-mem2 emits one BAM per lane, so group_size=number of lanes.
      // channel: [ meta_count, group_size ]
      ch_sample_fastq_counts = ch_aligner_inputs
          .map { meta_aligner, reads_fwd, reads_rev ->

              def meta_count = [
                  key: meta_aligner.key,
                  sample_type: meta_aligner.sample_type,
              ]

              return [meta_count, meta_aligner]
          }
          .groupTuple()
          .map { meta_count, metas_aligner ->
              def group_size = dna_aligner == 'parabricks' ? 1 : metas_aligner.size()
              return [meta_count, group_size]
          }

      // Now, group with expected size then sort into tumor and normal channels
      // channel: [ meta_group, [bam, ...], [bai, ...] ]
      ch_bams_united = ch_sample_fastq_counts
          .cross(
              // First element to match meta_count above for `cross`
              ch_aligner_bam_out.map { meta_aligner, bam, bai -> [[key: meta_aligner.key, sample_type: meta_aligner.sample_type], bam, bai] }
          )
          .map { count_tuple, bam_tuple ->

              def group_size = count_tuple[1]
              def (meta_bam, bam, bai) = bam_tuple

              def meta_group = [
                  *:meta_bam,
              ]

              return tuple(groupKey(meta_group, group_size), bam, bai)
          }
          .groupTuple()
          .branch { meta_group, bams, bais ->
              assert ['tumor', 'normal', 'donor'].contains(meta_group.sample_type)
              tumor: meta_group.sample_type == 'tumor'
              normal: meta_group.sample_type == 'normal'
              donor: meta_group.sample_type == 'donor'
              placeholder: true
          }

      // Set outputs, restoring original meta
      // channel: [ meta, [bam, ...], [bai, ...] ]
      ch_bam_tumor_out = Channel.empty()
          .mix(
              channels.WorkflowChannels.restoreMeta(ch_bams_united.tumor, ch_inputs),
              channels.PlaceholderChannels.bamBai(ch_inputs_tumor_sorted.skip),
          )

      ch_bam_normal_out = Channel.empty()
          .mix(
              channels.WorkflowChannels.restoreMeta(ch_bams_united.normal, ch_inputs),
              channels.PlaceholderChannels.bamBai(ch_inputs_normal_sorted.skip),
          )

      ch_bam_donor_out = Channel.empty()
          .mix(
              channels.WorkflowChannels.restoreMeta(ch_bams_united.donor, ch_inputs),
              channels.PlaceholderChannels.bamBai(ch_inputs_donor_sorted.skip),
          )

      emit:
      dna_tumor  = ch_bam_tumor_out  // channel: [ meta, [bam, ...], [bai, ...] ]
      dna_normal = ch_bam_normal_out // channel: [ meta, [bam, ...], [bai, ...] ]
      dna_donor  = ch_bam_donor_out  // channel: [ meta, [bam, ...], [bai, ...] ]

      versions   = ch_versions       // channel: [ versions.yml ]
  }
