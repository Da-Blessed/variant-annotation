# GFA deconstruction and variant annotation workflow

GFA pangenome graph를 입력으로 받아 `vg deconstruct`로 cohort VCF를 만들고, VCF를 전처리한 뒤 SnpEff와 AnnotSV를 실행하는 독립 Snakemake workflow입니다.

```text
GFA ──vg gbwt──> GBZ ──vg deconstruct──> raw VCF
                                           │
                    reference FASTA ───────┤
                                           v
                              bcftools preprocessing
                                  ├──> SnpEff VCF
                                  └──> AnnotSV TSV
```

중간 그래프는 GFA의 P-line/W-line haplotype과 sample metadata를 사용할 수 있도록 GBZ로 만듭니다. 두 annotation은 같은 전처리 VCF에서 독립적으로 실행됩니다.

- SnpEff: SNP/indel effect를 VCF `ANN` 필드에 기록
- AnnotSV: structural variant annotation과 ranking을 TSV로 출력

## 입력

`config/inputs.tsv`에 데이터셋을 등록합니다.

```tsv
name	gfa	reference_fasta	reference_sample	reference_path	reference_prefix
hprc	/data/hprc.gfa	/data/GRCh38.fa	GRCh38		GRCh38#0#
```

열의 의미는 다음과 같습니다.

| 열 | 의미 |
|---|---|
| `name` | 출력에 사용할 고유하고 안전한 데이터셋 이름 |
| `gfa` | 압축하지 않은 GFA 1.0/1.1 파일. S-line과 P-line 또는 W-line 필요 |
| `reference_fasta` | 압축하지 않은 기준 FASTA. VCF REF 검증과 left alignment에 사용 |
| `reference_sample` | GFA의 기준 sample 이름. `vg gbwt --set-reference`로 W-line에 reference sense를 부여 |
| `reference_path` | 기준 graph path 하나를 정확히 지정하며 `vg deconstruct --path`로 전달 |
| `reference_prefix` | 여러 기준 path의 공통 prefix이며 `vg deconstruct --path-prefix`로 전달 |

`reference_path`와 `reference_prefix` 중 정확히 하나만 입력해야 합니다. PanSN 형식의 W-line을 가진 human pangenome은 보통 `reference_sample`에 `GRCh38`, `reference_prefix`에 `GRCh38#0#` 같은 값을 사용합니다. 단일 reference path를 가진 GFA는 exact path 이름을 사용합니다. W-line 입력에서 `reference_sample`을 생략하면 VG가 모든 walk를 haplotype thread로 취급하여 deconstruct 기준 경로를 선택할 수 없으므로 필수입니다.

`deconstruct.contig_only_ref: true`이면 가능한 경우 `SAMPLE#HAPLOTYPE#CONTIG` 형식 대신 contig만 VCF `CHROM`에 기록합니다. 이때 생성되는 `CHROM`과 `reference_fasta` header, SnpEff database, AnnotSV build가 모두 일치해야 합니다. REF 불일치는 전처리 단계에서 오류로 종료합니다.

## VCF 전처리

`vg deconstruct` 출력에는 다음 작업을 순서대로 적용합니다.

1. 기준 FASTA에 대해 REF allele을 엄격히 검증하고 variant를 left-align
2. multiallelic record를 biallelic record로 분할
3. coordinate 정렬
4. 완전히 중복된 record 제거
5. bgzip 압축과 tabix index 생성

`config/config.yaml`의 기본 deconstruct 설정은 nested snarl까지 출력하고, conflicted genotype은 보존하지 않습니다.

```yaml
deconstruct:
  all_snarls: true
  contig_only_ref: true
  keep_conflicted: false
```

`all_snarls: false`로 바꾸면 top-level snarl만 VCF에 기록합니다. `keep_conflicted: true`는 `vg deconstruct --keep-conflicted`를 사용하므로 충돌 genotype의 해석에 주의해야 합니다.

## Annotation 설정

`config/config.yaml`에서 reference build와 database 경로를 설정합니다.

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

AnnotSV annotation bundle은 Bioconda package에 포함되지 않습니다. [공식 `INSTALL_annotations.sh`](https://github.com/lgmgeo/AnnotSV/blob/master/bin/INSTALL_annotations.sh)로 내려받은 디렉터리를 `annotations_dir`에 지정해야 합니다.

## 설치와 실행

```bash
conda env create -f environment.yaml
conda activate variant-annotation-workflow

# GFA deconstruction, 전처리, SnpEff, AnnotSV 전체 실행
snakemake --profile profiles/default

# GFA deconstruction과 전처리를 포함한 SnpEff branch만 실행
snakemake --snakefile workflow/snpeff.smk --profile profiles/default

# GFA deconstruction과 전처리를 포함한 AnnotSV branch만 실행
snakemake --snakefile workflow/annotsv.smk --profile profiles/default
```

VG는 1.70.0으로 고정했습니다. `vg gbwt` 임시 디렉터리 옵션은 VG 1.70.0에서 유효한 `--temp-dir`이고, `vg deconstruct`에는 임시 디렉터리 옵션을 전달하지 않습니다.

## 결과

| 경로 | 내용 |
|---|---|
| `results/{name}/{name}.preprocessed.vcf.gz` | deconstruct 후 정규화·분할·정렬한 VCF |
| `results/{name}/{name}.preprocessed.vcf.gz.tbi` | 전처리 VCF tabix index |
| `results/{name}/{name}.snpeff.vcf.gz` | SnpEff `ANN` annotation VCF |
| `results/{name}/{name}.snpeff.vcf.gz.tbi` | SnpEff VCF tabix index |
| `results/{name}/{name}.annotsv.tsv` | AnnotSV annotation/ranking TSV |

원본 deconstruct VCF와 GBZ는 각각 `work/deconstructed/`, `work/graph/`에 보관됩니다. `annotsv.min_size` 기본값은 50 bp입니다.

## 테스트

```bash
python -m unittest discover -s tests -v
snakemake --snakefile Snakefile --configfile tests/config.yaml --lint
snakemake --snakefile Snakefile --configfile tests/config.yaml --cores 1 --dry-run
snakemake --snakefile workflow/snpeff.smk --configfile tests/config.yaml --cores 1 --dry-run
snakemake --snakefile workflow/annotsv.smk --configfile tests/config.yaml --cores 1 --dry-run
```

참고 문서: [vg deconstruct](https://github.com/vgteam/vg/wiki/VCF-export-with-vg-deconstruct), [SnpEff command line](https://pcingola.github.io/SnpEff/snpeff/commandline/), [AnnotSV](https://github.com/lgmgeo/AnnotSV)
