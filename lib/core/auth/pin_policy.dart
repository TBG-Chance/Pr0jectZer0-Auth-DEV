class PinPolicy {
  static const int minimumLength = 6;
  static const int maximumLength = 12;

  const PinPolicy._();

  static String? validate(String pin) {
    if (pin.length < minimumLength || pin.length > maximumLength) {
      return 'PIN must be between $minimumLength and $maximumLength digits.';
    }

    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      return 'PIN must contain digits only.';
    }

    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) {
      return 'PIN cannot use the same digit repeatedly.';
    }

    if (_isSequential(pin)) {
      return 'PIN cannot be a simple ascending or descending sequence.';
    }

    return null;
  }

  static bool _isSequential(String pin) {
    if (pin.length < 4) return false;

    var ascending = true;
    var descending = true;

    for (var index = 1; index < pin.length; index++) {
      final previous = int.parse(pin[index - 1]);
      final current = int.parse(pin[index]);

      if (current != (previous + 1) % 10) ascending = false;
      if (current != (previous + 9) % 10) descending = false;
    }

    return ascending || descending;
  }
}
