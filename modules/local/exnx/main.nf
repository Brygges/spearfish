process EXNX {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/salmon_trinity_pandas:c684890e58b96364' :
        'community.wave.seqera.io/library/salmon_trinity_pandas:c684890e58b96364' }"
    
    input:
    tuple val(meta), path(assembly)
    path(quant)

    output:
    tuple val(meta), path("ExN50.stats"), emit: exn_stats
    tuple val(meta), path("*_ExNX_mqc.yaml"), emit: exn_mqc
    path("versions.yml"), emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    TRINITY_HOME=\$(dirname \$(which Trinity))/..
    export PATH=\$TRINITY_HOME/util:\$TRINITY_HOME/util/misc:\$PATH

    abundance_estimates_to_matrix.pl \\
        --est_method salmon \\
        --out_prefix ${prefix} \\
        --gene_trans_map none \\
        ${quant}

    contig_ExN50_statistic.pl \\
        ${prefix}.*.matrix \\
        ${assembly} \\
        transcript > ExN50.stats

    python ${projectDir}/bin/parse_exnx.py \\
        --exnx ExN50.stats \\
        --sample ${prefix}
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        trinity: \$(echo \$(Trinity --version) | awk '{print \$NF}')
    END_VERSIONS
    """
}