process TRINITY {
    tag "${meta.id}"
    label "process_high"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/salmon_trinity:65edd3573cdb65fa' :
        'community.wave.seqera.io/library/salmon_trinity:65edd3573cdb65fa' }"

    publishDir "${params.outdir}/trinity", mode: "copy", pattern: "*.Trinity.fasta", overwrite: true
    publishDir "${params.outdir}/trinity", mode: "copy", pattern: "*_abundance.Trinity.fasta", overwrite: true
    publishDir "${params.outdir}/trinity", mode: "copy", pattern: "abundance_estimate", overwrite: true

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*_trinity.Trinity.fasta"), emit: assembly
    tuple val(meta), path("abundance_estimate"), emit: abundance
    tuple val(meta), path("*_abundance.Trinity.fasta"), emit: annotated_assembly
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def reads1 = []
    def reads2 = []
    meta.single_end ? reads1 = reads : reads.eachWithIndex{ v, ix  -> ( ix & 1 ? reads2 : reads1) << v }

    if (meta.single_end) {
        reads_args = "--single ${reads1.join(',')}"
    } else {
        reads_args = "--left ${reads1.join(',')} --right ${reads2.join(',')}"
    }

    seqType_args = reads1[0] ==~ /(.*fasta(.gz)?$)|(.*fa(.gz)?$)/ ? "fa" : "fq"

    def available_memory = 10
    if (!task.memory) {
        log.info '[Trinity] Available memory not known, defaulting to 10 GB.'
    } else {
        available_memory = (task.memory.giga*0.8).intValue()
    }

    """
    Trinity \\
        --seqType ${seqType_args} \\
        --max_memory ${available_memory}G \\
        --CPU $task.cpus \\
        ${reads_args} \\
        --output ${prefix}_trinity \\
        $args \\

    align_and_estimate_abundance.pl \\
        --transcripts ${prefix}_trinity.Trinity.fasta \\
        --seqType ${seqType_args} \\
        ${reads_args} \\
        --est_method salmon \\
        --trinity_mode \\
        --prep_reference \\
        --output_dir abundance_estimate

    awk -F'\t' 'FNR==NR { tpm[\$1]=\$4; next } /^>/ { split(\$1, n, \" \"); id=substr(n[1],2); if (id in tpm) \$0=\$0 \" | TPM: \" tpm[id] } 1' \\
        abundance_estimate/quant.sf \\
        ${prefix}_trinity.Trinity.fasta \\
        > ${prefix}_abundance.Trinity.fasta
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process.tokenize(':')[-1]}":
        trinity: \$(Trinity --version 2>&1 | sed -n 's/.*Trinity version: *//p' | sed 's/ .*//' | sed 's/,.*//' | tr -d '"')
    END_VERSIONS
    """
}
