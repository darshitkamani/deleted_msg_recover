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
          // Draws the package's own "Ad Metrics Lab" floating debug overlay
          // (PreloadGoogleAds.showAdCounter) above every screen, gated
          // purely by AdsService.showAdMetricsLab (which mirrors the
          // `showAdMetricsLab` remote config flag) via showInRelease --
          // the package itself still refuses to render in release unless
          // that's passed true, so this is the only thing that can turn it
          // on in a live release build, and only remotely. A
          // ValueListenableBuilder (rather than reading .value once here)
          // because this builder isn't guaranteed to re-run at the moment
          // AdsService.init() resolves the fetched flag.
          builder: (context, child) => Stack(
            children: [
              if (child != null) child,
              ValueListenableBuilder<bool>(
                valueListenable: AdsService.instance.showAdMetricsLab,
                builder: (context, showAdMetricsLab, _) =>
                    PreloadGoogleAds.instance.showAdCounter(
                  showCounter: showAdMetricsLab,
                  showInRelease: showAdMetricsLab,
                ),
              ),
            ],
          ),
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
      AdsService.instance.showInterstitialOnNavigation();
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
  bool _adsInitStarted = false;

  /// Starts [AdsService.init] (idempotent, guarded here so the follow-up
  /// reload below only runs once) at the right moment for this user:
  ///  - Setup already finished (onboarding + app tour): as soon as the
  ///    persisted flags and permission state are known, i.e. during the
  ///    splash -- the SDK is warm long before HomeShell.
  ///  - Setup still pending (first run, or onboarding re-run because
  ///    notification access is missing): not during the splash or the
  ///    onboarding permission steps, only once the app tour page is on
  ///    screen, so a first-run user isn't hit with ad loading before then.
  ///    That still leaves the whole tour to warm up before HomeShell.
  void _maybeInitAds(AppState appState) {
    if (_adsInitStarted || !appState.ready || !appState.accessChecked) return;
    final setupPending =
        !appState.onboardingComplete || !appState.appTourComplete;
    final onTourPage =
        appState.onboardingComplete &&
        !appState.appTourComplete &&
        _splashMinTimeElapsed;
    if (setupPending && !onTourPage) return;

    _adsInitStarted = true;
    AdsService.instance.init().then((_) {
      // Warms up the one format the package still preloads (native) if it
      // isn't already loading. Interstitial, rewarded interstitial and app
      // open are not part of this -- AdsService loads those on demand.
      PreloadGoogleAds.instance.reloadUnloadedAds();
    });
  }

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
    if (appState.isSupportedPlatform) _maybeInitAds(appState);

    if (!appState.isSupportedPlatform) {
      return const IosUnsupportedScreen();
    }
    if (!appState.ready || !appState.accessChecked || !_splashMinTimeElapsed) {
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
