import 'package:any_docs/core/constant/get_pages.dart';
import 'package:any_docs/core/constant/url_constant.dart';
import 'package:any_docs/core/utils/app_colour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';

void main() {
   WidgetsFlutterBinding.ensureInitialized();
  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(

      debugShowCheckedModeBanner: false,
      title: 'Any Docs',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: appColor),
        useMaterial3: true,
      ),
      getPages: getPages,
      initialRoute: RouteConstant.homePage,
    );
  }
}


