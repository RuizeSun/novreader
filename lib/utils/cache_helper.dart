import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A simple cache helper that stores JSON-serializable data in
/// SharedPreferences with an expiration time (TTL).
///
/// The cache key is prefixed with `cache_` to avoid collisions with other
/// preferences. Each entry stores a JSON object with two fields:
///   - `data`: the actual cached payload (must be JSON‑serializable)
///   - `expiry`: epoch milliseconds indicating when the entry becomes stale.
class CacheHelper {
  static const _prefix = 'cache_';

  /// Retrieves a cached value of type [T] for the given [key].
  /// Returns `null` if the entry does not exist, is malformed, or has expired.
  static Future<T?> get<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefix + key);
    if (raw == null) return null;
    try {
      final Map<String, dynamic> wrapper =
          json.decode(raw) as Map<String, dynamic>;
      final int expiry = wrapper['expiry'] as int;
      final int now = DateTime.now().millisecondsSinceEpoch;
      if (now > expiry) {
        // Expired – clean up.
        await prefs.remove(_prefix + key);
        return null;
      }
      final dynamic data = wrapper['data'];
      return data as T;
    } catch (_) {
      // If parsing fails, treat as a miss and remove the corrupted entry.
      await prefs.remove(_prefix + key);
      return null;
    }
  }

  /// Stores [data] under [key] for the duration specified by [ttl].
  /// The [data] must be JSON‑serializable (e.g., primitives, List, Map, or
  /// objects that provide a `toJson` method and are converted before calling).
  static Future<void> set<T>(String key, T data, Duration ttl) async {
    final prefs = await SharedPreferences.getInstance();
    final int expiry = DateTime.now().add(ttl).millisecondsSinceEpoch;
    final Map<String, dynamic> wrapper = {'data': data, 'expiry': expiry};
    await prefs.setString(_prefix + key, json.encode(wrapper));
  }
}
