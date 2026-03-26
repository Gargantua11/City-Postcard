import 'city_code_name.dart';

class CityLocationHelper {
  static String? normalizeCityCode(String? raw) {
    final digits = _extractDigits(raw);
    if (digits == null) return null;

    if (kCityCodeNames.containsKey(digits)) {
      return digits;
    }

    if (digits.length >= 6) {
      final code6 = digits.substring(0, 6);
      if (kCityCodeNames.containsKey(code6)) {
        return code6;
      }

      final code4 = code6.substring(0, 4);
      if (kCityCodeNames.containsKey(code4)) {
        return code4;
      }
    }

    if (digits.length >= 4) {
      final code4 = digits.substring(0, 4);
      if (kCityCodeNames.containsKey(code4)) {
        return code4;
      }
    }

    if (digits.length >= 2) {
      final prefix = digits.substring(0, 2);
      for (final key in kCityCodeNames.keys) {
        if (key.startsWith(prefix)) return key;
      }
    }

    return digits;
  }

  static ParsedCityCodeAndName parseCityCodeAndName(String? raw) {
    final source = raw?.trim() ?? '';
    if (source.isEmpty) {
      return const ParsedCityCodeAndName(cityCode: null, cityName: null);
    }

    final codeMatch = RegExp(r'\d{4,6}').firstMatch(source);
    final code = normalizeCityCode(codeMatch?.group(0));

    final textWithoutDigits = source.replaceAll(RegExp(r'\d+'), '').trim();
    final cleanedName = _sanitizeCityName(textWithoutDigits);

    return ParsedCityCodeAndName(
      cityCode: code,
      cityName: cleanedName,
    );
  }

  static String? resolveCityName({
    String? cityName,
    String? cityCode,
  }) {
    final parsed = parseCityCodeAndName(cityName);
    final normalizedCode = normalizeCityCode(cityCode) ?? parsed.cityCode;

    final cleanedInputName = _sanitizeCityName(parsed.cityName ?? cityName);
    if (cleanedInputName != null && cleanedInputName.isNotEmpty) {
      return cleanedInputName;
    }

    if (normalizedCode == null || normalizedCode.isEmpty) return null;

    final mappedName = kCityCodeNames[normalizedCode]?.trim();
    if (mappedName != null && mappedName.isNotEmpty) return mappedName;

    if (normalizedCode.length >= 4) {
      final code4 = normalizedCode.substring(0, 4);
      final mapped4 = kCityCodeNames[code4]?.trim();
      if (mapped4 != null && mapped4.isNotEmpty) return mapped4;
    }

    return null;
  }

  static String? resolveProvinceName({
    String? provinceName,
    String? cityCode,
  }) {
    final cleanedProvince = _sanitizeCityName(provinceName);
    if (cleanedProvince != null && cleanedProvince.isNotEmpty) {
      return cleanedProvince;
    }

    final normalizedCode = normalizeCityCode(cityCode);
    if (normalizedCode == null || normalizedCode.length < 2) return null;

    return _provinceNameByPrefix[normalizedCode.substring(0, 2)];
  }

  static String? resolveProvinceCityText({
    String? cityName,
    String? cityCode,
    String? provinceName,
  }) {
    final parsed = parseCityCodeAndName(cityName);
    final normalizedCode = normalizeCityCode(cityCode) ?? parsed.cityCode;
    final resolvedCity = resolveCityName(cityName: cityName, cityCode: normalizedCode);
    final resolvedProvince = resolveProvinceName(
      provinceName: provinceName,
      cityCode: normalizedCode,
    );

    if (resolvedProvince != null &&
        resolvedProvince.isNotEmpty &&
        resolvedCity != null &&
        resolvedCity.isNotEmpty) {
      if (resolvedCity == resolvedProvince || resolvedCity.contains(resolvedProvince)) {
        return resolvedCity;
      }
      return '$resolvedProvince$resolvedCity';
    }

    if (resolvedCity != null && resolvedCity.isNotEmpty) {
      return resolvedCity;
    }
    if (resolvedProvince != null && resolvedProvince.isNotEmpty) {
      return resolvedProvince;
    }

    if (normalizedCode != null && normalizedCode.isNotEmpty) {
      final mappedCity = resolveCityName(cityCode: normalizedCode);
      final mappedProvince = resolveProvinceName(cityCode: normalizedCode);
      if (mappedProvince != null &&
          mappedProvince.isNotEmpty &&
          mappedCity != null &&
          mappedCity.isNotEmpty &&
          mappedProvince != mappedCity) {
        return '$mappedProvince$mappedCity';
      }
      if (mappedCity != null && mappedCity.isNotEmpty) return mappedCity;
      if (mappedProvince != null && mappedProvince.isNotEmpty) return mappedProvince;
      return normalizedCode;
    }

    return null;
  }

  static String mergeWithDetail({
    required String? base,
    String? detail,
    String fallback = '\u672a\u77e5\u5730\u70b9',
  }) {
    final normalizedBase = base?.trim() ?? '';
    final normalizedDetail = detail?.trim() ?? '';

    if (normalizedBase.isNotEmpty && normalizedDetail.isNotEmpty) {
      if (normalizedDetail.contains(normalizedBase)) return normalizedDetail;
      if (normalizedBase.contains(normalizedDetail)) return normalizedBase;
      return '$normalizedBase$normalizedDetail';
    }
    if (normalizedBase.isNotEmpty) return normalizedBase;
    if (normalizedDetail.isNotEmpty) return normalizedDetail;
    return fallback;
  }

  static String? _extractDigits(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return digits;
  }

  static String? _sanitizeCityName(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final cleaned = text
        .replaceAll(RegExp(r'^[\s,.;:，。；：]+'), '')
        .replaceAll(RegExp(r'[\s,.;:，。；：]+$'), '');
    if (cleaned.isEmpty) return null;
    return cleaned;
  }
}

class ParsedCityCodeAndName {
  const ParsedCityCodeAndName({
    required this.cityCode,
    required this.cityName,
  });

  final String? cityCode;
  final String? cityName;
}

const Map<String, String> _provinceNameByPrefix = <String, String>{
  '11': '\u5317\u4eac\u5e02',
  '12': '\u5929\u6d25\u5e02',
  '13': '\u6cb3\u5317\u7701',
  '14': '\u5c71\u897f\u7701',
  '15': '\u5185\u8499\u53e4\u81ea\u6cbb\u533a',
  '21': '\u8fbd\u5b81\u7701',
  '22': '\u5409\u6797\u7701',
  '23': '\u9ed1\u9f99\u6c5f\u7701',
  '31': '\u4e0a\u6d77\u5e02',
  '32': '\u6c5f\u82cf\u7701',
  '33': '\u6d59\u6c5f\u7701',
  '34': '\u5b89\u5fbd\u7701',
  '35': '\u798f\u5efa\u7701',
  '36': '\u6c5f\u897f\u7701',
  '37': '\u5c71\u4e1c\u7701',
  '41': '\u6cb3\u5357\u7701',
  '42': '\u6e56\u5317\u7701',
  '43': '\u6e56\u5357\u7701',
  '44': '\u5e7f\u4e1c\u7701',
  '45': '\u5e7f\u897f\u58ee\u65cf\u81ea\u6cbb\u533a',
  '46': '\u6d77\u5357\u7701',
  '50': '\u91cd\u5e86\u5e02',
  '51': '\u56db\u5ddd\u7701',
  '52': '\u8d35\u5dde\u7701',
  '53': '\u4e91\u5357\u7701',
  '54': '\u897f\u85cf\u81ea\u6cbb\u533a',
  '61': '\u9655\u897f\u7701',
  '62': '\u7518\u8083\u7701',
  '63': '\u9752\u6d77\u7701',
  '64': '\u5b81\u590f\u56de\u65cf\u81ea\u6cbb\u533a',
  '65': '\u65b0\u7586\u7ef4\u543e\u5c14\u81ea\u6cbb\u533a',
  '71': '\u53f0\u6e7e\u7701',
  '81': '\u9999\u6e2f\u7279\u522b\u884c\u653f\u533a',
  '82': '\u6fb3\u95e8\u7279\u522b\u884c\u653f\u533a',
};
