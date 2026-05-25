"""
Parse CATS-RF output files into MultiQC-compatible custom content files.

Usage:
    python parse_cats_rf.py \
        --sample <SAMPLE> \
        --scores <transcript_scores.tsv> \
        -as <assembly_score.tsv> \
        -gs <general_stats.tsv>
"""

import argparse
import re
import pandas as pd

def parse_transcript_score(file, sample):
    df = pd.read_csv(file, sep="\t")
    with open(f"{sample}_transcript_scores_mqc.tsv", "w") as f:
        f.write("# id: transcript_score_distributions\n")
        f.write("# section_name: Transcript Score Distributions\n")
        f.write("# description: Distribution of quality scores across transcripts\n")
        f.write("# plot_type: violin\n")
        f.write("# pconfig:\n")
        f.write("#  namespace: Transcript Scores\n")
        f.write("#  xmin: 0\n")
        f.write("#  xmax: 1\n")
        f.write("#  scale: false\n")
        f.write("#  violin_grouping: null\n\n") 
        df.to_csv(f, sep="\t", index=False)

def split_row(key, value):
    match_parenthesis = re.match(r'^(.*)\(([^,)]+),\s*([^)]+)\)(.*)$', key)
    if match_parenthesis:
        prefix, p1, p2, suffix = match_parenthesis.groups()
        values = [v.strip() for v in value.split(",", 1)]
        if len(values) == 2:
            return [
                (f"{prefix}({p1.strip()}){suffix}".strip(), values[0]),
                (f"{prefix}({p2.strip()}){suffix}".strip(), values[1]),
            ]

    keys = [k.strip() for k in key.split(",")]
    values = [v.strip() for v in value.split(",")]

    if len(keys) == 1 or len(keys) != len(values):
        return [(key, value)]

    return list(zip(keys, values))

def parse_table(file, sample, out, id, section_name, description):
    rows = []
    with open(file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            key, value = line.split("\t", 1)
            rows.extend(split_row(key, value))
    
    with open(out, "w") as f:
        f.write(f"# id: {id}\n")
        f.write(f"# section_name: {section_name}\n")
        f.write(f"# description: {description}\n")
        f.write("# plot_type: 'table'\n")
        f.write("# pconfig:\n")
        f.write("#  namespace: 'CATS-RF'\n")
        f.write("#  rows_are_samples: true\n\n")
        f.write(f"Metric\t{sample}\n")
        for key, value in rows:
            f.write(f"{key}\t{value}\n")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scores", required=True)
    parser.add_argument("--assemblyscore", "-as", required=True)
    parser.add_argument("--generalstats", "-gs", required=True)
    parser.add_argument("--sample", required=True)
    args = parser.parse_args()

    parse_transcript_score(args.scores, args.sample)

    parse_table(
        args.assemblyscore, args.sample,
        out=f"{args.sample}_assembly_score_mqc.tsv",
        id="cats_rf_assembly_score",
        section_name="Assembly Score",
        description="Overall assembly quality metrics from CATS-RF",
    )    

    parse_table(
        args.generalstats, args.sample,
        out=f"{args.sample}_general_stats_mqc.tsv",
        id="cats_rf_general_stats",
        section_name="General Statistics from CATS-RF",
        description="Assembly-level statistics from CATS-RF",
    )

if __name__ == "__main__":
    main()