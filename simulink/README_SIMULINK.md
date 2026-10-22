# Simulink Implementation — EV AM EMI Suppression

No `.slx` file is included here (it can't be generated without running
Simulink). What follows is exact, block-by-block instructions to build
it yourself in **~10-15 minutes**, plus the code that goes inside the
one custom block you need. This matches the architecture required by
the project spec:

```
AM Signal Generation -> EV EMI Generation -> Addition of Noise ->
Noisy AM Signal -> Noise-Strength Estimation -> LMS Adaptive Filter ->
Filtered AM Signal -> SNR/MSE Analysis -> Performance Comparison
```

## Step 0 — Prepare workspace variables

1. In MATLAB, `cd` into `EV_AM_EMI_Project/simulink/`.
2. Run `simulink_init.m`. This creates `s_am_ws`, `refEmi_ws`,
   `noisyAM_ws` (each an `[time, data]` two-column matrix), plus
   scalars `simFilterOrder`, `simMuLms`, `simStopTime`, `simSampleTime`,
   and prints the noise-strength estimate for the chosen level.

## Step 1 — New model

`File -> New -> Simulink Model` (blank, not a template). Save as
`EV_EMI_model.slx` in this `simulink/` folder. Set:
`Modeling` tab -> `Model Settings` -> **Solver**: Fixed-step,
**Fixed-step size** = `simSampleTime` (i.e. `1/Fs` = `1e-5`),
**Stop time** = `simStopTime` (i.e. `2`).

## Step 2 — Blocks to place (Simulink base library only — no toolbox needed)

| # | Block | Library | Purpose |
|---|---|---|---|
| 1 | From Workspace | Simulink → Sources | reads `noisyAM_ws` |
| 2 | From Workspace | Simulink → Sources | reads `refEmi_ws` |
| 3 | From Workspace | Simulink → Sources | reads `s_am_ws` (for the scope/comparison only, not fed into the filter) |
| 4 | MATLAB Function | Simulink → User-Defined Functions | runs the LMS algorithm |
| 5 | Constant (x2) | Simulink → Sources | `order` = `simFilterOrder`, `mu` = `simMuLms`, wired into the MATLAB Function block's parameter inputs |
| 6 | Display | Simulink → Sinks | shows the noise-strength estimate (see Step 4) |
| 7 | Scope | Simulink → Sinks | set to 2 input ports, shows noisy vs. filtered |
| 8 | To Workspace (x2) | Simulink → Sinks | logs `noisyAM` and the filtered output |

## Step 3 — Wiring

1. **From Workspace #1** (`noisyAM_ws`) → into **MATLAB Function** input `d`, and also → into **Scope** input 1, and also → into **To Workspace #1** (rename variable to `noisyAM_log`).
2. **From Workspace #2** (`refEmi_ws`) → into **MATLAB Function** input `x_ref`.
3. **Constant** blocks → into **MATLAB Function** inputs `order` and `mu`.
4. **MATLAB Function** output `e` → into **Scope** input 2, and also → into **To Workspace #2** (rename variable to `filtered_log`).
5. **From Workspace #3** (`s_am_ws`) → optionally into a 3rd Scope input, for a visual "clean vs noisy vs filtered" comparison (Scope → block parameters → Number of input ports = 3).

This wiring gives you exactly:
`Noisy AM Signal -> LMS Adaptive Filter -> Filtered AM Signal`,
with the "Addition of Noise" step already done in `simulink_init.m`
(equivalent to `add_emi.m` — same function, just run before the model
instead of as a Simulink Sum block). **If your report specifically
requires an explicit in-model Sum block:** instead of a single "From
Workspace" for `noisyAM_ws`, add two From Workspace blocks reading
`s_am_ws` and a new `emi_ws` variable (add `emi_ws = [t, emi_t];` to
`simulink_init.m`), and feed both into a `Sum` block (Simulink →
Math Operations, icon shape `++`) whose output replaces From Workspace #1
above.

## Step 4 — MATLAB Function block (Stage 5: LMS)

Double-click the MATLAB Function block and replace its contents with
the code in `lms_matlab_function_block.m` (same folder). Set the block's
input/output signature to match:
```matlab
function e = lms_matlab_function_block(x_ref, d, order, mu)
```
This is the exact same update equations as `lms_filter.m`
(`e(n)=d(n)-y(n)`, `w(n+1)=w(n)+mu*e(n)*x(n)`), rewritten with
`persistent w xbuf` because a MATLAB Function block executes once per
simulation sample, not once for a whole vector — persistent variables
are how the filter keeps its state (coefficients + input buffer) across
time steps.

## Step 5 — Noise-strength estimation (Stage 4)

`estimate_noise_strength.m` computes a single number over the WHOLE
signal (a power ratio) — it is not naturally a per-sample streaming
operation, and the project spec does not require it to be. The
straightforward, documented choice used here: it is computed once by
`simulink_init.m` (identical function, identical result to the MATLAB
pipeline) and displayed via the **Display** block, fed by a **Constant**
block wired to `estNoisePercent` in the base workspace (Constant block
parameter: `estNoisePercent`). This keeps Stage 4 visibly present in the
model without inventing a fake streaming-power block that Stage 4 in the
project document does not actually call for.

## Step 6 — To Workspace block settings

For both **To Workspace** blocks: `Save format` = **Array** (not
Structure/Timeseries — this makes `postprocess_simulink_results.m`
simpler). Set **Sample time** = `-1` (inherited).

## Step 7 — Run

Click **Run**. Then in MATLAB: run `postprocess_simulink_results.m`
(same folder) — it computes SNR/MSE/noise-reduction from the logged
signals using the exact same `calculate_snr.m` / `calculate_mse.m` /
`calculate_noise_reduction.m` functions as `main.m`, so Simulink and
MATLAB results are directly comparable (Stage 6/7: Performance
Comparison).

## To reproduce all four EMI levels in Simulink

Edit `emiLevelPercent` in `simulink_init.m` (5 / 10 / 20 / 30), re-run
it, re-run the model, re-run `postprocess_simulink_results.m`, and note
the printed numbers. (The model itself does not need to change between
levels — only the workspace variables it reads.)

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Undefined function 'generate_am_signal'` when running `simulink_init.m` | MATLAB's current folder isn't `simulink/`, or the parent project folder isn't on the path | `cd` into `simulink/` first; `simulink_init.m` already does `addpath('..')`, but only after it starts — make sure you're not running it from somewhere else entirely |
| From Workspace block errors about data format | It expects an `[time, data]` 2-column matrix (what `simulink_init.m` provides) or a `timeseries`/`Simulink.SimulationData.Dataset` — mixing formats across blocks causes mismatched output dimensions | Keep all three `From Workspace` blocks using the same 2-column matrix format |
| MATLAB Function block errors: `Inputs to MATLAB Function blocks must be...` | `order` fed in as a `Constant` block outputs `double` by default, which is fine, but if you typed a non-scalar or the Constant block's **Sample time** is `0` (continuous) while the model is fixed-step, you can get a type/rate mismatch | Set Constant blocks' **Sample time** to `-1` (inherited) or `simSampleTime` |
| Simulation runs but `e` output looks like pure noise / doesn't cancel anything | `mu` wired to the wrong value, or `order` doesn't match `simFilterOrder` (e.g. left at a MATLAB Function block default) | Double-check the Constant block values against `simMuLms`/`simFilterOrder` printed by `simulink_init.m` |
| `e` blows up to very large values / Inf | Step size too high for this reference signal's coloured spectrum (see `lms_filter.m` comments — the practical stable range is much tighter than the textbook bound) | Confirm `mu` = `0.0015` exactly (or whatever you tuned in MATLAB first) |
| Algebraic loop error | Only happens if you wire a block's output back into its own input path (e.g. accidentally feeding `e` back into `d`) | Check wiring against Step 3 above — there is no feedback loop in this model, only feed-forward |
| `To Workspace` variables not appearing after Run | Save format left as default without checking, or variable name collides with something already in the workspace | Explicitly rename each To Workspace block's variable (`noisyAM_log`, `filtered_log`) and set Save format = Array as in Step 6 |
| `postprocess_simulink_results.m` errors "Missing variables" | Ran it before running the Simulink model, or before `simulink_init.m` | Run in order: `simulink_init.m` → open+run the model → `postprocess_simulink_results.m` |
