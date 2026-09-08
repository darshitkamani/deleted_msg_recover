import 'dart:async';

import 'package:flutter/material.dart';

import 'ads_service.dart';

/// Displays [AdsService.nativeAd], remounting it a few times if it comes up
/// empty.
///
/// The `preload_google_ads` native ad widget only checks whether a preloaded
/// ad is already available in its own `initState` -- if the ad is still in
/// flight the moment this first mounts, it renders nothing and never checks
/// again on its own. Since this slot lives inside [HomeShell]
/// (lib/features/home_shell.dart), which is built once for the life of the
/// app and never recreated, without this retry it would stay blank for the
/// rest of the session whenever the ad wasn't ready on the very first frame.
class NativeAdSlot extends StatefulWidget {
  const NativeAdSlot({super.key});

  @override
  State<NativeAdSlot> createState() => _NativeAdSlotState();
}

class _NativeAdSlotState extends State<NativeAdSlot> {
  // Generous and increasingly spaced out: a cold-start ad request can take
  // well past 10-15s once SDK init, network handshake and the ad call
  // itself are all stacked on top of each other, so a couple of quick
  // retries isn't enough -- this keeps trying for a few minutes before
  // giving up for the session.
  static const _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 90),
  ];

  final _slotKey = GlobalKey();
  int _generation = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_generation >= _retryDelays.length) {
      debugPrint('[Ads] native: giving up after ${_retryDelays.length} empty attempts');
      return;
    }
    _timer = Timer(_retryDelays[_generation], _retryIfEmpty);
  }

  void _retryIfEmpty() {
    if (!mounted) return;
    final renderBox = _slotKey.currentContext?.findRenderObject() as RenderBox?;
    // The ad widget renders as a zero-height SizedBox.shrink() until an ad
    // has actually loaded, so any non-zero height here means one is already
    // showing -- stop remounting so a good ad is never torn down and
    // re-fetched for no reason.
    if (renderBox != null && renderBox.hasSize && renderBox.size.height > 0) {
      debugPrint('[Ads] native: showing (attempt ${_generation + 1})');
      return;
    }
    debugPrint('[Ads] native: still empty after attempt ${_generation + 1}, retrying');
    setState(() => _generation++);
    _scheduleRetry();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The key changes on each retry so the underlying ad widget is a fresh
    // element with a fresh initState, forcing it to re-check for a loaded ad.
    return KeyedSubtree(
      key: ValueKey(_generation),
      child: SizedBox(key: _slotKey, child: AdsService.instance.nativeAd()),
    );
  }
}
