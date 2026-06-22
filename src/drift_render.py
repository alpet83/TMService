#!/usr/bin/env python3
"""
drift_render.py -- visualization of TMService JSONL drift log
Usage: python drift_render.py <drift.jsonl> [-o drift_stats.svg] [--limit-pts N]
       [--width PX] [--height PX]
"""

import sys
import json
import argparse
from datetime import datetime
from pathlib import Path


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


def calc_ema(values, tc):
    result = []
    e = None
    for v in values:
        e = v if e is None else e * ((tc - 1) / tc) + v * (1.0 / tc)
        result.append(e)
    return result


def main():
    parser = argparse.ArgumentParser(description='Render TMService drift log to SVG')
    parser.add_argument('input', nargs='?', default='drift.jsonl',
                        help='JSONL drift log path (default: drift.jsonl)')
    parser.add_argument('-o', '--output', default=None,
                        help='Output SVG path (default: drift_stats.svg next to input)')
    parser.add_argument('--limit-pts', type=int, default=1440, metavar='N',
                        help='Show only last N points (default: 1440 = one day)')
    parser.add_argument('--width',  type=int, default=1728, metavar='PX',
                        help='Canvas width in pixels (default: 1728)')
    parser.add_argument('--height', type=int, default=576,  metavar='PX',
                        help='Canvas height in pixels (default: 576)')
    args = parser.parse_args()

    try:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        import matplotlib.dates as mdates
        from matplotlib.ticker import AutoMinorLocator
    except ImportError:
        print("matplotlib not found. Install: pip install matplotlib", file=sys.stderr)
        sys.exit(1)

    in_path = Path(args.input)
    if not in_path.exists():
        print("File not found: %s" % in_path, file=sys.stderr)
        sys.exit(1)

    out_path = Path(args.output) if args.output else in_path.parent / 'drift_stats.svg'

    print("Reading: %s" % in_path)
    records = load_jsonl(in_path)
    if not records:
        print("No records found.", file=sys.stderr)
        sys.exit(1)
    print("Loaded: %d records" % len(records))

    times     = []
    dta_ms    = []
    drift_msh = []  # stored as ms/min (= drift_msh_raw / 60)
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
        drift_msh.append(r.get('drift_msh', 0.0) / 60.0)  # convert ms/h -> ms/min
        st_adj.append(r.get('st_adjust', 0))
        is_ntp.append(bool(r.get('ntp_sync', False)))
        cpu_load.append(r.get('cpu_load', None))
        ntp_ms.append(r.get('ntp_ms', None))

    if not times:
        print("No valid records.", file=sys.stderr)
        sys.exit(1)

    total_pts = len(times)
    if args.limit_pts and total_pts > args.limit_pts:
        cut = total_pts - args.limit_pts
        times     = times[cut:]
        dta_ms    = dta_ms[cut:]
        drift_msh = drift_msh[cut:]
        st_adj    = st_adj[cut:]
        is_ntp    = is_ntp[cut:]
        cpu_load  = cpu_load[cut:]
        ntp_ms    = ntp_ms[cut:]
        print("Showing last %d of %d points" % (args.limit_pts, total_pts))

    ema30    = calc_ema(st_adj, 30)
    have_cpu = any(v is not None for v in cpu_load)
    cpu_vals = [v if v is not None else 0.0 for v in cpu_load]
    ntp_t    = [t for t, v, s in zip(times, ntp_ms, is_ntp) if s and v is not None]
    ntp_v    = [v for v, s in zip(ntp_ms, is_ntp) if s and v is not None]

    BG_OUTER = '#12121e'
    BG_INNER = '#1a1a2e'
    C_DRIFT  = '#00d4ff'
    C_PFC    = '#ff6688'
    C_RATE   = '#44ff88'
    C_SPEED  = '#ff8c00'
    C_EMA30  = '#ffee44'
    C_CPU    = '#cc44ff'
    C_NTP    = '#ff4466'
    C_GRID   = '#ffffff'
    C_TEXT   = '#bbbbbb'
    C_SPINE  = '#333355'
    C_STATS  = '#8899aa'

    dpi = 96
    fig, ax1 = plt.subplots(figsize=(args.width / dpi, args.height / dpi), dpi=dpi)
    fig.patch.set_facecolor(BG_OUTER)
    ax1.set_facecolor(BG_INNER)
    ax2 = ax1.twinx()

    if have_cpu:
        ax3 = ax1.twinx()
        ax3.spines['right'].set_position(('axes', 1.06))
    else:
        ax3 = None

    ax1.plot(times, dta_ms, color=C_DRIFT, linewidth=1.4,
             label='dta_ms  sys vs PFC (ms)', zorder=4)
    if ntp_t:
        ax1.plot(ntp_t, ntp_v, color=C_PFC, linewidth=1.2, alpha=0.8,
                 label='ntp_ms   PFC vs NTP (ms)', zorder=4)
    ax1.plot(times, drift_msh, color=C_RATE, linewidth=0.8,
             linestyle='--', alpha=0.6, label='drift_msm (ms/min)', zorder=3)
    ax1.axhline(0, color='#ffffff', linewidth=0.4, linestyle=':', alpha=0.25, zorder=1)
    ax1.set_ylabel('Offset (ms) / Drift rate (ms/min)', color=C_TEXT, fontsize=10)
    ax1.tick_params(axis='y', labelcolor=C_TEXT, colors=C_TEXT)
    ax1.tick_params(axis='x', labelcolor=C_TEXT, colors=C_TEXT)

    ax2.plot(times, st_adj, color=C_SPEED, linewidth=0.7, alpha=0.35,
             label='st_adjust (100ns/s)', zorder=2)
    ax2.plot(times, ema30, color=C_EMA30, linewidth=1.8, alpha=0.9,
             label='st_adjust EMA-30  ->  HWClockAdjust', zorder=4)
    ax2.set_ylabel('st_adjust (100 ns/s)', color=C_SPEED, fontsize=10)
    ax2.tick_params(axis='y', labelcolor=C_SPEED, colors=C_SPEED)

    if ax3 is not None:
        ax3.fill_between(times, cpu_vals, alpha=0.12, color=C_CPU, zorder=1)
        ax3.plot(times, cpu_vals, color=C_CPU, linewidth=0.8, alpha=0.55,
                 label='cpu_load (%)', zorder=2)
        ax3.set_ylabel('CPU load (%)', color=C_CPU, fontsize=10)
        ax3.tick_params(axis='y', labelcolor=C_CPU, colors=C_CPU)
        ax3.set_ylim(0, max(max(cpu_vals) * 1.5, 20))
        for spine in ax3.spines.values():
            spine.set_edgecolor(C_SPINE)

    ntp_sync_t = [t for t, s in zip(times, is_ntp) if s]
    if ntp_sync_t:
        ax1.scatter(ntp_sync_t, [0.0] * len(ntp_sync_t), color=C_NTP,
                    s=18, zorder=5, marker='|', linewidths=1.2, label='NTP sync')

    ax1.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
    ax1.xaxis.set_major_locator(mdates.AutoDateLocator(minticks=6, maxticks=20))
    ax1.xaxis.set_minor_locator(AutoMinorLocator(4))
    fig.autofmt_xdate(rotation=25, ha='right')

    ax1.grid(True, which='major', color=C_GRID, alpha=0.08, linewidth=0.5)
    ax1.grid(True, which='minor', color=C_GRID, alpha=0.03, linewidth=0.3)

    for ax in (ax1, ax2):
        for spine in ax.spines.values():
            spine.set_edgecolor(C_SPINE)

    duration_min = int((times[-1] - times[0]).total_seconds() / 60)
    lim_note = ' (last %d pts)' % args.limit_pts if total_pts > args.limit_pts else ''
    title = ('TMService  drift log  |  '
             + times[0].strftime('%Y-%m-%d  %H:%M')
             + ' - ' + times[-1].strftime('%H:%M')
             + '  |  %d pts%s  |  %d min' % (len(times), lim_note, duration_min))
    ax1.set_title(title, color=C_TEXT, fontsize=11, pad=10, fontfamily='monospace')

    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    lines3, labels3 = (ax3.get_legend_handles_labels() if ax3 else ([], []))
    ax1.legend(lines1 + lines2 + lines3, labels1 + labels2 + labels3,
               loc='upper left', facecolor='#1a1a2e', edgecolor='#334',
               labelcolor=C_TEXT, fontsize=9, framealpha=0.85)

    dta_min = min(dta_ms)
    dta_max = max(dta_ms)
    st_min  = min(st_adj)
    st_max  = max(st_adj)
    stat_lines = [
        'sys vs PFC:  [%+.2f ... %+.2f] ms' % (dta_min, dta_max),
        'st_adjust:   [%d ... %d] 100ns/s' % (st_min, st_max),
        'EMA-30 end:  %d  ->  HWClockAdjust' % round(ema30[-1]),
    ]
    if ntp_v:
        stat_lines.insert(1, 'PFC vs NTP:  [%+.2f ... %+.2f] ms' % (min(ntp_v), max(ntp_v)))
    if have_cpu:
        cpu_valid = [v for v in cpu_load if v is not None]
        stat_lines.append('cpu_load:    avg=%.1f%%  max=%.1f%%' % (
            sum(cpu_valid) / len(cpu_valid), max(cpu_valid)))
    ax1.text(0.99, 0.97, '\n'.join(stat_lines),
             transform=ax1.transAxes, ha='right', va='top',
             color=C_STATS, fontsize=8, fontfamily='monospace',
             bbox=dict(facecolor='#0a0a18', edgecolor='#333', alpha=0.7, pad=4))

    plt.tight_layout(pad=1.2)
    fig.savefig(str(out_path), format='svg', bbox_inches='tight',
                facecolor=fig.get_facecolor())
    print("Saved: %s" % out_path)


if __name__ == '__main__':
    main()
