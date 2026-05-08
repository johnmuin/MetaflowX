#!/usr/bin/env bash
set -Eeuo pipefail

# Deployment helper for MetaflowX.
#
# Default action is conservative:
#   - create the production database directory tree
#   - write a production Nextflow config that points to /share/data5/database/MetaflowX
#
# Heavy network/database actions are opt-in:
#   --install-nextflow   create a lightweight nextflow conda environment
#   --install-envs       create all conda environments
#   --install-basic-env  create/update only the MetaflowX base conda environment
#   --install-checkm2-env create/update only the CheckM2 conda environment
#   --install-quast-env create/update only the MetaQUAST conda environment
#   --install-antismash-env create/update only the antiSMASH conda environment
#   --install-metadecoder-env create/update only the MetaDecoder conda environment
#   --install-galah-env create/update only the Galah conda environment
#   --install-rgi-env create/update only the RGI conda environment
#   --install-bigmap-env create/update only the BiG-MAP conda environment
#   --install-metabinner-env create/update only the MetaBinner conda environment
#   --install-comebin-env create/update only the COMEBin conda environment
#   --install-binny-env create/update only the binny runtime
#   --install-deepurify-env create/update only the Deepurify conda environment
#   --install-vamb-env create/update only the Vamb conda environment
#   --install-gtdbtk-env create/update only the GTDB-Tk conda environment
#   --download-core-db   download/build host hg38, PhiX, MetaPhlAn, HUMAnN, eggNOG, CheckM2
#   --download-antismash-db download antiSMASH databases under DB_ROOT
#
# Example:
#   bash deploy_metaflowx_admin.sh
#   bash deploy_metaflowx_admin.sh --install-nextflow
#   bash deploy_metaflowx_admin.sh --install-envs
#   bash deploy_metaflowx_admin.sh --download-core-db

DB_ROOT="/share/data5/database/MetaflowX"
APP_ROOT="/share/data7/opt/MetaflowX"
CONDA_ROOT="/share/data7/apps/miniconda3"
ENV_BASIC="MetaflowX"
ENV_NEXTFLOW="nextflow"
ENV_CHECKM2="checkm2"
ENV_QUAST="quast"
ENV_ANTISMASH="antismash"
ENV_METADECODER="metadecoder"
ENV_GALAH="galah"
ENV_RGI="rgi"
ENV_BIGMAP="bigmap"
ENV_METABINNER="metabinner"
ENV_COMEBIN="comebin"
ENV_BINNY="binny"
ENV_DEEPURIFY="deepurify"
ENV_VAMB="vamb"
ENV_GTDBTK="gtdbtk"
THREADS="16"
DO_INSTALL_NEXTFLOW=0
DO_INSTALL_ENVS=0
DO_INSTALL_BASIC_ENV=0
DO_INSTALL_CHECKM2_ENV=0
DO_INSTALL_QUAST_ENV=0
DO_INSTALL_ANTISMASH_ENV=0
DO_INSTALL_METADECODER_ENV=0
DO_INSTALL_GALAH_ENV=0
DO_INSTALL_RGI_ENV=0
DO_INSTALL_BIGMAP_ENV=0
DO_INSTALL_METABINNER_ENV=0
DO_INSTALL_COMEBIN_ENV=0
DO_INSTALL_BINNY_ENV=0
DO_INSTALL_DEEPURIFY_ENV=0
DO_INSTALL_VAMB_ENV=0
DO_INSTALL_GTDBTK_ENV=0
DO_DOWNLOAD_CORE_DB=0
DO_DOWNLOAD_KRAKEN2=0
DO_DOWNLOAD_GTDBTK=0
DO_DOWNLOAD_BIGMAP_DB=0
DO_DOWNLOAD_VFDB_DB=0
DO_DOWNLOAD_CARD_DB=0
DO_DOWNLOAD_DEEPURIFY_DB=0
DO_DOWNLOAD_CAT_DB=0
DO_DOWNLOAD_ANTISMASH_DB=0
RUN_AS_USER=""
USE_ENV_PROXY=0
KRAKEN2_STANDARD_URL="https://genome-idx.s3.amazonaws.com/kraken/k2_standard_20260226.tar.gz"
KRAKEN2_STANDARD_MD5_URL="https://genome-idx.s3.amazonaws.com/kraken/k2_standard_20260226.tar.gz.md5"
METAPHLAN_INDEX="mpa_vJan21_CHOCOPhlAnSGB_202103"
METAPHLAN_DB_BASE_URL="http://cmprod1.cibio.unitn.it/biobakery4/metaphlan_databases"
HUMANN_CHOCO_URL="http://huttenhower.sph.harvard.edu/humann_data/chocophlan/full_chocophlan.v201901_v31.tar.gz"
HUMANN_UNIREF_URL="https://huttenhower.sph.harvard.edu/humann_data/uniprot/uniref_annotated/uniref90_annotated_v201901b_full.tar.gz"
HUMANN_MAPPING_URL="http://huttenhower.sph.harvard.edu/humann_data/full_mapping_v201901b.tar.gz"
GTDBTK_DATA_URL="https://data.gtdb.ecogenomic.org/releases/release220/220.0/auxillary_files/gtdbtk_package/full_package/gtdbtk_r220_data.tar.gz"
EGGNOG_DB_BASE_URL="http://eggnog5.embl.de/download/emapperdb-5.0.2"
PFAM_A_HMM_URL="https://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.gz"
VFDB_PRO_URL="http://www.mgc.ac.cn/VFs/Down/VFDB_setB_pro.fas.gz"
CARD_DATA_URL="https://card.mcmaster.ca/latest/data"
CARD_VARIANTS_URL="https://card.mcmaster.ca/latest/variants"
DEEPURIFY_GDRIVE_ID="1TCVePKE98o1pNN2U6naILXHqX4tuea5a"
DEEPURIFY_ARCHIVE=""
CAT_GTDB_URL="http://tbb.bio.uu.nl/tina/CAT_pack_prepare/20231120_CAT_gtdb.tar.gz"

usage() {
  cat <<USAGE
Usage: bash $0 [options]

Options:
  --db-root PATH            Production DB root, default: ${DB_ROOT}
  --app-root PATH           MetaflowX repo path, default: ${APP_ROOT}
  --conda-root PATH         Miniconda root, default: ${CONDA_ROOT}
  --threads N               Threads for build/download commands, default: ${THREADS}
  --run-as-user USER        Run conda/download commands as USER via sudo -u
  --no-proxy                Clear proxy variables before downloads; default
  --use-env-proxy           Preserve current proxy variables for downloads
  --metaphlan-index NAME    MetaPhlAn index to install, default: ${METAPHLAN_INDEX}
  --install-nextflow        Create a lightweight nextflow conda environment
  --install-envs            Create all conda environments; compatibility umbrella option
  --install-basic-env       Create/update only the MetaflowX base conda environment
  --install-checkm2-env     Create/update only the CheckM2 conda environment
  --install-quast-env       Create/update only the MetaQUAST conda environment
  --install-antismash-env   Create/update only the antiSMASH conda environment
  --install-metadecoder-env Create/update only the MetaDecoder conda environment
  --install-galah-env       Create/update only the Galah conda environment
  --install-rgi-env         Create/update only the RGI conda environment
  --install-bigmap-env      Create/update only the BiG-MAP conda environment
  --install-metabinner-env  Create/update only the MetaBinner conda environment
  --install-comebin-env     Create/update only the COMEBin conda environment
  --install-binny-env       Create/update only the binny runtime
  --install-deepurify-env   Create/update only the Deepurify conda environment
  --install-vamb-env        Create/update only the Vamb conda environment
  --install-gtdbtk-env      Create/update only the GTDB-Tk conda environment
  --download-core-db        Download/build hg38, PhiX, MetaPhlAn, HUMAnN, eggNOG, CheckM2
  --download-kraken2        Download prebuilt Ben Langmead Kraken2/Bracken Standard DB
  --download-gtdbtk         Also download GTDB-Tk DB; needs ~110GB disk
  --download-bigmap-db      Download and hmmpress Pfam-A.hmm for BiG-MAP/BiG-SCAPE
  --download-vfdb-db        Download VFDB setB protein FASTA and build Diamond index
  --download-card-db        Download CARD/RGI data expected by MetaflowX RGI module
  --download-deepurify-db   Download Deepurify DB with gdown
  --deepurify-archive PATH  Use an already downloaded Deepurify DB archive
  --download-cat-db         Download prebuilt CAT_pack GTDB DB
  --download-antismash-db   Download antiSMASH databases under DB_ROOT
  -h, --help                Show this help

Notes:
  This script is non-root friendly and never changes ownership.
  The user running it must already have write access to DB_ROOT.
  Database downloads are large and can take many hours.
USAGE
}

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

run_cmd() {
  if [[ -z "${RUN_AS_USER}" || "$(id -un)" == "${RUN_AS_USER}" ]]; then
    "$@"
  else
    sudo -u "${RUN_AS_USER}" "$@"
  fi
}

download_helpers_cmd() {
  cat <<EOF
set -Eeuo pipefail
if [[ "${USE_ENV_PROXY}" != "1" ]]; then
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
fi

download_file() {
  local url="\$1"
  local name="\${2:-\${url##*/}}"
  command -v aria2c >/dev/null 2>&1 || {
    echo "ERROR: aria2c not found. Install it with: conda activate ${ENV_BASIC} && mamba install -y -c conda-forge aria2" >&2
    return 127
  }
  if [[ -s "\${name}" ]]; then
    echo "Resuming or verifying existing file with aria2c: \${name}"
  fi
  aria2c \
    --continue=true \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    -x 8 -s 8 -j 1 \
    --file-allocation=none \
    --check-certificate=false \
    -o "\${name}" \
    "\${url}"
  test -s "\${name}"
}

download_optional() {
  local url="\$1"
  local name="\${2:-\${url##*/}}"
  download_file "\${url}" "\${name}" || echo "WARNING: optional download failed: \${url}" >&2
}

download_tar_gz() {
  local url="\$1"
  local name="\${2:-\${url##*/}}"
  if [[ -s "\${name}" ]] && tar tzf "\${name}" >/dev/null 2>&1; then
    echo "Using verified archive: \${name}"
    return 0
  fi
  download_file "\${url}" "\${name}"
  tar tzf "\${name}" >/dev/null
}

download_tar() {
  local url="\$1"
  local name="\${2:-\${url##*/}}"
  if [[ -s "\${name}" ]] && tar tf "\${name}" >/dev/null 2>&1; then
    echo "Using verified archive: \${name}"
    return 0
  fi
  download_file "\${url}" "\${name}"
  tar tf "\${name}" >/dev/null
}

download_gzip() {
  local url="\$1"
  local name="\${2:-\${url##*/}}"
  if [[ -s "\${name}" ]] && gzip -t "\${name}" >/dev/null 2>&1; then
    echo "Using verified gzip: \${name}"
    return 0
  fi
  download_file "\${url}" "\${name}"
  gzip -t "\${name}" >/dev/null
}
EOF
}

conda_create_or_update_cmd() {
  local env_name="$1"
  local yml_file="$2"
  cat <<EOF
source '${CONDA_ROOT}/etc/profile.d/conda.sh'
cd '${APP_ROOT}/docs/environment'
if command -v mamba >/dev/null 2>&1; then
  SOLVER=mamba
else
  SOLVER=conda
fi
if conda env list | awk '{print \$1}' | grep -Fxq '${env_name}'; then
  "\${SOLVER}" env update -f '${yml_file}' -n '${env_name}'
else
  "\${SOLVER}" env create -f '${yml_file}' -n '${env_name}'
fi
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-root) DB_ROOT="$2"; shift 2 ;;
    --app-root) APP_ROOT="$2"; shift 2 ;;
    --conda-root) CONDA_ROOT="$2"; shift 2 ;;
    --threads) THREADS="$2"; shift 2 ;;
    --run-as-user) RUN_AS_USER="$2"; shift 2 ;;
    --no-proxy) USE_ENV_PROXY=0; shift ;;
    --use-env-proxy) USE_ENV_PROXY=1; shift ;;
    --metaphlan-index) METAPHLAN_INDEX="$2"; shift 2 ;;
    --install-nextflow) DO_INSTALL_NEXTFLOW=1; shift ;;
    --install-envs) DO_INSTALL_ENVS=1; shift ;;
    --install-basic-env) DO_INSTALL_BASIC_ENV=1; shift ;;
    --install-checkm2-env) DO_INSTALL_CHECKM2_ENV=1; shift ;;
    --install-quast-env) DO_INSTALL_QUAST_ENV=1; shift ;;
    --install-antismash-env) DO_INSTALL_ANTISMASH_ENV=1; shift ;;
    --install-metadecoder-env) DO_INSTALL_METADECODER_ENV=1; shift ;;
    --install-galah-env) DO_INSTALL_GALAH_ENV=1; shift ;;
    --install-rgi-env) DO_INSTALL_RGI_ENV=1; shift ;;
    --install-bigmap-env) DO_INSTALL_BIGMAP_ENV=1; shift ;;
    --install-metabinner-env) DO_INSTALL_METABINNER_ENV=1; shift ;;
    --install-comebin-env) DO_INSTALL_COMEBIN_ENV=1; shift ;;
    --install-binny-env) DO_INSTALL_BINNY_ENV=1; shift ;;
    --install-deepurify-env) DO_INSTALL_DEEPURIFY_ENV=1; shift ;;
    --install-vamb-env) DO_INSTALL_VAMB_ENV=1; shift ;;
    --install-gtdbtk-env) DO_INSTALL_GTDBTK_ENV=1; shift ;;
    --download-core-db) DO_DOWNLOAD_CORE_DB=1; shift ;;
    --download-kraken2) DO_DOWNLOAD_KRAKEN2=1; shift ;;
    --download-gtdbtk) DO_DOWNLOAD_GTDBTK=1; shift ;;
    --download-bigmap-db) DO_DOWNLOAD_BIGMAP_DB=1; shift ;;
    --download-vfdb-db) DO_DOWNLOAD_VFDB_DB=1; shift ;;
    --download-card-db) DO_DOWNLOAD_CARD_DB=1; shift ;;
    --download-deepurify-db) DO_DOWNLOAD_DEEPURIFY_DB=1; shift ;;
    --deepurify-archive) DEEPURIFY_ARCHIVE="$2"; shift 2 ;;
    --download-cat-db) DO_DOWNLOAD_CAT_DB=1; shift ;;
    --download-antismash-db) DO_DOWNLOAD_ANTISMASH_DB=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ -d "${APP_ROOT}" ]] || die "MetaflowX repo not found: ${APP_ROOT}"
[[ -d "${CONDA_ROOT}" ]] || die "Conda root not found: ${CONDA_ROOT}"

ENV_DIR="${CONDA_ROOT}/envs"
PROD_CONFIG="${DB_ROOT}/metaflowx_prod.config"

if [[ -e "${DB_ROOT}" && ! -w "${DB_ROOT}" ]]; then
  cat >&2 <<EOF
ERROR: DB_ROOT exists but is not writable: ${DB_ROOT}

Ask the cluster administrator or storage owner to grant write access first.
Examples:
  mkdir -p '${DB_ROOT}'
  chmod 2775 '${DB_ROOT}'
  setfacl -m u:$(id -un):rwx '${DB_ROOT}'
  setfacl -d -m u:$(id -un):rwx '${DB_ROOT}'

Or choose a writable path with:
  --db-root /path/you/can/write/MetaflowX
EOF
  exit 1
fi

log "Creating MetaflowX production database directory tree under ${DB_ROOT}"
mkdir -p \
  "${DB_ROOT}/host" \
  "${DB_ROOT}/host/hg38_bowtie2" \
  "${DB_ROOT}/phix/bowtie2" \
  "${DB_ROOT}/metaphlan" \
  "${DB_ROOT}/humann" \
  "${DB_ROOT}/kraken2/standard" \
  "${DB_ROOT}/eggnog/bact_arch" \
  "${DB_ROOT}/eggnog/eggnog_5.0" \
  "${DB_ROOT}/checkm2" \
  "${DB_ROOT}/gtdbtk/release220/metadata" \
  "${DB_ROOT}/gtdbtk/release220/mash" \
  "${DB_ROOT}/cat_pack/GTDB/release226" \
  "${DB_ROOT}/antismash" \
  "${DB_ROOT}/bigmap" \
  "${DB_ROOT}/CARD" \
  "${DB_ROOT}/VFDB" \
  "${DB_ROOT}/deepurify/Deepurify-DB" \
  "${DB_ROOT}/logs"

log "Writing production Nextflow config: ${PROD_CONFIG}"
cat > "${PROD_CONFIG}" <<EOF
/*
 * MetaflowX production configuration for pg-xujm.
 * Generated by deploy_metaflowx_admin.sh on $(date '+%F %T').
 *
 * Use with:
 *   NXF_SYNTAX_PARSER=v1 nextflow run ${APP_ROOT} \\
 *     -profile conda \\
 *     -c ${PROD_CONFIG} \\
 *     --input samplesheet.csv \\
 *     --outdir out \\
 *     --mode 1 \\
 *     -ansi-log false
 */

conda.enabled = true
process.conda = "${ENV_DIR}/${ENV_BASIC}"

params {
  pipeline_assets = "${APP_ROOT}"

  // QC host and PhiX filtering
  host_db = "${DB_ROOT}/host/hg38_bowtie2"
  host_db_index = "hg38"
  phix_db = "${DB_ROOT}/phix/bowtie2"
  phix_db_index = "phix"

  // MetaPhlAn / HUMAnN
  mpa_db = "${DB_ROOT}/metaphlan"
  mpa_index = "${METAPHLAN_INDEX}"
  sgb2gtdb_index = "${METAPHLAN_INDEX}_SGB"
  humann_chocophlan_db = "${DB_ROOT}/humann/chocophlan"
  humann_protein_db = "${DB_ROOT}/humann/uniref"
  humann_map_db = "${DB_ROOT}/humann/utility_mapping"

  // Optional Kraken2
  kraken2_db = "${DB_ROOT}/kraken2/standard"

  // eggNOG
  eggnog_diamond_db = "${DB_ROOT}/eggnog/bact_arch/bact_arch.dmnd"
  eggnog_mapper_db = "${DB_ROOT}/eggnog/eggnog_5.0"

  // MAG quality and taxonomy
  checkm2_db = "${DB_ROOT}/checkm2/CheckM2_database/uniref100.KO.1.dmnd"
  gtdbtk_db = "${DB_ROOT}/gtdbtk/release220"
  mash_db = "${DB_ROOT}/gtdbtk/release220/mash"
  gtdb_archaeal_metadata = "${DB_ROOT}/gtdbtk/release220/metadata/ar53_metadata_r220.tsv.gz"
  gtdb_bacterial_metadata = "${DB_ROOT}/gtdbtk/release220/metadata/bac120_metadata_r220.tsv.gz"

  // Optional functional/specialized DBs
  antismash_db = "${DB_ROOT}/antismash"
  binny_path = "${ENV_DIR}/${ENV_BINNY}/opt/binny"
  metabinner_path = "${ENV_DIR}/${ENV_METABINNER}/bin"
  cat_gtdb_db = "${DB_ROOT}/cat_pack/GTDB/current"
  bigspace_db = "${DB_ROOT}/bigmap/Pfam-A.hmm"
  CARD_db = "${DB_ROOT}/CARD"
  VFDB_db = "${DB_ROOT}/VFDB/VFDB_setB_pro.fas.S.fasta"
  deepurify_db = "${DB_ROOT}/deepurify/Deepurify-DB"
}

process {
  withName: CHECKM2 {
    conda = "${ENV_DIR}/${ENV_CHECKM2}"
  }
  withName: MULTICHECKM2 {
    conda = "${ENV_DIR}/${ENV_CHECKM2}"
  }
  withName: METAQUAST {
    conda = "${ENV_DIR}/${ENV_QUAST}"
  }
  withName: ANTISMASH {
    conda = "${ENV_DIR}/${ENV_ANTISMASH}"
  }
  withName: METADECODER {
    conda = "${ENV_DIR}/${ENV_METADECODER}"
  }
  withName: GALAH {
    conda = "${ENV_DIR}/${ENV_GALAH}"
  }
  withName: GALAHMULTIBIN {
    conda = "${ENV_DIR}/${ENV_GALAH}"
  }
  withName: RGI {
    conda = "${ENV_DIR}/${ENV_RGI}"
  }
  withName: BIGMAP {
    conda = "${ENV_DIR}/${ENV_BIGMAP}"
  }
  withName: METABINNER {
    conda = "${ENV_DIR}/${ENV_METABINNER}"
  }
  withName: COMEBIN {
    conda = "${ENV_DIR}/${ENV_COMEBIN}"
  }
  withName: BINNY {
    conda = "${ENV_DIR}/${ENV_BINNY}"
  }
  withName: DEEPURIFYCLEAN {
    conda = "${ENV_DIR}/${ENV_DEEPURIFY}"
  }
  withName: DEEPURIFYREBIN {
    conda = "${ENV_DIR}/${ENV_DEEPURIFY}"
  }
  withName: DEEPURIFYCLEANRENAME {
    conda = "${ENV_DIR}/${ENV_DEEPURIFY}"
  }
  withName: VAMBBIN {
    conda = "${ENV_DIR}/${ENV_VAMB}"
  }
  withName: GTDB {
    conda = "${ENV_DIR}/${ENV_GTDBTK}"
  }
}
EOF
if [[ "${DO_INSTALL_NEXTFLOW}" -eq 1 ]]; then
  log "Installing lightweight Nextflow conda environment: ${ENV_NEXTFLOW}"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && if command -v mamba >/dev/null 2>&1; then SOLVER=mamba; else SOLVER=conda; fi && \${SOLVER} create -y -n '${ENV_NEXTFLOW}' -c bioconda -c conda-forge nextflow"
fi

if [[ "${DO_INSTALL_ENVS}" -eq 1 ]]; then
  DO_INSTALL_BASIC_ENV=1
  DO_INSTALL_CHECKM2_ENV=1
  DO_INSTALL_QUAST_ENV=1
  DO_INSTALL_ANTISMASH_ENV=1
  DO_INSTALL_METADECODER_ENV=1
  DO_INSTALL_GALAH_ENV=1
  DO_INSTALL_RGI_ENV=1
  DO_INSTALL_BIGMAP_ENV=1
  DO_INSTALL_METABINNER_ENV=1
  DO_INSTALL_COMEBIN_ENV=1
  DO_INSTALL_BINNY_ENV=1
  DO_INSTALL_DEEPURIFY_ENV=1
  DO_INSTALL_VAMB_ENV=1
  DO_INSTALL_GTDBTK_ENV=1
fi

if [[ "${DO_INSTALL_BASIC_ENV}" -eq 1 ]]; then
  log "Installing MetaflowX base conda environment from docs/environment/basic.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_BASIC}" "basic.yml")"

  log "Installing runtime patch packages into ${ENV_BASIC}: aria2 gdown setuptools<81"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda activate '${ENV_BASIC}' && if command -v mamba >/dev/null 2>&1; then SOLVER=mamba; else SOLVER=conda; fi && \${SOLVER} install -y -c conda-forge aria2 gdown 'setuptools<81' && python -c 'import pkg_resources'"
fi

if [[ "${DO_INSTALL_CHECKM2_ENV}" -eq 1 ]]; then
  log "Installing CheckM2 conda environment from docs/environment/checkm2.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_CHECKM2}" "checkm2.yml")"

  log "Installing CheckM2 Python package into ${ENV_CHECKM2}"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda activate '${ENV_CHECKM2}' && pip install checkm2"
fi

if [[ "${DO_INSTALL_QUAST_ENV}" -eq 1 ]]; then
  log "Installing MetaQUAST conda environment from docs/environment/quast.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_QUAST}" "quast.yml")"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda run -n '${ENV_QUAST}' metaquast.py --version"
fi

if [[ "${DO_INSTALL_ANTISMASH_ENV}" -eq 1 ]]; then
  log "Installing antiSMASH conda environment from docs/environment/antismash.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_ANTISMASH}" "antismash.yml")"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda run -n '${ENV_ANTISMASH}' antismash --version"
fi

if [[ "${DO_INSTALL_METADECODER_ENV}" -eq 1 ]]; then
  log "Installing MetaDecoder conda environment from docs/environment/metadecoder.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_METADECODER}" "metadecoder.yml")"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda run -n '${ENV_METADECODER}' metadecoder --version"
fi

if [[ "${DO_INSTALL_GALAH_ENV}" -eq 1 ]]; then
  log "Installing Galah conda environment from docs/environment/galah.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_GALAH}" "galah.yml")"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda run -n '${ENV_GALAH}' galah --version"
fi

if [[ "${DO_INSTALL_RGI_ENV}" -eq 1 ]]; then
  log "Installing RGI conda environment from docs/environment/rgi.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_RGI}" "rgi.yml")"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda run -n '${ENV_RGI}' rgi main --version"
fi

if [[ "${DO_INSTALL_BIGMAP_ENV}" -eq 1 ]]; then
  log "Installing BiG-MAP conda environment from docs/environment/bigmap.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_BIGMAP}" "bigmap.yml")"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda activate '${ENV_BIGMAP}' && mkdir -p '${ENV_DIR}/${ENV_BIGMAP}/opt' && if [[ ! -d '${ENV_DIR}/${ENV_BIGMAP}/opt/BiG-MAP/.git' ]]; then git clone https://github.com/medema-group/BiG-MAP.git '${ENV_DIR}/${ENV_BIGMAP}/opt/BiG-MAP'; fi && chmod +x '${ENV_DIR}/${ENV_BIGMAP}/opt/BiG-MAP/src/'*.py && cp -f '${ENV_DIR}/${ENV_BIGMAP}/opt/BiG-MAP/src/'*.py '${ENV_DIR}/${ENV_BIGMAP}/bin/' && command -v BiG-MAP.family.py && command -v BiG-MAP.map.py"
fi

if [[ "${DO_INSTALL_METABINNER_ENV}" -eq 1 ]]; then
  log "Installing MetaBinner conda environment from docs/environment/metabinner.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_METABINNER}" "metabinner.yml")"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda run -n '${ENV_METABINNER}' run_metabinner.sh --help >/dev/null 2>&1 || conda run -n '${ENV_METABINNER}' which run_metabinner.sh"
fi

if [[ "${DO_INSTALL_COMEBIN_ENV}" -eq 1 ]]; then
  log "Installing COMEBin conda environment from docs/environment/comebin.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_COMEBIN}" "comebin.yml")"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda run -n '${ENV_COMEBIN}' which run_comebin.sh"
fi

if [[ "${DO_INSTALL_BINNY_ENV}" -eq 1 ]]; then
  log "Installing binny runtime from docs/environment/binny.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_BINNY}" "binny.yml")"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda activate '${ENV_BINNY}' && mkdir -p '${ENV_DIR}/${ENV_BINNY}/opt' && if [[ ! -d '${ENV_DIR}/${ENV_BINNY}/opt/binny/.git' ]]; then git clone https://github.com/a-h-b/binny.git '${ENV_DIR}/${ENV_BINNY}/opt/binny'; fi && cd '${ENV_DIR}/${ENV_BINNY}/opt/binny' && ./binny -i config/config.init.yaml && test -x ./binny"
fi

if [[ "${DO_INSTALL_DEEPURIFY_ENV}" -eq 1 ]]; then
  log "Installing Deepurify conda environment from docs/environment/deepurify.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_DEEPURIFY}" "deepurify.yml")"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda run -n '${ENV_DEEPURIFY}' deepurify --version"
fi

if [[ "${DO_INSTALL_VAMB_ENV}" -eq 1 ]]; then
  log "Installing Vamb conda environment from docs/environment/vamb.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_VAMB}" "vamb.yml")"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda run -n '${ENV_VAMB}' vamb --version"
fi

if [[ "${DO_INSTALL_GTDBTK_ENV}" -eq 1 ]]; then
  log "Installing GTDB-Tk conda environment from docs/environment/gtdbtk.yml"
  run_cmd bash -lc "$(conda_create_or_update_cmd "${ENV_GTDBTK}" "gtdbtk.yml")"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda run -n '${ENV_GTDBTK}' gtdbtk --version"
fi

if [[ "${DO_DOWNLOAD_CORE_DB}" -eq 1 ]]; then
  log "Downloading/building hg38 Bowtie2 host index"
  run_cmd bash -lc "$(download_helpers_cmd)
source '${CONDA_ROOT}/etc/profile.d/conda.sh'
conda activate '${ENV_BASIC}'
cd '${DB_ROOT}/host'
download_gzip 'http://hgdownload.cse.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz' 'hg38.fa.gz'
cd '${DB_ROOT}/host/hg38_bowtie2'
if [[ -s hg38.1.bt2 && -s hg38.2.bt2 && -s hg38.3.bt2 && -s hg38.4.bt2 && -s hg38.rev.1.bt2 && -s hg38.rev.2.bt2 ]]; then
  echo 'Using existing hg38 Bowtie2 index'
else
  bowtie2-build --verbose --threads '${THREADS}' ../hg38.fa.gz hg38
fi"

  log "Downloading/building PhiX Bowtie2 index"
  run_cmd bash -lc "$(download_helpers_cmd)
source '${CONDA_ROOT}/etc/profile.d/conda.sh'
conda activate '${ENV_BASIC}'
cd '${DB_ROOT}/phix'
download_gzip 'https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/002/596/845/GCA_002596845.1_ASM259684v1/GCA_002596845.1_ASM259684v1_genomic.fna.gz' 'phix.fa.gz'
cd '${DB_ROOT}/phix/bowtie2'
if [[ -s phix.1.bt2 && -s phix.2.bt2 && -s phix.3.bt2 && -s phix.4.bt2 && -s phix.rev.1.bt2 && -s phix.rev.2.bt2 ]]; then
  echo 'Using existing PhiX Bowtie2 index'
else
  bowtie2-build --verbose --threads '${THREADS}' ../phix.fa.gz phix
fi"

  log "Installing MetaPhlAn database explicitly: ${METAPHLAN_INDEX}"
  run_cmd bash -lc "
$(download_helpers_cmd)
source '${CONDA_ROOT}/etc/profile.d/conda.sh'
conda activate '${ENV_BASIC}'
cd '${DB_ROOT}/metaphlan'
download_tar '${METAPHLAN_DB_BASE_URL}/bowtie2_indexes/${METAPHLAN_INDEX}_bt2.tar'
download_optional '${METAPHLAN_DB_BASE_URL}/bowtie2_indexes/${METAPHLAN_INDEX}_bt2.md5'
download_tar '${METAPHLAN_DB_BASE_URL}/${METAPHLAN_INDEX}.tar'
download_optional '${METAPHLAN_DB_BASE_URL}/${METAPHLAN_INDEX}.md5'
download_optional '${METAPHLAN_DB_BASE_URL}/${METAPHLAN_INDEX}.nwk'
if command -v md5sum >/dev/null 2>&1 && test -s '${METAPHLAN_INDEX}_bt2.md5'; then md5sum -c '${METAPHLAN_INDEX}_bt2.md5'; fi
if command -v md5sum >/dev/null 2>&1 && test -s '${METAPHLAN_INDEX}.md5'; then md5sum -c '${METAPHLAN_INDEX}.md5'; fi
if compgen -G '${METAPHLAN_INDEX}*.bt2*' >/dev/null; then
  echo 'Using existing MetaPhlAn Bowtie2 index files'
else
  tar xf '${METAPHLAN_INDEX}_bt2.tar'
fi
if [[ -s '${METAPHLAN_INDEX}.pkl' || -s '${METAPHLAN_INDEX}_VINFO.csv' || -s '${METAPHLAN_INDEX}_marker_info.txt' || -s '${METAPHLAN_INDEX}_species.txt' ]]; then
  echo 'Using existing MetaPhlAn metadata files'
else
  tar xf '${METAPHLAN_INDEX}.tar'
fi
printf '%s\n' '${METAPHLAN_INDEX}' > mpa_latest
"

  log "Installing HUMAnN databases explicitly with resumable downloads"
  run_cmd bash -lc "
$(download_helpers_cmd)
source '${CONDA_ROOT}/etc/profile.d/conda.sh'
conda activate '${ENV_BASIC}'
cd '${DB_ROOT}/humann'
mkdir -p chocophlan uniref utility_mapping
download_tar_gz '${HUMANN_CHOCO_URL}' 'full_chocophlan.v201901_v31.tar.gz'
download_tar_gz '${HUMANN_UNIREF_URL}' 'uniref90_annotated_v201901b_full.tar.gz'
download_tar_gz '${HUMANN_MAPPING_URL}' 'full_mapping_v201901b.tar.gz'
if find chocophlan -type f | grep -q .; then
  echo 'Using existing HUMAnN ChocoPhlAn files'
else
  tar xzf full_chocophlan.v201901_v31.tar.gz -C chocophlan
fi
if find uniref -type f | grep -q .; then
  echo 'Using existing HUMAnN UniRef files'
else
  tar xzf uniref90_annotated_v201901b_full.tar.gz -C uniref
fi
if find utility_mapping -type f | grep -q .; then
  echo 'Using existing HUMAnN utility mapping files'
else
  tar xzf full_mapping_v201901b.tar.gz -C utility_mapping
fi
"

  log "Installing eggNOG mapper databases"
  run_cmd bash -lc "
$(download_helpers_cmd)
source '${CONDA_ROOT}/etc/profile.d/conda.sh'
conda activate '${ENV_BASIC}'
cd '${DB_ROOT}/eggnog/bact_arch'
if [[ -s bact_arch.dmnd ]]; then
  echo 'Using existing eggNOG bact_arch Diamond database'
else
  create_dbs.py -m diamond --dbname bact_arch --taxa Bacteria,Archaea --data_dir '${DB_ROOT}/eggnog/bact_arch' -y
fi
test -s '${DB_ROOT}/eggnog/bact_arch/bact_arch.dmnd'
cd '${DB_ROOT}/eggnog/eggnog_5.0'
if [[ -s eggnog.db ]]; then
  echo 'Using existing eggNOG mapper eggnog.db'
else
  download_gzip '${EGGNOG_DB_BASE_URL}/eggnog.db.gz' 'eggnog.db.gz'
  gunzip -f eggnog.db.gz
fi
if [[ -s eggnog.taxa.db ]]; then
  echo 'Using existing eggNOG mapper eggnog.taxa.db'
else
  download_tar_gz '${EGGNOG_DB_BASE_URL}/eggnog.taxa.tar.gz' 'eggnog.taxa.tar.gz'
  tar -zxf eggnog.taxa.tar.gz
  rm -f eggnog.taxa.tar.gz
fi
if [[ -s eggnog_proteins.dmnd ]]; then
  echo 'Using existing eggNOG mapper eggnog_proteins.dmnd'
else
  download_gzip '${EGGNOG_DB_BASE_URL}/eggnog_proteins.dmnd.gz' 'eggnog_proteins.dmnd.gz'
  gunzip -f eggnog_proteins.dmnd.gz
fi
test -s '${DB_ROOT}/eggnog/eggnog_5.0/eggnog.db'
test -s '${DB_ROOT}/eggnog/eggnog_5.0/eggnog.taxa.db'
test -s '${DB_ROOT}/eggnog/eggnog_5.0/eggnog_proteins.dmnd'
"

  log "Installing CheckM2 database"
  run_cmd bash -lc "source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda activate '${ENV_CHECKM2}' && checkm2 database --download --path '${DB_ROOT}/checkm2'"
fi

if [[ "${DO_DOWNLOAD_KRAKEN2}" -eq 1 ]]; then
  log "Downloading prebuilt Kraken2/Bracken Standard DB from Ben Langmead AWS indexes"
  log "Archive URL: ${KRAKEN2_STANDARD_URL}"
  run_cmd bash -lc "$(download_helpers_cmd)
source '${CONDA_ROOT}/etc/profile.d/conda.sh'
conda activate '${ENV_BASIC}'
cd '${DB_ROOT}/kraken2/standard'
download_tar_gz '${KRAKEN2_STANDARD_URL}' 'k2_standard_20260226.tar.gz'
download_optional '${KRAKEN2_STANDARD_MD5_URL}' 'k2_standard_20260226.tar.gz.md5'
if command -v md5sum >/dev/null 2>&1 && test -s k2_standard_20260226.tar.gz.md5; then md5sum -c k2_standard_20260226.tar.gz.md5; fi
tar xzf k2_standard_20260226.tar.gz"
fi

if [[ "${DO_DOWNLOAD_GTDBTK}" -eq 1 ]]; then
  log "Downloading GTDB-Tk database and metadata"
  run_cmd bash -lc "$(download_helpers_cmd)
source '${CONDA_ROOT}/etc/profile.d/conda.sh'
conda activate '${ENV_BASIC}'
cd '${DB_ROOT}/gtdbtk'
download_tar_gz '${GTDBTK_DATA_URL}' 'gtdbtk_r220_data.tar.gz'
tar xvzf gtdbtk_r220_data.tar.gz -C '${DB_ROOT}/gtdbtk/release220' --strip-components=1
cd '${DB_ROOT}/gtdbtk/release220/metadata'
download_gzip 'https://data.gtdb.ecogenomic.org/releases/release220/220.0/ar53_metadata_r220.tsv.gz' 'ar53_metadata_r220.tsv.gz'
download_gzip 'https://data.gtdb.ecogenomic.org/releases/release220/220.0/bac120_metadata_r220.tsv.gz' 'bac120_metadata_r220.tsv.gz'"
fi

if [[ "${DO_DOWNLOAD_BIGMAP_DB}" -eq 1 ]]; then
  log "Downloading Pfam-A.hmm for BiG-MAP/BiG-SCAPE"
  run_cmd bash -lc "$(download_helpers_cmd)
source '${CONDA_ROOT}/etc/profile.d/conda.sh'
conda activate '${ENV_BASIC}'
cd '${DB_ROOT}/bigmap'
if [[ -s Pfam-A.hmm ]]; then
  echo 'Using existing Pfam-A.hmm'
else
  download_gzip '${PFAM_A_HMM_URL}' 'Pfam-A.hmm.gz'
  gunzip -f Pfam-A.hmm.gz
fi
test -s Pfam-A.hmm
if [[ -s Pfam-A.hmm.h3f && -s Pfam-A.hmm.h3i && -s Pfam-A.hmm.h3m && -s Pfam-A.hmm.h3p ]]; then
  echo 'Using existing hmmpress files for Pfam-A.hmm'
else
  hmmpress Pfam-A.hmm
fi"
fi

if [[ "${DO_DOWNLOAD_VFDB_DB}" -eq 1 ]]; then
  log "Downloading VFDB setB protein database"
  run_cmd bash -lc "$(download_helpers_cmd)
source '${CONDA_ROOT}/etc/profile.d/conda.sh'
conda activate '${ENV_BASIC}'
cd '${DB_ROOT}/VFDB'
if [[ -s VFDB_setB_pro.fas ]]; then
  echo 'Using existing VFDB_setB_pro.fas'
else
  download_gzip '${VFDB_PRO_URL}' 'VFDB_setB_pro.fas.gz'
  gunzip -f VFDB_setB_pro.fas.gz
fi
if [[ -s VFDB_setB_pro.fas.S.fasta ]]; then
  echo 'Using existing simplified VFDB FASTA'
else
  awk '/^>/{split(\$0,a,\" \"); print a[1]; next} {print}' VFDB_setB_pro.fas > VFDB_setB_pro.fas.S.fasta
fi
test -s VFDB_setB_pro.fas.S.fasta
if [[ -s VFDB_setB_pro.fas.S.dmnd ]]; then
  echo 'Using existing VFDB Diamond index'
else
  diamond makedb --in VFDB_setB_pro.fas.S.fasta --db VFDB_setB_pro.fas.S
fi"
fi

if [[ "${DO_DOWNLOAD_CARD_DB}" -eq 1 ]]; then
  log "Downloading CARD/RGI database files required by MetaflowX"
  run_cmd bash -lc "$(download_helpers_cmd)
source '${CONDA_ROOT}/etc/profile.d/conda.sh'
conda activate '${ENV_BASIC}'
cd '${DB_ROOT}/CARD'
mkdir -p raw_data raw_variants wildcard
if [[ ! -s card_data.tar ]]; then
  download_file '${CARD_DATA_URL}' 'card_data.tar'
fi
if [[ ! -s card_variants.tar ]]; then
  download_file '${CARD_VARIANTS_URL}' 'card_variants.tar'
fi
tar tf card_data.tar >/dev/null
tar tf card_variants.tar >/dev/null
tar xf card_data.tar -C raw_data
tar xf card_variants.tar -C raw_variants
find_first() {
  local pattern=\"\$1\"
  find raw_data raw_variants -type f -name \"\${pattern}\" | head -n 1
}
find_versioned_card_file() {
  local prefix=\"\$1\"
  local suffix=\"\$2\"
  if [[ \"\${suffix}\" == '.fasta' ]]; then
    find raw_data raw_variants -type f -name \"\${prefix}_v*.fasta\" ! -name '*_all.fasta' | sort -V | tail -n 1
  else
    find raw_data raw_variants -type f -name \"\${prefix}_v*\${suffix}\" | sort -V | tail -n 1
  fi
}
copy_required() {
  local pattern=\"\$1\"
  local dest=\"\$2\"
  local src
  src=\$(find_first \"\${pattern}\")
  if [[ -z \"\${src}\" ]]; then
    echo \"ERROR: Could not find required CARD file matching \${pattern}\" >&2
    return 1
  fi
  cp -f \"\${src}\" \"\${dest}\"
}
copy_versioned_required() {
  local prefix=\"\$1\"
  local suffix=\"\$2\"
  local src
  local dest
  src=\$(find_versioned_card_file \"\${prefix}\" \"\${suffix}\")
  if [[ -z \"\${src}\" ]]; then
    echo \"ERROR: Could not find required CARD file matching \${prefix}_v*\${suffix}\" >&2
    return 1
  fi
  dest=\$(basename \"\${src}\")
  echo \"Installing CARD file \${src} as \${dest}\"
  cp -f \"\${src}\" \"\${dest}\"
}
copy_required 'card.json' 'card.json'
copy_versioned_required 'card_database' '.fasta'
copy_versioned_required 'card_database' '_all.fasta'
copy_versioned_required 'wildcard_database' '.fasta'
copy_versioned_required 'wildcard_database' '_all.fasta'
copy_required 'index-for-model-sequences.txt' 'wildcard/index-for-model-sequences.txt'
copy_required 'all_amr_61mers.txt' 'wildcard/all_amr_61mers.txt'
copy_required '61_kmer_db.json' 'wildcard/61_kmer_db.json'
test -s card.json
find . -maxdepth 1 -type f -name 'card_database_v*.fasta' ! -name '*_all.fasta' | grep -q .
find . -maxdepth 1 -type f -name 'card_database_v*_all.fasta' | grep -q .
find . -maxdepth 1 -type f -name 'wildcard_database_v*.fasta' ! -name '*_all.fasta' | grep -q .
find . -maxdepth 1 -type f -name 'wildcard_database_v*_all.fasta' | grep -q .
test -s wildcard/index-for-model-sequences.txt
test -s wildcard/all_amr_61mers.txt
test -s wildcard/61_kmer_db.json"
fi

if [[ "${DO_DOWNLOAD_ANTISMASH_DB}" -eq 1 ]]; then
  log "Installing antiSMASH databases into ${DB_ROOT}/antismash"
  run_cmd bash -lc "if [[ '${USE_ENV_PROXY}' != '1' ]]; then unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY; fi; mkdir -p '${DB_ROOT}/antismash'; source '${CONDA_ROOT}/etc/profile.d/conda.sh' && conda run -n '${ENV_ANTISMASH}' download-antismash-databases --database-dir '${DB_ROOT}/antismash' && find '${DB_ROOT}/antismash/mite' -path '*/mite.fasta' -type f | grep -q ."
fi

if [[ "${DO_DOWNLOAD_DEEPURIFY_DB}" -eq 1 ]]; then
  log "Downloading Deepurify database from Google Drive"
  run_cmd bash -lc "$(download_helpers_cmd)
source '${CONDA_ROOT}/etc/profile.d/conda.sh'
conda activate '${ENV_BASIC}'
cd '${DB_ROOT}/deepurify'
command -v gdown >/dev/null 2>&1 || {
  echo 'ERROR: gdown not found. Run --install-envs first or install gdown into MetaflowX.' >&2
  exit 127
}
if find Deepurify-DB -mindepth 1 -type f | grep -q .; then
  echo 'Using existing Deepurify-DB directory'
else
  if [[ -n '${DEEPURIFY_ARCHIVE}' ]]; then
    test -s '${DEEPURIFY_ARCHIVE}'
    cp -f '${DEEPURIFY_ARCHIVE}' deepurify_db_download
  else
    gdown '${DEEPURIFY_GDRIVE_ID}' -O deepurify_db_download || {
      cat >&2 <<'DEEPURIFY_GDOWN_ERROR'
ERROR: gdown could not retrieve the Deepurify Google Drive file.
The upstream Google Drive link may be private, quota-limited, or blocked.
Download the DB archive manually from a browser, then rerun:
  ./deploy_metaflowx_admin.sh --download-deepurify-db --deepurify-archive /path/to/archive
DEEPURIFY_GDOWN_ERROR
      exit 1
    }
  fi
  test -s deepurify_db_download
  if tar tf deepurify_db_download >/dev/null 2>&1; then
    tar xf deepurify_db_download
  elif unzip -t deepurify_db_download >/dev/null 2>&1; then
    unzip -o deepurify_db_download
  else
    echo 'ERROR: Deepurify download is neither tar nor zip archive.' >&2
    exit 1
  fi
fi
mkdir -p Deepurify-DB
if find . -maxdepth 2 -type d -name 'Deepurify-DB' | grep -qv '^\./Deepurify-DB$'; then
  src=\$(find . -maxdepth 2 -type d -name 'Deepurify-DB' | grep -v '^\./Deepurify-DB$' | head -n 1)
  cp -a \"\${src}\"/. Deepurify-DB/
fi
if ! find Deepurify-DB -mindepth 1 -type f | grep -q .; then
  echo 'ERROR: Deepurify-DB is still empty after download/extraction.' >&2
  exit 1
fi"
fi

if [[ "${DO_DOWNLOAD_CAT_DB}" -eq 1 ]]; then
  log "Downloading prebuilt CAT_pack GTDB database"
  run_cmd bash -lc "$(download_helpers_cmd)
source '${CONDA_ROOT}/etc/profile.d/conda.sh'
conda activate '${ENV_BASIC}'
cd '${DB_ROOT}/cat_pack/GTDB'
download_tar_gz '${CAT_GTDB_URL}' 'CAT_gtdb.tar.gz'
tar xzf CAT_gtdb.tar.gz
db_dir=\$(find . -maxdepth 2 -type f \( -name '*.dmnd' -o -name 'taxids_with_multiple_offspring.txt' -o -name 'nodes.dmp' \) -printf '%h\n' | sort -u | head -n 1)
if [[ -z \"\${db_dir}\" ]]; then
  echo 'ERROR: Could not identify extracted CAT_pack GTDB database directory.' >&2
  exit 1
fi
rm -f current
ln -s \"\${db_dir#./}\" current
test -e current"
fi

log "Deployment script completed."
log "Production config: ${PROD_CONFIG}"
log "Next step after core DB is ready:"
log "  source ${CONDA_ROOT}/etc/profile.d/conda.sh"
log "  conda activate ${ENV_NEXTFLOW}"
log "  NXF_SYNTAX_PARSER=v1 nextflow run ${APP_ROOT} -profile conda -c ${PROD_CONFIG} --input samplesheet.csv --outdir out --mode 1 -ansi-log false"
