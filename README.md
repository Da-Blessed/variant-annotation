# SnpEff and AnnotSV annotation workflow

PanGenie, vg 또는 다른 genotyper가 만든 VCF를 입력으로 받아 SnpEff와 AnnotSV를 실행하는 독립 Snakemake project입니다. Genotyping workflow와 repository lifecycle을 분리했기 때문에 임의의 VCF를 추가해 재사용할 수 있습니다.

두 annotation은 같은 정규화된 입력 VCF에서 병렬로 실행합니다.

- SnpEff: SNP/indel을 중심으로 variant effect를 VCF `ANN` 필드에 기록
- AnnotSV: structural variant annotation과 ranking을 TSV로 출력

SnpEff의 SV 지원은 제한적이고 AnnotSV는 SV 중심 도구이므로, 한 결과를 다른 도구에 직렬 입력하지 않고 별도 산출물로 보존합니다.

## 입력 설정

`config/inputs.tsv`에 annotation할 VCF를 등록합니다. plain VCF와 bgzip VCF를 모두 받을 수 있으며 내부에서 bgzip/index 형식으로 정규화합니다.

```tsv
name	vcf
pangenie	/path/to/pangenie.cohort.vcf.gz
vg_shortread	/path/to/vg.shortread.cohort.vcf.gz
vg_longread	/path/to/vg.longread.cohort.vcf.gz
```

`config/config.yaml`에서 reference build와 database 경로를 맞춥니다.

```yaml
snpeff:
  genome: GRCh38.mane.1.0.ensembl
  data_dir: resources/snpeff
  download_database: true

annotsv:
  genome_build: GRCh38
  annotations_dir: resources/AnnotSV_annotations
  min_size: 50
```

SnpEff database는 `download_database: true`일 때 최초 실행에서 내려받습니다. 이미 설치한 database를 쓸 때는 `data_dir`을 지정하고 `download_database: false`로 둡니다.

AnnotSV의 annotation bundle은 Bioconda package에 포함되지 않습니다. [공식 `INSTALL_annotations.sh`](https://github.com/lgmgeo/AnnotSV/blob/master/bin/INSTALL_annotations.sh)로 한 번 내려받고 생성된 디렉터리를 `annotations_dir`에 지정해야 합니다. 입력 VCF와 SnpEff/AnnotSV 설정은 동일한 reference assembly 및 contig naming을 사용해야 합니다.

## 설치와 실행

```bash
conda env create -f environment.yaml
conda activate variant-annotation-workflow

# SnpEff와 AnnotSV 모두
snakemake --profile profiles/default

# SnpEff만
snakemake --snakefile workflow/snpeff.smk --profile profiles/default

# AnnotSV만
snakemake --snakefile workflow/annotsv.smk --profile profiles/default
```

## 결과

| 경로 | 내용 |
|---|---|
| `results/{name}/{name}.snpeff.vcf.gz` | SnpEff `ANN` annotation VCF |
| `results/{name}/{name}.snpeff.vcf.gz.tbi` | tabix index |
| `results/{name}/{name}.annotsv.tsv` | AnnotSV annotation/ranking TSV |

`annotsv.min_size` 기본값은 50 bp입니다. small variant effect는 SnpEff 결과를, SV annotation은 AnnotSV 결과를 중심으로 해석하세요.

## 테스트

```bash
python -m unittest discover -s tests -v
snakemake --snakefile Snakefile --configfile tests/config.yaml --lint
snakemake --snakefile Snakefile --configfile tests/config.yaml --cores 1 --dry-run
snakemake --snakefile workflow/snpeff.smk --configfile tests/config.yaml --cores 1 --dry-run
snakemake --snakefile workflow/annotsv.smk --configfile tests/config.yaml --cores 1 --dry-run
```

참고 문서: [SnpEff command line](https://pcingola.github.io/SnpEff/snpeff/commandline/), [SnpEff VCF input/output](https://pcingola.github.io/SnpEff/snpeff/inputoutput/), [AnnotSV](https://github.com/lgmgeo/AnnotSV)
