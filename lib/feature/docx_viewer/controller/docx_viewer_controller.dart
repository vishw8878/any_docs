import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xml/xml.dart';

/// Represents a run of text with formatting, OR an inline image.
class DocxRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? color; // hex e.g. "FF0000"
  final double? fontSize;

  // Inline image support. If imageBytes is set, this run represents an
  // image, not text — `text` will be empty and should be ignored.
  final Uint8List? imageBytes;
  final double? imageWidth;  // logical px, converted from EMU
  final double? imageHeight; // logical px, converted from EMU

  const DocxRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color,
    this.fontSize,
    this.imageBytes,
    this.imageWidth,
    this.imageHeight,
  });

  bool get isImage => imageBytes != null;
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
  // Parallel structure to tableRows: background fill color per cell
  // (hex string like "0E8C6B", or null for no shading)
  final List<List<String?>>? tableCellShading;

  const DocxBlock({
    required this.type,
    this.runs = const [],
    this.headingLevel = 0,
    this.isBullet = false,
    this.isNumbered = false,
    this.listLevel = 0,
    this.tableRows,
    this.tableCellShading,
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

  // rId -> raw image bytes, built once per document from
  // word/_rels/document.xml.rels + word/media/*
  final Map<String, Uint8List> _imagesByRelId = {};

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
      _imagesByRelId.clear();

      final file = File(filePath);

      if (!await file.exists()) {
        errorMessage.value = 'File not found at path: $filePath';
        return;
      }

      if (!filePath.toLowerCase().endsWith('.docx')) {
        errorMessage.value =
        'Unsupported file type. Only .docx files are supported.';
        return;
      }

      final bytes = await file.readAsBytes();
      debugPrint('DOCX file path: $filePath');
      debugPrint('DOCX byte length: ${bytes.length}');

      if (bytes.length < 4) {
        errorMessage.value =
        'File is empty or too small to be a valid DOCX (${bytes.length} bytes)';
        return;
      }

      // A real ZIP (and therefore a real .docx) must start with 'PK'
      final isZipSignature = bytes[0] == 0x50 && bytes[1] == 0x4B;
      debugPrint(
          'DOCX starts with PK signature: $isZipSignature (first bytes: ${bytes.take(8).toList()})');

      if (!isZipSignature) {
        errorMessage.value =
        'This file is not a valid .docx (it may be a legacy .doc file '
            'or corrupted). Please provide a .docx file.';
        return;
      }

      final Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (e) {
        errorMessage.value =
        'Invalid DOCX: could not open as a ZIP archive ($e)';
        return;
      }
      debugPrint('DOCX archive entry count: ${archive.length}');

      String normalize(String name) => name.replaceAll('\\', '/').toLowerCase();

      // Lookup of every archive entry by normalized path, used for
      // document.xml, the rels file, and media files alike.
      final Map<String, ArchiveFile> entriesByPath = {
        for (final f in archive) normalize(f.name): f,
      };

      final docXml = entriesByPath['word/document.xml'] ??
          entriesByPath.entries
              .firstWhereOrNull((e) => e.key.endsWith('word/document.xml'))
              ?.value;

      if (docXml == null) {
        debugPrint(
            'DOCX entries found: ${archive.map((f) => f.name).join(', ')}');
        errorMessage.value = 'Invalid DOCX: document.xml not found';
        return;
      }

      // Parse word/_rels/document.xml.rels to map rId -> media path, then
      // load the actual image bytes from word/media/*.
      final relsFile = entriesByPath['word/_rels/document.xml.rels'];
      if (relsFile != null) {
        try {
          final relsContent = relsFile.content;
          if (relsContent is List<int>) {
            final relsXmlString =
            utf8.decode(relsContent, allowMalformed: true);
            final relsDoc = XmlDocument.parse(relsXmlString);
            for (final rel in relsDoc.findAllElements('Relationship')) {
              final type = rel.getAttribute('Type') ?? '';
              if (!type.endsWith('/image')) continue;
              final id = rel.getAttribute('Id');
              var target = rel.getAttribute('Target');
              if (id == null || target == null) continue;

              // Targets are relative to word/, e.g. "media/foo.png"
              target = target.replaceAll('\\', '/');
              if (target.startsWith('/')) {
                target = target.substring(1);
              } else {
                target = 'word/$target';
              }

              final imgEntry = entriesByPath[normalize(target)];
              final imgContent = imgEntry?.content;
              if (imgContent is List<int>) {
                _imagesByRelId[id] = Uint8List.fromList(imgContent);
              }
            }
            debugPrint('DOCX images resolved: ${_imagesByRelId.length}');
          }
        } catch (e) {
          debugPrint('DOCX rels parse error (images may be missing): $e');
        }
      }

      final content = docXml.content;
      if (content is! List<int>) {
        errorMessage.value =
        'Invalid DOCX: document.xml has unexpected content type';
        return;
      }

      final xmlString = utf8.decode(content, allowMalformed: true);
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

    final body = doc.findAllElements('w:body').firstOrNull;
    if (body == null) return result;

    for (final child in body.childElements) {
      final tag = child.localName;
      if (tag == 'p') {
        result.add(_parseParagraph(child));
      } else if (tag == 'tbl') {
        result.add(_parseTable(child));
      }
    }

    return result;
  }

  DocxBlock _parseParagraph(XmlElement para) {
    final pPr = para.findElements('w:pPr').firstOrNull;
    int headingLevel = 0;
    bool isBullet = false;
    bool isNumbered = false;
    int listLevel = 0;

    if (pPr != null) {
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

      final numPr = pPr.findElements('w:numPr').firstOrNull;
      if (numPr != null) {
        final ilvl = numPr.findElements('w:ilvl').firstOrNull;
        listLevel = int.tryParse(ilvl?.getAttribute('w:val') ?? '0') ?? 0;
        isBullet = true;
      }
    }

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
            fontSize = (int.tryParse(szVal) ?? 24) / 2.0;
          }
        }

        // Inline images live inside w:r as w:drawing
        for (final drawing in child.findElements('w:drawing')) {
          final imageRun = _parseDrawing(drawing);
          if (imageRun != null) runs.add(imageRun);
        }

        final textBuffer = StringBuffer();
        for (final t in child.findElements('w:t')) {
          textBuffer.write(t.innerText);
        }

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
        runs.addAll(_parseRuns(child));
      }
    }

    return runs;
  }

  /// Parses a <w:drawing> element and resolves it to image bytes via the
  /// rId -> media map built in _parseDocx.
  DocxRun? _parseDrawing(XmlElement drawing) {
    final blip = drawing.findAllElements('a:blip').firstOrNull;
    if (blip == null) return null;

    final rId = blip.getAttribute('r:embed') ??
        blip.attributes
            .firstWhereOrNull((a) => a.localName == 'embed')
            ?.value;
    if (rId == null) return null;

    final bytes = _imagesByRelId[rId];
    if (bytes == null) return null;

    // Extent is in EMUs (914400 per inch); convert to logical px at 96 DPI.
    final extent = drawing.findAllElements('wp:extent').firstOrNull;
    double? width;
    double? height;
    if (extent != null) {
      final cx = double.tryParse(extent.getAttribute('cx') ?? '');
      final cy = double.tryParse(extent.getAttribute('cy') ?? '');
      if (cx != null) width = cx / 914400 * 96;
      if (cy != null) height = cy / 914400 * 96;
    }

    return DocxRun(
      text: '',
      imageBytes: bytes,
      imageWidth: width,
      imageHeight: height,
    );
  }

  DocxBlock _parseTable(XmlElement tbl) {
    final List<List<List<DocxRun>>> tableRows = [];
    final List<List<String?>> tableCellShading = [];

    for (final tr in tbl.findElements('w:tr')) {
      final List<List<DocxRun>> row = [];
      final List<String?> rowShading = [];

      for (final tc in tr.findElements('w:tc')) {
        final List<DocxRun> cellRuns = [];
        for (final p in tc.findElements('w:p')) {
          cellRuns.addAll(_parseRuns(p));
          if (cellRuns.isNotEmpty) {
            cellRuns.add(const DocxRun(text: '\n'));
          }
        }
        row.add(cellRuns);

        // Cell background shading lives in w:tcPr/w:shd
        String? fill;
        final tcPr = tc.findElements('w:tcPr').firstOrNull;
        final shd = tcPr?.findElements('w:shd').firstOrNull;
        final fillVal = shd?.getAttribute('w:fill');
        if (fillVal != null &&
            fillVal.toLowerCase() != 'auto' &&
            fillVal.toLowerCase() != 'ffffff') {
          fill = fillVal;
        }
        rowShading.add(fill);
      }

      if (row.isNotEmpty) {
        tableRows.add(row);
        tableCellShading.add(rowShading);
      }
    }

    return DocxBlock(
      type: DocxBlockType.table,
      tableRows: tableRows,
      tableCellShading: tableCellShading,
    );
  }
}