import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/server/system_info.dart';
import 'package:tilepad/src/server/plugins/state_store.dart';

void main() {
  group('SystemInfoService', () {
    test('publishes host into the store on start', () {
      final store = StateStore();
      final svc = SystemInfoService(store, interval: const Duration(hours: 1));
      svc.start();
      addTearDown(svc.stop);
      expect(store.get(systemSourceId, 'host'), isNotNull);
    });

    test('presets include the combined monitor + every metric', () {
      final ids = systemPresetButtons()
          .map((b) => b.stateBinding?.stateId)
          .toSet();
      expect(ids, containsAll(systemStates.map((s) => s.id)));
      expect(ids, contains(systemSummaryStateId));
      expect(systemPresetButtons().first.stateBinding?.stateId,
          systemSummaryStateId); // monitor first
    });
  });

  group('CPU (/proc/stat)', () {
    test('parses totals and computes % from two samples', () {
      final a = SystemMetrics.parseProcStatCpu('cpu  100 0 100 800 0 0 0 0');
      final b = SystemMetrics.parseProcStatCpu('cpu  200 0 200 1500 0 0 0 0');
      expect(a, isNotNull);
      expect(b, isNotNull);
      // total delta 900, idle delta 700 -> ~22.2% busy
      final pct = SystemMetrics.cpuPercent(a!, b!);
      expect(pct, closeTo(22.2, 0.5));
    });

    test('returns null for a non-cpu line', () {
      expect(SystemMetrics.parseProcStatCpu('intr 12345'), isNull);
    });
  });

  group('RAM (/proc/meminfo)', () {
    test('parses total and available', () {
      const content =
          'MemTotal:       16384000 kB\nMemFree: 1000 kB\nMemAvailable:    8000000 kB\n';
      final mem = SystemMetrics.parseMemInfo(content);
      expect(mem, isNotNull);
      expect(mem!.totalKb, 16384000);
      expect(mem.usedKb, 16384000 - 8000000);
    });
  });

  group('Disk (df)', () {
    test('parses the use percentage', () {
      const df = 'Filesystem 1K-blocks Used Available Use% Mounted on\n'
          '/dev/sda1 500000000 380000000 120000000 76% /\n';
      expect(SystemMetrics.parseDfPercent(df), 76);
    });
  });

  group('Windows CIM key=value', () {
    test('parses a Format-List block', () {
      const out = 'LoadPercentage : 42\n\nName : Intel\n';
      final map = SystemMetrics.parseCimList(out);
      expect(map['LoadPercentage'], '42');
      expect(map['Name'], 'Intel');
    });
  });

  group('formatting', () {
    test('formats GB from kB', () {
      expect(SystemMetrics.formatGbFromKb(16384000), '15.6 GB');
    });

    test('formats uptime', () {
      expect(SystemMetrics.formatUptime(const Duration(minutes: 45)), '45m');
      expect(
          SystemMetrics.formatUptime(const Duration(hours: 3, minutes: 12)),
          '3h 12m');
      expect(
          SystemMetrics.formatUptime(const Duration(days: 1, hours: 2)),
          '1d 2h');
    });
  });

  group('systemStates', () {
    test('exposes the expected states', () {
      final ids = systemStates.map((s) => s.id).toSet();
      expect(
          ids,
          containsAll(
              ['cpu', 'ram', 'disk', 'uptime', 'host', 'clock', 'battery', 'net']));
      expect(systemSourceId, 'system');
    });
  });

  group('clock', () {
    test('formats 12-hour time with AM/PM', () {
      expect(SystemMetrics.formatClock(DateTime(2026, 6, 3, 9, 5)), '9:05 AM');
      expect(SystemMetrics.formatClock(DateTime(2026, 6, 3, 13, 0)), '1:00 PM');
      expect(SystemMetrics.formatClock(DateTime(2026, 6, 3, 0, 30)), '12:30 AM');
    });
  });

  group('battery (/sys + pmset)', () {
    test('parses a capacity file', () {
      expect(SystemMetrics.parseBatteryCapacity('87\n'), 87);
      expect(SystemMetrics.parseBatteryCapacity('garbage'), isNull);
    });

    test('parses pmset battery output', () {
      const out =
          "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=123)\t72%; discharging; 3:21 remaining present: true";
      expect(SystemMetrics.parsePmsetBattery(out), '72%');
    });
  });

  group('network (/proc/net/dev)', () {
    const sample = 'Inter-|   Receive                                                |  Transmit\n'
        ' face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets\n'
        '    lo: 12345 100 0 0 0 0 0 0 12345 100\n'
        '  eth0: 1000 10 0 0 0 0 0 0 2000 20\n';

    test('sums rx/tx bytes across non-loopback interfaces', () {
      final t = SystemMetrics.parseProcNetDev(sample);
      expect(t, isNotNull);
      expect(t!.rx, 1000);
      expect(t.tx, 2000);
    });

    test('formats a byte rate', () {
      expect(SystemMetrics.formatRate(512), '512 B/s');
      expect(SystemMetrics.formatRate(2048), '2.0 KB/s');
      expect(SystemMetrics.formatRate(5 * 1024 * 1024), '5.0 MB/s');
    });
  });
}
