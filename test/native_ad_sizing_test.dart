import 'package:flutter_test/flutter_test.dart';

import 'package:deleted_msg_recover/core/ads/native_ad_sizing.dart';

// Expected values below come from the sdp library's own value tables (sdp-android 1.1.0),
// e.g. values-sw390dp: _100sdp=130dp, _45sdp=58.5dp, _8sdp=10.4dp, _32sdp=41.6dp.
// Medium template = media 100 + icon row (45 + 8 top + 8 bottom) + button 32.
// Small template  = icon row (45 + 8 + 8) + button 32.
// The slot adds 10dp of padding and the sizing adds 2dp for pixel rounding.
void main() {
  const chrome = 10 + 2;

  test('Pixel 7 (1080px @ 420dpi = 411dp) uses the 390 table, not 411/300', () {
    final h = NativeAdHeights.forSmallestWidthDp(411.4);
    expect(h.medium, closeTo(130 + 2 * 10.4 + 58.5 + 41.6 + chrome, 0.001));
    expect(h.small, closeTo(2 * 10.4 + 58.5 + 41.6 + chrome, 0.001));
  });

  test('a 432dp phone (Pixel 3a XL) uses the 420 table and exceeds the old 265 cap', () {
    final h = NativeAdHeights.forSmallestWidthDp(432);
    expect(h.medium, closeTo(140 + 2 * 11.2 + 63 + 44.8 + chrome, 0.001));
    // What was clipped: the template needs 270.2dp against 255dp left inside a 265dp box.
    expect(h.medium, greaterThan(265));
  });

  test('changes exactly at the 30dp bucket boundaries', () {
    // 389.9dp reports as 389 -> 360 table; 390 -> 390 table.
    final below = NativeAdHeights.forSmallestWidthDp(389.9);
    final at = NativeAdHeights.forSmallestWidthDp(390);
    expect(below.medium, closeTo(193 * 1.2 + chrome, 0.001));
    expect(at.medium, closeTo(193 * 1.3 + chrome, 0.001));
  });

  test('narrow phones fit exactly too, not the old 265/135 defaults', () {
    final h = NativeAdHeights.forSmallestWidthDp(360);
    expect(h.medium, closeTo(193 * 1.2 + chrome, 0.001));
    expect(h.small, closeTo(93 * 1.2 + chrome, 0.001));
    expect(h.small, lessThan(135));
  });

  test('never uses a table below the 300dp base', () {
    final base = NativeAdHeights.forSmallestWidthDp(300);
    final narrower = NativeAdHeights.forSmallestWidthDp(240);
    expect(narrower.medium, base.medium);
    expect(narrower.small, base.small);
    expect(base.medium, closeTo(193 + chrome, 0.001));
  });

  test('grows with the screen so wider devices are not clipped either', () {
    final phone = NativeAdHeights.forSmallestWidthDp(411);
    final tablet = NativeAdHeights.forSmallestWidthDp(600);
    expect(tablet.medium, greaterThan(phone.medium));
    expect(tablet.small, greaterThan(phone.small));
  });
}
