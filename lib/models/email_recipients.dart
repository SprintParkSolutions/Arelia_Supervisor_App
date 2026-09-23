/// Shared parsing for email settings, including pasted lists and test aliases.
class EmailRecipients {
  static List<String> parse(String input) {
    final addresses = <String>{};
    for (final part in input.split(RegExp(r'[,;\r\n]+'))) {
      final address = part.trim().toLowerCase();
      if (address.isEmpty) continue;
      if (!RegExp(r'^[^\s@;,]+@[^\s@;,]+\.[^\s@;,]+$').hasMatch(address)) {
        throw FormatException('Invalid email address: $address');
      }
      addresses.add(address);
    }
    return addresses.toList();
  }

  static Map<String, String> groups({
    required String supervisor,
    required String manager,
  }) {
    final result = <String, String>{};
    for (final address in parse(supervisor)) {
      result[address] = 'Supervisor';
    }
    for (final address in parse(manager)) {
      result[address] = result.containsKey(address)
          ? 'Supervisor and Manager'
          : 'Manager';
    }
    return result;
  }

  static String? validate(String? input) {
    try {
      parse(input ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }
}
