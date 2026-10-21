class ContentUnlockStore {
  ContentUnlockStore._();

  static final Set<String> _unlocked = {};

  static String _key(String targetType, String id) => '$targetType:$id';

  static bool isUnlocked(String targetType, String id) {
    if (targetType.isEmpty || id.isEmpty) return false;
    return _unlocked.contains(_key(targetType, id));
  }

  static void mark(String targetType, String id) {
    if (targetType.isEmpty || id.isEmpty) return;
    _unlocked.add(_key(targetType, id));
  }

  static void clear(String targetType, String id) {
    _unlocked.remove(_key(targetType, id));
  }
}
