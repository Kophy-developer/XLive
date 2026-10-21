import 'package:flutter/foundation.dart';

class AgoraStreamController extends ChangeNotifier {
  bool _talkBackActive = false;
  bool _micPublishEnabled = false;
  bool _hostMicEnabled = true;
  bool _hostCameraEnabled = true;
  bool _screenShareActive = false;
  bool _canFlipCamera = false;
  final Set<int> _remoteScreenUids = <int>{};
  bool _disposed = false;

  bool get talkBackActive => _talkBackActive;
  bool get micPublishEnabled => _micPublishEnabled;
  bool get hostMicEnabled => _hostMicEnabled;
  bool get hostCameraEnabled => _hostCameraEnabled;
  bool get screenShareActive => _screenShareActive;
  bool get hasRemoteScreenShare => _remoteScreenUids.isNotEmpty;
  bool get canFlipCamera => _canFlipCamera;

  void setCanFlipCamera(bool value) {
    if (_canFlipCamera == value) return;
    _canFlipCamera = value;
    notifyListeners();
  }

  void setTalkBackActive(bool value) {
    if (_talkBackActive == value) return;
    _talkBackActive = value;
    if (!value) _micPublishEnabled = false;
    notifyListeners();
  }

  void setMicPublishEnabled(bool value) {
    if (_micPublishEnabled == value) return;
    _micPublishEnabled = value;
    notifyListeners();
  }

  void setHostMicEnabled(bool value) {
    if (_hostMicEnabled == value) return;
    _hostMicEnabled = value;
    notifyListeners();
  }

  void setHostCameraEnabled(bool value) {
    if (_hostCameraEnabled == value) return;
    _hostCameraEnabled = value;
    notifyListeners();
  }

  void setScreenShareActive(bool value) {
    if (_screenShareActive == value) return;
    _screenShareActive = value;
    notifyListeners();
  }

  void markRemoteScreenShare(int uid, bool active) {
    final before = _remoteScreenUids.length;
    if (active) {
      _remoteScreenUids.add(uid);
    } else {
      _remoteScreenUids.remove(uid);
    }
    if (_remoteScreenUids.length != before) notifyListeners();
  }

  void tearDown() {
    if (_disposed) return;
    _talkBackActive = false;
    _micPublishEnabled = false;
    _screenShareActive = false;
    _canFlipCamera = false;
    _remoteScreenUids.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
