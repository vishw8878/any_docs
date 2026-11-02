import 'dart:developer';
import 'package:flutter/foundation.dart';
//Todo : Every dev should have to use this class to print any kind of log by vishw,
// Todo : if some specific log function is missed then kindly add them below

//Todo : color code for msg
//   Black("30"),
//   Red("31"),
//   Green("32"),
//   Yellow("33"),
//   Blue("34"),
//   Magenta("35"),
//   Cyan("36"),
//   White("37");

class AppLogger {
  // Debug print
  static void printDebug(value) {
    if (kDebugMode) {
      debugPrint(value.toString());
    }
  }

  // Log print
  static void printLog(value) {
    if (kDebugMode) {
      log(value.toString());
    }
  }

  // Normal print
  static void printConsole(value) {
    if (kDebugMode) {
      print(value.toString());
    }
  }

  static void i(value) {
    if (kDebugMode) {
      debugPrint('\x1B[32m${"INFO: $value"}\x1B[0m');
    }
  }

  static void e(value) {
    if (kDebugMode) {
      debugPrint('\x1B[31m${"ERROR: $value"}\x1B[0m');
    }
  }

  static void w(value) {
    if (kDebugMode) {
      debugPrint('\x1B[33m${"ERROR: $value"}\x1B[0m');
    }
  }
}
