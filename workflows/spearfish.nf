/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { SRA_TOOLBOX } from '../modules/local/sra_toolbox/main'
include { FASTP } from '../modules/local/fastp/main'
include { FALCO } from '../modules/local/falco/main'
include { SORTMERNA } from '../modules/local/sortmerna/main'
include { TRINITY } from '../modules/local/trinity/main'
include { RNASPADES } from '../modules/local/rnaspades/main'
include { EXNX } from '../modules/local/exnx/main'
include { BUSCO } from '../modules/local/busco/main'
include { CATSRF } from '../modules/local/cats-rf/main'
include { MULTIQC } from '../modules/local/multiqc/main'
include { EGGNOGMAPPER } from '../modules/local/eggnog-mapper/main'
include { TRANSDECODER } from '../modules/local/transdecoder/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_transcrit_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SPEARFISH {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = channel.empty()

    // Branch input based on SRA accession or file paths
    ch_samplesheet
        .branch { meta, fastqs ->
            sra: fastqs[0] =~ /^SRR\d+$/
            files: true
        }
        .set { ch_input_type }

    // For SRA inputs
    SRA_TOOLBOX(
        ch_input_type.sra.map { meta, fastqs -> tuple(meta, fastqs[0]) }
    )
    ch_versions = ch_versions.mix(SRA_TOOLBOX.out.versions)

    // Correct single_end for SRA based on actual FASTQ files
    SRA_TOOLBOX.out.fastq
        .map { meta, fastq ->
            def num_files = fastq instanceof List ? fastq.size() : 1
            [meta + [single_end: num_files == 1], fastq]
        }
        .set { ch_sra_fastq }

    // For file inputs, use directly
    ch_input_type.files
        .map { meta, fastqs -> [meta, fastqs] }
        .set { ch_file_fastq }

    // Combine SRA and file inputs
    ch_sra_fastq.mix(ch_file_fastq).set { ch_all_fastq }
    ch_fastq = ch_all_fastq

    // ====================== //
    // PRE-ASSEMBLY QC        //
    // ====================== //
    
    FALCO( ch_all_fastq )
    ch_falcoreport = FALCO.out.falcoreport
    ch_versions = ch_versions.mix(FALCO.out.versions)

    FASTP( ch_all_fastq )
    ch_reads = FASTP.out.reads
    ch_versions = ch_versions.mix(FASTP.out.versions)

    SORTMERNA( FASTP.out.reads )
    ch_filter_reads = SORTMERNA.out.reads
    ch_sortmerna_log = SORTMERNA.out.sortmerna_log
    ch_versions = ch_versions.mix(SORTMERNA.out.versions)

    // ====================== //
    // DE NOVO ASSEMBLY       //
    // ====================== //    

    if (params.assembler == 'trinity') {
        TRINITY( SORTMERNA.out.reads )
        ch_assembly = TRINITY.out.assembly
        ch_abundance = TRINITY.out.abundance
        ch_versions = ch_versions.mix(TRINITY.out.versions)

        EXNX( TRINITY.out.assembly, TRINITY.out.abundance )
        ch_exnx = EXNX.out.exn_stats
        ch_exnx_mqc = EXNX.out.exn_mqc
        ch_versions = ch_versions.mix(EXNX.out.versions)

    } else if (params.assembler == 'spades') {
        RNASPADES( SORTMERNA.out.reads )
        ch_assembly = RNASPADES.out.assembly
        ch_abundance = RNASPADES.out.abundance
        ch_versions = ch_versions.mix(RNASPADES.out.versions)

        EXNX( RNASPADES.out.assembly, RNASPADES.out.abundance )
        ch_exnx = EXNX.out.exn_stats
        ch_exnx_mqc = EXNX.out.exn_mqc
        ch_versions = ch_versions.mix(EXNX.out.versions)
    } else {
        error "Unknown assembler '${params.assembler}'. Valid options: 'trinity', 'spades'."
    }

    // ====================== //
    // POST-ASSEMBLY EVALUATION //
    // ====================== //  

    CATSRF( ch_assembly, SORTMERNA.out.reads )
    ch_scores = CATSRF.out.transcript_scores
    ch_stats = CATSRF.out.general_stats
    ch_summary = CATSRF.out.summary_stats
    ch_versions = ch_versions.mix(CATSRF.out.versions)

    BUSCO( ch_assembly )
    ch_busco = BUSCO.out.busco
    ch_versions = ch_versions.mix(BUSCO.out.versions)

    TRANSDECODER{
        ch_assembly
    }
    ch_transdecoder = TRANSDECODER.out.pep

    EGGNOGMAPPER{
        ch_transdecoder
    }
    ch_annotation = EGGNOGMAPPER.out.annotation

    // ====================== //
    // MULTIQC REPORT         //
    // ====================== // 

    MULTIQC( ch_transdecoder )
    ch_multiqc_report = MULTIQC.out.multiqcreport
    ch_multiqc_data = MULTIQC.out.multiqcdata

    //
    // Collate and save software versions
    //
    def topic_versions = Channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.results_dir}/${params.outdir}/pipeline_info",
            name:  'spearfish_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    emit:
    fastq = ch_fastq
    falcoreport = ch_falcoreport
    reads = ch_reads
    filter_reads = ch_filter_reads
    sortmerna_log = ch_sortmerna_log
    assembly = ch_assembly
    abundance = ch_abundance
    exnx = ch_exnx
    exnx_mqc = ch_exnx_mqc
    busco = ch_busco
    transcript_scores = ch_scores
    general_stats = ch_stats
    summary_stats = ch_summary
    multiqc_report = ch_multiqc_report
    multiqc_data = ch_multiqc_data
    pep = ch_transdecoder
    annotation = ch_annotation
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
