process BUSCO {
    tag "${meta.id}"
    label 'process_low' 

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/busco:6.0.0--7def4b2c35a1aed1' :
        'community.wave.seqera.io/library/busco:6.0.0--7def4b2c35a1aed1' }"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*/short_summary*"), emit: busco
    path "versions.yml", emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    busco \\
        --in ${assembly} \\
        --mode transcriptome \\
        --out ${prefix} \\
        --lineage_dataset mollusca_odb10

    cat <<-END_VERSIONS > versions.yml
        "${task.process}":
        busco: "\$(busco --version 2>&1 | sed 's/.* //')"
    END_VERSIONS
    """   
}