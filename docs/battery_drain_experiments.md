# macOS battery drain investigation and experiment log

Status: **ongoing**  
Timezone for every wall-clock timestamp: **Asia/Seoul (KST, UTC+09:00)**  
Investigation started: 2026-08-25  
Last durable update: 2026-08-28, immediately before a planned reboot

This is the durable source of truth for the battery investigation. Append new
experiments; do not silently replace old measurements when the interpretation
changes. The conclusions formerly held only in temporary audit directories have
been copied here because `/tmp` may be cleared by reboot.

## Current conclusion

The battery regression is real, and it is not just a nonlinear menu-bar battery
percentage:

- The first retained high-drain run starts on the morning of 2026-07-06.
- Around that change, duration-weighted drain rose from 28.9 to 43.8 percentage
  points per hour, while independently calculated pack power rose from 14.6 to
  22.1 W. The approximately 51% rise in physical watts confirms a real load
  increase.
- The change coincides with the AeroSpace/SketchyBar migration day, but the first
  high run began before the recorded AeroSpace config link, SketchyBar config
  link/service launch, and implementation commits. Retained data therefore cannot
  assign the exact cause to either app.
- The 2026-08-26 tests show that neither AeroSpace nor SketchyBar is individually
  necessary for high draw. With AeroSpace stopped and SketchyBar running, the Mac
  averaged 25.16 W. With SketchyBar stopped and AeroSpace running, it averaged
  22.05 W and drifted from 20.53 W to 25.32 W without changing that app state.
- Stopping Hammerspoon while SketchyBar and its helpers remained stopped reduced a
  matched 41-minute window from 19.51 to 18.09 W. That 1.42 W difference belongs
  to a broad, changing workload bundle, not demonstrably to the Hammerspoon app:
  Apple's Hammerspoon-labelled coalition also contained shells, tmux, Codex,
  Neovim, Node, Python, bun, and sampling processes.
- The battery itself is degraded: 77% maximum capacity, 800 cycles, and **Service
  Recommended** on 2026-08-28. Replacement is warranted independently. This
  shortens runtime but does not explain the sudden July 6 physical-power step.

The most defensible working model is a mixed regression: workload and/or display
rendering is a large variable component; the desktop stack may add overhead; and
the degraded, manually capped battery turns the watt increase into very short
wall-clock runtime. A reboot followed by counterbalanced measurements is the next
step.

## Battery and machine context

| Observation                     | Value                                                                                                    |
| ------------------------------- | -------------------------------------------------------------------------------------------------------- |
| macOS                           | 26.5.2 (build 25F84)                                                                                     |
| Battery health on 2026-08-25    | 77% maximum capacity, 795 cycles, Service Recommended                                                    |
| Battery health on 2026-08-28    | 77% maximum capacity, 800 cycles, Service Recommended                                                    |
| Manual charge limit             | 80%                                                                                                      |
| Displays during the latest work | Built-in Retina Display plus two LG ULTRAFINE displays                                                   |
| Relevant versions               | AeroSpace 0.21.1-Beta; SketchyBar 2.24.0; Hammerspoon 1.1.1; tmux 3.7c; WezTerm 20251111-071056-118802c2 |

At a charge limit of 80%, a battery with 77% of original capacity starts with at
most roughly `0.80 * 0.77 = 61.6%` of its original energy. The charge cap does not
make the displayed percentage fall faster, but it reduces usable time from the
unplug point. For example, the first controlled run's 51.3 percentage points/hour
would imply about 1.95 hours for 100 displayed points but only about 1.56 hours
from 80% to 0%, if the rate remained constant. That extrapolation is descriptive,
not a safe runtime forecast.

## Historical onset

### Change-point result

The long-history source was
`/var/db/Battery/BDC/BDC_SBC_version3.0_*.csv`. The audit reconstructed 456
high-confidence 2026 discharge runs using these rules:

- `IsCharging=0`;
- gaps no longer than seven minutes;
- monotonically falling `CurrentCapacity`;
- at least ten percentage points lost; and
- at least ten minutes long.

Direct pack watts were calculated independently of the UI percentage as:

```text
abs(Amperage_mA) / 1000 *
  (CellVoltage0_mV + CellVoltage1_mV + CellVoltage2_mV) / 1000
```

| Period                        | Runs | Median drain | Duration-weighted drain | Duration-weighted direct power |
| ----------------------------- | ---: | -----------: | ----------------------: | -----------------------------: |
| 2026-01-01 through 2026-06-24 |  328 |    29.2 pp/h |               30.5 pp/h |            16.3 W over 420.0 h |
| 2026-06-25 through 2026-07-05 |   19 |    30.0 pp/h |               28.9 pp/h |                         14.6 W |
| 2026-07-06 through 2026-07-15 |   27 |    42.9 pp/h |               43.8 pp/h |                         22.1 W |
| 2026-07-06 through 2026-08-25 |  109 |    42.6 pp/h |               42.7 pp/h |            21.2 W over 128.6 h |

The near-onset comparison is a **+52%** rise in percentage drain and a **+51%**
rise in direct watts. Mean current rose from 1.27 to 1.96 A. A blind local-window
scan chose July 6 as the strongest rise between June 20 and July 20 for every
tested window:

| Window  | Before/after drain | Before/after direct power |
| ------- | -----------------: | ------------------------: |
| 5 days  |  30.0 -> 44.0 pp/h |            15.0 -> 22.1 W |
| 10 days |  28.7 -> 43.8 pp/h |            14.6 -> 22.1 W |
| 14 days |  29.9 -> 42.2 pp/h |            15.1 -> 21.4 W |

`AppleRawMaxCapacity` changed by only -1.48% across the boundary (4607.9 to
4539.5 mAh), far too little to explain a roughly 51% watt increase.

### Exact boundary that retained data supports

- Last observed pre-regression-style run: 2026-07-05 approximately
  10:26-12:51 KST, 98% to 41%, 23.6 pp/h, 12.1 W. Its raw BDC timestamps are
  01:01:40-03:26:40.
- First observed fast run: start anchored by file creation at
  **2026-07-06 10:05:50 KST**, ending approximately 12:00:50 KST, 98% to 16%,
  42.8 pp/h, 21.3 W. Its raw BDC timestamps are 00:41:40-02:36:40.
- A 20-hour 5-minute sampling gap follows the July 5 file. The actual change
  happened after the last July 5 observation and no later than 10:05:50 on July 6. `10:05:50` is the first observed onset, not an exact causal instant.

Retained BDC gaps also exist on February 12-23, June 4-14, July 3-5, July 25-26,
August 7-10, and August 15-18.

### Migration chronology and causal limit

| Time (KST)                   | Recorded event                                                                                     |
| ---------------------------- | -------------------------------------------------------------------------------------------------- |
| 2026-07-01 18:45             | AeroSpace application installed                                                                    |
| 2026-07-06 10:05:50          | First observed high-drain run begins                                                               |
| 2026-07-06 10:53:25          | `~/.config/aerospace` symlink created                                                              |
| 2026-07-06 11:42             | Commit `b9e6803`: initial integration design                                                       |
| 2026-07-06 11:46:50-11:46:51 | `~/.config/sketchybar` symlink and first recorded service log                                      |
| 2026-07-06 12:00:50          | Approximate end of first high-drain run                                                            |
| 2026-07-06 15:18:56          | First AeroSpace-related repository commit found in the audit                                       |
| 2026-07-06 15:50             | Commit `f2c9e78`: first committed SketchyBar baseline; commit notes it existed uncommitted earlier |
| 2026-07-06 15:54             | Commit `9e788b8`: per-monitor workspace grouping                                                   |
| 2026-07-06 16:20             | Commit `a553bc7`: CPU/GPU/RAM polling                                                              |
| 2026-07-06 17:03             | Commit `4221f7d`: current AeroSpace config first enters history                                    |
| 2026-07-06 17:05             | Commit `14fec92`: AeroSpace and SketchyBar symlink setup committed                                 |

Splitting the first July 6 run at the filesystem evidence does not reveal an
activation jump:

| Slice                             |                         Observed drain |               Direct power |
| --------------------------------- | -------------------------------------: | -------------------------: |
| Before AeroSpace config link      |  98% to 68% in about 45 min; 40.0 pp/h |                     19.7 W |
| After AeroSpace config link       |  64% to 16% in about 65 min; 44.3 pp/h |                     22.5 W |
| Before recorded SketchyBar launch | 98% to 26% in about 100 min; 43.2 pp/h |                     21.7 W |
| After recorded SketchyBar launch  |  22% to 16% in about 10 min; 36.0 pp/h | 18.9 W; only three samples |

The first run was already fast for roughly 47 minutes before the AeroSpace link
and roughly 101 minutes before the SketchyBar link/service record. AeroSpace may
have been launched manually after its July 1 installation, and uncommitted files
may have existed earlier; there is no historical process list to confirm either.
The evidence supports migration-era correlation, not a precise app-level cause.

## Evidence sources and caveats

| Source                                                                    | Useful coverage                      | Use and limitation                                                                                                                         |
| ------------------------------------------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Battery Data Collection controller CSVs                                   | January-August 2026 with listed gaps | Best retained onset history and independent current-times-voltage power. Raw clocks required reconstruction/file-time anchoring.           |
| `/var/db/powerlog/Library/BatteryLife/CurrentPowerlog.PLSQL` and archives | High-resolution recent intervals     | Primary whole-system `SystemPower`, direct instantaneous V x I, UI level, and partial coalition attribution. The current database rotates. |
| `pmset -g log`                                                            | Only August 18-25 when audited       | First complete retained August 19 run was already fast; no onset baseline.                                                                 |
| `/var/log/powermanagement/*.asl`                                          | Only August 11-25 when audited       | First awake run, August 11 09:01-10:31, was 80% to 37% (28.52 pp/h); no pre-migration baseline.                                            |
| BatteryLife SQLite UI history                                             | July 21 onward when audited          | First retained July 21 run was high; too late to locate onset.                                                                             |
| Git, symlink birth times, and service logs                                | Exact recorded configuration events  | Establish what was recorded, not whether an app or uncommitted config ran earlier.                                                         |

Percentage points per hour are useful for human runtime but are quantized,
smoothed, capacity-dependent, and visibly nonuniform. The primary endpoint for a
new controlled experiment is time-weighted `SystemPower` from
`PLBatteryAgent_EventBackward_Battery`, filtered to `ExternalConnected=0`. The
secondary electrical check is:

```text
abs(InstantAmperage_mA) * Voltage_mV / 1,000,000 = watts
```

For every reported watt mean, record the boundary convention. The August 26
`SystemPower` figures below are preserved from the previously finalized audit,
but its exact original estimator was not retained. Re-querying the current
database shows that no single obvious convention reproduces every phase exactly:
the full afternoon run is roughly 22.0-22.4 W depending on interpolation, and its
short second phase is roughly 24.8-26.2 W. This sensitivity does not change the
qualitative conclusions, but these legacy figures must not be mixed with future
figures as if their estimators were identical. The reproducible query later in
this document defines one convention for all new trials.

Do not compare an enclosing discharge session to an exact experiment marker.

Coalition energy is diagnostic only. In a sampled run, coalition rows explained
about 24% of physical system power. They are responsibility/launch groupings, not
exclusive process meters, and their energy fields must be overlap-prorated before
comparison.

## Controlled experiments on 2026-08-26

Application states were checked at the boundaries. `pp/h` means displayed
percentage points per hour.

| Test | Exact interval             | AeroSpace                    | SketchyBar + helpers               | Hammerspoon | UI change                                                   |      Drain | Finalized SystemPower | PowerLog direct sample mean |            BDC direct sample mean |
| ---- | -------------------------- | ---------------------------- | ---------------------------------- | ----------- | ----------------------------------------------------------- | ---------: | --------------------: | --------------------------: | --------------------------------: |
| A    | 09:27:40-10:27:22 (59m42s) | stopped; manual hold present | running                            | running     | 80% -> 29% (`pmset`; user called the endpoint at about 30%) | 51.26 pp/h |               25.16 W |                     24.61 W | 23.64 W (n=12, about 09:30-10:25) |
| B    | 14:18:39-15:27:28 (68m49s) | running                      | stopped; all three helpers stopped | running     | 80% -> 30%                                                  | 43.59 pp/h |               22.05 W |                     22.98 W |                                 - |
| C    | 22:32:05-23:13:36 (41m31s) | running                      | stopped; all three helpers stopped | stopped     | 80% -> 58%                                                  | 31.79 pp/h |               18.09 W |                     18.79 W |  18.52 W (n=7, about 22:40-23:10) |

### Test A: AeroSpace off, SketchyBar on

- PowerLog battery samples: 91.
- Coverage: 3573 seconds; the first sample arrived eight seconds after the
  marker.
- Time-weighted `SystemPower`: **25.161 W**.
- Median `SystemPower`: 24.294 W; unweighted mean 24.901 W; observed range
  13.924-49.912 W.
- Excluding the first ten minutes: 24.790 W across 75 samples.
- PowerLog direct V x I arithmetic sample mean: **24.613 W**; median 24.195 W.
- Independent BDC direct V x I: 12 five-minute samples, mean **23.637 W** and
  median 24.220 W.
- At 51.26 pp/h, an 80%-capped unplug session extrapolates to about 1.56 hours
  from 80% to 0%. The rate need not remain linear.

This proves that AeroSpace is not required for a roughly 25 W session. It does
not prove that SketchyBar caused the draw because there was no same-time workload
control.

### Test B: SketchyBar off, AeroSpace and Hammerspoon on

The full interval averaged **22.05 W**, 3.11 W (12.4%) lower than the morning.
That difference is not a clean app effect: the run itself changed substantially
without an application-state change.

| Segment                    | UI change                            |      Drain | Finalized SystemPower | PowerLog direct sample mean |
| -------------------------- | ------------------------------------ | ---------: | --------------------: | --------------------------: |
| 14:18:39-15:05:43 (47m04s) | 80% -> 50%; 53% observed at 15:01:53 | 38.24 pp/h |               20.53 W |                     21.27 W |
| 15:05:43-15:27:28 (21m45s) | 50% -> 30%                           | 55.17 pp/h |               25.32 W |                     26.30 W |

The same process state rose by 4.79 W. Thus the menu percentage was nonuniform,
but the acceleration was not merely the gauge: electrical load rose too. The
second segment was essentially as power-hungry as Test A even though SketchyBar
was stopped, so SketchyBar is not necessary for the high state.

From 15:27:28 to 15:38:24, the meter continued from 30% to 20% (about 54.9 pp/h).
SketchyBar remained off until only seconds before the endpoint. This tail is
observational, not a primary test, because its endpoint is contaminated by the
restart.

### Test C: Hammerspoon off, SketchyBar off, AeroSpace on

The exact user markers are 22:32:05-23:13:36. Do not substitute the enclosing
22:30:48-23:27:19 battery-source run.

- Time-weighted `SystemPower`: **18.09 W**.
- PowerLog direct V x I arithmetic sample mean: **18.79 W**; median 18.49 W.
- Independent BDC direct V x I: **18.52 W** across seven five-minute samples,
  covering approximately 22:40-23:10 rather than the entire marked interval.
- A same-length slice of Test B, 14:18:39-15:00:10, had Hammerspoon on,
  SketchyBar off, AeroSpace on, `SystemPower` **19.51 W**, and direct V x I
  **20.51 W**. Its UI loss was approximately 80% to 54% (about 37.6 pp/h), with
  an endpoint sampling caveat.
- Test C was lower by 1.42 W (7.3%) in finalized `SystemPower` and 1.72 W (8.4%)
  in the PowerLog direct arithmetic sample mean.

The later, broader workload bundle used less power. This is not proof that the
Hammerspoon executable itself cost 1.42-1.72 W. Even after its process had quit,
PowerLog attributed 2.705 W and about 1.1 aggregate CPU cores to the
`org.hammerspoon.Hammerspoon` coalition. Process mapping showed that coalition
also contained descendants such as `bash`, `sleep`, `zsh`, `node`, `tmux`,
`codex`, `codex-code-mode-host`, `nvim`, Python/`uv`, `bun`, and power-sampling
commands. The matched earlier coalition was 3.995 W and 1.65 cores.

## Component audits

### tmux GPU meter versus SketchyBar GPU meter

Both refresh every five seconds, but they do not perform equivalent work:

- tmux Dracula's `gpu_usage.sh` invokes
  `sudo powermetrics --samplers gpu_power -i500 -n1`. A measured call took about
  1.08 seconds wall time and 0.56-0.58 CPU-seconds.
- [SketchyBar's GPU plugin](../sketchybar/plugins/gpu.sh) reads `IOAccelerator`
  once with `ioreg`. The complete script used about 0.041 CPU-seconds per update;
  the bare query used about 0.0275.
- The tmux implementation was therefore roughly 12-14 times more CPU-expensive
  per update. Two attached client/session refresh streams produced about 1170
  calls/hour, extrapolating to roughly 667 CPU-seconds/hour (18.5% of one core).
  The SketchyBar GPU query extrapolated to roughly 30 CPU-seconds/hour.
- tmux GPU status was enabled by commit `349b919` on 2024-12-30 and had no 2026
  implementation change. It is a meaningful current tax but cannot by itself
  explain the July 2026 onset unless the number of active tmux refresh streams or
  attachment pattern changed then.

### SketchyBar

The current config has nine timed items, totalling approximately 4380 shell
plugin launches per awake hour:

| Item                      | Interval | Approximate runs/hour |
| ------------------------- | -------: | --------------------: |
| Hidden recording check    |      2 s |                  1800 |
| CPU                       |      5 s |                   720 |
| GPU                       |      5 s |                   720 |
| Clock                     |     10 s |                   360 |
| RAM                       |     10 s |                   360 |
| Battery                   |     30 s |                   120 |
| Wi-Fi                     |     30 s |                   120 |
| Amphetamine               |     30 s |                   120 |
| Input-source safety check |     60 s |                    60 |

Most plugins source `colors.sh`, which in the audited configuration led to about
4320 `defaults` and 4320 `tr` utility invocations per hour in addition to the
plugin processes. A short profile saw 12.36% of one CPU core, 24.9 wakeups/second,
and 57-60 forks per 20 seconds. However, recent whole-coalition PowerLog samples
attributed only about 0.11-0.22 W directly to SketchyBar. That does not include a
clean measure of indirect `WindowServer` redraw cost.

Historical defects are important but are not evidence of a currently active
storm:

- Commit `6c0705c` on 2026-07-08 introduced the hidden two-second recording poll.
- Commit `e99fc56` on 2026-07-08 introduced recurring `default_menu_items`
  polling every five seconds. SketchyBar 2.24 had an unbounded window-info array
  leak on that query; commit `d9913a1` removed the recurring query on 2026-08-11.
- Historical logs contained 839 fork-exhaustion messages, 5296 missing Bluetooth
  lock-PID messages, 83 `rmdir` errors, allocator warnings, and more than 80,000
  unique short-lived PIDs. The quiet August 25 observation did not show that old
  storm still running.
- `input_watcher` polls the input API in-process every 150 ms (about 6.8
  wakeups/second) but showed very little CPU. Bluetooth and CodexBar helpers are
  event-driven with slow safety checks.

### AeroSpace and Hammerspoon recovery

- AeroSpace had recursive SIGSEGV crashes on August 18 and August 24.
- Hammerspoon requested 151 automatic recovery restarts from July 27 through
  August 25: 147 relaunches and four failures, sometimes in bursts. A wake always
  schedules one recovery attempt even if the display set is unchanged.
- A direct idle observation found one AeroSpace instance, no duplicate, no hot
  loop, zero forks in 30 seconds, and zero event callbacks in 20 seconds.
- Commit `c92a04f` introduced Hammerspoon recovery on 2026-07-29; commit
  `74f7e9f` refined it on 2026-08-15. It cannot explain the initial July 6 step,
  though restart bursts can waste power later.
- [The stop/restart helper](../aerospace/scripts/restart.sh) creates
  `~/.cache/aerospace/manually-stopped` on an intentional stop. That marker keeps
  display/wake recovery from undoing the test. Manual start/restart removes it.

### Workload and WindowServer

Point snapshots during the high-draw period showed changing contributors,
including WezTerm, WindowServer, tmux, Chrome helpers, Codex, and Claude. In Test
B, identified coalition changes accounted for only about 1.2 W of an observed
roughly 4.8 W phase rise: Hammerspoon-labelled coalition +0.53 W, WezTerm +0.486
W, WindowServer +0.221 W, and CodexBar +0.100 W. Partial coalition coverage means
the remainder cannot be assigned defensibly.

This variability is why successive percentage intervals under interactive work
cannot establish an app's causal cost.

## Transient SketchyBar launch/display incident

On 2026-08-26, `brew services start sketchybar` reported the service loaded and
running (PID 13838), and the bar was drawing. Nevertheless,
`sketchybar --query displays` returned the built-in display twice and omitted both
LG displays. AeroSpace, Hammerspoon, and `system_profiler` all saw the correct
three-display topology. There were no actual SketchyBar windows for the LGs.

The unified log repeatedly reported SkyLight messages including inability to
bridge the WindowManagement interface and invalid display `0x00000004`. Reloading
and toggling the bar from `display=main` back to `display=all` did not fix it. A
foreground manual SketchyBar process saw all three displays; a temporary process
retained by Hammerspoon also saw them and stopped when Hammerspoon quit.

By 2026-08-28 12:04, the Homebrew service plist had been recreated and the service
correctly saw all three displays. No permanent dotfile change was made for this
incident. Treat it as a transient launch-context/macOS registration problem and
verify displays after reboot.

The same logs contain historical `No space left on device` errors. They were not
current on August 26: the disk then had about 77 GiB free and only 1% of inodes
used. The error logs themselves were approximately 15.6 and 17.6 MiB.

## Pre-reboot snapshot: 2026-08-28 13:25:38 KST

This captures the state before the planned clean reboot:

| Field                           | Value                                                                                                |
| ------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Uptime                          | 9 days, 20 hours, 50 minutes                                                                         |
| Load averages                   | 5.45, 9.67, 10.79                                                                                    |
| Power                           | AC attached, battery 80%, not charging because of the manual cap                                     |
| AeroSpace                       | running, PID 22165; manual-stop marker absent                                                        |
| SketchyBar                      | running, PID 82400; Homebrew service loaded and running                                              |
| Hammerspoon                     | running, PID 40398                                                                                   |
| SketchyBar helpers              | `bluetooth_boucles_watcher` PID 82495; `input_watcher` PID 82575; `codexbar_usage_watcher` PID 82581 |
| Displays reported by AeroSpace  | 1 Built-in Retina Display; 2 LG ULTRAFINE (1); 3 LG ULTRAFINE (2)                                    |
| Displays reported by SketchyBar | built-in direct ID 1, 1512x982; LG direct ID 4, 1920x1080; LG direct ID 5, 1920x1080                 |
| PowerLog current DB             | 32.88 MiB; main file modified 12:33, WAL modified 13:21                                              |
| Current BDC file                | `BDC_SBC_version3.0_2026-08-28_00:06:11.csv`                                                         |

The relevant config symlinks were born on July 6: AeroSpace at 10:53:25 and
SketchyBar at 11:46:50. AeroSpace has `start-at-login = true`; SketchyBar runs as
a Homebrew service.

The working tree was not clean during these experiments. Before adding this
document it was:

```text
 M hammerspoon/init.lua
 M oh-my-zsh/custom/01_env.zsh
 M oh-my-zsh/install-installers.sh
 M sketchybar/README.md
?? hammerspoon/tests/tmux_restore_agents_menu_test.lua
?? hammerspoon/tmux_restore_agents_menu.lua
```

The active Hammerspoon work adds a tmux restore-menu controller and a SketchyBar
restart menu action. These are user changes; do not discard them or assume that
the tests used commit `003d816` unchanged. That commit (2026-08-25 09:30 KST) is
only the committed baseline.

At 13:38:49, after the 13:25 process snapshot and while this document was being
written, `symlink.sh` also appeared modified and an untracked `kitty/` directory
appeared. They were not created or inspected by this investigation and are not
assumed to have been active in the August 26 tests.

## First experiment after reboot

The immediate reboot test should first answer whether a fresh launch materially
changes the all-on baseline. Do not toggle an app before recording the initial
state.

1. Reboot while connected to power and let the machine reach the 80% charge cap.
2. Log in, open the normal three-display arrangement, and wait 10-15 minutes for
   startup, indexing, app restoration, and temperature to settle.
3. Verify that AeroSpace, SketchyBar, Hammerspoon, and exactly one of each
   SketchyBar helper are running. Verify that both AeroSpace and SketchyBar see
   all three displays.
4. Record brightness, Low Power Mode, connected displays, refresh rates, active
   tmux clients, major foreground apps, battery temperature, process state, exact
   time, and battery percentage.
5. Unplug only after the state record. Keep all three components on for this
   first baseline. Avoid starting/stopping apps or changing display topology.
6. Discard the first ten minutes from the primary watt average. Continue another
   45-60 minutes, or to 50%, whichever is safer. Do not deliberately run below
   30% for this investigation.
7. Record the exact end time and state before reconnecting power. Extract
   time-weighted `SystemPower` promptly because the live PowerLog database rotates.
8. Append the result to this file. A percentage-only result is provisional until
   watts have been extracted.

Suggested state capture:

```bash
date '+%F %T %z %Z'
uptime
sw_vers
pmset -g batt
system_profiler SPPowerDataType

for process_name in AeroSpace sketchybar Hammerspoon \
  input_watcher bluetooth_boucles_watcher codexbar_usage_watcher; do
  printf '%-30s' "$process_name"
  pgrep -x "$process_name" || echo stopped
done

test -e "$HOME/.cache/aerospace/manually-stopped" \
  && echo 'AeroSpace manual hold: present' \
  || echo 'AeroSpace manual hold: absent'

brew services info sketchybar
aerospace list-monitors --format '%{monitor-id} %{monitor-name}'
sketchybar --query displays
tmux list-clients -F '#{client_name} #{session_name} #{client_created}' 2>/dev/null
```

Do not paste an unfiltered `launchctl print` into an issue or this document: a
job's environment can contain secrets. Query only the fields needed for service
state.

## Reversible component controls

### AeroSpace

The Hammerspoon **Stop AeroSpace** button is appropriate for an experiment. It
runs the first command below and leaves the intentional-stop marker so automatic
display recovery does not relaunch AeroSpace.

```bash
# Stop and hold
~/.config/aerospace/scripts/restart.sh stop

# Start/restart and clear the hold
~/.config/aerospace/scripts/restart.sh manual

# Verify
pgrep -x AeroSpace || echo 'AeroSpace stopped'
test -e "$HOME/.cache/aerospace/manually-stopped" \
  && echo 'manual hold present' || echo 'manual hold absent'
```

Because AeroSpace is configured to start at login, a new login or external app
launch can make an old stop marker stale. Always verify both the PID and marker.

### SketchyBar and its helpers

SketchyBar is managed with Homebrew `KeepAlive`; `killall sketchybar` alone is not
a stable off state. Stop the service, then stop the three helper processes that
were launched by its config:

```bash
brew services stop sketchybar
pkill -x input_watcher 2>/dev/null || true
pkill -x bluetooth_boucles_watcher 2>/dev/null || true
pkill -x codexbar_usage_watcher 2>/dev/null || true

pgrep -x sketchybar || echo 'SketchyBar stopped'
pgrep -x input_watcher || echo 'input_watcher stopped'
pgrep -x bluetooth_boucles_watcher || echo 'bluetooth watcher stopped'
pgrep -x codexbar_usage_watcher || echo 'CodexBar watcher stopped'
```

Restore it with:

```bash
brew services start sketchybar
sleep 5
brew services info sketchybar
sketchybar --query displays
pgrep -x input_watcher
pgrep -x bluetooth_boucles_watcher
pgrep -x codexbar_usage_watcher
```

If the display query omits or duplicates a monitor, mark the trial invalid and
record the incident; do not silently reload until after its state is captured.

### Hammerspoon

Use Hammerspoon's normal Quit command and restore it with `open -a Hammerspoon`.
For an experiment, confirm the process is gone; do not infer app activity from an
old `org.hammerspoon.Hammerspoon` coalition label.

```bash
pgrep -x Hammerspoon || echo 'Hammerspoon stopped'
open -a Hammerspoon
```

## PowerLog extraction for an exact interval

Run this soon after a test. Replace the two KST markers, but keep their numeric
UTC offset. This query establishes a clipped last-sample-hold convention for all
**new** trials and reports sample coverage plus both whole-system and direct
battery watts. It is intentionally reproducible; it will not exactly regenerate
every legacy August 26 finalized value because that audit's estimator was not
preserved consistently. Re-query every trial being compared with this same query.

```bash
battery_powerlog_db=/var/db/powerlog/Library/BatteryLife/CurrentPowerlog.PLSQL
battery_start_epoch="$(date -j -f '%Y-%m-%d %H:%M:%S %z' \
  '2026-08-26 22:32:05 +0900' '+%s')"
battery_end_epoch="$(date -j -f '%Y-%m-%d %H:%M:%S %z' \
  '2026-08-26 23:13:36 +0900' '+%s')"

sqlite3 -readonly -header -column "$battery_powerlog_db" <<SQL
WITH
bounds(start_ts, end_ts) AS (
  VALUES(CAST($battery_start_epoch AS REAL), CAST($battery_end_epoch AS REAL))
),
raw AS (
  SELECT battery.*,
         lead(
           battery.timestamp,
           1,
           (SELECT end_ts FROM bounds)
         ) OVER (ORDER BY battery.timestamp) AS next_ts
  FROM PLBatteryAgent_EventBackward_Battery AS battery, bounds
  WHERE battery.timestamp BETWEEN (
    SELECT max(timestamp)
    FROM PLBatteryAgent_EventBackward_Battery
    WHERE timestamp <= bounds.start_ts
  ) AND bounds.end_ts
),
segments AS (
  SELECT *,
         max(timestamp, start_ts) AS segment_start,
         min(next_ts, end_ts) AS segment_end
  FROM raw, bounds
),
valid AS (
  SELECT *, segment_end - segment_start AS seconds
  FROM segments
  WHERE segment_end > segment_start
    AND ExternalConnected = 0
)
SELECT count(*) AS samples,
       round(sum(seconds), 1) AS covered_seconds,
       round(max(next_ts - timestamp), 1) AS maximum_sample_gap_seconds,
       round(sum(SystemPower * seconds) / sum(seconds), 2) AS system_w_left_hold,
       round(
         sum((abs(InstantAmperage) * Voltage / 1000000.0) * seconds)
           / sum(seconds),
         2
       ) AS direct_battery_w_left_hold,
       round(min(Level), 1) AS minimum_level,
       round(max(Level), 1) AS maximum_level
FROM valid;
SQL
```

If `covered_seconds` is materially shorter than the marked interval, or the
maximum sample gap is much longer than the normal cadence, do not use the mean
without explaining the gap. Preserve the exact query/convention with the result.
For archived `.PLSQL.gz` files, decompress a copy into a temporary working
directory; never alter the system archive in place.

## Controlled test matrix after the reboot baseline

Use a counterbalanced 2 x 2 test rather than one week per setting:

| State | AeroSpace | SketchyBar and helpers |
| ----- | --------- | ---------------------- |
| 00    | off/held  | off                    |
| 10    | on        | off                    |
| 01    | off/held  | on                     |
| 11    | on        | on                     |

Run at least three replicates per state. Randomize or reverse the order across
days (for example `11 -> 00 -> 10 -> 01`, then the reverse) so time of day,
temperature, and workload drift do not always favor the same state. Recharge and
cool between trials. Start at 80%, settle on AC for 10-15 minutes, unplug, discard
the first ten minutes, and measure 45-60 minutes.

Hold these constant:

- display count, arrangement, resolution, refresh rate, and brightness;
- keyboard brightness, Wi-Fi/Bluetooth state, Low Power Mode, audio, and
  Amphetamine state;
- foreground apps and window layout;
- number of tmux clients and whether its GPU meter is enabled;
- scripted workload or genuine idle-awake state;
- room and battery temperature as far as practical; and
- no charging, sleep, app updates, indexing, or interactive window churn during
  the measured interval.

Primary endpoint: time-weighted `SystemPower` after the ten-minute warm-up.
Secondary endpoints: direct V x I, median/IQR, coverage, battery temperature, and
pp/h. Once the core matrix is complete, separately toggle tmux's GPU sampler and
SketchyBar's high-frequency stats/recording items.

## What is and is not established

| Claim                                                            | Status                                                                               |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| The July regression is only a battery-meter artifact             | Rejected: direct watts rose about 51%.                                               |
| Battery wear contributes to short runtime                        | Established: 77% health, Service Recommended.                                        |
| Battery wear caused the July 6 step                              | Not supported: capacity changed only about 1.5% at the boundary.                     |
| AeroSpace alone is required for high draw                        | Rejected by Test A.                                                                  |
| SketchyBar alone is required for high draw                       | Rejected by Test B's high second phase.                                              |
| SketchyBar has zero cost                                         | Not established; direct and WindowServer overhead still need controlled measurement. |
| AeroSpace has zero cost                                          | Not established; stop/on trials occurred under different workloads.                  |
| Hammerspoon itself used all Hammerspoon-labelled coalition power | Rejected: the coalition contained many descendants.                                  |
| Quitting Hammerspoon reduced this session's broader workload     | Supported by one matched-window observation, not yet replicated.                     |
| tmux and SketchyBar GPU meters are equivalent                    | Rejected: tmux uses `powermetrics` and is about 12-14x costlier per update.          |
| tmux GPU polling caused the July 2026 onset                      | Not supported by config history; it was enabled in December 2024.                    |
| The migration day is unrelated                                   | Not established; July 6 correlation is strong enough to test rigorously.             |

## Append-only experiment template

Copy this section for every trial. Record planned state and verified state
separately.

```markdown
### E-YYYYMMDD-N: short description

- Hypothesis:
- Exact start (KST, include `+0900`):
- Exact end (KST, include `+0900`):
- Duration:
- Planned state: AeroSpace [on/off], SketchyBar+helpers [on/off], Hammerspoon [on/off]
- Verified start PIDs/markers/service state:
- Verified end PIDs/markers/service state:
- Battery: start/end UI %, raw %, temperature, cycle count, maximum capacity
- Power source: AC settle duration; exact unplug/replug times
- Displays: count, names, arrangement, resolution, refresh, brightness
- Workload: apps, foreground window, scripted task, tmux clients, GPU sampler state
- Other controls: LPM, Wi-Fi, Bluetooth, audio, keyboard light, Amphetamine
- Warm-up excluded:
- PowerLog convention and sample coverage:
- Primary result: time-weighted SystemPower W
- Secondary: direct V x I W, median/IQR, pp/h
- Anomalies/confounders:
- Interpretation (including what this trial cannot prove):
```

Summary row to append:

| ID           | Exact interval KST | A      | SB     | HS     | UI start/end | Warm-up | SystemPower | Direct W | Notes                      |
| ------------ | ------------------ | ------ | ------ | ------ | ------------ | ------- | ----------- | -------- | -------------------------- |
| E-YYYYMMDD-N | start-end          | on/off | on/off | on/off | x% -> y%     | 10 min  | x.xx W      | x.xx W   | verified state/confounders |

## Related repository files

- [SketchyBar README](../sketchybar/README.md)
- [SketchyBar configuration](../sketchybar/sketchybarrc)
- [SketchyBar GPU plugin](../sketchybar/plugins/gpu.sh)
- [AeroSpace configuration](../aerospace/aerospace.toml)
- [AeroSpace stop/restart helper](../aerospace/scripts/restart.sh)
- [Hammerspoon AeroSpace recovery watcher](../hammerspoon/aerospace_recovery.lua)
- [Hammerspoon configuration](../hammerspoon/init.lua)
- [tmux configuration](../tmux/.tmux.conf)
- [tmux README](../tmux/README.md)
- [Initial SketchyBar/AeroSpace design](superpowers/specs/2026-07-06-sketchybar-aerospace-design.md)
- [Monitor grouping and stats design](superpowers/specs/2026-07-06-sketchybar-monitor-groups-stats-design.md)

The temporary audit directories that originally held intermediate reports were
`/tmp/codex-battery-audit-20260825/` and
`/tmp/codex-powerlog-db-audit.0JSHg7/`. They are intentionally not repository
evidence and may disappear on reboot; their durable findings are recorded above.
