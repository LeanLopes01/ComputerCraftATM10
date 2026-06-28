# ATM10 Power Monitoring & Fusion Autopilot

A ComputerCraft (CC: Tweaked) dashboard for **All the Mods 10**, built on top of [Advanced Peripherals](https://docs.advanced-peripherals.de/) logic adapters. It monitors every power-generation block on the network from a single monitor, draws a live line graph of total output, tracks an Applied Energistics 2 fluix/chemical network for fusion fuel, and automatically tunes a Mekanism Fusion Reactor's injection rate.

## Files

| File | Purpose |
|---|---|
| `startup.lua` | Main dashboard. Runs automatically on boot (it's `startup.lua`) and never returns — it's an infinite monitoring loop. |
| `varredura.lua` | One-shot diagnostic: dumps every method exposed by `me_bridge_1` into `metodos_ae2.txt`. Run this first whenever the AE2/Mekanism mod versions change. |
| `teste_ae2.lua` | One-shot diagnostic: probes the ME Bridge's chemical/fluid API (`getChemicals`, `getChemical`, `getFluids`) and writes the raw results to `teste_ae2_output.txt`, so you can see the exact field names (`name`, `count`) and registry names (e.g. `mekanismgenerators:tritium`) the mod actually uses. |
| `teste_fusao.lua` | One-shot diagnostic: finds the fusion reactor logic adapter, lists every method it implements, then calls the relevant ones (production, injection rate, temperatures, fuel tanks) and writes the results to `teste_fusao_output.txt`. |
| `metodos_ae2.txt` / `teste_ae2_output.txt` / `teste_fusao_output.txt` | Generated output from the scripts above. Not meant to be edited by hand — delete and re-run the matching script to refresh them. |

## Why the diagnostic scripts exist

Advanced Peripherals' method names and return shapes have changed across mod versions (e.g. some builds expose `getProduction()` on the fusion adapter, others only `getProductionRate()`; percentage getters return a `0–1` fraction, not `0–100`). Rather than guessing, `varredura.lua`, `teste_ae2.lua` and `teste_fusao.lua` query the live peripherals with `peripheral.getMethods(...)` and `pcall(...)`, so you always know exactly which methods exist and what they return *for the modpack version you're actually running*. Re-run them after any modpack update before trusting `startup.lua`'s numbers.

## startup.lua — how it works

### Required peripherals

- A `monitor` (any size; the script auto-scales based on `monitor.getSize()`).
- `me_bridge_1` — Advanced Peripherals ME Bridge wired into the AE2 network, used to read stored Tritium/Deuterium.
- Any combination of:
  - `BigReactors-Reactor` / `BigReactors-Turbine` (Extreme Reactors fission setup)
  - `fissionReactorLogicAdapter` (Mekanism fission reactor)
  - `turbineValve` (Mekanism industrial turbine)
  - `fusionReactorLogicAdapter` (Mekanism fusion reactor)
  - `inductionPort` / `inductionMatrix` (Mekanism induction matrix, used as the base's energy buffer)

Peripherals are discovered automatically every loop via `peripheral.getNames()` / `peripheral.getType()` — nothing needs to be wired to a fixed side, as long as everything is on the wired/modem network.

### Main loop (every 10 seconds)

1. **Clear and redraw the frame.** A vertical divider splits the monitor: ~58% left for the device list, ~42% right for the trend graph, energy-matrix status and AE2 fuel readout.
2. **Read AE2 fuel.** Calls `me_bridge_1.getChemical({name = "mekanismgenerators:tritium"})` and the deuterium equivalent, reading the `count` field. The per-tick production/consumption rate (`taxa_t` / `taxa_d`) is derived by comparing against the previous loop's reading, divided by the 10-second sleep interval.
3. **Walk every peripheral** and dispatch by type:
   - **Extreme Reactor (fission):** temperature bar, stored energy, fuel %, active state.
   - **Extreme Turbine:** energy-produced-per-tick bar, rotor RPM, fluid flow rate.
   - **Mek Fission (`fissionReactorLogicAdapter`):** temperature bar, burn rate vs max, damage %, fuel %, coolant %. If damage exceeds `limite_dano_reator` (80%) or temperature exceeds `limite_temp_fissao`, it calls `device.scram()` automatically and flags it on screen.
   - **Mek Turbine (`turbineValve`):** production bar (converted Joules → FE), flow rate vs max, steam %.
   - **Mek Fusion (`fusionReactorLogicAdapter`):** production bar, then runs the **autopilot**:
     - If Tritium or Deuterium drops below `min_reserva_combustivel`, injection rate is forced down to the minimum (2 mB/t).
     - If either fuel's net rate is negative (being consumed faster than produced), injection rate is decreased by 2.
     - If both fuels are positive and above the reserve threshold, injection rate is increased by 2, up to `limite_max_injection` (50 mB/t).
     - Also displays plasma/case temperature and tritium/deuterium tank %.
   - **Induction Matrix:** tracked separately (not drawn inline) — used later for the storage panel.
4. **Right-hand panel:**
   - A **line graph** (not a filled bar chart) of total base generation over time, redrawn from a rolling history buffer sized to the panel's width.
   - The induction matrix's current charge %, stored FE, FE needed to fill, and a capacity bar.
   - Tritium/Deuterium current amounts plus their live per-tick rate (`+X/t` or `-X/t`).
5. Sleep 10 seconds and repeat forever.

### Key conversion/formatting helpers

- `jToFE(joules)` — Mekanism energy (Joules) to Forge Energy: `J * 0.4`.
- `formatNum(val)` — compacts large numbers into `k`/`M`/`G`/`T` suffixes for display.
- `getAE2Fuel(me_bridge, name)` — wraps the `getChemical`/`getFluid` lookup with safe fallbacks so a missing method or unknown chemical never crashes the loop.

### Known modpack-version sensitive bits

These are the values most likely to drift if Mekanism/Advanced Peripherals is updated — re-verify with the diagnostic scripts above if numbers look wrong:

- Chemical registry names (`mekanismgenerators:tritium` / `mekanismgenerators:deuterium`).
- The chemical/fluid result's amount field (`count`, confirmed for this version — earlier versions used `amount`).
- `fusionReactorLogicAdapter.getProductionRate()` (some versions expose `getProduction()` instead).
- All percentage getters (`getDamagePercent`, `get*FilledPercentage`) return a `0–1` fraction, not `0–100`.

<img width="2560" height="1440" alt="Image" src="https://github.com/user-attachments/assets/c6d3ef07-4259-4297-9bf9-dbe1d26437c7" />
<img width="2560" height="1440" alt="Image" src="https://github.com/user-attachments/assets/51df5d88-2e55-44ed-a350-a64af5108f93" />
<img width="2560" height="1440" alt="Image" src="https://github.com/user-attachments/assets/bdfad215-3eb0-43c7-80db-d7a413729ddc" />
