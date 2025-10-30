/// دالة حساب درجة القرب الجغرافي بين المستخدم والموزع
/// بناءً على المحافظات والمراكز المشتركة
class LocationProximity {
  /// حساب درجة القرب
  /// - محافظة مشتركة = 10 نقاط
  /// - مركز مشترك = 15 نقطة (أهم من المحافظة)
  static int calculateProximityScore({
    required List<String>? userGovernorates,
    required List<String>? userCenters,
    required List<String>? distributorGovernorates,
    required List<String>? distributorCenters,
  }) {
    int score = 0;

    // إذا كانت البيانات فارغة، لا توجد نقاط
    if (userGovernorates == null || 
        distributorGovernorates == null ||
        userGovernorates.isEmpty || 
        distributorGovernorates.isEmpty) {
      return 0;
    }

    // حساب تطابق المحافظات
    final commonGovernorates = userGovernorates
        .where((gov) => distributorGovernorates.contains(gov))
        .length;
    score += commonGovernorates * 10;

    // حساب تطابق المراكز (أهم)
    if (userCenters != null && 
        distributorCenters != null &&
        userCenters.isNotEmpty && 
        distributorCenters.isNotEmpty) {
      final commonCenters = userCenters
          .where((center) => distributorCenters.contains(center))
          .length;
      score += commonCenters * 15;
    }

    return score;
  }

  /// التحقق من وجود مركز مشترك (لعرض شارة "قريب منك")
  static bool hasCommonCenter({
    required List<String>? userCenters,
    required List<String>? distributorCenters,
  }) {
    if (userCenters == null || 
        distributorCenters == null ||
        userCenters.isEmpty || 
        distributorCenters.isEmpty) {
      return false;
    }

    return userCenters.any((center) => distributorCenters.contains(center));
  }

  /// التحقق من وجود محافظة مشتركة (لعرض أيقونة)
  static bool hasCommonGovernorate({
    required List<String>? userGovernorates,
    required List<String>? distributorGovernorates,
  }) {
    if (userGovernorates == null || 
        distributorGovernorates == null ||
        userGovernorates.isEmpty || 
        distributorGovernorates.isEmpty) {
      return false;
    }

    return userGovernorates
        .any((gov) => distributorGovernorates.contains(gov));
  }

  /// ترتيب قائمة حسب القرب
  static List<T> sortByProximity<T>({
    required List<T> items,
    required int Function(T) getProximityScore,
  }) {
    final sorted = List<T>.from(items);
    sorted.sort((a, b) {
      final scoreA = getProximityScore(a);
      final scoreB = getProximityScore(b);
      return scoreB.compareTo(scoreA); // الأعلى درجة أولاً
    });
    return sorted;
  }
}
