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
                    style: const TextStyle(color: Colors.red, fontSize: 15),
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
    // A paragraph is "empty" only if it has no text AND no images.
    final hasText = block.runs.any((r) => !r.isImage && r.text.trim().isNotEmpty);
    final hasImage = block.runs.any((r) => r.isImage);

    if (!hasText && !hasImage) {
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

    // If the paragraph is ONLY an image (or images), lay them out directly
    // rather than inside a RichText, so sizing/aspect ratio behaves well.
    if (hasImage && !hasText) {
      return Padding(
        padding: padding,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: block.runs
              .where((r) => r.isImage)
              .map((r) => _buildImage(r))
              .toList(),
        ),
      );
    }

    Widget textWidget;

    if (block.runs.isEmpty) {
      textWidget = const SizedBox.shrink();
    } else {
      textWidget = RichText(
        text: TextSpan(
          children: block.runs
              .map((run) => _buildInlineSpan(run, block.headingLevel))
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

  /// Builds either a text span or an image span (WidgetSpan) for a run,
  /// so images and text can be mixed inline inside the same RichText.
  InlineSpan _buildInlineSpan(DocxRun run, int headingLevel) {
    if (run.isImage) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _buildImage(run),
      );
    }
    return _buildTextSpan(run, headingLevel);
  }

  Widget _buildImage(DocxRun run) {
    // Cap the rendered width so large embedded images don't overflow the
    // 800px reading column; keep aspect ratio using the parsed EMU size.
    const maxWidth = 700.0;
    double? width = run.imageWidth;
    double? height = run.imageHeight;
    if (width != null && width > maxWidth && height != null) {
      final scale = maxWidth / width;
      width = maxWidth;
      height = height * scale;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          run.imageBytes!,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => Container(
            width: width ?? 120,
            height: height ?? 80,
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
          ),
        ),
      ),
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
        decoration:
        run.underline ? TextDecoration.underline : TextDecoration.none,
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

  /// Parses "0E8C6B" style hex into a Color. Returns null on failure.
  Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }

  /// Picks readable text color (black/white) against a given background,
  /// so text stays legible on dark shaded cells (e.g. green/orange badges).
  Color _readableTextOn(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  Widget _buildTable(DocxBlock block) {
    final tableRows = block.tableRows ?? [];
    if (tableRows.isEmpty) return const SizedBox.shrink();
    final shading = block.tableCellShading;

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

            final hasHeaderStyling = isFirstRow ||
                cells.any((cellRuns) => cellRuns.any((r) => r.bold));

            return TableRow(
              // Row-level fallback background (header highlight) when no
              // per-cell shading is used; individual cells override this
              // below via their own Container color.
              decoration: BoxDecoration(
                color: hasHeaderStyling ? Colors.blue[50] : Colors.white,
              ),
              children: cells.asMap().entries.map((cellEntry) {
                final cellIndex = cellEntry.key;
                final cellRuns = cellEntry.value;

                final fillHex = (shading != null &&
                    rowIndex < shading.length &&
                    cellIndex < shading[rowIndex].length)
                    ? shading[rowIndex][cellIndex]
                    : null;
                final bgColor = _parseHexColor(fillHex);

                return Container(
                  color: bgColor, // null = no override, keeps row decoration
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: RichText(
                    text: TextSpan(
                      children: cellRuns
                          .where((r) => r.isImage || r.text != '\n')
                          .map((r) {
                        if (r.isImage) {
                          return WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: _buildImage(r),
                          );
                        }
                        final span =
                        _buildTextSpan(r, hasHeaderStyling ? 3 : 0);
                        // Force readable text color over a colored cell.
                        if (bgColor != null) {
                          return TextSpan(
                            text: span.text,
                            style: span.style?.copyWith(
                              color: _readableTextOn(bgColor),
                            ),
                          );
                        }
                        return span;
                      }).toList(),
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