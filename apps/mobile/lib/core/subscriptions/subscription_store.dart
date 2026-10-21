import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/subscriptions/subscriptions_repository.dart';

class SubscriptionStore extends ChangeNotifier {
  SubscriptionStore._();

  static final SubscriptionStore instance = SubscriptionStore._();

  final SubscriptionsRepository _repo = SubscriptionsRepository();
  final Set<String> _subscribedCreatorIds = <String>{};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  Set<String> get subscribedCreatorIds => Set.unmodifiable(_subscribedCreatorIds);

  bool isSubscribedTo(String? creatorId) {
    if (creatorId == null || creatorId.isEmpty) return false;
    return _subscribedCreatorIds.contains(creatorId);
  }

  void addSubscribedCreator(String creatorId) {
    if (creatorId.isEmpty) return;
    if (_subscribedCreatorIds.add(creatorId)) {
      notifyListeners();
    }
  }

  void removeSubscribedCreator(String creatorId) {
    if (creatorId.isEmpty) return;
    if (_subscribedCreatorIds.remove(creatorId)) {
      notifyListeners();
    }
  }

  void clear() {
    _subscribedCreatorIds.clear();
    _loaded = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final subs = await _repo.listMine(limit: 100);
      _subscribedCreatorIds.clear();
      for (final sub in subs) {
        final cid = sub.creatorId.trim();
        if (cid.isNotEmpty) {
          final s = sub.status?.toLowerCase();
          if (s == null || s == 'active' || s == 'trialing' || s == 'paid') {
            _subscribedCreatorIds.add(cid);
          }
        }
      }
      _loaded = true;
      notifyListeners();
    } catch (_) {}
  }
}
