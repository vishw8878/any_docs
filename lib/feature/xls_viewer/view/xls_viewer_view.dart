import 'package:any_docs/core/utils/app_colour.dart';
import 'package:any_docs/feature/xls_viewer/controller/xls_viewer_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

class XlsViewerView extends GetView<XlsViewerController> {
  const XlsViewerView({super.key});

  @override
  Widget build(BuildContext context) {
    final title = controller.fileName.length > 18
        ? '${controller.fileName.substring(0, 18)}...'
        : controller.fileName;

    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () {
            Get.back();
          },
          child: Icon(
            Icons.arrow_back,
            color: whiteColor,
          ),
        ),
        backgroundColor: appColor,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.normal,
            color: whiteColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.share,
              color: whiteColor,
            ),
            tooltip: 'Share',
            onPressed: () async {
              if (controller.filePath.isNotEmpty) {
                await Share.shareXFiles(
                  [XFile(controller.filePath)],
                  sharePositionOrigin: Rect.fromCircle(
                    radius: Get.width * 0.25,
                    center: const Offset(0, 0),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (controller.errorMessage.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                controller.errorMessage.value,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          );
        }

        final sheets = controller.sheetNames;
        final selected = controller.selectedSheet.value;
        final rows = controller.excelData[selected] ?? [];

        if (sheets.isEmpty) {
          return const Center(child: Text('No sheets in this file.'));
        }

        return Column(
          children: [
            // Sheet selection tabs
            if (sheets.length > 1)
              Container(
                height: 50,
                color: Colors.grey[200],
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: sheets.length,
                  itemBuilder: (context, index) {
                    final sheetName = sheets[index];
                    final isSelected = sheetName == selected;
                    return GestureDetector(
                      onTap: () => controller.selectedSheet.value = sheetName,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? appColor : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: appColor),
                        ),
                        child: Text(
                          sheetName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : appColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Spreadsheet table
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('This sheet is empty.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Table(
                            defaultColumnWidth: const IntrinsicColumnWidth(),
                            border: TableBorder.all(
                              color: Colors.grey[400]!,
                              width: 0.8,
                            ),
                            children: rows.asMap().entries.map((entry) {
                              final rowIndex = entry.key;
                              final rowCells = entry.value;

                              return TableRow(
                                children: rowCells.map((cell) {

                                  // Use the actual cell background color if present,
                                  // otherwise fall back to alternating row shading
                                  Color? resolvedBg = cell.backgroundColor;
                                  resolvedBg ??= rowIndex % 2 == 0
                                      ? Colors.grey[50]
                                      : Colors.white;

                                  // Determine text color: actual font color or readable default
                                  Color textColor =
                                      cell.fontColor ?? Colors.black87;

                                  return Container(
                                    color: resolvedBg,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Text(
                                      cell.value,
                                      style: TextStyle(
                                        fontSize: cell.fontSize ?? 13,
                                        fontWeight: cell.isBold
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontStyle: cell.isItalic
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                        color: textColor,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }
}
