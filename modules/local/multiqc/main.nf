process MULTIQC {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/multiqc:1.34--4fc8657c816047c0' :
        'community.wave.seqera.io/library/multiqc:1.34--4fc8657c816047c0' }"

    input:
    tuple val(meta), path(outdir)

    output:
    tuple val(meta), path("*multiqc_report.html"), emit: multiqcreport
    path("*multiqc_report_data"), emit: multiqcdata
    path "versions.yml", emit: versions

    def multiqc_config = params.multiqc_config.startsWith('/') ? params.multiqc_config : "${projectDir}/${params.multiqc_config}"

    script:
    """
    multiqc --config ${multiqc_config} ${projectDir}/results/${params.outdir}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$(multiqc --version 2>&1 | sed -e "s/multiqc //g")
    END_VERSIONS
    """
}