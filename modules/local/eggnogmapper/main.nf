process EGGNOGMAPPER {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/eggnog-mapper:2.1.13--3707cb2d1fc34e7a' :
        'community.wave.seqera.io/library/eggnog-mapper:2.1.13--3707cb2d1fc34e7a' }"

    input:
    tuple val(meta), path(pep)

    output:
    tuple val(meta), path('enm/enm_annotations.emapper.hits'), emit: annotation

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    mkdir -p enm

    emapper.py \\
        -i $pep \\
        --itype proteins \\
        -o enm_annotations \\
        --output_dir enm/ \\
        --data_dir ${projectDir}/datadir/
    """
}