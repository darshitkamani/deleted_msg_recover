import 'package:preload_google_ads/preload_google_ads.dart';

import 'ads_service.dart';
import 'native_placement.dart';

export 'native_placement.dart';

/// A native ad slot for one [placement] in the app. Builds nothing until ads
/// are set up ([AdsService.ready]), and nothing at all if the config switches
/// that placement off ([AdsService.showsNativeAt]) -- no request, and no
/// frame left behind: [builder], if given, wraps the ad in its frame or
/// "Sponsored" label, and goes away with it.
///
/// Every native ad in the app goes through this rather than calling
/// `PreloadGoogleAds.instance.showNativeAd()` directly: a slot built before
/// set-up (e.g. the splash ending before the ad config download does) would
/// fire a request that fails straight away and then retries on the
/// package's defaults.
class NativeAdSlot extends StatelessWidget {
  final NativePlacement placement;
  final Widget Function(BuildContext context, Widget ad)? builder;

  const NativeAdSlot({super.key, required this.placement, this.builder});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdsService.instance.ready,
      builder: (context, ready, _) {
        if (!ready || !AdsService.instance.showsNativeAt(placement)) {
          return const SizedBox.shrink();
        }
        final ad = PreloadGoogleAds.instance.showNativeAd();
        return builder?.call(context, ad) ?? ad;
      },
    );
  }
}
