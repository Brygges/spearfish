process SORTMERNA {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/bbmap_sortmerna:1a213ac348f4abac' :
        'community.wave.seqera.io/library/bbmap_sortmerna:1a213ac348f4abac' }"

    input:
    tuple val(meta), path(reads)
    
    output:
    tuple val(meta), path("*_sort*.fq"), emit: reads
    tuple val(meta), path("*_sortmerna.log"), emit: sortmerna_log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    def reads1 = []
    def reads2 = []
    meta.single_end ? reads1 = reads : reads.eachWithIndex{ v, ix  -> ( ix & 1 ? reads2 : reads1) << v }

    if (meta.single_end) {
        reads_args = "--reads ${reads1.join(',')}"
    } else {
        reads_args = "--reads ${reads1.join(',')} --reads ${reads2.join(',')}"
    }

    """
    sortmerna \\
        --ref ${projectDir}/datadir/smr_v4.3_default_db.fasta \\
        $reads_args \\
        --paired_in \\
        --workdir . \\
        --fastx \\
        --other ${prefix}_smr \\
        --out2 \\
        --log
    
    mv out/aligned.log ${prefix}_sortmerna.log

    repair.sh \\
        in=${prefix}_smr_fwd.fq \\
        in2=${prefix}_smr_rev.fq \\
        out=${prefix}_sort_1.fq \\
        out2=${prefix}_sort_2.fq \\
        outs=${prefix}_singletons.fq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sortmerna: \$(sortmerna --version 2>&1 | grep -oP 'SortMeRNA version \\K[\\d.]+' | head -1)
    END_VERSIONS
    """
}

