import 'dart:math' as math;

/// Heights for the native ad slot that fit the ad drawn inside it exactly.
///
/// `preload_google_ads` draws its native ad from an Android template laid out in `sdp`
/// units, but wraps it in a Flutter box whose height is capped at a fixed 265dp (medium) /
/// 135dp (small). Whether that fits depends on the device, so the ad was cut off on some
/// phones -- the install button lost -- and left a gap under it on others.
///
/// `sdp` does NOT scale smoothly with screen width. The library ships fixed value tables
/// every 30dp of smallest width (300, 330, 360, 390, 420, ...) and Android picks the largest
/// one that is not wider than the device -- so a 411dp phone uses the 390 table (1.3x), not
/// 1.37x, and a 432dp phone the 420 table (1.4x). Every dimen in a table is its number times
/// bucket/300 (e.g. `_100sdp` = 130dp in the 390 table), so the exact height follows.
///
/// The box is always exactly as tall as its maximum (the ad view fills it, drawn from the
/// top), so any height above what the template needs shows up as empty space under the ad.
/// The templates' heights are fixed sdp values -- every text line and view has a set size,
/// nothing depends on the ad's text or font scale -- so an exact fit is safe.
class NativeAdHeights {
  final double medium;
  final double small;

  const NativeAdHeights({required this.medium, required this.small});

  /// Template content, in sdp: media 100 + icon row (45 + 8 + 8) + button 32.
  static const _mediumTemplateSdp = 193.0;

  /// Template content, in sdp: icon row (45 + 8 + 8) + button 32.
  static const _smallTemplateSdp = 93.0;

  /// The slot wraps the ad in 5dp of padding on every side.
  static const _shellPadding = 10.0;

  /// Only covers pixel rounding of the individual views.
  static const _slack = 2.0;

  /// The library's value tables start at 300dp and step by 30dp.
  static const _baseBucketDp = 300;
  static const _bucketStepDp = 30;

  factory NativeAdHeights.forSmallestWidthDp(double smallestWidthDp) {
    // Android reports smallest width as a whole number of dp, and picks the largest table
    // that doesn't exceed it. Below the first table it just uses the base values.
    final bucketDp = math.max(
      _baseBucketDp,
      (smallestWidthDp.floor() ~/ _bucketStepDp) * _bucketStepDp,
    );
    final sdp = bucketDp / _baseBucketDp;
    double fit(double templateSdp) => templateSdp * sdp + _shellPadding + _slack;
    return NativeAdHeights(
      medium: fit(_mediumTemplateSdp),
      small: fit(_smallTemplateSdp),
    );
  }
}
