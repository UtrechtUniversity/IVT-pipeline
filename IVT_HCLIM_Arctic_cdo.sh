#!/bin/bash
set -e

# ================================================================
# Script: IVT_HCLIM_Arctic_cdo.sh
#
# Purpose:
#   Calculates Integrated Vapor Transport (IVT) from vertically stacked
#   specific humidity (hus), zonal wind (ua), and meridional wind (va)
#   fields produced by the HCLIM regional climate model.
#
# Process Overview:
#   For each monthly file (YYYYMM), this script:
#
#   1. Computes the moisture flux components:
#        q*u (zonal) and q*v (meridional)
#
#   2. Appends pressure layer bounds (plev_bounds) to enable vertical integration.
#
#   3. Vertically integrates q*u and q*v over pressure using CDO's `vertint`,
#      which approximates:
#         ∫(q*u) dp   and   ∫(q*v) dp
#
#   4. Divides both components by gravitational acceleration (g = 9.81 m/s²)
#      to convert units from kg/(m²·s·Pa) → kg/(m·s)
#
#   5. Computes IVT magnitude:
#        IVT = sqrt[ (IVT_x)² + (IVT_y)² ]
#
#   6. Outputs IVT magnitude with variable name `IVT` in NetCDF format.
#
# Scientific Justification:
#   IVT is defined as the vertically integrated horizontal flux of water vapor:
#
#     IVT = √[ (1/g) ∫ q·u dp ]² + [ (1/g) ∫ q·v dp ]²
#
#   where:
#     - q  = specific humidity [kg/kg]
#     - u, v = wind components [m/s]
#     - p  = pressure level [Pa]
#     - g  = gravitational acceleration [9.81 m/s²]
#
#   This script performs this integration using pressure bounds and layer-averaged
#   values, and ensures correct treatment of vertical dimension and units throughout.
#
# Inputs:
#   - hus, ua, va monthly merged/staked NetCDF files per YYYYMM
#   - level_bounds.nc: contains plev_bounds variable for vertical integration
#
# Output:
#   - IVT_HCLIM_<YYYYMM>.nc: IVT magnitude field in [kg m⁻¹ s⁻¹]
#
# Usage (called from wrapper):
#   ./IVT_HCLIM_Arctic_cdo.sh <GCM> <EXP> <MEMBER> <YYYYMM> <input_dir> <output_dir>
#
# Dependencies:
#   - CDO (Climate Data Operators)
#   - NCO tools: ncks, ncatted
#
# ================================================================

# === USAGE CHECK ===
if [ "$#" -ne 6 ]; then
  echo "Usage: $0 <GCM> <EXP> <MEMBER> <YYYYMM> <input_dir> <output_dir>"
  exit 1
fi

# === INPUTS FROM WRAPPER ===
GCM=$1         # e.g., CNRMESM21
EXP=$2         # e.g., hist or ssp370
MEMBER=$3      # e.g., r1i1p1f2
YYYYMM=$4      # e.g., 201412
INPUT_DIR=$5   # merged monthly variable files
OUTPUT_DIR=$6  # final IVT output


# Constants
g=9.81

# === FILES ===
hus_file="${INPUT_DIR}/hus_${YYYYMM}_stacked_with_level.nc"
ua_file="${INPUT_DIR}/ua_${YYYYMM}_stacked_with_level.nc"
va_file="${INPUT_DIR}/va_${YYYYMM}_stacked_with_level.nc"

mkdir -p "$OUTPUT_DIR"

echo "Calculating IVT components for $month..."

# === STEP 1: Multiply q*u and q*v ===
cdo mul "$hus_file" "$ua_file" "${OUTPUT_DIR}/q_u_${YYYYMM}.nc"
cdo mul "$hus_file" "$va_file" "${OUTPUT_DIR}/q_v_${YYYYMM}.nc"

# === STEP 2: Append bounds variable and attribute ===
ncks -A -v plev_bounds "${INPUT_DIR}/../work/level_bounds.nc" "${OUTPUT_DIR}/q_u_${YYYYMM}.nc"
ncks -A -v plev_bounds "${INPUT_DIR}/../work/level_bounds.nc" "${OUTPUT_DIR}/q_v_${YYYYMM}.nc"

ncatted -O -a bounds,plev,o,c,'plev_bounds' "${OUTPUT_DIR}/q_u_${YYYYMM}.nc"
ncatted -O -a bounds,plev,o,c,'plev_bounds' "${OUTPUT_DIR}/q_v_${YYYYMM}.nc"

# === STEP 3: Vertical integration ===
cdo vertint "${OUTPUT_DIR}/q_u_${YYYYMM}.nc" "${OUTPUT_DIR}/ivt_x_${YYYYMM}_Pa.nc"
cdo vertint "${OUTPUT_DIR}/q_v_${YYYYMM}.nc" "${OUTPUT_DIR}/ivt_y_${YYYYMM}_Pa.nc"

# === STEP 4: Divide by gravity ===
cdo divc,$g "${OUTPUT_DIR}/ivt_x_${YYYYMM}_Pa.nc" "${OUTPUT_DIR}/ivt_x_${YYYYMM}.nc"
cdo divc,$g "${OUTPUT_DIR}/ivt_y_${YYYYMM}_Pa.nc" "${OUTPUT_DIR}/ivt_y_${YYYYMM}.nc"

# === STEP 5: Compute IVT magnitude ===
cdo sqr "${OUTPUT_DIR}/ivt_x_${YYYYMM}.nc" "${OUTPUT_DIR}/ivt_x_sq_${YYYYMM}.nc"
cdo sqr "${OUTPUT_DIR}/ivt_y_${YYYYMM}.nc" "${OUTPUT_DIR}/ivt_y_sq_${YYYYMM}.nc"
cdo add "${OUTPUT_DIR}/ivt_x_sq_${YYYYMM}.nc" "${OUTPUT_DIR}/ivt_y_sq_${YYYYMM}.nc" "${OUTPUT_DIR}/ivt_sum_sq_${YYYYMM}.nc"
cdo sqrt "${OUTPUT_DIR}/ivt_sum_sq_${YYYYMM}.nc" "${OUTPUT_DIR}/IVT_HCLIM_${YYYYMM}_tmp.nc"

# === STEP 6: Rename variable to IVT ===
cdo chname,hus,IVT "${OUTPUT_DIR}/IVT_HCLIM_${YYYYMM}_tmp.nc" "${OUTPUT_DIR}/IVT_HCLIM_${YYYYMM}.nc"

# === STEP 7: Cleanup ===
rm "${OUTPUT_DIR}/ivt_x_sq_${YYYYMM}.nc" "${OUTPUT_DIR}/ivt_y_sq_${YYYYMM}.nc" "${OUTPUT_DIR}/ivt_sum_sq_${YYYYMM}.nc"
rm "${OUTPUT_DIR}/q_u_${YYYYMM}.nc" "${OUTPUT_DIR}/q_v_${YYYYMM}.nc" "${OUTPUT_DIR}/ivt_x_${YYYYMM}_Pa.nc" "${OUTPUT_DIR}/ivt_y_${YYYYMM}_Pa.nc" "${OUTPUT_DIR}/IVT_HCLIM_${YYYYMM}_tmp.nc"

echo "✅ IVT for $YYYYMM saved to ${OUTPUT_DIR}/IVT_HCLIM_${YYYYMM}.nc"

