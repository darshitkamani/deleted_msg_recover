/// A country's ISO 3166-1 alpha-2 code, display name, and international
/// calling code -- backs the country picker on the Direct Chat screen.
class Country {
  final String isoCode;
  final String name;
  final String dialCode;

  const Country({
    required this.isoCode,
    required this.name,
    required this.dialCode,
  });

  /// Unicode regional-indicator flag emoji derived from the ISO code (each
  /// letter maps to a regional-indicator symbol) -- no image assets needed.
  String get flagEmoji {
    return isoCode
        .toUpperCase()
        .codeUnits
        .map((c) => String.fromCharCode(0x1F1E6 + (c - 'A'.codeUnitAt(0))))
        .join();
  }

  @override
  bool operator ==(Object other) =>
      other is Country && other.isoCode == isoCode;

  @override
  int get hashCode => isoCode.hashCode;
}

/// Countries WhatsApp is commonly used in, sorted alphabetically by name.
/// Not exhaustive of every ISO territory, but covers the calling codes a
/// Direct Chat number is realistically going to need.
const List<Country> countries = [
  Country(isoCode: 'AF', name: 'Afghanistan', dialCode: '93'),
  Country(isoCode: 'AL', name: 'Albania', dialCode: '355'),
  Country(isoCode: 'DZ', name: 'Algeria', dialCode: '213'),
  Country(isoCode: 'AR', name: 'Argentina', dialCode: '54'),
  Country(isoCode: 'AU', name: 'Australia', dialCode: '61'),
  Country(isoCode: 'AT', name: 'Austria', dialCode: '43'),
  Country(isoCode: 'BH', name: 'Bahrain', dialCode: '973'),
  Country(isoCode: 'BD', name: 'Bangladesh', dialCode: '880'),
  Country(isoCode: 'BY', name: 'Belarus', dialCode: '375'),
  Country(isoCode: 'BE', name: 'Belgium', dialCode: '32'),
  Country(isoCode: 'BO', name: 'Bolivia', dialCode: '591'),
  Country(isoCode: 'BA', name: 'Bosnia and Herzegovina', dialCode: '387'),
  Country(isoCode: 'BR', name: 'Brazil', dialCode: '55'),
  Country(isoCode: 'BG', name: 'Bulgaria', dialCode: '359'),
  Country(isoCode: 'KH', name: 'Cambodia', dialCode: '855'),
  Country(isoCode: 'CM', name: 'Cameroon', dialCode: '237'),
  Country(isoCode: 'CA', name: 'Canada', dialCode: '1'),
  Country(isoCode: 'CL', name: 'Chile', dialCode: '56'),
  Country(isoCode: 'CN', name: 'China', dialCode: '86'),
  Country(isoCode: 'CO', name: 'Colombia', dialCode: '57'),
  Country(isoCode: 'CR', name: 'Costa Rica', dialCode: '506'),
  Country(isoCode: 'HR', name: 'Croatia', dialCode: '385'),
  Country(isoCode: 'CU', name: 'Cuba', dialCode: '53'),
  Country(isoCode: 'CY', name: 'Cyprus', dialCode: '357'),
  Country(isoCode: 'CZ', name: 'Czech Republic', dialCode: '420'),
  Country(isoCode: 'DK', name: 'Denmark', dialCode: '45'),
  Country(isoCode: 'DO', name: 'Dominican Republic', dialCode: '1'),
  Country(isoCode: 'EC', name: 'Ecuador', dialCode: '593'),
  Country(isoCode: 'EG', name: 'Egypt', dialCode: '20'),
  Country(isoCode: 'SV', name: 'El Salvador', dialCode: '503'),
  Country(isoCode: 'EE', name: 'Estonia', dialCode: '372'),
  Country(isoCode: 'ET', name: 'Ethiopia', dialCode: '251'),
  Country(isoCode: 'FI', name: 'Finland', dialCode: '358'),
  Country(isoCode: 'FR', name: 'France', dialCode: '33'),
  Country(isoCode: 'GE', name: 'Georgia', dialCode: '995'),
  Country(isoCode: 'DE', name: 'Germany', dialCode: '49'),
  Country(isoCode: 'GH', name: 'Ghana', dialCode: '233'),
  Country(isoCode: 'GR', name: 'Greece', dialCode: '30'),
  Country(isoCode: 'GT', name: 'Guatemala', dialCode: '502'),
  Country(isoCode: 'HN', name: 'Honduras', dialCode: '504'),
  Country(isoCode: 'HK', name: 'Hong Kong', dialCode: '852'),
  Country(isoCode: 'HU', name: 'Hungary', dialCode: '36'),
  Country(isoCode: 'IS', name: 'Iceland', dialCode: '354'),
  Country(isoCode: 'IN', name: 'India', dialCode: '91'),
  Country(isoCode: 'ID', name: 'Indonesia', dialCode: '62'),
  Country(isoCode: 'IR', name: 'Iran', dialCode: '98'),
  Country(isoCode: 'IQ', name: 'Iraq', dialCode: '964'),
  Country(isoCode: 'IE', name: 'Ireland', dialCode: '353'),
  Country(isoCode: 'IL', name: 'Israel', dialCode: '972'),
  Country(isoCode: 'IT', name: 'Italy', dialCode: '39'),
  Country(isoCode: 'JM', name: 'Jamaica', dialCode: '1'),
  Country(isoCode: 'JP', name: 'Japan', dialCode: '81'),
  Country(isoCode: 'JO', name: 'Jordan', dialCode: '962'),
  Country(isoCode: 'KZ', name: 'Kazakhstan', dialCode: '7'),
  Country(isoCode: 'KE', name: 'Kenya', dialCode: '254'),
  Country(isoCode: 'KW', name: 'Kuwait', dialCode: '965'),
  Country(isoCode: 'LA', name: 'Laos', dialCode: '856'),
  Country(isoCode: 'LV', name: 'Latvia', dialCode: '371'),
  Country(isoCode: 'LB', name: 'Lebanon', dialCode: '961'),
  Country(isoCode: 'LY', name: 'Libya', dialCode: '218'),
  Country(isoCode: 'LT', name: 'Lithuania', dialCode: '370'),
  Country(isoCode: 'LU', name: 'Luxembourg', dialCode: '352'),
  Country(isoCode: 'MY', name: 'Malaysia', dialCode: '60'),
  Country(isoCode: 'MV', name: 'Maldives', dialCode: '960'),
  Country(isoCode: 'MT', name: 'Malta', dialCode: '356'),
  Country(isoCode: 'MX', name: 'Mexico', dialCode: '52'),
  Country(isoCode: 'MA', name: 'Morocco', dialCode: '212'),
  Country(isoCode: 'MM', name: 'Myanmar', dialCode: '95'),
  Country(isoCode: 'NP', name: 'Nepal', dialCode: '977'),
  Country(isoCode: 'NL', name: 'Netherlands', dialCode: '31'),
  Country(isoCode: 'NZ', name: 'New Zealand', dialCode: '64'),
  Country(isoCode: 'NI', name: 'Nicaragua', dialCode: '505'),
  Country(isoCode: 'NG', name: 'Nigeria', dialCode: '234'),
  Country(isoCode: 'NO', name: 'Norway', dialCode: '47'),
  Country(isoCode: 'OM', name: 'Oman', dialCode: '968'),
  Country(isoCode: 'PK', name: 'Pakistan', dialCode: '92'),
  Country(isoCode: 'PA', name: 'Panama', dialCode: '507'),
  Country(isoCode: 'PY', name: 'Paraguay', dialCode: '595'),
  Country(isoCode: 'PE', name: 'Peru', dialCode: '51'),
  Country(isoCode: 'PH', name: 'Philippines', dialCode: '63'),
  Country(isoCode: 'PL', name: 'Poland', dialCode: '48'),
  Country(isoCode: 'PT', name: 'Portugal', dialCode: '351'),
  Country(isoCode: 'QA', name: 'Qatar', dialCode: '974'),
  Country(isoCode: 'RO', name: 'Romania', dialCode: '40'),
  Country(isoCode: 'RU', name: 'Russia', dialCode: '7'),
  Country(isoCode: 'SA', name: 'Saudi Arabia', dialCode: '966'),
  Country(isoCode: 'RS', name: 'Serbia', dialCode: '381'),
  Country(isoCode: 'SG', name: 'Singapore', dialCode: '65'),
  Country(isoCode: 'SK', name: 'Slovakia', dialCode: '421'),
  Country(isoCode: 'SI', name: 'Slovenia', dialCode: '386'),
  Country(isoCode: 'ZA', name: 'South Africa', dialCode: '27'),
  Country(isoCode: 'KR', name: 'South Korea', dialCode: '82'),
  Country(isoCode: 'ES', name: 'Spain', dialCode: '34'),
  Country(isoCode: 'LK', name: 'Sri Lanka', dialCode: '94'),
  Country(isoCode: 'SD', name: 'Sudan', dialCode: '249'),
  Country(isoCode: 'SE', name: 'Sweden', dialCode: '46'),
  Country(isoCode: 'CH', name: 'Switzerland', dialCode: '41'),
  Country(isoCode: 'SY', name: 'Syria', dialCode: '963'),
  Country(isoCode: 'TW', name: 'Taiwan', dialCode: '886'),
  Country(isoCode: 'TZ', name: 'Tanzania', dialCode: '255'),
  Country(isoCode: 'TH', name: 'Thailand', dialCode: '66'),
  Country(isoCode: 'TN', name: 'Tunisia', dialCode: '216'),
  Country(isoCode: 'TR', name: 'Turkey', dialCode: '90'),
  Country(isoCode: 'UA', name: 'Ukraine', dialCode: '380'),
  Country(isoCode: 'AE', name: 'United Arab Emirates', dialCode: '971'),
  Country(isoCode: 'GB', name: 'United Kingdom', dialCode: '44'),
  Country(isoCode: 'US', name: 'United States', dialCode: '1'),
  Country(isoCode: 'UY', name: 'Uruguay', dialCode: '598'),
  Country(isoCode: 'UZ', name: 'Uzbekistan', dialCode: '998'),
  Country(isoCode: 'VE', name: 'Venezuela', dialCode: '58'),
  Country(isoCode: 'VN', name: 'Vietnam', dialCode: '84'),
  Country(isoCode: 'YE', name: 'Yemen', dialCode: '967'),
  Country(isoCode: 'ZM', name: 'Zambia', dialCode: '260'),
  Country(isoCode: 'ZW', name: 'Zimbabwe', dialCode: '263'),
];

const Country defaultCountry = Country(
  isoCode: 'IN',
  name: 'India',
  dialCode: '91',
);
