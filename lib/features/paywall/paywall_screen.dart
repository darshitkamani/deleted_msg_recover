import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// UI shell for a subscription paywall, styled after the reference app.
/// Deliberately not wired to any purchase flow -- there is no Play Billing
/// integration yet, so "Continue" only explains that purchases aren't live,
/// rather than pretending to complete one.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _lifetimeSelected = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B2B22),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.paywallTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.paywallSubtitle,
                style: TextStyle(
                  color: Colors.orange.shade300,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              _FeatureRow(text: l10n.paywallFeatureSeen),
              const SizedBox(height: 10),
              _FeatureRow(text: l10n.paywallFeaturePrivate),
              const SizedBox(height: 10),
              _FeatureRow(text: l10n.paywallFeatureAdsFree),
              const SizedBox(height: 26),
              _PlanCard(
                badgeLabel: l10n.paywallTrialBadge,
                badgeColor: Colors.white.withValues(alpha: 0.12),
                title: l10n.paywallMonthlyLabel,
                subtitle: l10n.paywallMonthlySubLabel,
                selected: !_lifetimeSelected,
                onTap: () => setState(() => _lifetimeSelected = false),
              ),
              const SizedBox(height: 12),
              _PlanCard(
                badgeLabel: l10n.paywallSaveBadge,
                badgeColor: Colors.orange.shade600,
                title: l10n.paywallLifetimeLabel,
                subtitle: l10n.paywallLifetimeSubLabel,
                selected: _lifetimeSelected,
                onTap: () => setState(() => _lifetimeSelected = true),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.paywallComingSoon)),
                        );
                      },
                      child: Center(
                        child: Text(
                          l10n.paywallContinueAction,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  l10n.paywallDisclaimer,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;

  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String badgeLabel;
  final Color badgeColor;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.badgeLabel,
    required this.badgeColor,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.green.shade400 : Colors.white.withValues(alpha: 0.14),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
