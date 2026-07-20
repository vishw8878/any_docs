import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xml/xml.dart';

/// Represents a run of text with formatting
class DocxRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? color; // hex e.g. "FF0000"
  final double? fontSize;

  const DocxRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color,
    this.fontSize,
  });
}

/// Represents a single paragraph or table cell
class DocxBlock {
  final DocxBlockType type;
  final List<DocxRun> runs;
  final int headingLevel; // 0 = normal, 1-6 = heading
  final bool isBullet;
  final bool isNumbered;
  final int listLevel;

  // For table support
  final List<List<List<DocxRun>>>? tableRows; // rows -> cells -> runs

  const DocxBlock({
    required this.type,
    this.runs = const [],
    this.headingLevel = 0,
    this.isBullet = false,
    this.isNumbered = false,
    this.listLevel = 0,
    this.tableRows,
  });
}

enum DocxBlockType { paragraph, table, pageBreak }

class DocxViewerController extends GetxController {
  dynamic arguments;

  String filePath = '';
  String fileName = '';

  RxBool isLoading = true.obs;
  RxString errorMessage = ''.obs;
  RxList<DocxBlock> blocks = <DocxBlock>[].obs;

  @override
  void onInit() {
    arguments = Get.arguments;
    if (arguments is List && arguments.length >= 2) {
      filePath = arguments[0] as String;
      fileName = arguments[1] as String;
      _parseDocx();
    } else {
      isLoading.value = false;
      errorMessage.value = 'No file path provided';
    }
    super.onInit();
  }

  Future<void> _parseDocx() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final file = File(filePath);
      final bytes = await file.readAsBytes();

      // DOCX is a ZIP archive
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find word/document.xml
      ArchiveFile? docXml;
      for (final f in archive) {
        if (f.name == 'word/document.xml') {
          docXml = f;
          break;
        }
      }

      if (docXml == null) {
        errorMessage.value = 'Invalid DOCX: document.xml not found';
        return;
      }

      final xmlString = utf8.decode(docXml.content as List<int>);
      final document = XmlDocument.parse(xmlString);

      final parsed = _parseDocument(document);
      blocks.assignAll(parsed);
    } catch (e, stack) {
      debugPrint('DOCX parse error: $e\n$stack');
      errorMessage.value = 'Failed to render document: $e';
    } finally {
      isLoading.value = false;
    }
  }

  List<DocxBlock> _parseDocument(XmlDocument doc) {
    final List<DocxBlock> result = [];

    // Body is under w:document > w:body
    final body = doc.findAllElements('w:body').firstOrNull;
    if (body == null) return result;

    for (final child in body.childElements) {
      final tag = child.localName;
      if (tag == 'p') {
        final block = _parseParagraph(child);
        result.add(block);
      } else if (tag == 'tbl') {
        final block = _parseTable(child);
        result.add(block);
      }
    }

    return result;
  }

  DocxBlock _parseParagraph(XmlElement para) {
    // Get paragraph properties
    final pPr = para.findElements('w:pPr').firstOrNull;
    int headingLevel = 0;
    bool isBullet = false;
    bool isNumbered = false;
    int listLevel = 0;

    if (pPr != null) {
      // Heading style
      final styleEl = pPr.findElements('w:pStyle').firstOrNull;
      final styleName = styleEl?.getAttribute('w:val') ?? '';
      if (styleName.toLowerCase().startsWith('heading')) {
        final num = int.tryParse(styleName.replaceAll(RegExp(r'[^0-9]'), ''));
        headingLevel = num ?? 0;
      } else if (styleName.toLowerCase() == 'title') {
        headingLevel = 1;
      } else if (styleName.toLowerCase() == 'subtitle') {
        headingLevel = 2;
      }

      // List / numbering
      final numPr = pPr.findElements('w:numPr').firstOrNull;
      if (numPr != null) {
        final ilvl = numPr.findElements('w:ilvl').firstOrNull;
        listLevel = int.tryParse(ilvl?.getAttribute('w:val') ?? '0') ?? 0;
        // Heuristic: treat as bullet (numId exists)
        isBullet = true;
      }
    }

    // Parse runs
    final runs = _parseRuns(para);

    return DocxBlock(
      type: DocxBlockType.paragraph,
      runs: runs,
      headingLevel: headingLevel,
      isBullet: isBullet,
      isNumbered: isNumbered,
      listLevel: listLevel,
    );
  }

  List<DocxRun> _parseRuns(XmlElement parent) {
    final List<DocxRun> runs = [];

    for (final child in parent.childElements) {
      if (child.localName == 'r') {
        // Text run
        final rPr = child.findElements('w:rPr').firstOrNull;
        bool bold = false;
        bool italic = false;
        bool underline = false;
        String? color;
        double? fontSize;

        if (rPr != null) {
          bold = rPr.findElements('w:b').isNotEmpty ||
              rPr.findElements('w:bCs').isNotEmpty;
          italic = rPr.findElements('w:i').isNotEmpty ||
              rPr.findElements('w:iCs').isNotEmpty;
          underline = rPr.findElements('w:u').isNotEmpty &&
              (rPr.findElements('w:u').firstOrNull?.getAttribute('w:val') !=
                  'none');
          final colorEl = rPr.findElements('w:color').firstOrNull;
          color = colorEl?.getAttribute('w:val');
          if (color == 'auto') color = null;
          final szEl = rPr.findElements('w:sz').firstOrNull;
          final szVal = szEl?.getAttribute('w:val');
          if (szVal != null) {
            // Half-points to points
            fontSize = (int.tryParse(szVal) ?? 24) / 2.0;
          }
        }

        // Collect text content from w:t elements
        final textBuffer = StringBuffer();
        for (final t in child.findElements('w:t')) {
          textBuffer.write(t.innerText);
        }

        // Handle line breaks
        if (child.findElements('w:br').isNotEmpty) {
          textBuffer.write('\n');
        }

        final text = textBuffer.toString();
        if (text.isNotEmpty) {
          runs.add(DocxRun(
            text: text,
            bold: bold,
            italic: italic,
            underline: underline,
            color: color,
            fontSize: fontSize,
          ));
        }
      } else if (child.localName == 'hyperlink') {
        // Recurse into hyperlink
        runs.addAll(_parseRuns(child));
      }
    }

    return runs;
  }

  DocxBlock _parseTable(XmlElement tbl) {
    final List<List<List<DocxRun>>> tableRows = [];

    for (final tr in tbl.findElements('w:tr')) {
      final List<List<DocxRun>> row = [];
      for (final tc in tr.findElements('w:tc')) {
        final List<DocxRun> cellRuns = [];
        for (final p in tc.findElements('w:p')) {
          cellRuns.addAll(_parseRuns(p));
          // Add newline between paragraphs in same cell
          if (cellRuns.isNotEmpty) {
            cellRuns.add(const DocxRun(text: '\n'));
          }
        }
        row.add(cellRuns);
      }
      if (row.isNotEmpty) tableRows.add(row);
    }

    return DocxBlock(
      type: DocxBlockType.table,
      tableRows: tableRows,
    );
  }
}