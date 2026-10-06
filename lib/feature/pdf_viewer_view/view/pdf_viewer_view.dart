import 'package:any_docs/core/utils/app_colour.dart';
import 'package:any_docs/feature/pdf_viewer_view/controller/pdf_viewer_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

class PdfViewerPage extends GetView<PdfViewerController> {
  const PdfViewerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final title = controller.fileName.length > 18
        ? '${controller.fileName.substring(0, 18)}...'
        : controller.fileName;

    return Material(
      child: PopScope(
        canPop: true,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: Get.back,
              icon: Icon(
                Icons.arrow_back,
                color: whiteColor,
              ),
            ),
            backgroundColor: Colors.red[900],
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.normal,
                color: whiteColor,
              ),
            ),
            actions: [
              Obx(
                () => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(
                    child: Text(
                      '${controller.currentPage.value}/${controller.totalPages.value}',
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: whiteColor,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.keyboard_double_arrow_down_rounded,
                  color: whiteColor,
                ),
                tooltip: 'Go to last page',
                onPressed: controller.goToLastPage,
              ),
              IconButton(
                icon: Icon(
                  Icons.numbers_rounded,
                  color: whiteColor,
                ),
                tooltip: 'Go to page',
                onPressed: controller.showGoToPageDialog,
              ),
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
          body: PDFView(
            fitPolicy: FitPolicy.BOTH,
            filePath: controller.filePath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: false,
            pageFling: false,
            onRender: (pages) {
              controller.updateTotalPages(pages ?? 0);
            },
            onError: (error) {
              debugPrint(error.toString());
            },
            onPageError: (page, error) {
              debugPrint('$page: ${error.toString()}');
            },
            onViewCreated: controller.setPdfViewController,
            onPageChanged: (int? page, int? total) {
              if (page != null) {
                controller.updateCurrentPage(page);
              } else {
                controller.currentPage.value = 0;
              }

              if (total != null) {
                controller.updateTotalPages(total);
              }
            },
          ),
        ),
      ),
    );
  }
}
