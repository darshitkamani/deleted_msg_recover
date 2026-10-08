import 'package:flutter/foundation.dart';

/// Meta ad formats as the bridge knows them -- the names match the `format`
/// strings MetaAdsBridge.kt reports impressions/clicks under.
enum MetaAdFormat {
  native('Native'),
  nativeBanner('Native Banner'),
  interstitial('Interstitial'),
  banner('Banner'),
  mediumRectangle('Med. Rectangle');

  const MetaAdFormat(this.label);

  final String label;
}

/// Running counts for one format since launch.
class MetaFormatStats {
  final requests = ValueNotifier(0);
  final loaded = ValueNotifier(0);
  final failed = ValueNotifier(0);
  final impressions = ValueNotifier(0);
  final clicks = ValueNotifier(0);

  /// Times this format fell back to AdMob after a Meta error.
  final fallbacks = ValueNotifier(0);

  late final Listenable all = Listenable.merge([
    requests,
    loaded,
    failed,
    impressions,
    clicks,
    fallbacks,
  ]);
}

/// Meta-side counters behind the Meta Ad Lab overlay (meta_ad_lab.dart) --
/// the Meta counterpart of preload_google_ads' AdStats.
class MetaAdStats {
  MetaAdStats._();

  static final instance = MetaAdStats._();

  final Map<MetaAdFormat, MetaFormatStats> byFormat = {
    for (final format in MetaAdFormat.values) format: MetaFormatStats(),
  };

  /// The most recent Meta error ("Native Banner: 1001 No fill"), for the lab.
  final lastError = ValueNotifier<String?>(null);

  /// Whether the SDK initialized; null until init has answered.
  final initialized = ValueNotifier<bool?>(null);

  MetaFormatStats operator [](MetaAdFormat format) => byFormat[format]!;

  void recordError(MetaAdFormat format, String error) {
    this[format].failed.value++;
    lastError.value = '${format.label}: $error';
  }

  /// [format] is the MetaAdFormat name, [event] "impression" or "click".
  void recordEvent(String format, String event) {
    final match = MetaAdFormat.values.where((f) => f.name == format);
    if (match.isEmpty) return;
    final stats = this[match.first];
    if (event == 'impression') stats.impressions.value++;
    if (event == 'click') stats.clicks.value++;
  }
}
