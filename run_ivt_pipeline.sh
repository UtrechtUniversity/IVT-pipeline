#!/bin/bash
set -euo pipefail

# --------------------------------------------------------
# IVT Processing Pipeline Wrapper Script
# --------------------------------------------------------
# This script automates the workflow for calculating
# Integrated Vapor Transport (IVT) from HCLIM climate model data.
# Model layers 300-1000hPa are used (9 layers: (300 400 500 600 700 750 850 925 1000))
#
# This script uses a specific Python version for creating level bounds:
# Default path: /usr/local/apps/python3/3.12.9-01/bin/python3
# If this path does not exist on your system, modify the PYTHON variable below to match your environment
#    e.g., PYTHON=/usr/bin/python3
#
# It sequentially runs:
#   1) Vertical layer merging of selected variables (hus, ua, va)
#   2) Creation of pressure level bounds (once per run)
#   3) IVT calculation for specified months and years
#
# Users specify the climate model (GCM), start/end years,
# and optionally start/end months for partial year processing.
#
# The script handles experiment selection (hist/ssp370) based
# on the year and sets model-specific member IDs automatically.
#
# Paths to model input files, intermediate merged files, and
# final IVT output are hardcoded but can be adjusted below.
#
# Usage:
#   ./run_ivt_pipeline.sh <GCM> <START_YEAR> <END_YEAR> [START_MONTH] [END_MONTH]
#
# Example:
#   ./run_ivt_pipeline.sh           		       # default is CNRMESM21 Dec 2014
#   ./run_ivt_pipeline.sh NORESM2MM 2015 2015 03 06    # runs Mar-Jun 2015 for NorESM2-MM
#   ./run_ivt_pipeline.sh CNRMESM21 2014 2014 12 12    # run Jan 2014 only for CNRM-ESM2.1
# --------------------------------------------------------

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [GCM] [START_YEAR] [END_YEAR] [START_MONTH] [END_MONTH]"
  exit 0
fi

GCM=${1:-"CNRMESM21"} # default CNRMESM21 201412 if not passed
START_YEAR=${2:-2014}
END_YEAR=${3:-2014}
START_MONTH=${4:-12}
END_MONTH=${5:-12}

# === Paths ===
MODEL_INPUT="/ec/res4/scratch/nld1254/hclim"
WORK_DIR="${MODEL_INPUT}/work"
MERGED_FILES="${MODEL_INPUT}/merged_monthly_variables"
IVT_OUTPUT="${MODEL_INPUT}/ivt"

mkdir -p "$WORK_DIR" "$MERGED_FILES" "$IVT_OUTPUT"

# Set python alias to full path of python3 - comment this line if your environment already has python3 or python properly set
PYTHON='/usr/local/apps/python3/3.12.9-01/bin/python3'

# Validate months are 01-12
if ! [[ "$START_MONTH" =~ ^(0[1-9]|1[0-2])$ ]] || ! [[ "$END_MONTH" =~ ^(0[1-9]|1[0-2])$ ]]; then
  echo "Error: START_MONTH and END_MONTH must be two-digit months between 01 and 12"
  exit 1
fi

# === GCM-specific settings ===
if [[ $GCM == "CNRMESM21" ]]; then
  MEMBER="r1i1p1f2"
elif [[ $GCM == "NORESM2MM" ]]; then
  MEMBER="r1i1p1f1"
else
  echo "Unsupported GCM: $GCM"
  exit 1
fi

# === level_bounds ===
# The create_level_bounds.py needs to be run only one time, the output file (level_bounds.nc)  will be used by the IVT calculation code.       
if [ ! -f "${WORK_DIR}/level_bounds.nc" ]; then
  echo "📘 Creating level_bounds.nc in $WORK_DIR..."
  $PYTHON create_level_bounds.py
  mv level_bounds.nc "${WORK_DIR}/level_bounds.nc"
else
  echo "✅ level_bounds.nc already exists in $WORK_DIR, skipping creation."
fi


# === Build list of months to process ===
MONTH_LIST=()
for YEAR in $(seq $START_YEAR $END_YEAR); do
  if [[ "$YEAR" -eq "$START_YEAR" && "$YEAR" -eq "$END_YEAR" ]]; then
    MONTH_START=$START_MONTH
    MONTH_END=$END_MONTH
  elif [[ "$YEAR" -eq "$START_YEAR" ]]; then
    MONTH_START=$START_MONTH
    MONTH_END=12
  elif [[ "$YEAR" -eq "$END_YEAR" ]]; then
    MONTH_START=01
    MONTH_END=$END_MONTH
  else
    MONTH_START=01
    MONTH_END=12
  fi

  for MONTH in $(seq -w $MONTH_START $MONTH_END); do
    MONTH_LIST+=("${YEAR}${MONTH}")
  done
done

# === Print model and member info ===
echo "Running IVT calculations for model: $GCM, member: $MEMBER"
echo "Processing time range (months):"

# === Print summary and confirm ===
for m in "${MONTH_LIST[@]}"; do
  echo "  - $m"
done

read -p "🔁 Continue processing the above months? (yes/y to proceed): " confirm
if [[ "$confirm" != "yes" && "$confirm" != "y" ]]; then
  echo "❌ Aborting IVT pipeline."
  exit 0
fi

# === Main processing loop ===
for YYYYMM in "${MONTH_LIST[@]}"; do
  YEAR=${YYYYMM:0:4}

  if (( YEAR < 2015 )); then
    EXP="hist"
  else
    EXP="ssp370"
  fi

  echo ">>> Processing $YYYYMM for $GCM ($EXP)..."

  ./merge_verticallayers_allvar_cdo.sh "$GCM" "$EXP" "$MEMBER" "$YYYYMM" "$MODEL_INPUT" "$MERGED_FILES"
  ./IVT_HCLIM_Arctic_cdo.sh "$GCM" "$EXP" "$MEMBER" "$YYYYMM" "$MERGED_FILES" "$IVT_OUTPUT"

  echo ">>> Finished $YYYYMM"
  echo "----------------------"
done

echo "✅ All processing complete."
