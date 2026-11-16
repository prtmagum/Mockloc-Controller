import 'dart:async';

import 'package:location_core/location_core.dart';

/// Broadcast yang langsung mengirim nilai (atau error) terakhir ke pendengar
/// baru, seperti GPS yang langsung memberi fix terakhir saat di-subscribe.
class LatestFix {
  LatestFix({void Function()? onStart, void Function()? onStop})
      : _ctrl = StreamController<LocationFix>.broadcast(onListen: onStart, onCancel: onStop);

  final StreamController<LocationFix> _ctrl;
  LocationFix? _fix;
  Object? _error;

  LocationFix? get fix => _fix;
  Object? get error => _error;

  void add(LocationFix fix) {
    _fix = fix;
    _error = null;
    _ctrl.add(fix);
  }

  void addError(Object error) {
    _fix = null;
    _error = error;
    _ctrl.addError(error);
  }

  void reset() {
    _fix = null;
    _error = null;
  }

  Stream<LocationFix> stream() => Stream.multi((c) {
        final error = _error, fix = _fix;
        if (error != null) {
          c.addError(error);
        } else if (fix != null) {
          c.add(fix);
        }
        final sub = _ctrl.stream.listen(c.add, onError: c.addError, onDone: c.close);
        c.onCancel = sub.cancel;
      });
}
