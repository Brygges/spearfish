process FALCO {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/falco:1.2.5--02a78c049c3e7d9b' :
        'community.wave.seqera.io/library/falco:1.2.5--02a78c049c3e7d9b' }"    

    input:
    tuple val(meta), path(fastq)

    output:
    tuple val(meta), path("*.txt"), emit: fastqtxt
    path("*.html"), emit: falcoreport
    path "versions.yml", emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (meta.single_end) {
        """
        falco \\
            ${fastq} \\
            -D ${prefix}_data.txt \\
            -R ${prefix}_report.html

        sed -i "s/^Filename\t.*/Filename\t${prefix}/" ${prefix}_data.txt
        sed -i "s/[^\t]*\$/${prefix}/" ${prefix}_summary.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            falco: \$(falco --version 2>&1 | head -1 | sed -e "s/falco //g")
        END_VERSIONS
        """
    } else {
        """
        falco \\
            ${fastq[0]} \\
            -D ${prefix}_1_data.txt \\
            -R ${prefix}_1_report.html

        falco \\
            ${fastq[1]} \\
            -D ${prefix}_2_data.txt \\
            -R ${prefix}_2_report.html
        
        sed -i "s/^Filename\t.*/Filename\t${prefix}_1/" ${prefix}_1_data.txt
        sed -i "s/^Filename\t.*/Filename\t${prefix}_2/" ${prefix}_2_data.txt
        sed -i "s/[^\t]*\$/${prefix}/" summary.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            falco: \$(falco --version 2>&1 | head -1 | sed -e "s/falco //g")
        END_VERSIONS
        """
    }
}