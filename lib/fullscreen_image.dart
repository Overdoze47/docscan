import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:doc/ad_helper.dart';
import 'package:image/image.dart' as img;

class FullScreenImage extends StatefulWidget {
  final String path;
  final ValueNotifier<String> name;
  final ValueChanged<String> onNameChanged;

  const FullScreenImage({Key? key, required this.path, required this.name, required this.onNameChanged}) : super(key: key);

  @override
  _FullScreenImageState createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;

  img.Image? _image;
  img.Image? _filteredImage;

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

  void _applyFilter(void Function(img.Image) filter) {
    if (_image != null) {
      setState(() {
        _filteredImage = img.copyResize(_image!, width: 600);
        filter(_filteredImage!);
      });
    }
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
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
      body: Column(
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
              child: _filteredImage != null
                  ? InteractiveViewer(
                child: Image.memory(
                  img.encodeJpg(_filteredImage!),
                  errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                    return const Text('Fehler beim Laden des Bildes');
                  },
                ),
              )
                  : CircularProgressIndicator(),
            ),
          ),
          Container(
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: 4.0),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ElevatedButton(
                  onPressed: () => _applyFilter((image) {}),
                  child: Text('Original'),
                  style: ElevatedButton.styleFrom(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  ),
                ),
                SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () => _applyFilter(img.grayscale),
                  child: Text('Graustufen'),
                  style: ElevatedButton.styleFrom(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  ),
                ),
                SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () => _applyFilter((image) => img.adjustColor(image, brightness: 10)),
                  child: Text('Helligkeit'),
                  style: ElevatedButton.styleFrom(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  ),
                ),
                SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () => _applyFilter((image) => img.adjustColor(image, contrast: 10)),
                  child: Text('Kontrast'),
                  style: ElevatedButton.styleFrom(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

