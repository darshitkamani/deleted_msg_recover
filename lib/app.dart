import 'dart:math';

import 'package:flutter/material.dart';
import 'package:preload_google_ads/preload_google_ads.dart' hide AppState;
import 'package:provider/provider.dart';

import 'core/ads/ads_service.dart';
import 'core/app_state.dart';
import 'core/update/update_service.dart';
import 'features/apptour/app_tour_screen.dart';
import 'features/home_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/unsupported/ios_unsupported_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'widgets/update_ready_banner.dart';

class RecoverApp extends StatelessWidget {
  const RecoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: Consumer<AppState>(
        builder: (context, appState, _) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
          locale: appState.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [_InterstitialAdNavigatorObserver()],
          home: const _RootRouter(),
        ),
      ),
    );
  }
}

/// Shows a preloaded interstitial ad on every 5th screen navigation, app
/// wide -- see AdsService's `interstitialCounter: 5`, which is what actually
/// makes it "every 5th" (the package's own showInter() counts calls
/// internally and only shows once that threshold is hit, then resets), so
/// this observer's only job is to report each navigation.
///
/// Only `PageRoute` pushes count -- a `showDialog` (e.g. the exit
/// confirmation dialogs) pushes a `DialogRoute`/`PopupRoute`, not a
/// `PageRoute`, so those aren't real screen navigations and don't consume a
/// count.
class _InterstitialAdNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      PreloadGoogleAds.instance.showInterstitialAd(callBack: (ad, error) {});
    }
  }
}

class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  bool _splashMinTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    // A random 3-5s floor under the splash -- purely cosmetic pacing, not
    // tied to how long AppState/ads actually take to be ready.
    final splashDuration = Duration(
      milliseconds: 3000 + Random().nextInt(2001),
    );
    Future.delayed(splashDuration, () {
      if (mounted) setState(() => _splashMinTimeElapsed = true);
    });
    // Kicked off right away so the SDK is already warm by the time the user
    // reaches HomeShell, instead of only starting that network round trip
    // once onboarding/app-tour are behind them. AdsService.init() is
    // idempotent, so this is safe even though the splash itself never shows
    // an ad.
    //
    // AdsService.init() also starts exitDialogAdPreloader loading as part of
    // its own chain -- that's the ad every exit-confirmation dialog in the
    // app shows (see AdsService.exitDialogAdPreloader's doc comment), and
    // its load/fail is also exactly what the splash gate below is waiting
    // to react to. There's deliberately no separate "probe" load here
    // anymore: that would just be a second, wasted medium native ad request
    // duplicating one this app is already making for a real reason.
    AdsService.instance.init().then((_) {
      // Warms up the rewarded interstitial (shown before a status
      // download/share -- see StatusesScreen) along with anything else not
      // already loading, so it's more likely to already be sitting ready by
      // the time the user actually taps download/share, instead of only
      // starting that request on the very first tap and showing nothing for
      // it.
      PreloadGoogleAds.instance.reloadUnloadedAds();
    });

    // Held here (rather than gating only on AppState.ready) so the very
    // first medium native ad slot the user reaches -- RecoverScreen's --
    // already has an ad sitting in the preload queue instead of rendering
    // empty for a beat. Leaves as soon as this attempt is settled one way
    // or the other -- loaded, or failed -- rather than only reacting to
    // success and otherwise always sitting through the full timeout below
    // even when the ad has clearly already failed (e.g. no network).

    // Checked from app launch, not just once HomeShell is reached -- an
    // "immediate" (blocking) update is meant to gate the whole app as soon
    // as possible, not only once the user has clicked through onboarding.
    // A "flexible" update instead just downloads silently in the
    // background; onUpdateReady only fires once that's finished, at which
    // point the user could be on any screen, so the banner below is shown
    // via the root Overlay rather than depending on whichever screen
    // happens to have a Scaffold under it.
    UpdateService.instance.checkForUpdate(
      onUpdateReady: () {
        if (!mounted) return;
        UpdateReadyBanner.show(
          context,
          onRestart: () => UpdateService.instance.completeFlexibleUpdate(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.isSupportedPlatform) {
      return const IosUnsupportedScreen();
    }
    if (!appState.ready || !_splashMinTimeElapsed) {
      return const SplashScreen();
    }
    if (!appState.onboardingComplete) {
      return const OnboardingScreen();
    }
    if (!appState.appTourComplete) {
      return AppTourScreen(onContinue: appState.completeAppTour);
    }
    return const HomeShell();
  }
}
