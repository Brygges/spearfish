process CATSRF {
    tag "${meta.id}"
    label "process_medium"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/cats-rf_kallisto_pandas:3bc96882f6f5daed' :
        'community.wave.seqera.io/library/cats-rf_kallisto_pandas:3bc96882f6f5daed' }"

    input:
    tuple val(meta), path(assembly)
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*_assembly_score_mqc.tsv"), emit: summary_stats
    tuple val(meta), path("*_general_stats_mqc.tsv"), emit: general_stats
    tuple val(meta), path("*_transcript_scores_mqc.tsv"), emit: transcript_scores
    path("versions.yml"), emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    def reads1 = []
    def reads2 = []
    meta.single_end ? reads1 = reads : reads.eachWithIndex{ v, ix  -> ( ix & 1 ? reads2 : reads1) << v }

    if (meta.single_end) {
        reads_args = "-C se ${reads1.join(',')}"
    } else {
        reads_args = "${reads1.join(',')} ${reads2.join(',')}"
    }

    """
    CATS_rf -D out -o cats \\
        ${assembly} \\
        ${reads_args} \\

    python ${projectDir}/bin/parse_cats_rf.py \\
        --scores out/cats_transcript_scores.tsv \\
        -gs out/cats_general_statistics_table.tsv \\
        -as out/cats_assembly_score_summary.tsv \\
        --sample ${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        CATS-RF: \$(echo \$(CATS_rf --version) | awk '{print \$NF}')
    END_VERSIONS
    """
}