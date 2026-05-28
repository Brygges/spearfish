process SRA_TOOLBOX {
    tag "$meta.id"
    label 'process_single'

    publishDir "${projectDir}/results/${params.outdir}/fastq", mode: "copy", pattern: '*.fastq'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/sra-tools:3.4.1--c7109f1ef9368369' :
        'community.wave.seqera.io/library/sra-tools:3.4.1--c7109f1ef9368369' }"

    input:
    tuple val(meta), val(accession_id)

    output:
    tuple val(meta), path("*.fastq"), emit: fastq
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''

    """
    prefetch \\
        --max-size 100G \\
        ${accession_id} || true
    
    fasterq-dump \\
        --split-files \\
        --threads ${task.cpus} \\
        --progress \\
        ${args} \\
        ${accession_id}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sra-tools: \$(prefetch --version 2>&1 | grep -Eo '[0-9.]+' | head -n 1)
    END_VERSIONS
    """
}