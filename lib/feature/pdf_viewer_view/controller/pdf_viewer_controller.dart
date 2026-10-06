import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:get/get.dart';

class PdfViewerController extends GetxController {
  dynamic arguments;

  String filePath = '';
  String fileName = '';

  final currentPage = 0.obs;
  final totalPages = 0.obs;
  final pageInputController = TextEditingController();

  PDFViewController? _pdfViewController;

  @override
  void onInit() {
    arguments = Get.arguments;
    if (arguments is List && arguments.length >= 2) {
      filePath = arguments[0] as String;
      fileName = arguments[1] as String;
    }
    super.onInit();
  }

  void setPdfViewController(PDFViewController pdfViewController) {
    _pdfViewController = pdfViewController;
  }

  void updateTotalPages(int pages) {
    totalPages.value = pages;
  }

  void updateCurrentPage(int zeroBasedPage) {
    currentPage.value = zeroBasedPage + 1;
  }

  Future<void> goToLastPage() async {
    if (totalPages.value <= 0) {
      return;
    }

    await goToPage(totalPages.value);
  }

  Future<void> goToPage(int page) async {
    final pageCount = totalPages.value;

    if (_pdfViewController == null || pageCount <= 0) {
      return;
    }

    final targetPage = page.clamp(1, pageCount);
    await _pdfViewController!.setPage(targetPage - 1);
    currentPage.value = targetPage;
  }

  void showGoToPageDialog() {
    pageInputController.text = currentPage.value > 0
        ? currentPage.value.toString()
        : '';

    Get.dialog(
      AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: pageInputController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Page number',
            helperText: totalPages.value > 0
                ? 'Enter 1 to ${totalPages.value}'
                : null,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => submitPageJump(),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: submitPageJump,
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  Future<void> submitPageJump() async {
    final page = int.tryParse(pageInputController.text.trim());

    if (page == null) {
      Get.snackbar(
        'Invalid page',
        'Please enter a valid page number.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    await goToPage(page);
  }

  @override
  void onClose() {
    pageInputController.dispose();
    super.onClose();
  }
}
