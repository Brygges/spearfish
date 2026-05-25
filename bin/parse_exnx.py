import pandas as pd
import argparse
import yaml

def parse_exnx(file, sample):
    df = pd.read_csv(file, sep="\t", usecols=["Ex", "ExN50"])
    xy_pairs = {int(row["Ex"]): int(row["ExN50"]) for _, row in df.iterrows()}
    peak_pair = max(xy_pairs, key=xy_pairs.get)

    if 80 <= peak_pair <= 100:
        status = '<span style="color: #5F8575; font-weight: bold;">PASS</span> - Peak found around E90N50, which indicates good quality assembly.'
    else:
        status = '<span style="color: #FFBF00; font-weight: bold;">WARN</span> - Peak found for Ex < 80, indicating lower assembly quality.'

    data = {
        "id": "exnx",
        "section_name": "ExN50 Statistics",
        "description": f"{status} The following plot shows the expression-weighted N50 (ExN50), which can be used to indicate overall quality assesment.",
        "plot_type": 'linegraph',
        "pconfig": {
            "id": "exnx_plot",
            "ymin": 0,
            "xlab": "Ex",
            "ylab": "ExN50",
            "x_bands": [
                {"from": 80, "to": 100, "color": "#5F8575", "opacity": 0.2}
            ],
        },
        "data": {
            sample: xy_pairs
        }
    }

    with open(f"{sample}_ExNX_mqc.yaml", "w") as f:
        yaml.dump(data, f, default_flow_style=False)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--exnx", required=True)
    parser.add_argument("--sample", required=True)
    args = parser.parse_args()

    parse_exnx(args.exnx, args.sample)

if __name__ == "__main__":
    main()