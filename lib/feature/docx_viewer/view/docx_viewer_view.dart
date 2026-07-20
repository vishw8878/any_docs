import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:any_docs/feature/docx_viewer/controller/docx_viewer_controller.dart';
import 'package:any_docs/core/utils/app_colour.dart';

class DocxViewerView extends GetView<DocxViewerController> {
  const DocxViewerView({super.key});

  @override
  Widget build(BuildContext context) {
    final title = controller.fileName.length > 18
        ? '${controller.fileName.substring(0, 18)}...'
        : controller.fileName;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: InkWell(
          onTap: () => Get.back(),
          child: Icon(Icons.arrow_back, color: whiteColor),
        ),
        backgroundColor: Colors.blue[900],
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.normal, color: whiteColor),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: whiteColor),
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
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.red, fontSize: 15),
                  ),
                ],
              ),
            ),
          );
        }

        if (controller.blocks.isEmpty) {
          return const Center(child: Text('Document is empty.'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: controller.blocks
                      .map((block) => _buildBlock(context, block))
                      .toList(),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBlock(BuildContext context, DocxBlock block) {
    switch (block.type) {
      case DocxBlockType.table:
        return _buildTable(block);
      case DocxBlockType.pageBreak:
        return const Divider(height: 32, thickness: 1);
      case DocxBlockType.paragraph:
        return _buildParagraph(block);
    }
  }

  Widget _buildParagraph(DocxBlock block) {
    final allText = block.runs.map((r) => r.text).join();

    // Skip completely empty paragraphs but keep single spacing
    if (allText.trim().isEmpty) {
      return const SizedBox(height: 8);
    }

    EdgeInsets padding;

    if (block.headingLevel == 1) {
      padding = const EdgeInsets.only(top: 20, bottom: 8);
    } else if (block.headingLevel == 2) {
      padding = const EdgeInsets.only(top: 16, bottom: 6);
    } else if (block.headingLevel >= 3) {
      padding = const EdgeInsets.only(top: 12, bottom: 4);
    } else {
      padding = const EdgeInsets.only(bottom: 6);
    }

    Widget textWidget;

    if (block.runs.isEmpty) {
      textWidget = const SizedBox.shrink();
    } else {
      textWidget = RichText(
        text: TextSpan(
          children: block.runs
              .map((run) => _buildTextSpan(run, block.headingLevel))
              .toList(),
        ),
      );
    }

    // Bullet / list prefix
    if (block.isBullet) {
      final indent = (block.listLevel + 1) * 16.0;
      return Padding(
        padding: EdgeInsets.only(left: indent, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ',
                style: TextStyle(
                  fontSize: _headingFontSize(block.headingLevel),
                  color: Colors.black87,
                )),
            Expanded(child: textWidget),
          ],
        ),
      );
    }

    // Add a top border for h1/h2
    if (block.headingLevel == 1) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            textWidget,
            const SizedBox(height: 4),
            Divider(color: Colors.blue[900], thickness: 1.5),
          ],
        ),
      );
    }

    return Padding(
      padding: padding,
      child: textWidget,
    );
  }

  TextSpan _buildTextSpan(DocxRun run, int headingLevel) {
    // Resolve text color
    Color textColor = Colors.black87;
    if (run.color != null && run.color!.isNotEmpty) {
      try {
        textColor = Color(int.parse('FF${run.color!}', radix: 16));
      } catch (_) {}
    }
    // Heading color override
    if (headingLevel == 1) textColor = Colors.blue.shade900;
    if (headingLevel == 2) textColor = Colors.blueGrey.shade800;

    // Font size: use explicit size or derive from heading level
    final fontSize = run.fontSize ?? _headingFontSize(headingLevel);
    final fontWeight = (run.bold || headingLevel > 0)
        ? FontWeight.bold
        : FontWeight.normal;

    return TextSpan(
      text: run.text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
        decoration: run.underline ? TextDecoration.underline : TextDecoration.none,
        color: textColor,
        height: 1.5,
      ),
    );
  }

  double _headingFontSize(int level) {
    switch (level) {
      case 1:
        return 24;
      case 2:
        return 20;
      case 3:
        return 17;
      case 4:
        return 15;
      case 5:
      case 6:
        return 14;
      default:
        return 14;
    }
  }

  Widget _buildTable(DocxBlock block) {
    final tableRows = block.tableRows ?? [];
    if (tableRows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: Colors.grey.shade400, width: 0.8),
          children: tableRows.asMap().entries.map((rowEntry) {
            final rowIndex = rowEntry.key;
            final cells = rowEntry.value;
            final isFirstRow = rowIndex == 0;

            // Check if any cell in this row has bold runs (marks it as header)
            final hasHeaderStyling = isFirstRow ||
                cells.any((cellRuns) => cellRuns.any((r) => r.bold));

            return TableRow(
              decoration: BoxDecoration(
                color: hasHeaderStyling ? Colors.blue[50] : Colors.white,
              ),
              children: cells.map((cellRuns) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: RichText(
                    text: TextSpan(
                      children: cellRuns
                          .where((r) => r.text != '\n')
                          .map((r) => _buildTextSpan(
                              r, hasHeaderStyling ? 3 : 0))
                          .toList(),
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }
}