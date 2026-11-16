import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_core/location_core.dart';
import 'package:mock_location_kit/mock_location_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeReal implements LocationSource {
  int listeners = 0;
  final _ctrl = StreamController<LocationFix>.broadcast();

  @override
  Stream<LocationFix> watch() => Stream.multi((c) {
        listeners++;
        final sub = _ctrl.stream.listen(c.add);
        c.onCancel = () {
          listeners--;
          return sub.cancel();
        };
      });

  @override
  Future<LocationFix> current() => watch().first;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('mode mock berhenti berlangganan ke GPS asli', () async {
    final real = _FakeReal();
    final source = SwitchableLocationSource(real: real, mock: PanelLocationSource());
    final sub = source.watch().listen((_) {});
    await _settle();
    expect(real.listeners, 1);

    source.mode.value = MockMode.panel;
    await _settle();
    expect(real.listeners, 0);

    source.mode.value = MockMode.real;
    await _settle();
    expect(real.listeners, 1);
    await sub.cancel();
  });

  test('panel mengirim titik dan error ke pendengar', () async {
    final panel = PanelLocationSource();
    final events = <Object>[];
    final sub = panel.watch().listen(events.add, onError: events.add);
    panel.setPoint(const MockPoint(id: 'a', name: 'Rumah', group: 'Rumah', lat: -6.9, lng: 108.4));
    panel.setError(const GpsPermissionDeniedException());
    await _settle();
    expect(events.first, isA<LocationFix>().having((f) => f.isMock, 'isMock', isTrue));
    expect(events.last, isA<GpsPermissionDeniedException>());
    await sub.cancel();
  });

  test('decodeControllerFix memetakan error Controller', () {
    expect(() => decodeControllerFix({'error': 'service_disabled'}), throwsA(isA<GpsDisabledException>()));
    expect(() => decodeControllerFix({'error': 'permission_denied'}),
        throwsA(isA<GpsPermissionDeniedException>()));
    final fix = decodeControllerFix({'lat': -6.9, 'lng': 108.4, 'accuracy': 10.0, 'time': 1700000000000});
    expect(fix.isMock, isTrue);
    expect(fix.lat, -6.9);
  });

  test('PointStore: nama duplikat di grup yang sama diberi akhiran', () async {
    final store = PointStore();
    await store.add(name: 'Rumah', group: 'Rumah', lat: 1, lng: 2);
    final dup = await store.add(name: 'Rumah', group: 'Rumah', lat: 1, lng: 2);
    final other = await store.add(name: 'Rumah', group: 'Kantor', lat: 1, lng: 2);
    expect(dup.name, 'Rumah (2)');
    expect(other.name, 'Rumah');
    expect(store.nextDefaultName(), 'Titik 1');
  });

  test('PointStore: impor CSV lalu ekspor JSON dan impor lagi', () async {
    final store = PointStore();
    final report = await store.importText('nama,lat,lng\nA,-6.1,106.8\nB,x,y\n');
    expect(report.added, 1);
    expect(report.badLines, [3]);
    final again = PointStore(prefsKey: 'other');
    await again.importText(store.exportJson());
    expect(again.points.single.name, 'A');
  });
}
