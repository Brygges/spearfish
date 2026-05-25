process TRANSDECODER {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/transdecoder:5.7.1--61ba3789fffae9f0' :
        'community.wave.seqera.io/library/transdecoder:5.7.1--61ba3789fffae9f0' }"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("${output_dir}/longest_orfs.pep"), emit: pep

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    output_dir = "${meta.id}/${assembly}.transdecoder_dir"

    """
    TransDecoder.LongOrfs \\
        -O $prefix \\
        -t $assembly
    """
}