# EV AM EMI Project

**Implementation of an Adaptive EMI Suppression System for AM Radio in Electric Vehicles**
VVIT ECE Final-Year Project — Team A6 — Guide: Dr. K. Vijay Vardhan

## Complete MATLAB implementation

This folder includes the synthetic AM/EMI simulation and a separate
measured-source simulation path. The measured-source path reads the charger
voltage CSV, preprocesses it, and uses it as the source for a simulated
interference/reference pair. It does not model a live receiver or vehicle.

## How to run

1. Put all `.m` files in the same folder (or add the folder to your MATLAB path).
2. In MATLAB, `cd` into this folder.
3. Run the mandatory LMS pipeline:
   ```matlab
   main
   ```
4. Results are printed to the console, saved to `results/final_results_table.csv`
   and `results/final_results.mat`, and 14 figures are generated.

No toolboxes are required for `main.m` itself. It writes the numerical
results to `results/final_results_table.csv`, saves all workspace results
to `results/final_results.mat`, and writes the figures under `results/`.

To run the optional LMS/NLMS/RLS comparison after `main`, run
`compare_algorithms`. Simulink construction instructions are in
`simulink/README_SIMULINK.md`.

## Measured-source CSV demo

The loader is included as `load_emi_dataset.m`; you do not need to download a
separate loader. Put the supplied file at
`data/EVCharger_Lab_Data_V1.CSV`, then run this from the project root:

```matlab
cd('D:\emiproject\outputs\EV_AM_EMI_Project')
run_measured_demo
```

`preprocess_emi.m` applies a base-MATLAB high-pass FIR and discards its startup
transient. The demo uses the first 0.2 seconds at the dataset's 1 MHz sample
rate, generates a scaled 100 kHz AM carrier, calibrates source gain on the
training segment, tunes NLMS on validation data, and evaluates on the separate
test segment. It writes metrics, a log, a MAT file, and a figure under
`results/measured_source_simulation/`.

The recorded channel is single-phase charger voltage, not a paired AM receiver
interference/reference recording. An assumed coupling FIR creates the ANC
reference relationship, so results must be described as an offline
measured-source simulation. Attribute the dataset to SupraEMI (2021),
*Waveform Data -EVCharger_Lab* (Version V1), Zenodo,
https://doi.org/10.5281/zenodo.4431657.

## Documented simulation assumptions

These are choices made because the project document does not pin them down,
or because they simplify a real EV/RF system into something tractable in a
plain MATLAB simulation. All are called out in code comments at the point
they're used; summarized here for the report's "Limitations" section:

- **Fs = 100 kHz, fc = 10 kHz** — a scaled-down carrier frequency, not the
  real ~558 kHz AM band, chosen to keep simulation run time short while
  satisfying Nyquist. The signal-processing chain (AM modulation, EMI,
  LMS cancellation) is frequency-scale-independent, so the qualitative
  and relative (dB, %) results transfer to the real band; only the
  absolute Hz values would need to change for a literal RF-accurate model.
- **EMI model** (`generate_emi.m`) — a physically-motivated but still
  synthetic model: harmonics of an assumed 2 kHz switching frequency,
  amplitude-modulated by a start→accelerate→cruise envelope, passed
  through an assumed unknown 4-tap coupling filter, plus broadband
  Gaussian noise. This is NOT measured EV data.
- **LMS reference signal availability** — the adaptive filter is given a
  reference correlated with the EMI source (a "PWM-sync tap") but not a
  perfect copy of the interference actually riding on the AM signal; it
  must learn the unknown coupling path itself. In a real vehicle, this
  assumes access to the inverter's own switching reference — reasonable
  for an in-vehicle system, NOT for an external/aftermarket radio with no
  such tap. This limitation is intentional and should be stated in the
  report.
- **Noise-strength estimation** (`estimate_noise_strength.m`) — estimates
  noise power as (received power) − (analytically expected clean-signal
  power), where the expected clean power is computed from known
  transmitter parameters rather than measured from a clean reference a
  real receiver wouldn't have. This is a calibration-style assumption,
  not a claim that arbitrary EMI can be measured without any reference.
- **`mu_lms = 0.0015`** — tuned empirically for this specific EMI model,
  filter order, and signal levels. The commonly-quoted stability bound
  `mu < 2/(order*E[x^2])` is far looser than what actually converges here,
  because the reference spectrum is dominated by a few strong harmonics
  (large eigenvalue spread) rather than being flat/white. See the comment
  block in `lms_filter.m` and `main.m`.

## Validation status

This code was written and reviewed but **not executed inside MATLAB** by
the assistant that generated it (no MATLAB interpreter was available in
that environment). The exact algorithm was re-implemented in Python/NumPy
and run end-to-end as a correctness check (no NaN/Inf, correct EMI power
scaling, sane before/after SNR at all four levels) before delivery — see
the "VALIDATION NOTE" block at the bottom of `main.m` for the numbers that
check produced. **Your own MATLAB run is the authoritative result** — use
`results/final_results_table.csv`, not the numbers in that comment block,
in your report.

## Project structure

```
EV_AM_EMI_Project/
├── main.m                        - run this (mandatory LMS pipeline)
├── generate_am_signal.m          - Stage 1
├── generate_emi.m                - Stage 2
├── add_emi.m                     - Stage 3
├── estimate_noise_strength.m     - Stage 4
├── lms_filter.m                  - Stage 5 (mandatory)
├── nlms_filter.m                 - optional extension (Part 22)
├── rls_filter.m                  - optional extension (Part 22)
├── compare_algorithms.m          - optional LMS vs NLMS vs RLS comparison
├── calculate_snr.m               - Stage 6
├── calculate_mse.m               - Stage 6
├── calculate_noise_reduction.m   - Stage 6
├── calculate_fft.m               - spectrum helper
├── run_noise_conditions.m        - loops Stages 1-7 over 5/10/20/30%
├── plot_results.m                - Figures 1-14
├── results/                      - CSV/MAT outputs land here
└── simulink/                     - Simulink build instructions + helper scripts
    ├── README_SIMULINK.md        - exact block-by-block instructions + troubleshooting
    ├── simulink_init.m           - prepares workspace variables for the model
    ├── lms_matlab_function_block.m - code to paste into the MATLAB Function block
    └── postprocess_simulink_results.m - computes SNR/MSE from the Simulink run
```

## Notes

- Run `main.m` in MATLAB to regenerate the synthetic LMS results. Run `compare_algorithms.m` for the optional LMS/NLMS/RLS comparison.
- This package does not include a `.slx` model. `simulink/README_SIMULINK.md` gives block-by-block construction instructions and the MATLAB Function block code.