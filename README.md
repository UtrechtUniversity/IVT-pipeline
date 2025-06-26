# IVT Calculation Pipeline

## Purpose

This pipeline calculates **Integrated Vapor Transport (IVT)** from 3D atmospheric reanalysis or climate model output. IVT is a key quantity in identifying **atmospheric rivers** and studying **moisture transport**, especially over polar and mid-latitude regions.

The physical calculation follows this formula:

> **IVT** = (1/g) · ∫ q · **V** · dp

Where:
- `q` is specific humidity
- `V` is the horizontal wind vector (`u`, `v`)
- `p` is pressure
- `g` is gravitational acceleration (9.81 m/s²)

The pipeline computes both components (IVTₓ and IVTᵧ) and the total magnitude.

---

## Required Input

You will need monthly-mean NetCDF files **with pressure level dimensions**, containing:
- `hus` — specific humidity
- `ua` — zonal wind
- `va` — meridional wind

Each variable should be vertically stacked and named following the format:
hus_YYYYMM_stacked_with_level.nc
ua_YYYYMM_stacked_with_level.nc
va_YYYYMM_stacked_with_level.nc


These must be stored in the input directory defined in the wrapper script.

---

## Output

For each month, the pipeline produces:
- `IVT_HCLIM_YYYYMM.nc` — the final IVT magnitude file
- Intermediate products (automatically cleaned up):
  - `q_u_*.nc`, `q_v_*.nc`
  - `ivt_x_*.nc`, `ivt_y_*.nc`
  - Temporary squared and summed fields

Output filenames follow this pattern and are stored in the output directory:
IVT_HCLIM_<YYYYMM>.nc

---

## How to Run

### 1. Clone the repository
```bash
git clone https://github.com/UtrechtUniversity/ivt-pipeline.git
cd ivt-pipeline
```

### 2. Make script executable

`chmod +x run_ivt_pipeline.sh IVT_HCLIM_Arctic_cdo.sh merge_verticallayers_allvar_cdo.sh`

### 3. Run the pipeline

`./run_ivt_pipeline.sh`

You will be prompted to enter:
    GCM name (e.g., CNRMESM21)
    Start and end year/month

The script will show you a summary of the months and model being processed before continuing.

## Notes for Adapting to Your Environment

### Python Path
If your HPC environment does not have python available by default, edit the line in run_ivt_pipeline.sh where level_bounds.nc is created:
You can determine your Python path using:

`which python`

Or comment out the python line if you already have level_bounds.nc prepared.

### Level Bounds

The pipeline uses a helper script (scripts/create_level_bounds.py) to generate the required plev_bounds variable used in vertical integration. This is automatically handled, but you can manually generate it if needed.

## Dependencies

This pipeline depends on:
    CDO (Climate Data Operators)
    NCO (NetCDF Operators)
    Python 3 with numpy and netCDF4
