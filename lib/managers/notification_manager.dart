import '../models/todo_model.dart';
import '../utils/timezone_utils.dart';

class NotificationManager {
  static DateTime? calculateNextNotification(DateTime startTime, NotificationInterval interval) {
    final duration = interval.duration;
    if (duration == null) return null;
    
    DateTime nextTime = startTime.add(duration);
    
    // 현재 시간보다 이전이면 다음 알림으로 조정
    while (nextTime.isBefore(TimeZoneUtils.kstNow)) {
      nextTime = nextTime.add(duration);
    }
    
    return nextTime;
  }
  
  static bool shouldNotify(DateTime? lastNotificationTime, NotificationInterval interval) {
    if (interval == NotificationInterval.none || lastNotificationTime == null) {
      return false;
    }
    
    final duration = interval.duration;
    if (duration == null) return false;
    
    final nextNotificationTime = lastNotificationTime.add(duration);
    return TimeZoneUtils.kstNow.isAfter(nextNotificationTime);
  }
}