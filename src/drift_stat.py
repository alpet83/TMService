#!/usr/bin/env python3
"""
drift_stat.py -- statistical analysis of TMService JSONL drift log
Usage: python drift_stat.py <drift.jsonl> [-o report.txt] [--hours N]
"""

import sys
import json
import math
import argparse
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict


def load_jsonl(path):
    records = []
    with open(path, encoding='utf-8') as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError as e:
                print("  warn: line %d skip (%s)" % (lineno, e), file=sys.stderr)
    return records


def stats(values):
    """Return dict with basic statistics for a list of floats."""
    if not values:
        return {}
    n = len(values)
    mean = sum(values) / n
    variance = sum((v - mean) ** 2 for v in values) / n
    std = math.sqrt(variance)
    rmse = math.sqrt(sum(v ** 2 for v in values) / n)
    sv = sorted(values)
    def pct(p):
        idx = min(int(p / 100.0 * n), n - 1)
        return sv[idx]
    return {
        'n': n,
        'mean': mean,
        'std': std,
        'rmse': rmse,
        'min': sv[0],
        'p5':  pct(5),
        'p25': pct(25),
        'p50': pct(50),
        'p75': pct(75),
        'p95': pct(95),
        'p99': pct(99),
        'max': sv[-1],
    }


def abs_stats(values):
    return stats([abs(v) for v in values])


def drift_over_window(times, values, window_hours):
    """
    For each point, compute slope (ms/h) over a sliding window of window_hours.
    Returns list of (time, slope) pairs.
    """
    results = []
    window = timedelta(hours=window_hours)
    for i in range(len(times)):
        t0 = times[i] - window / 2
        t1 = times[i] + window / 2
        seg_t = []
        seg_v = []
        for j in range(len(times)):
            if t0 <= times[j] <= t1:
                seg_t.append((times[j] - times[i]).total_seconds() / 3600.0)
                seg_v.append(values[j])
        if len(seg_t) < 3:
            continue
        # linear regression slope
        n = len(seg_t)
        sx = sum(seg_t)
        sy = sum(seg_v)
        sxx = sum(x * x for x in seg_t)
        sxy = sum(x * y for x, y in zip(seg_t, seg_v))
        denom = n * sxx - sx * sx
        if abs(denom) < 1e-12:
            continue
        slope = (n * sxy - sx * sy) / denom
        results.append((times[i], slope))
    return results


def format_stats(s, unit='ms', indent='  '):
    if not s:
        return indent + '(no data)'
    return (
        '%smean=%+.3f  std=%.3f  rmse=%.3f  %s\n'
        '%smin=%+.3f  p5=%+.3f  p50=%+.3f  p95=%+.3f  max=%+.3f  (n=%d)'
    ) % (
        indent, s['mean'], s['std'], s['rmse'], unit,
        indent, s['min'], s['p5'], s['p50'], s['p95'], s['max'], s['n']
    )


def hr(char='-', width=72):
    return char * width


def main():
    parser = argparse.ArgumentParser(description='Statistical analysis of TMService JSONL drift log')
    parser.add_argument('input', nargs='?', default='drift.jsonl')
    parser.add_argument('-o', '--output', default=None,
                        help='Output text report (default: stdout only)')
    parser.add_argument('--hours', type=float, default=None,
                        help='Analyze only last N hours of data')
    args = parser.parse_args()

    in_path = Path(args.input)
    if not in_path.exists():
        print("File not found: %s" % in_path, file=sys.stderr)
        sys.exit(1)

    records = load_jsonl(in_path)
    if not records:
        print("No records.", file=sys.stderr)
        sys.exit(1)

    # Parse records
    times     = []
    dta_ms    = []
    drift_msh = []
    st_adj    = []
    is_ntp    = []
    cpu_load  = []
    ntp_ms    = []

    for r in records:
        try:
            ts = datetime.fromisoformat(r['ts'])
        except Exception:
            try:
                ts = datetime.strptime(r['ts'], '%Y-%m-%dT%H:%M:%S.%f')
            except Exception:
                continue
        times.append(ts)
        dta_ms.append(r.get('dta_ms', 0.0))
        drift_msh.append(r.get('drift_msh', 0.0))
        st_adj.append(int(r.get('st_adjust', 0)))
        is_ntp.append(bool(r.get('ntp_sync', False)))
        cpu_load.append(r.get('cpu_load', None))
        ntp_ms.append(r.get('ntp_ms', None))

    total_all = len(times)
    if not times:
        print("No valid records.", file=sys.stderr)
        sys.exit(1)

    # Trim to last N hours if requested
    if args.hours:
        cutoff = times[-1] - timedelta(hours=args.hours)
        idx = next((i for i, t in enumerate(times) if t >= cutoff), 0)
        times     = times[idx:]
        dta_ms    = dta_ms[idx:]
        drift_msh = drift_msh[idx:]
        st_adj    = st_adj[idx:]
        is_ntp    = is_ntp[idx:]
        cpu_load  = cpu_load[idx:]
        ntp_ms    = ntp_ms[idx:]

    n = len(times)
    duration = times[-1] - times[0]
    duration_h = duration.total_seconds() / 3600.0

    # NTP sync points: both dta_ms and ntp_ms available
    ntp_idx = [i for i, s in enumerate(is_ntp) if s and ntp_ms[i] is not None]
    ntp_dta   = [dta_ms[i]  for i in ntp_idx]   # sys vs PFC at sync
    ntp_ntp   = [ntp_ms[i]  for i in ntp_idx]   # PFC vs NTP at sync
    # system vs NTP = dta_ms + ntp_ms  (sys - PFC) + (PFC - NTP) = sys - NTP
    ntp_sys   = [dta_ms[i] + ntp_ms[i] for i in ntp_idx]

    # Segmented hourly analysis
    hour_buckets = defaultdict(lambda: {'dta': [], 'drift': [], 'sta': []})
    t0 = times[0]
    for i in range(n):
        h = int((times[i] - t0).total_seconds() / 3600)
        hour_buckets[h]['dta'].append(abs(dta_ms[i]))
        hour_buckets[h]['drift'].append(drift_msh[i])
        hour_buckets[h]['sta'].append(st_adj[i])

    # CPU stats
    cpu_valid = [v for v in cpu_load if v is not None]

    lines = []
    W = lines.append

    W(hr('='))
    W('TMService drift log  --  statistical report')
    W(hr('='))
    W('File    : %s' % in_path)
    W('Period  : %s  ..  %s' % (
        times[0].strftime('%Y-%m-%d %H:%M'),
        times[-1].strftime('%Y-%m-%d %H:%M')))
    W('Duration: %.2f h  (%d min total,  %d shown)' % (
        duration_h, total_all, n))
    W('NTP sync events in window: %d' % len(ntp_idx))
    W('')

    # ------------------------------------------------------------------ #
    W(hr())
    W('1.  SYSTEM TIME vs PFC TIMER  (dta_ms)')
    W(hr())
    W('  This measures how much the Windows clock has drifted from the')
    W('  PFC (TSC-based) timer. Controlled by SetSystemTimeAdjustment.')
    W('')
    s = stats(dta_ms)
    W(format_stats(s, 'ms'))
    W('')
    W('  |dta_ms| absolute:')
    sa = abs_stats(dta_ms)
    W('  mean=%.3f  std=%.3f  p50=%.3f  p95=%.3f  p99=%.3f  max=%.3f ms' % (
        sa['mean'], sa['std'], sa['p50'], sa['p95'], sa['p99'], sa['max']))

    W('')
    # ------------------------------------------------------------------ #
    W(hr())
    W('2.  PFC TIMER vs NTP  (ntp_ms)  --  only at NTP sync events')
    W(hr())
    W('  Measures how much the PFC timer itself differs from network time.')
    W('  Captures PFC instability independent of SetSystemTimeAdjustment.')
    W('')
    if ntp_ntp:
        s2 = stats(ntp_ntp)
        W(format_stats(s2, 'ms'))
        W('')
        W('  |ntp_ms| absolute:')
        sa2 = abs_stats(ntp_ntp)
        W('  mean=%.3f  std=%.3f  p50=%.3f  p95=%.3f  max=%.3f ms' % (
            sa2['mean'], sa2['std'], sa2['p50'], sa2['p95'], sa2['max']))
    else:
        W('  (no NTP sync data available)')

    W('')
    # ------------------------------------------------------------------ #
    W(hr())
    W('3.  SYSTEM TIME vs NTP  (dta_ms + ntp_ms)  --  at sync events')
    W(hr())
    W('  True accuracy of the Windows clock vs external reference.')
    W('')
    if ntp_sys:
        s3 = stats(ntp_sys)
        W(format_stats(s3, 'ms'))
        W('')
        sa3 = abs_stats(ntp_sys)
        W('  |sys_vs_ntp| absolute:')
        W('  mean=%.3f  std=%.3f  p50=%.3f  p95=%.3f  max=%.3f ms' % (
            sa3['mean'], sa3['std'], sa3['p50'], sa3['p95'], sa3['max']))
    else:
        W('  (no NTP sync data)')

    W('')
    # ------------------------------------------------------------------ #
    W(hr())
    W('4.  ACCURACY COMPARISON  (at %d NTP sync events)' % len(ntp_idx))
    W(hr())
    if ntp_ntp and ntp_sys:
        rmse_pfc = math.sqrt(sum(v**2 for v in ntp_ntp) / len(ntp_ntp))
        rmse_sys = math.sqrt(sum(v**2 for v in ntp_sys) / len(ntp_sys))
        W('')
        W('  RMSE vs NTP:')
        W('    PFC timer   : %8.3f ms' % rmse_pfc)
        W('    System time : %8.3f ms' % rmse_sys)
        W('')
        if rmse_pfc < rmse_sys:
            ratio = rmse_sys / max(rmse_pfc, 0.001)
            W('  >> PFC timer is ~%.1fx more accurate than system time vs NTP' % ratio)
        elif rmse_sys < rmse_pfc:
            ratio = rmse_pfc / max(rmse_sys, 0.001)
            W('  >> System time is ~%.1fx more accurate than PFC timer vs NTP' % ratio)
        else:
            W('  >> PFC timer and system time have similar accuracy vs NTP')
        W('')
        # Per-event comparison
        pfc_wins = sum(1 for p, s in zip(ntp_ntp, ntp_sys) if abs(p) < abs(s))
        sys_wins = sum(1 for p, s in zip(ntp_ntp, ntp_sys) if abs(s) < abs(p))
        W('  Per-event wins (closer to NTP):')
        W('    PFC timer wins   : %d / %d  (%.0f%%)' % (
            pfc_wins, len(ntp_idx), 100.0 * pfc_wins / len(ntp_idx)))
        W('    System time wins : %d / %d  (%.0f%%)' % (
            sys_wins, len(ntp_idx), 100.0 * sys_wins / len(ntp_idx)))
    else:
        W('  (insufficient NTP data for comparison)')

    W('')
    # ------------------------------------------------------------------ #
    W(hr())
    W('5.  DRIFT RATE  (drift_msh, ms/h)')
    W(hr())
    W('  Rate of change of system vs PFC offset. High variance = instability.')
    W('')
    sd = stats(drift_msh)
    W(format_stats(sd, 'ms/h'))
    W('')
    W('  Drift rate |drift_msh| > 10 ms/h : %d / %d points  (%.1f%%)' % (
        sum(1 for v in drift_msh if abs(v) > 10),
        n,
        100.0 * sum(1 for v in drift_msh if abs(v) > 10) / max(n, 1)))
    W('  Drift rate |drift_msh| > 30 ms/h : %d / %d points  (%.1f%%)' % (
        sum(1 for v in drift_msh if abs(v) > 30),
        n,
        100.0 * sum(1 for v in drift_msh if abs(v) > 30) / max(n, 1)))

    W('')
    # ------------------------------------------------------------------ #
    W(hr())
    W('6.  CLOCK SPEED CONTROL  (st_adjust, 100 ns/s units)')
    W(hr())
    W('  Range of SetSystemTimeAdjustment corrections applied.')
    W('  Narrow range = stable base clock. Wide range = compensation chasing noise.')
    W('')
    ss = stats(st_adj)
    W('  mean=%+.0f  std=%.0f  min=%d  p5=%d  p50=%d  p95=%d  max=%d' % (
        ss['mean'], ss['std'],
        int(ss['min']), int(ss['p5']), int(ss['p50']), int(ss['p95']), int(ss['max'])))
    W('  Range span: %d  (max - min)' % (int(ss['max']) - int(ss['min'])))
    W('  Suggested HWClockAdjust base: %d  (EMA-style estimate of mean)' % round(ss['mean']))

    if cpu_valid:
        W('')
        W(hr())
        W('7.  CPU LOAD')
        W(hr())
        sc = stats(cpu_valid)
        W('  mean=%.1f%%  std=%.1f%%  p50=%.1f%%  p95=%.1f%%  max=%.1f%%' % (
            sc['mean'], sc['std'], sc['p50'], sc['p95'], sc['max']))

    # ------------------------------------------------------------------ #
    W('')
    W(hr())
    W('8.  HOURLY BREAKDOWN  (|dta_ms| mean per hour)')
    W(hr())
    W('  Hour |  |dta_ms| mean (ms)  |  drift_msh mean (ms/h)  |  st_adj mean')
    W('  -----|---------------------|-------------------------|-------------')
    for h in sorted(hour_buckets.keys()):
        bk = hour_buckets[h]
        dta_m  = sum(bk['dta'])  / len(bk['dta'])  if bk['dta']  else 0
        drft_m = sum(bk['drift'])/ len(bk['drift']) if bk['drift'] else 0
        sta_m  = sum(bk['sta'])  / len(bk['sta'])  if bk['sta']  else 0
        label  = (t0 + timedelta(hours=h)).strftime('%H:%M')
        W('  +%3dh (%s) |  %7.3f ms         |  %+9.2f ms/h       |  %+7.0f' % (
            h, label, dta_m, drft_m, sta_m))

    W('')
    W(hr('='))
    W('End of report')
    W(hr('='))

    report = '\n'.join(lines)
    print(report)

    if args.output:
        out_path = Path(args.output)
        out_path.write_text(report + '\n', encoding='utf-8')
        print('\nReport saved: %s' % out_path, file=sys.stderr)


if __name__ == '__main__':
    main()
