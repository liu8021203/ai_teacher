

import 'package:flutter/material.dart';

class AppUtil{


  // 根据生日计算年龄
  static String calculateAge(String birthday) {
    try {
      // 处理带有时间部分的日期格式（例如"2025-04-03 00:00:00"）
      final DateTime birthDate = DateTime.parse(birthday.split(' ')[0]);
      final DateTime today = DateTime.now();

      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }

      // 如果年龄为负数（出生日期在未来），返回0
      return age < 0 ? "0" : age.toString();
    } catch (e) {
      return "0";
    }
  }


  static double calculateTextWidth(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1, // 单行文本
    )..layout(); // 触发布局计算

    return textPainter.width;
  }
}