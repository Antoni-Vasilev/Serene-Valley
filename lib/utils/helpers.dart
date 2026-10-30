import 'dart:ui';
import 'dart:math';

class Helpers {
  static String formatTime(double timeOfDay) {
    int hours = timeOfDay.floor();
    int minutes = ((timeOfDay - hours) * 60).floor();
    
    String hourString = hours.toString().padLeft(2, '0');
    String minuteString = minutes.toString().padLeft(2, '0');
    
    return '$hourString:$minuteString';
  }

  static String formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  static double distance(Offset a, Offset b) {
    return sqrt(pow(a.dx - b.dx, 2) + pow(a.dy - b.dy, 2));
  }

  static Offset clampOffset(Offset offset, double minX, double minY, double maxX, double maxY) {
    return Offset(
      offset.dx.clamp(minX, maxX),
      offset.dy.clamp(minY, maxY),
    );
  }

  static bool isInRect(Offset point, Offset rectOffset, double width, double height) {
    return point.dx >= rectOffset.dx && 
           point.dx <= rectOffset.dx + width &&
           point.dy >= rectOffset.dy && 
           point.dy <= rectOffset.dy + height;
  }
}
