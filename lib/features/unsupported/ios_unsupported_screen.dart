import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

class IosUnsupportedScreen extends StatelessWidget {
  const IosUnsupportedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.iosUnsupportedTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(l10n.iosUnsupportedBody, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
