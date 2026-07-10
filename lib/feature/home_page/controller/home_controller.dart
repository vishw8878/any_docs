import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:open_file/open_file.dart' as open_file;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:pdf/pdf.dart' as pdf_plugin;
import 'package:pdf/widgets.dart' as pw;
import 'package:any_docs/core/constant/url_constant.dart';
import 'package:any_docs/core/utils/loaderScreen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class HomePageController extends GetxController {
  
  final _sharedFiles = <SharedMediaFile>[];
  RxBool isPasswordProtected = false.obs;
  RxBool openGallery = false.obs;
  RxBool showLoader = false.obs;
  TextEditingController passwordTextController = TextEditingController();

  // final List<SharedMediaFile> _sharedFiles = [];

  // late final TextEditingController passwordTextController;
  //
  StreamSubscription<List<SharedMediaFile>>? _shareSubscription;

  // final isPasswordProtected = false.obs;
  // final openGallery = false.obs;
  // final showLoader = false.obs;

  @override
  void onInit() {
    super.onInit();

    FlutterNativeSplash.remove();

    passwordTextController = TextEditingController();

    _initializeShareIntent();
  }

  @override
  void onClose() {
    _shareSubscription?.cancel();
    passwordTextController.dispose();
    super.onClose();
  }

  Future<void> _initializeShareIntent() async {
    _shareSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (files) async {
        debugPrint('Share intent received');
        await _handleSharedFiles(files, fromInitialLaunch: false);
      },
      onError: (error) {
        debugPrint(error.toString());
      },
    );

    final initialFiles =
    await ReceiveSharingIntent.instance.getInitialMedia();


    if (initialFiles.isNotEmpty) {
      debugPrint('Share intent received (terminated)');
      await _handleSharedFiles(
        initialFiles,
        fromInitialLaunch: true,
      );
    }
  }

  Future<void> _handleSharedFiles(
      List<SharedMediaFile> files, {
        required bool fromInitialLaunch,
      }) async {
    await ReceiveSharingIntent.instance.reset();
    if (files.isEmpty) return;

    _sharedFiles
      ..clear()
      ..addAll(files);

    final sharedFile = _sharedFiles.first;

    if (!sharedFile.path.toLowerCase().endsWith('.pdf')) {
      return;
    }

    if (!fromInitialLaunch) {
      _openPdf(sharedFile.path);
      return;
    }

    final protected = await isPdgProtected(sharedFile.path);

    if (!protected) {
      _openPdf(sharedFile.path);
      return;
    }

    _showPasswordDialog(
      pdfPath: sharedFile.path,
      fileName: sharedFile.path.split('/').last,
    );
  }

  void _openPdf(String path) {
    Get.toNamed(
      RouteConstant.pdfViewerPage,
      arguments: [
        path,
        path.split('/').last,
      ],
    );
  }

  Future<void> onPdfButtonPressed() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      final isProtected = await isPdgProtected(file.path);

      if (!isProtected) {
        _openPdf(file.path);
        return;
      }

      _showPasswordDialog(
        pdfPath: file.path,
        fileName: fileName,
      );
    } catch (e, stackTrace) {
      debugPrint('PDF Picker Error: $e');
      debugPrintStack(stackTrace: stackTrace);

      Get.snackbar(
        'Error',
        'Unable to open PDF.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  Future<void> _showPasswordDialog({
    required String pdfPath,
    required String fileName,
  }) async {
    passwordTextController.clear();

    Get.defaultDialog(
      title: 'Security Alert!',
      barrierDismissible: false,
      content: Column(
        children: [
          const Text('PDF is password protected.'),
          const SizedBox(height: 12),
          TextField(
            controller: passwordTextController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Enter password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              Get.back();

              await _unlockPdf(
                pdfPath,
                fileName,
                passwordTextController.text.trim(),
              );
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }
  Future<void> _unlockPdf(
      String pdfPath,
      String fileName,
      String password,
      ) async {
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      final bytes = await File(pdfPath).readAsBytes();

      final document = PdfDocument(
        inputBytes: bytes,
        password: password,
      );

      document.security.userPassword = '';

      final outputBytes = document.saveSync();

      document.dispose();

      final directory = await getTemporaryDirectory();

      final outputFile = File(
        '${directory.path}/$fileName',
      );

      await outputFile.writeAsBytes(outputBytes);

      Get.back();

      _openPdf(outputFile.path);
    } catch (e) {
      Get.back();

      Get.snackbar(
        'Invalid Password',
        'Please enter the correct password.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  Future<void> convertImageToPdf() async {
    final picker = ImagePicker();
    final pdf = pw.Document();

    Get.dialog(
      PopScope(
        canPop: false,
        child: Center(
          child: Loading(),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      List<XFile> images = [];

      if (openGallery.value) {
        images = await picker.pickMultiImage(
          imageQuality: 100,
        );
      } else {
        final image = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 100,
        );

        if (image != null) {
          images.add(image);
        }
      }

      if (images.isEmpty) {
        Get.back();
        return;
      }

      for (final image in images) {
        final bytes = await image.readAsBytes();
        final dimension = await _loadImage(image);

        pdf.addPage(
          pw.Page(
            pageFormat: pdf_plugin.PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(2),
            build: (_) {
              return pw.Center(
                child: pw.Image(
                  pw.MemoryImage(bytes),
                  width: dimension.width.toDouble(),
                  height: dimension.height.toDouble(),
                ),
              );
            },
          ),
        );
      }

      final outputBytes = await pdf.save();

      final directory = await getTemporaryDirectory();

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}.pdf';

      final file = File(
        '${directory.path}/$fileName',
      );

      await file.writeAsBytes(outputBytes);

      Get.back();

      _openPdf(file.path);
    } catch (e, stackTrace) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      debugPrint('ImageToPdf Error: $e');
      debugPrintStack(stackTrace: stackTrace);

      Get.snackbar(
        'Error',
        'Unable to create PDF.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }


  Future<void> saveAndLaunchFile(
      List<int> bytes,
      String fileName,
      ) async {
    try {
      final Directory directory;

      if (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isLinux ||
          Platform.isWindows) {
        directory = await path_provider.getApplicationSupportDirectory();
      } else {
        final path =
        await PathProviderPlatform.instance.getApplicationSupportPath();

        directory = Directory(path!);
      }

      final file = File(
        Platform.isWindows
            ? '${directory.path}\\$fileName'
            : '${directory.path}/$fileName',
      );

      await file.writeAsBytes(bytes, flush: true);

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      showLoader.value = false;

      if (Platform.isAndroid || Platform.isIOS) {
        final result = await open_file.OpenFile.open(file.path);

        if (result.type != open_file.ResultType.done) {
          Get.snackbar(
            'Error',
            result.message,
          );
        }

        return;
      }

      if (Platform.isWindows) {
        await Process.run(
          'start',
          [file.path],
          runInShell: true,
        );
        return;
      }

      if (Platform.isMacOS) {
        await Process.run(
          'open',
          [file.path],
          runInShell: true,
        );
        return;
      }

      if (Platform.isLinux) {
        await Process.run(
          'xdg-open',
          [file.path],
          runInShell: true,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Unable to open PDF.',
      );
    }
  }

  Future<bool> isPdgProtected(path) async {
    bool isEncrypted(List<int> bytes) {
      final signature = bytes.sublist(0, 8);
      final String hexSignature =
      signature.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
      log('hexSignature.toUpperCase()');
      log('hex string: ${hexSignature.toUpperCase()}');
      return hexSignature.toUpperCase() ==
          '255044462D312E34';
    }

    File file = File(path);
    List<int> bytes = await file.readAsBytes();

    if (isEncrypted(bytes)) {
      return true;
    } else {
      return false;
    }
  }

  Future<ui.Image> _loadImage(XFile file) async {
    Uint8List bytes = await file.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }



  ///*************************************************************************************************//////////



}
