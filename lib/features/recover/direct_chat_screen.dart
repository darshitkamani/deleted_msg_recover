import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:preload_google_ads/preload_google_ads.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/country.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/country_picker.dart';

/// Composes a wa.me deep link to open a chat with any phone number,
/// pre-filled with a message -- WhatsApp itself resolves this to whichever
/// of WhatsApp/WhatsApp Business is installed, no native code needed.
class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({super.key});

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _numberController = TextEditingController();
  final _messageController = TextEditingController();
  Country _country = defaultCountry;

  @override
  void dispose() {
    _numberController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPicker(context);
    if (picked != null && mounted) setState(() => _country = picked);
  }

  String? _buildLink() {
    final digits = _numberController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    final message = _messageController.text;
    final query = message.isEmpty
        ? ''
        : '?text=${Uri.encodeComponent(message)}';
    return 'https://wa.me/${_country.dialCode}$digits$query';
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final link = _buildLink();
    if (link == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.directChatNumberRequired)));
      return;
    }
    final uri = Uri.parse(link);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.linkOpenFailed)));
    }
  }

  Future<void> _copyLink() async {
    final l10n = AppLocalizations.of(context);
    final link = _buildLink();
    if (link == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.directChatNumberRequired)));
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.directChatLinkCopied)));
    }
  }

  static OutlineInputBorder _outlineBorder(Color color, {double width = 1.4}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CountryCodeButton(country: _country, onTap: _pickCountry),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _numberController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: l10n.directChatNumberLabel,
                          border: _outlineBorder(
                            theme.colorScheme.outlineVariant,
                          ),
                          enabledBorder: _outlineBorder(
                            theme.colorScheme.outlineVariant,
                          ),
                          focusedBorder: _outlineBorder(
                            theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _messageController,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: l10n.directChatMessageLabel,
                  border: _outlineBorder(theme.colorScheme.outlineVariant),
                  enabledBorder: _outlineBorder(
                    theme.colorScheme.outlineVariant,
                  ),
                  focusedBorder: _outlineBorder(
                    theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _send,
                icon: const Icon(Icons.send_rounded),
                label: Text(l10n.directChatSendAction),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _copyLink,
                icon: const Icon(Icons.copy_rounded),
                label: Text(l10n.directChatCopyLinkAction),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: PreloadGoogleAds.instance.showNativeAd(),
        ),
      ],
    );
  }
}

/// The country flag + dial code control that sits to the left of the phone
/// number field, in an outlined box matching the field's border. The dial
/// code lives here rather than as the field's `prefixText` -- that fades in
/// and out with focus (standard Material behavior for an empty, unfocused
/// field), which read as broken since "+91" would flicker away.
class _CountryCodeButton extends StatelessWidget {
  final Country country;
  final VoidCallback onTap;

  const _CountryCodeButton({required this.country, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 1.4,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(country.flagEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Text(
                '+${country.dialCode}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
