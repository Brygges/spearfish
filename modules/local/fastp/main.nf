process FASTP {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/fastp:1.3.2--916946baf992e235' :
        'community.wave.seqera.io/library/fastp:1.3.2--916946baf992e235' }"
    

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.fastq"), emit: reads
    path "*.json", emit: json
    path "*.html", emit: html
    path "versions.yml", emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (meta.single_end) {
        """
        fastp \\
            --in1 ${reads} \\
            --out1 ${prefix}.fastq \\
            --json ${prefix}.json \\
            --html ${prefix}.html

        sed -i "s/--in1 [^ ]*/--in1 ${prefix}/g" ${prefix}.json

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed -e "s/fastp //g")
        END_VERSIONS
        """
    } else {
        """
        fastp \\
            --in1 ${reads[0]} \\
            --in2 ${reads[1]} \\
            --out1 ${prefix}_1.fastq \\
            --out2 ${prefix}_2.fastq \\
            --json ${prefix}.json \\
            --html ${prefix}.html
        
        sed -i "s/--in1 [^ ]*/--in1 ${prefix}_1/g; s/--in2 [^ ]*/--in2 ${prefix}_2/g" ${prefix}.json

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed -e "s/fastp //g")
        END_VERSIONS
        """
    }
}