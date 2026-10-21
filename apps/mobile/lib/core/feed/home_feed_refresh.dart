import 'dart:async';

import '../../features/feed/feed_repository.dart';

class HomeFeedRefresh {
  HomeFeedRefresh._();

  static final HomeFeedRefresh instance = HomeFeedRefresh._();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void request() {
    FeedRepository.clearCache();
    if (!_controller.isClosed) _controller.add(null);
  }
}
