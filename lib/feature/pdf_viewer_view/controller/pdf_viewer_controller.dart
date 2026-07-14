import 'package:get/get.dart';

class PdfViewerController extends GetxController {
  dynamic arguments;

  String filePath = '';
  String fileName = '';
  // Initial Selected Value

  RxInt currentPage = 0.obs;
  RxString totalPages = "".obs;

  @override
  void onInit() {
    arguments = Get.arguments;
    if (arguments is List && arguments.length >= 2) {
      filePath = arguments[0] as String;
      fileName = arguments[1] as String;
    }
    super.onInit();
  }
}
