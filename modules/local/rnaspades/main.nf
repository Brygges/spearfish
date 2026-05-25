process RNASPADES {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/salmon_spades:a43c2456df5c9c30' :
        'community.wave.seqera.io/library/salmon_spades:a43c2456df5c9c30' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*spades_out/transcripts.fasta'), emit: assembly
    tuple val(meta), path('*spades_out'), emit: spades_out
    tuple val(meta), path('*spades_out/assembly_graph.fastg'), emit: assemblygraph
    tuple val(meta), path('abundance/quant.sf'), emit: abundance
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def reads1 = []
    def reads2 = []
    meta.single_end ? reads1 = reads : reads.eachWithIndex{ v, ix  -> ( ix & 1 ? reads2 : reads1) << v }

    if (meta.single_end) {
        reads_args = "-s ${reads1.join(',')}"
    } else {
        reads_args = "-1 ${reads1.join(',')} -2 ${reads2.join(',')}"
    }

    def available_memory = 10
    if (!task.memory) {
        log.info '[Trinity] Available memory not known, defaulting to 10 GB.'
    } else {
        available_memory = (task.memory.giga*0.8).intValue()
    }

    """
    rnaspades.py \\
        ${reads_args} \\
        -m ${available_memory} \\
        -o ${prefix}_spades_out

    salmon \\
        index -t ${prefix}_spades_out/transcripts.fasta \\
        -i transcript_index

    salmon \\
        quant -i transcript_index \\
        -l A \\
        ${reads_args} \\
        --validateMappings \\
        -o abundance/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rnaspades: \$(rnaspades.py --version 2>&1 | sed -e "s/rnaspades //g")
    END_VERSIONS
    """
}