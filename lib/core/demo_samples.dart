import 'dart:math';

import 'package:flutter/widgets.dart';

/// A made-up sender and message for the app's illustrations of a deleted
/// message (onboarding's flow, the popup-permission dialog), so they don't
/// always show the same person saying the same thing.
class DemoSample {
  final String name;
  final String message;

  const DemoSample(this.name, this.message);

  static final _random = Random();

  static const _namesEn = [
    'Rahul',
    'Priya',
    'Amit',
    'Sneha',
    'Arjun',
    'Neha',
    'Vikram',
    'Anjali',
    'Rohan',
    'Kavya',
  ];
  static const _messagesEn = [
    'See you at 6?',
    'Call me when you are free',
    'Did you get my photo?',
    "I'm on my way",
    "Don't tell anyone 🤫",
    'Can you send me ₹500?',
    'Meeting moved to 4 pm',
    'Happy birthday! 🎉',
    'Where are you?',
    'Sorry, wrong chat 😅',
  ];

  static const _namesHi = [
    'राहुल',
    'प्रिया',
    'अमित',
    'स्नेहा',
    'अर्जुन',
    'नेहा',
    'विक्रम',
    'अंजलि',
    'रोहन',
    'काव्या',
  ];
  static const _messagesHi = [
    '6 बजे मिलते हैं?',
    'फ्री हो तो कॉल करना',
    'मेरी फ़ोटो मिली?',
    'मैं रास्ते में हूँ',
    'किसी को मत बताना 🤫',
    'मुझे ₹500 भेज सकते हो?',
    'मीटिंग 4 बजे हो गई है',
    'जन्मदिन मुबारक! 🎉',
    'तुम कहाँ हो?',
    'सॉरी, गलत चैट 😅',
  ];

  /// A random pairing, in the app's current language. Pick it once per
  /// screen (e.g. in initState/didChangeDependencies), not in build, so it
  /// doesn't change on every rebuild.
  static DemoSample random(BuildContext context) {
    final hindi = Localizations.localeOf(context).languageCode == 'hi';
    final names = hindi ? _namesHi : _namesEn;
    final messages = hindi ? _messagesHi : _messagesEn;
    return DemoSample(
      names[_random.nextInt(names.length)],
      messages[_random.nextInt(messages.length)],
    );
  }
}
