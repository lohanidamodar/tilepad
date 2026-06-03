import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:picons/picons.dart';

import '../models/button.dart';
import 'plugins/state_store.dart';

/// Reserved live-state source id for built-in system metrics. Tiles bind to
/// `system/<stateId>` exactly like a plugin state.
const String systemSourceId = 'system';

/// A built-in system metric exposed as a live state + offered as a preset.
class SystemState {
  final String id;
  final String label;

  /// Phosphor code point (as a string) for the preset button icon.
  final String iconName;
  const SystemState(this.id, this.label, this.iconName);
}

/// The system metrics published under [systemSourceId].
final List<SystemState> systemStates = [
  SystemState('cpu', 'CPU', PiconsRegular.cpu.codePoint.toString()),
  SystemState('ram', 'RAM', PiconsRegular.memory.codePoint.toString()),
  SystemState('disk', 'Disk', PiconsRegular.hardDrives.codePoint.toString()),
  SystemState('uptime', 'Uptime', PiconsRegular.clock.codePoint.toString()),
  SystemState('clock', 'Clock', PiconsRegular.clockCountdown.codePoint.toString()),
  SystemState('battery', 'Battery', PiconsRegular.batteryHigh.codePoint.toString()),
  SystemState('net', 'Network', PiconsRegular.wifiHigh.codePoint.toString()),
  SystemState('host', 'Host', PiconsRegular.desktopTower.codePoint.toString()),
];

/// Reserved state id of the combined multi-metric readout.
const String systemSummaryStateId = 'summary';

/// Builds the combined "System Monitor" preset (CPU/RAM/Disk/Uptime in one
/// tile). Default-placed larger than 1x1.
Button systemMonitorPreset() => Button(
      name: 'System Monitor',
      iconName: PiconsRegular.gauge.codePoint.toString(),
      color: '#1F2937',
      actions: const [],
      stateBinding: StateBinding(
        pluginId: systemSourceId,
        stateId: systemSummaryStateId,
        mode: StateBindingMode.title,
      ),
    );

/// Ready-made library buttons: the combined monitor first, then one per metric.
/// Used by the "System info" presets in the library picker.
List<Button> systemPresetButtons() => [
      systemMonitorPreset(),
      for (final s in systemStates)
        Button(
          name: s.label,
          iconName: s.iconName,
          color: '#334155',
          actions: const [],
          stateBinding: StateBinding(
            pluginId: systemSourceId,
            stateId: s.id,
            mode: StateBindingMode.title,
          ),
        ),
    ];

/// A point-in-time CPU tick from `/proc/stat`.
@immutable
class CpuSample {
  final int total;
  final int idle;
  const CpuSample(this.total, this.idle);
}

/// Parsed `/proc/meminfo` figures (kB).
@immutable
class MemInfo {
  final int totalKb;
  final int usedKb;
  const MemInfo(this.totalKb, this.usedKb);
}

/// Pure parsing/formatting helpers — unit tested independently of the OS.
class SystemMetrics {
  SystemMetrics._();

  /// Parses the aggregate `cpu` line of `/proc/stat`. Returns null if [line] is
  /// not the cpu line.
  static CpuSample? parseProcStatCpu(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first != 'cpu') return null;
    final nums = parts.skip(1).map((p) => int.tryParse(p) ?? 0).toList();
    if (nums.length < 4) return null;
    final total = nums.fold<int>(0, (a, b) => a + b);
    final idle = nums[3] + (nums.length > 4 ? nums[4] : 0); // idle + iowait
    return CpuSample(total, idle);
  }

  /// CPU % busy between two `/proc/stat` samples.
  static double cpuPercent(CpuSample prev, CpuSample curr) {
    final totalD = curr.total - prev.total;
    final idleD = curr.idle - prev.idle;
    if (totalD <= 0) return 0;
    return ((totalD - idleD) / totalD * 100).clamp(0, 100);
  }

  static MemInfo? parseMemInfo(String content) {
    int? read(String key) {
      final m = RegExp('$key:\\s+(\\d+)\\s*kB').firstMatch(content);
      return m == null ? null : int.tryParse(m.group(1)!);
    }

    final total = read('MemTotal');
    final available = read('MemAvailable') ?? read('MemFree');
    if (total == null || available == null) return null;
    return MemInfo(total, total - available);
  }

  /// Extracts the "Use%" column from `df` output.
  static int? parseDfPercent(String df) {
    for (final line in df.split('\n').skip(1)) {
      final m = RegExp(r'(\d+)%').firstMatch(line);
      if (m != null) return int.tryParse(m.group(1)!);
    }
    return null;
  }

  /// Parses `key : value` / `key=value` lines (PowerShell Format-List / our
  /// own key=value script output) into a map.
  static Map<String, String> parseCimList(String out) {
    final map = <String, String>{};
    for (final line in out.split('\n')) {
      final m = RegExp(r'^\s*([A-Za-z0-9_]+)\s*[:=]\s*(.*?)\s*$').firstMatch(line);
      if (m != null && m.group(2)!.isNotEmpty) {
        map[m.group(1)!] = m.group(2)!;
      }
    }
    return map;
  }

  static String formatGbFromKb(int kb) =>
      '${(kb / 1024 / 1024).toStringAsFixed(1)} GB';

  /// Compact "used / total GB" with no decimals, for tight tiles.
  static String formatGbPair(int usedKb, int totalKb) =>
      '${(usedKb / 1024 / 1024).round()}/${(totalKb / 1024 / 1024).round()} GB';

  static String formatGbFromBytes(int bytes) =>
      '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';

  static String formatUptime(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  /// Formats a wall-clock time as 12-hour "h:mm AM/PM".
  static String formatClock(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  /// Parses a Linux `/sys/class/power_supply/BAT*/capacity` file (a bare int).
  static int? parseBatteryCapacity(String content) =>
      int.tryParse(content.trim());

  /// Extracts the charge percentage from macOS `pmset -g batt` output.
  static String? parsePmsetBattery(String out) {
    final m = RegExp(r'(\d+)%').firstMatch(out);
    return m == null ? null : '${m.group(1)}%';
  }

  /// Sums received/transmitted bytes across non-loopback interfaces in the
  /// contents of Linux `/proc/net/dev`.
  static ({int rx, int tx})? parseProcNetDev(String content) {
    var rx = 0, tx = 0;
    var matched = false;
    for (final line in content.split('\n')) {
      final idx = line.indexOf(':');
      if (idx < 0) continue;
      final iface = line.substring(0, idx).trim();
      if (iface.isEmpty || iface == 'lo') continue;
      final nums = line
          .substring(idx + 1)
          .trim()
          .split(RegExp(r'\s+'))
          .map(int.tryParse)
          .toList();
      // Columns: rx bytes is [0]; tx bytes is [8].
      if (nums.length < 9 || nums[0] == null || nums[8] == null) continue;
      rx += nums[0]!;
      tx += nums[8]!;
      matched = true;
    }
    return matched ? (rx: rx, tx: tx) : null;
  }

  /// Formats a per-second byte rate as B/s, KB/s or MB/s.
  static String formatRate(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }
}

/// Samples system metrics on a timer and publishes them to the shared
/// [StateStore] under [systemSourceId], so live tiles render them through the
/// existing pipeline. In-process and cross-platform with graceful fallback.
class SystemInfoService {
  final StateStore store;
  final Duration interval;

  Timer? _timer;
  CpuSample? _prevCpu; // Linux delta sampling
  ({int rx, int tx})? _prevNet; // Linux/macOS cumulative byte counters

  SystemInfoService(this.store, {this.interval = const Duration(seconds: 2)});

  void start() {
    // Host is static — publish immediately.
    store.set(systemSourceId, 'host', value: Platform.localHostname);
    _sample();
    _timer = Timer.periodic(interval, (_) => _sample());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sample() async {
    try {
      if (Platform.isWindows) {
        await _sampleWindows();
      } else if (Platform.isLinux) {
        await _sampleLinux();
      } else if (Platform.isMacOS) {
        await _sampleMacOS();
      }
      // Wall-clock time is platform-independent and cheap.
      _put('clock', SystemMetrics.formatClock(DateTime.now()));
      _publishSummary();
    } catch (e) {
      debugPrint('SystemInfoService sample error: $e');
    }
  }

  void _put(String id, String? value) {
    if (value != null && value.isNotEmpty) {
      store.set(systemSourceId, id, value: value);
    }
  }

  /// Publishes the network tile from cumulative byte counters, deriving the
  /// per-second rate against the previous sample. [rx]/[tx] are total bytes.
  void _putNetDelta(int rx, int tx) {
    final prev = _prevNet;
    _prevNet = (rx: rx, tx: tx);
    if (prev == null) return; // need two samples for a rate
    final secs = interval.inSeconds == 0 ? 1 : interval.inSeconds;
    final down = ((rx - prev.rx) / secs).round().clamp(0, 1 << 62);
    final up = ((tx - prev.tx) / secs).round().clamp(0, 1 << 62);
    _put('net',
        '↓ ${SystemMetrics.formatRate(down)}  ↑ ${SystemMetrics.formatRate(up)}');
  }

  /// Publishes the network tile from already-per-second rates (Windows perf
  /// counters expose these directly).
  void _putNetRate(int down, int up) {
    _put('net',
        '↓ ${SystemMetrics.formatRate(down)}  ↑ ${SystemMetrics.formatRate(up)}');
  }

  /// Composes the combined multi-metric `summary` state (one metric per line)
  /// that powers the single "System Monitor" tile.
  void _publishSummary() {
    String? v(String id) => store.get(systemSourceId, id)?.value as String?;
    final lines = <String>[];
    if (v('cpu') != null) lines.add('CPU   ${v('cpu')}');
    if (v('ram') != null) lines.add('RAM   ${v('ram')}');
    if (v('disk') != null) lines.add('Disk  ${v('disk')}');
    if (v('uptime') != null) lines.add('Up    ${v('uptime')}');
    if (lines.isNotEmpty) {
      store.set(systemSourceId, 'summary', value: lines.join('\n'));
    }
  }

  // --- Linux ---------------------------------------------------------------
  Future<void> _sampleLinux() async {
    try {
      final stat = await File('/proc/stat').readAsString();
      final sample = SystemMetrics.parseProcStatCpu(stat.split('\n').first);
      if (sample != null) {
        if (_prevCpu != null) {
          _put('cpu', '${SystemMetrics.cpuPercent(_prevCpu!, sample).round()}%');
        }
        _prevCpu = sample;
      }
    } catch (_) {}

    try {
      final mem = SystemMetrics.parseMemInfo(
          await File('/proc/meminfo').readAsString());
      if (mem != null) {
        _put('ram',
            SystemMetrics.formatGbPair(mem.usedKb, mem.totalKb));
      }
    } catch (_) {}

    try {
      final up = await File('/proc/uptime').readAsString();
      final secs = double.tryParse(up.split(' ').first);
      if (secs != null) {
        _put('uptime',
            SystemMetrics.formatUptime(Duration(seconds: secs.round())));
      }
    } catch (_) {}

    try {
      final net = SystemMetrics.parseProcNetDev(
          await File('/proc/net/dev').readAsString());
      if (net != null) _putNetDelta(net.rx, net.tx);
    } catch (_) {}

    try {
      // First battery that reports a capacity (laptops only).
      for (final dir in Directory('/sys/class/power_supply').listSync()) {
        final cap = File('${dir.path}/capacity');
        if (cap.existsSync()) {
          final pct = SystemMetrics.parseBatteryCapacity(cap.readAsStringSync());
          if (pct != null) {
            _put('battery', '$pct%');
            break;
          }
        }
      }
    } catch (_) {}

    await _putDf();
  }

  Future<void> _putDf() async {
    try {
      final df = await Process.run('df', ['-k', '/']);
      final pct = SystemMetrics.parseDfPercent(df.stdout.toString());
      if (pct != null) _put('disk', '$pct%');
    } catch (_) {}
  }

  // --- macOS ---------------------------------------------------------------
  Future<void> _sampleMacOS() async {
    try {
      final top = await Process.run('top', ['-l', '1', '-n', '0']);
      final m = RegExp(r'CPU usage:.*?([\d.]+)%\s*idle')
          .firstMatch(top.stdout.toString());
      if (m != null) {
        final idle = double.tryParse(m.group(1)!) ?? 0;
        _put('cpu', '${(100 - idle).round()}%');
      }
    } catch (_) {}

    try {
      final total = await Process.run('sysctl', ['-n', 'hw.memsize']);
      final bytes = int.tryParse(total.stdout.toString().trim());
      if (bytes != null) {
        _put('ram', 'of ${SystemMetrics.formatGbFromBytes(bytes)}');
      }
    } catch (_) {}

    try {
      final boot = await Process.run('sysctl', ['-n', 'kern.boottime']);
      final m = RegExp(r'sec\s*=\s*(\d+)').firstMatch(boot.stdout.toString());
      if (m != null) {
        final bootSec = int.parse(m.group(1)!);
        final secs = DateTime.now().millisecondsSinceEpoch ~/ 1000 - bootSec;
        _put('uptime', SystemMetrics.formatUptime(Duration(seconds: secs)));
      }
    } catch (_) {}

    try {
      final batt = await Process.run('pmset', ['-g', 'batt']);
      _put('battery', SystemMetrics.parsePmsetBattery(batt.stdout.toString()));
    } catch (_) {}

    try {
      // `netstat -ib` reports cumulative bytes; sum the non-loopback rows.
      final out = await Process.run('netstat', ['-ib']);
      var rx = 0, tx = 0;
      final seen = <String>{};
      for (final line in out.stdout.toString().split('\n').skip(1)) {
        final cols = line.trim().split(RegExp(r'\s+'));
        if (cols.length < 10 || cols[0] == 'lo0' || !seen.add(cols[0])) continue;
        final ibytes = int.tryParse(cols[6]);
        final obytes = int.tryParse(cols[9]);
        if (ibytes != null && obytes != null) {
          rx += ibytes;
          tx += obytes;
        }
      }
      if (rx > 0 || tx > 0) _putNetDelta(rx, tx);
    } catch (_) {}

    await _putDf();
  }

  // --- Windows -------------------------------------------------------------
  Future<void> _sampleWindows() async {
    const script = r'''
$cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
$os = Get-CimInstance Win32_OperatingSystem
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
$up = [int]((Get-Date) - $os.LastBootUpTime).TotalSeconds
$ni = Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface
$rx = [int64](($ni | Measure-Object -Property BytesReceivedPersec -Sum).Sum)
$tx = [int64](($ni | Measure-Object -Property BytesSentPersec -Sum).Sum)
$bat = (Get-CimInstance Win32_Battery | Measure-Object -Property EstimatedChargeRemaining -Average).Average
Write-Output "cpu=$cpu"
Write-Output "memFree=$($os.FreePhysicalMemory)"
Write-Output "memTotal=$($os.TotalVisibleMemorySize)"
Write-Output "diskSize=$($disk.Size)"
Write-Output "diskFree=$($disk.FreeSpace)"
Write-Output "uptime=$up"
Write-Output "netRx=$rx"
Write-Output "netTx=$tx"
Write-Output "battery=$bat"
''';
    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', script],
    );
    final m = SystemMetrics.parseCimList(result.stdout.toString());

    final cpu = m['cpu'];
    if (cpu != null) _put('cpu', '${double.tryParse(cpu)?.round() ?? cpu}%');

    final memTotal = int.tryParse(m['memTotal'] ?? '');
    final memFree = int.tryParse(m['memFree'] ?? '');
    if (memTotal != null && memFree != null) {
      _put('ram',
          SystemMetrics.formatGbPair(memTotal - memFree, memTotal));
    }

    final diskSize = int.tryParse(m['diskSize'] ?? '');
    final diskFree = int.tryParse(m['diskFree'] ?? '');
    if (diskSize != null && diskFree != null && diskSize > 0) {
      _put('disk', '${((diskSize - diskFree) / diskSize * 100).round()}%');
    }

    final up = int.tryParse(m['uptime'] ?? '');
    if (up != null) {
      _put('uptime', SystemMetrics.formatUptime(Duration(seconds: up)));
    }

    // Perf counters are already per-second rates.
    final rx = int.tryParse(m['netRx'] ?? '');
    final tx = int.tryParse(m['netTx'] ?? '');
    if (rx != null && tx != null) _putNetRate(rx, tx);

    final bat = m['battery'];
    if (bat != null && bat.isNotEmpty) {
      _put('battery', '${double.tryParse(bat)?.round() ?? bat}%');
    }
  }
}
