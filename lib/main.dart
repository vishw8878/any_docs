import 'package:any_docs/core/constant/get_pages.dart';
import 'package:any_docs/core/constant/url_constant.dart';
import 'package:any_docs/core/utils/app_colour.dart';
import 'package:any_docs/feature/home_page/binding/home_binding.dart';
import 'package:any_docs/feature/home_page/view/home_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
      initialRoute: FirebaseAuth.instance.currentUser == null
          ? RouteConstant.LOGIN
          : RouteConstant.homePage,
      unknownRoute: GetPage(
        name: '/unknown',
        page: () => const HomePageView(),
        binding: HomePageBinding(),
      ),
    );
  }
}
