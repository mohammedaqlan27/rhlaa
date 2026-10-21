class AppConstants {
  AppConstants._();

  /// انحناء موحد للعناصر
  static const double borderRadius = 16.0;

  /// تصنيفات الرحلات
  static const List<String> tripCategories = ['داخلية', 'خارجية'];

  /// المحافظات اليمنية
  static const List<String> yemenGovernorates = [
    'أمانة العاصمة (صنعاء)', 'محافظة صنعاء', 'عدن', 'تعز', 'حضرموت',
    'إب', 'الحديدة', 'مأرب', 'شبوة', 'ذمار', 'حجة', 'عمران',
    'صعدة', 'الجوف', 'البيضاء', 'الضالع', 'لحج', 'أبين',
    'المهرة', 'المحويت', 'ريمة', 'سقطرى',
  ];

  /// الوجهات الخارجية
  static const Map<String, List<String>> externalDestinations = {
    'السعودية': ['الرياض', 'جدة', 'مكة المكرمة', 'المدينة المنورة', 'الدمام', 'خميس مشيط', 'جازان'],
    'الإمارات': ['دبي', 'أبوظبي', 'الشارقة'],
    'عمان': ['مسقط', 'صلالة', 'صحار', 'نزوى'],
  };

  /// قائمة مسطحة بكل المدن الخارجية
  static List<String> get allExternalCities =>
      externalDestinations.values.expand((c) => c).toList();

  /// أنواع المركبات
  static const Map<String, List<String>> vehicleCategories = {
    'اقتصادية': ['كورولا', 'كامري'],
    'عائلية': ['لاندكروزر', 'برادو'],
    'نقل جماعي': ['هايس', 'كوستر'],
    'نقل بضائع': ['هيلوكس', 'شاص', 'دينا'],
  };

  /// حالات الرحلة
  static const List<String> tripStatuses = [
    'مفعّلة', 'في الطريق', 'تم الوصول', 'مكتملة', 'ملغاة'
  ];
}
