import 'package:flutter/foundation.dart';

class FeedSoundStore extends ChangeNotifier {
  FeedSoundStore._();
  static final FeedSoundStore instance = FeedSoundStore._();

  bool _muted = true;

  bool get muted => _muted;

  void setMuted(bool value) {
    if (_muted == value) return;
    _muted = value;
    notifyListeners();
  }

  void toggle() => setMuted(!_muted);

  double get volume => _muted ? 0 : 1;
}
