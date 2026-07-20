import 'package:any_docs/feature/xls_viewer/controller/xls_viewer_controller.dart';
import 'package:get/get.dart';

class XlsViewerBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(XlsViewerController());
  }
}
