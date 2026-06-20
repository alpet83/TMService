# TMService
SNTP win32 client/server with smart time control.
Using system timer speed change for soft time correction.

File `IdSNTPX.pas` distributed under original licenses from http://www.indyproject.org/

---

## Overview

TMService is a background Windows application (x32) that maintains system clock accuracy by controlling the **rate** of the hardware timer via `SetSystemTimeAdjustment`, rather than jumping the clock forward or backward. It also runs a virtual high-precision PFC timer (TSC-based) for independent timekeeping.

Architecture:
- `TProfileTimer` (PFC timer) — high-precision virtual timer backed by the TSC counter.
- `SetSystemTimeAdjustment` — controls the speed of the Windows system clock.
- NTP client (Indy `TIdSNTP`) — synchronises with an NTP server pool.
- Built-in SNTP server — serves time to other hosts on the network.

---

## Configuration file

Looked up at `c:\Apps\conf\tmservice.conf` by default. Format: INI.

---

### Section `[config]`

#### NTP synchronisation

| Parameter | Type | Example | Description |
|---|---|---|---|
| `NTPServers` | string | `0.pool.ntp.org;time.windows.com` | Semicolon-separated list of NTP servers. Queried in turn; results are averaged with variance-weighted selection. |
| `NTPQueryRate` | int (min) | `1` | Initial NTP poll interval in minutes. May be adjusted automatically via `AutoQueryRate`. |
| `MinQueryRate` | int (min) | `2` | Minimum poll interval (lower bound for auto-regulation). |
| `MaxQueryRate` | int (min) | `60` | Maximum poll interval (upper bound for auto-regulation). |
| `AutoQueryRate` | string | `15@30,50@10,250@5` | Auto-regulation of the NTP poll interval based on current PFC timer divergence (ms/h). Format: `threshold_ms/h@interval_min,...`. Example: divergence < 15 ms/h → 30-minute interval; < 50 ms/h → 10 minutes, etc. Values are clamped to `[MinQueryRate, MaxQueryRate]`. |
| `VTSyncRate` | int (min) | `1` | Interval (minutes) for measuring the difference between the system clock and the PFC timer via `CompareVirtualTimer`. Recommended: `1`. |
| `SyncOffset` | int (min) | `1` | Random offset of the NTP poll cycle from the top of the hour (flood protection when many clients start simultaneously). |
| `SyncTimeout` | int (sec) | `25` | Timeout for a single NTP request. |
| `TermTimeout` | int (sec) | `2` | Forced termination timeout for the sync thread. |
| `CheckDelay` | int (ms) | `500` | Delay before the NTP request inside the sync loop. |

#### Hardware clock speed adjustment

| Parameter | Type | Example | Description |
|---|---|---|---|
| `HWClockAdjust` | int (ms/h) | `1` | Initial `st_adjust` value — desired clock speed offset in **milliseconds per hour** (positive = speed up, negative = slow down). `0` disables hardware adjustment. |
| `MinClockAdjust` | int (ms/h) | `-53000` | Lower bound for `st_adjust`. Limits maximum clock slowdown. Windows allows approximately ±1.5% of the base frequency (~±54 000 ms/h at a 15.625 ms base tick). |
| `MaxClockAdjust` | int (ms/h) | `53700` | Upper bound for `st_adjust`. |
| `HWAdjustByCPULoad` | float | `0` | Correction coefficient for `st_adjust` based on CPU load: `st_dev = st_adjust + sta_cpu_ratio * avg_cpu_load`. Useful when the hardware timer is sensitive to processor heat. |
| `PWMRange` | int (ms) | `50000` | PWM period for clock speed regulation in ms. The PWM alternates +25 ms/h and −25 ms/h corrections to achieve fractional `st_adjust` values. |
| `PWMSplit` | int (ms) | `25000` | Initial position of the PWM "split point" (time spent in the "accelerate" phase). |
| `HWClockRes` | int (100 ns) | `0` | Desired Windows system timer resolution in units of 100 ns (passed to `NtSetTimerResolution`). Lower value = more frequent ticks = higher `Sleep` and timestamp precision. `0` = do not change. Typical values: `156250` (15.625 ms, default), `10000` (1 ms). |

#### PFC timer (virtual high-precision timer)

| Parameter | Type | Example | Description |
|---|---|---|---|
| `PFCAdjust` | float (ms/h) | `-114.326` | Speed correction for the PFC timer in ms/h. A negative value means the timer runs slightly slower than the TSC (compensates for crystal drift). Saved automatically when `PFCAdjustSave=1`. |
| `PFCAdjustSave` | bool | `1` | Automatically save the corrected `PFCAdjust` value to the config file after each NTP sync. |
| `PFCAdjustLow` | float (ms/h) | `-2500` | Lower bound for automatic `PFCAdjust` correction. |
| `PFCAdjustHigh` | float (ms/h) | `+2500` | Upper bound for automatic `PFCAdjust` correction. |
| `PFCAdjustTreshold` | float (ms/h) | `5` | Activation threshold for `AutoPFCAdjust` — if PFC vs NTP divergence is below this value (ms/h), `pfc_adjust` is left unchanged. |
| `AutoPFCAdjust` | bool | `1` | Enable automatic `PFCAdjust` tuning based on NTP sync results. |
| `AproxFactor` | float | `0.87` | Approximation coefficient for hard clock corrections: `dta := dta * AproxFactor`. A value < 1 means partial correction per step (the remainder is smoothed out in subsequent cycles). |

#### Miscellaneous

| Parameter | Type | Example | Description |
|---|---|---|---|
| `BindIP` | string | `0.0.0.0` | IP address to bind the built-in SNTP server to. |
| `EnableNTPServer` | bool | `0` | Enable the built-in SNTP server (UDP 123). Serves time to other network hosts based on the PFC timer. |
| `EnableSyncStat` | bool | `0` | Log statistics of incoming SNTP requests (file `peersync*.log`). |
| `MyStratum` | int | `2` | Stratum of the built-in SNTP server. Typically = upstream stratum + 1. |
| `ShowConsole` | bool | `1` | Show the colour console with log output. |
| `ShowCPUStat` | bool | `0` | Log per-core CPU load statistics. |
| `ProcessPriority` | int | `32` | Process priority (WinAPI constants: `32` = NORMAL, `0x8000` = ABOVE_NORMAL, `128` = HIGH). |
| `StatsFile` | string | `c:\Apps\logs\timestats.csv` | Path to the CSV sync-statistics file. |
| `SaveDriftStat` | bool | `0` | Save a time series of VTT vs system clock divergence to `vtdrift.stat`. |
| `DriftLogFile` | string | *(empty)* | Path to the JSONL drift log file. If empty or absent, no log is written. One JSON line is appended per active sync minute with fields: `ts` (ISO-8601), `dta_ms`, `drift_msh`, `prv_dev_msh`, `st_adjust`, `pfc_adj_msh`, `ntp_ms`, `drift_ema_msh`, `sync_exp`, `ntp_sync`, `n_ticks`, `pwm_split`, `chk_elps_ms`. |
| `RefDtaEmaTC` | int | `2` | Time constant for the fast EMA of the speed correction signal (`ref_dta`). Applied only when `\|dta_ms\| < 1 ms` — smooths measurement noise in the fine-tuning zone. `0` or `1` = disabled; `2` = minimal smoothing (α=0.5); `5` = moderate (α=0.2). |
| `EmaSpeedMode` | int | `0` | Mode for updating the baseline clock speed EMA (`st_adjust_ema`): `0` = update at a drift extremum (transition from rising to falling); `1` = update only when the last 2 `\|dta_ms\|` measurements are both below `EmaSpeedThr`. |
| `EmaSpeedThr` | float (ms) | `0.8` | `\|dta_ms\|` threshold for `EmaSpeedMode=1`. The EMA is updated only if both recent drift measurements fell below this value. |
| `MicroCorr` | int (µs) | `-20` | Micro-correction passed to the NTP client (`IdSNTP1.mcs`). Compensates for systematic NTP packet processing delay. |
| `PFCTrust` | float | `1.0` | Trust coefficient for the PFC timer when no NTP sync has occurred. Scales the clock speed correction signal (`ref_dta`) in cycles where NTP servers were not queried. Range: `0.0`..`1.0`. See the section below. |

---

#### PFCTrust — anchor trust coefficient

The PFC timer (TSC-based) acts as an **anchor**: its readings determine how much the system clock is ahead or behind (`dta_ms`), and the speed correction (`ref_dta → st_adjust`) is derived from that. While the anchor is stable, this works well. But the anchor can be unstable:

- **Virtual machines** (Hyper-V, VMware, VirtualBox) — the hypervisor may pause the TSC during vCPU migration between cores or when the VM is suspended. TSC jumps look like system clock "drift" and cause spurious corrections.
- **CPU throttling** (SpeedStep, C-states) — on some platforms the TSC does not scale correctly with frequency changes, adding ±1–5 ms/min of noise.
- **Multi-socket systems** — TSCs on different sockets may diverge.

**The problem:** if the PFC timer itself drifts by ±3 ms/min, the measured `dta_ms` contains that noise. The correction algorithm treats it as a real system clock offset and adjusts `st_adjust` in response to anchor noise — causing `st_adjust` to oscillate and degrading actual time accuracy.

**Example with an unstable PFC:**

```
Actual system clock offset:          +2 ms/h
PFC timer noise:                    ±180 ms/h  (±3 ms/min)
Measured dta_ms (system vs PFC):    ±182 ms/h  — mostly noise
Without PFCTrust: algorithm chases noise, st_adjust ±5000 units
With PFCTrust=0.1: correction ×0.1, st_adjust ±500 — much calmer
```

**Parameter values:**

| `PFCTrust` | Behaviour |
|---|---|
| `1.0` | Full trust. Correction applied at full weight. Optimal when PFC is stable (physical machine, modern Intel/AMD). |
| `0.5` | Half correction without NTP. Good compromise for moderately unstable PFC (light throttling, some VMs). |
| `0.1`–`0.2` | Minimal correction without NTP. For severely unstable PFC (older Hyper-V, VirtualBox). |
| `0.0` | Clock speed correction frozen until the next NTP sync. Only NTP events move `st_adjust`. |

The parameter takes effect **only when no NTP query occurred in the current cycle** (`ntp_sync = false`). After an NTP sync the correction is always applied at full weight — at that point there is confirmation from an external reference.

---

### Section `[bounds]`

Thresholds that govern the correction algorithm's operating mode.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `min_dvg` | float (ms) | `~16` (timer resolution) | Minimum **absolute** system clock offset (ms) at which a hard time correction (`IndySetLocalTime`) is performed. Below this threshold — hardware speed adjustment only. |
| `max_dvg` | float (ms) | `1800000` (30 min) | Maximum offset allowed for a hard correction. If the offset exceeds this value it is treated as anomalous and is **not** corrected (requires manual intervention). |
| `max_rqt` | float (ms) | `1000` | Maximum acceptable NTP round-trip time (ms). Responses with RTT above this value are discarded as unreliable. |
| `min_date` | date | today | Minimum valid system date. If the system date is earlier, it is treated as an anomaly. |

#### How `min_dvg` / `max_dvg` interact with the algorithm

```
|dta_ms| < min_dvg              → sync_expected = FALSE → hw_adjust (speed tuning),
                                                           no hard correction
|dta_ms| in [min_dvg, max_dvg] → sync_expected = TRUE  → hard time correction
                                                           hw_adjust NOT performed (*)
|dta_ms| > max_dvg             → sync_expected = FALSE → hw_adjust, no hard correction
```

(*) — known limitation: when drift persistently exceeds `min_dvg`, hardware speed correction
is blocked and the program performs a hard time reset every minute instead of smooth
adjustment. Lowering `min_dvg` (e.g. to 50 ms) widens the hw_adjust operating zone.

---

## Bug fixes (history)

### v1.0.2.28+ — st_adjust instability under sustained drift

**Symptom:** when the system clock drifted by more than 125 ms (> min_dvg), the program performed a hard time reset every minute instead of gradual speed adjustment. After 20–30 minutes, ±300 ms oscillation with a 2-minute period would develop.

**Root cause A** (`prv_dev := 0` on `sync_expected`): each hard sync reset the previous drift rate history. The next `hw_adjust` call saw `prv_dev = 0` and doubled the correction from zero → `st_adjust` grew without bound → overshoot.

**Root cause B** (no step size limit): with a short `last_chk_elps` or after `prv_dev = 0`, the computed `ref_dta` could exceed 10 000 ms/h in a single iteration, guaranteeing overshoot.

**Fix A:** removed the `prv_dev := 0` reset — the value is now preserved across synchronisations.

**Fix B:** added a per-step limit: `if Abs(ref_dta) > 3000 then ref_dta := Sign(ref_dta) * 3000`.
