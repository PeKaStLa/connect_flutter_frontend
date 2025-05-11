class ParsingUtils {
  // Helper function to safely parse doubles from dynamic values
  static double? parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    // Added check for empty string specifically
    if (value is String) {
      if (value.trim().isEmpty) return null; // Treat empty strings as null
      return double.tryParse(value);
    }
    return null;
  }
}