extension StringExtensions on String {
  /// تحويل أول حرف لحرف كبير
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  /// تحويل أول حرف من كل كلمة لحرف كبير
  String capitalizeWords() {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize()).join(' ');
  }
}
