import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Holds per-cell display data including value and formatting
class CellData {
  final String value;
  final bool isBold;
  final bool isItalic;
  final Color? backgroundColor;
  final Color? fontColor;
  final double? fontSize;

  const CellData({
    required this.value,
    this.isBold = false,
    this.isItalic = false,
    this.backgroundColor,
    this.fontColor,
    this.fontSize,
  });
}

class XlsViewerController extends GetxController {
  dynamic arguments;

  String filePath = '';
  String fileName = '';

  RxBool isLoading = true.obs;
  RxString errorMessage = ''.obs;

  // Data structure: Sheet Name -> List of Rows -> List of CellData
  final RxMap<String, List<List<CellData>>> excelData =
      <String, List<List<CellData>>>{}.obs;
  final RxList<String> sheetNames = <String>[].obs;

  final RxString selectedSheet = ''.obs;

  @override
  void onInit() {
    arguments = Get.arguments;
    if (arguments is List && arguments.length >= 2) {
      filePath = arguments[0] as String;
      fileName = arguments[1] as String;
      loadExcelData();
    } else {
      isLoading.value = false;
      errorMessage.value = 'Invalid arguments passed';
    }
    super.onInit();
  }

  /// Converts an [ExcelColor] to a Flutter [Color].
  /// Returns null if the color is "none" (no fill) or pure default black/white background.
  Color? _excelColorToFlutterColor(ExcelColor excelColor) {
    final hex = excelColor.colorHex;
    // 'none' means no fill was set
    if (hex == 'none') return null;
    try {
      // ExcelColor hex is 8-char ARGB format: "AARRGGBB"
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      } else if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}
    return null;
  }

  /// Returns null for backgrounds that are effectively "no fill":
  /// pure white (FFFFFFFF), transparent, or default Excel none.
  Color? _resolveBackground(ExcelColor excelColor) {
    final color = _excelColorToFlutterColor(excelColor);
    if (color == null) return null;
    // Skip fully-white (FFFFFFFF) and fully-transparent
    if (color.toARGB32() == 0xFFFFFFFF || (color.a * 255.0).round() == 0) return null;
    return color;
  }

  Future<void> loadExcelData() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final Map<String, List<List<CellData>>> loadedSheets = {};
      final List<String> names = [];

      for (var tableName in excel.tables.keys) {
        names.add(tableName);
        final sheet = excel.tables[tableName];
        if (sheet == null) continue;

        final List<List<CellData>> rows = [];

        for (var row in sheet.rows) {
          final List<CellData> rowCells = [];
          for (var cell in row) {
            final val = cell?.value;
            final style = cell?.cellStyle;

            // Resolve background color from ExcelColor
            Color? bgColor;
            if (style != null) {
              bgColor = _resolveBackground(style.backgroundColor);
            }

            // Resolve font color from ExcelColor
            Color? fontColor;
            if (style != null) {
              fontColor = _excelColorToFlutterColor(style.fontColor);
              // Default black font color — treat as null so we use our defaults
              if (fontColor != null && fontColor.toARGB32() == 0xFF000000) {
                fontColor = null;
              }
            }

            rowCells.add(CellData(
              value: val != null ? val.toString() : '',
              isBold: style?.isBold ?? false,
              isItalic: style?.isItalic ?? false,
              backgroundColor: bgColor,
              fontColor: fontColor,
              fontSize: style?.fontSize?.toDouble(),
            ));
          }
          rows.add(rowCells);
        }
        loadedSheets[tableName] = rows;
      }

      sheetNames.assignAll(names);
      excelData.assignAll(loadedSheets);

      if (names.isNotEmpty) {
        selectedSheet.value = names.first;
      } else {
        errorMessage.value = 'No sheets found in the Excel file';
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading Excel: $e');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage.value = 'Unable to parse Excel file: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }
}
