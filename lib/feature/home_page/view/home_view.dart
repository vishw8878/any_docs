import 'package:any_docs/core/constant/url_constant.dart';
import 'package:any_docs/core/utils/app_colour.dart';
import 'package:any_docs/feature/home_page/controller/home_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

class HomePageView extends GetView<HomePageController> {
  const HomePageView({super.key});

  static const _cardTextStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 16,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        centerTitle: true,
        backgroundColor: appColor,
        title: const Text(
          'Any Docs',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            color: Colors.white,
            tooltip: 'Exit',
            icon: const Icon(Icons.exit_to_app_rounded),
            onPressed: _showExitDialog,
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .90,
        children: [
          _HomeCard(
            title: 'Open PDF',
            icon: Icons.picture_as_pdf,
            onTap: controller.onPdfButtonPressed,
          ),
          _HomeCard(
            title: 'Open DOCX',
            icon: CupertinoIcons.doc_fill,
            onTap: controller.onDocxButtonPressed,
          ),
          _HomeCard(
            title: 'Open XLS',
            icon: FontAwesomeIcons.fileExcel,
            onTap: controller.onXlsButtonPressed,
          ),
          _HomeCard(
            title: 'Image to PDF',
            icon: Icons.image,
            onTap: _showImagePickerSheet,
          ),
          /*_HomeCard(
            title: 'PDF to Images',
            icon: Icons.photo_library,
            onTap: controller.convertPdfToImages,
          ),*/
        ],
      ),
    );
  }

  void _comingSoon() {
    Get.snackbar(
      'Coming Soon',
      'This feature will be improved in a future update.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: appColor,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
    );
  }

  void _showImagePickerSheet() {
    Get.bottomSheet(
      backgroundColor: Colors.white,
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ImageOption(
                image: 'assets/camera.jpg',
                title: 'Camera',
                onTap: () {
                  Get.back();
                  controller.openGallery.value = false;
                  controller.convertImageToPdf();
                },
              ),
              _ImageOption(
                image: 'assets/gallery.png',
                title: 'Gallery',
                onTap: () {
                  Get.back();
                  controller.openGallery.value = true;
                  controller.convertImageToPdf();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Exit'),
        content: const Text('Do you want to close the application?'),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(Get.context!).maybePop(),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
     final color = appColor;

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 55,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: HomePageView._cardTextStyle.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageOption extends StatelessWidget {
  const _ImageOption({
    required this.image,
    required this.title,
    required this.onTap,
  });

  final String image;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            image,
            height: 90,
            width: 90,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style:  TextStyle(
              color: appColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}