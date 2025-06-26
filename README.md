# IVT Calculation Pipeline

## 🔬 Project Scope

This IVT (Integrated Vapor Transport) calculation pipeline was originally developed for use with **HCLIM model output** from the **PolarRES project**. Specifically, it processes monthly-merged NetCDF files containing specific humidity (`hus`) and horizontal winds (`ua`, `va`) on pressure levels.

While the pipeline is tailored for the PolarRES data structure and naming conventions, it can be **adapted for similar climate model output** from other sources. Users working with different datasets should review the wrapper script and ensure that:

- Input file names follow the required naming scheme (e.g., `hus_YYYYMM_stacked_with_level.nc`)
- Pressure level values and units match the defaults used in the vertical integration step
- The directory structure (`INPUT_DIR`, `OUTPUT_DIR`) is set accordingly

The script has been tested on high-performance computing (HPC) environments using **CDO**, **NCO**, and **Python**. Minor edits may be needed to adapt it to other systems or data conventions.


## Purpose

This pipeline calculates **Integrated Vapor Transport (IVT)** from 3D climate model output. IVT is a key quantity in identifying **atmospheric rivers** and studying **moisture transport**, especially over polar and mid-latitude regions.

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

You will need 6 hourly data in monthly NetCDF files containing:
- `hus` — specific humidity
- `ua` — zonal wind
- `va` — meridional wind

Each variable is available as one vertical level per file and will be merged (stacked) automatically.


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
