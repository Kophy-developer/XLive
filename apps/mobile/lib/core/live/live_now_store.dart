import '../../features/feed/feed_repository.dart';

class LiveNowStore {
  LiveNowStore._();

  static final LiveNowStore instance = LiveNowStore._();

  final Set<String> _liveCreatorIds = <String>{};
  DateTime? _fetchedAt;
  Future<void>? _inFlight;

  bool isLive(String? userId) {
    final id = userId?.trim();
    if (id == null || id.isEmpty) return false;
    return _liveCreatorIds.contains(id);
  }

  Future<void> refresh({bool force = false}) async {
    if (!force && _fetchedAt != null && DateTime.now().difference(_fetchedAt!) < const Duration(seconds: 45)) {
      return;
    }
    final existing = _inFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final future = _doRefresh();
    _inFlight = future;
    try {
      await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<void> _doRefresh() async {
    try {
      final items = await FeedRepository().getLive(limit: 50);
      _liveCreatorIds
        ..clear()
        ..addAll(items.map((e) => e.creatorId?.trim()).whereType<String>().where((e) => e.isNotEmpty));
      _fetchedAt = DateTime.now();
    } catch (_) {}
  }
}
