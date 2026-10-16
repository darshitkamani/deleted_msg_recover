import 'package:preload_google_ads/preload_google_ads.dart';

import 'ads_service.dart';

/// A native ad slot that only builds once ads are set up
/// ([AdsService.ready]) -- empty until then. Every native ad in the app goes
/// through this rather than calling `PreloadGoogleAds.instance.showNativeAd()`
/// directly: a slot built before set-up (e.g. the splash ending before the
/// ad config download does) would fire a request that fails straight away
/// and then retries on the package's defaults.
class NativeAdSlot extends StatelessWidget {
  const NativeAdSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdsService.instance.ready,
      builder: (context, ready, _) => ready
          ? PreloadGoogleAds.instance.showNativeAd()
          : const SizedBox.shrink(),
    );
  }
}
