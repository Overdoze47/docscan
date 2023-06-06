import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:doc/ad_helper.dart';
import 'package:image/image.dart' as img;
import 'my_app.dart';
import 'package:hand_signature/signature.dart';
import 'package:path_provider/path_provider.dart';

class FullScreenImage extends StatefulWidget {
  final String path;
  final ValueNotifier<String> name;
  final Function(String) onNameChanged;
  final FileType fileType; // add this line

  const FullScreenImage({
    Key? key,
    required this.path,
    required this.name,
    required this.onNameChanged,
    required this.fileType, // and this line
  }) : super(key: key);

  @override
  _FullScreenImageState createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;
  String? _signedImagePath;
  String? _updatedPath;

  img.Image? _image;
  img.Image? _filteredImage;

  final HandSignatureControl _signatureControl = HandSignatureControl(
    threshold: 3.0,
    smoothRatio: 0.65,
    velocityRange: 2.0,
  );
  bool _isSigning = false;

  @override
  void initState() {
    super.initState();
    _loadImage();

    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );

    _bannerAd.load();
  }

  Future<void> _loadImage() async {
    final bytes = await File(widget.path).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image != null) {
      setState(() {
        _image = image;
        _filteredImage = img.copyResize(image, width: 600);
      });
    }
  }

  Future<ui.Image> _loadImageFromBytes(ByteData data) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(data.buffer.asUint8List(), (ui.Image img) {
      completer.complete(img);
    });
    return completer.future;
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    _signatureControl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    String correctedPath = widget.path.replaceFirst('/data/user/0/', '/data/data/');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xff005874),
        title: ValueListenableBuilder<String>(
          valueListenable: widget.name,
          builder: (context, value, child) {
            return Text(value);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              TextEditingController nameController = TextEditingController(text: widget.name.value);
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Bildname ändern'),
                    content: TextField(
                      controller: nameController,
                      onChanged: (value) {},
                      decoration: InputDecoration(hintText: "Neuer Name"),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Abbrechen'),
                      ),
                      TextButton(
                        onPressed: () {
                          String newName = nameController.text;
                          widget.onNameChanged(newName);
                          widget.name.value = newName;
                          Navigator.of(context).pop();
                        },
                        child: Text('Speichern'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_isBannerAdReady)
                Container(
                  child: AdWidget(ad: _bannerAd),
                  width: screenWidth,
                  height: _bannerAd.size.height.toDouble(),
                  alignment: Alignment.center,
                ),
              Expanded(
                child: Center(
                  child: widget.fileType == FileType.jpg
                      ? _filteredImage != null
                      ? InteractiveViewer(
                    child: _signedImagePath != null
                        ? Image.file(
                      File(_signedImagePath!),
                      errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                        return const Text('Fehler beim Laden des Bildes');
                      },
                    )
                        : Image.memory(
                      img.encodeJpg(_filteredImage!),
                      errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                        return const Text('Fehler beim Laden des Bildes');
                      },
                    ),
                  )
                      : CircularProgressIndicator()
                      : (() {
                    print('Loading PDF from path: $correctedPath');
                    return PDFView(
                      filePath: correctedPath,
                      enableSwipe: true,
                      swipeHorizontal: true,
                      autoSpacing: false,
                      pageFling: false,
                      onError: (error) {
                        print('Error loading PDF: $error');
                      },
                      onPageError: (page, error) {
                        print('Error on page $page: $error');
                      },
                      onViewCreated: (PDFViewController pdfViewController) {
                        // Optionaler Code, der ausgeführt wird, sobald die PDF-Ansicht erstellt wurde
                      },
                      onRender: (_pages) {
                        // Optionaler Code, der ausgeführt wird, sobald die PDF gerendert wurde
                      },
                    );
                  }()),
                ),
              ),
            ],
          ),
          if (_isSigning)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.5),
                child: HandSignature(
                  control: _signatureControl,
                  color: Color(0xff235276),
                  type: SignatureDrawType.shape,
                ),
              ),
            ),
        ],
      ),
    );
  }
}



