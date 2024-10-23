extension StringExtension on String {
  bool get isBlank => trim().isEmpty;
  bool get isNotBlank => !isBlank;

  int parseIntOr(int defaultValue) {
    try {
      return int.parse(trim());
    } on FormatException {
      return defaultValue;
    }
  }

  int parseIntOrZero() => parseIntOr(0);
}

extension StringNullExtension on String? {
  int parseIntOr(int defaultValue) {
    return this?.parseIntOr(defaultValue) ?? defaultValue;
  }

  int parseIntOrZero() => this?.parseIntOrZero() ?? 0;
}
