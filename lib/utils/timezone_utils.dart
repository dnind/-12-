// KST 시간대 유틸리티
class TimeZoneUtils {
  static DateTime get kstNow {
    final utc = DateTime.now().toUtc();
    return utc.add(const Duration(hours: 9)); // KST는 UTC+9
  }
  
  static DateTime toKST(DateTime dateTime) {
    return dateTime.toUtc().add(const Duration(hours: 9));
  }
}