import 'package:any_docs/core/utils/app_colour.dart';
import 'package:any_docs/feature/pdf_viewer_view/controller/pdf_viewer_controller.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter/material.dart';
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
        child: WillPopScope(
            onWillPop: () async {
              return true;
            },
            child: Scaffold(
              appBar: AppBar(
                leading: InkWell(
                    onTap: () {
                      Get.back();
                    },
                    child: Icon(
                      Icons.arrow_back,
                      color: whiteColor,
                    )),
                backgroundColor: Colors.red[900],
                title: Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.normal, color: whiteColor),
                ),
                actions: [
                  Obx(() => Padding(
                        padding: EdgeInsets.only(right: Get.width * 0.05),
                        child: Text(
                          '${controller.currentPage.value}/${controller.totalPages.value}',
                          style: TextStyle(
                              fontWeight: FontWeight.normal, color: whiteColor),
                        ),
                      )),
                  IconButton(
                    icon: Icon(
                      Icons.share,
                      color: whiteColor,
                    ),
                    tooltip: 'Download',
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
                  controller.totalPages.value = (pages ?? 0).toString();
                },
                onError: (error) {
                  debugPrint(error.toString());
                },
                onPageError: (page, error) {
                  debugPrint('$page: ${error.toString()}');
                },
                onViewCreated: (PDFViewController pdfViewController) {},
                onPageChanged: (int? page, int? total) {
                  if (page != null && total != null) {
                    controller.currentPage.value = page + 1;
                  } else {
                    controller.currentPage.value = 0;
                  }
                },
              ),
            )));
  }
}
