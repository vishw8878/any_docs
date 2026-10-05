import 'package:any_docs/core/constant/url_constant.dart';
import 'package:any_docs/feature/docx_viewer/binding/docx_viewer_binding.dart';
import 'package:any_docs/feature/docx_viewer/view/docx_viewer_view.dart';
import 'package:any_docs/feature/home_page/binding/home_binding.dart';
import 'package:any_docs/feature/home_page/view/home_view.dart';
import 'package:any_docs/feature/pdf_viewer_view/binding/pdf_viewer_binding.dart';
import 'package:any_docs/feature/pdf_viewer_view/view/pdf_viewer_view.dart';
import 'package:any_docs/feature/xls_viewer/binding/xls_viewer_binding.dart';
import 'package:any_docs/feature/xls_viewer/view/xls_viewer_view.dart';
import 'package:get/get.dart';

import '../../feature/login/login_binding.dart';
import '../../feature/login/login_view.dart';
import '../../feature/sign_up/sign_up_binding.dart';
import '../../feature/sign_up/sign_up_view.dart';

List<GetPage> getPages = [
  GetPage(
      name: RouteConstant.homePage,
      page: () => HomePageView(),
      binding: HomePageBinding(),
    // preventDuplicates: false
  ),
  GetPage(
      name: RouteConstant.pdfViewerPage,
      page: () => PdfViewerPage(),
      binding: PdfViewerBinding()),
  GetPage(
      name: RouteConstant.docxViewerPage,
      page: () => DocxViewerView(),
      binding: DocxViewerBinding()),
  GetPage(
      name: RouteConstant.xlsViewerPage,
      page: () => XlsViewerView(),
      binding: XlsViewerBinding()),

      GetPage(
        name: RouteConstant.LOGIN,
        page: () => const LoginView(),
        binding: LoginBinding(),
      ),

      GetPage(
        name: RouteConstant.SIGN_UP,
        page: () => const SignUpView(),
        binding: SignUpBinding(),
      ),
];
