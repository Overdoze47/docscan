import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:doc/ad_helper.dart';

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

  @override
  void initState() {
    super.initState();

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
                          widget.name.value = newName; // Aktualisieren Sie den Wert des ValueNotifier
                          Navigator.of(context).pop();
                        },
                        child: Text('Speichern'),
                      ),
                    ],
                  );
                },
              );
            }, // Hier fehlte eine Klammer
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
              child: InteractiveViewer(
                child: Image.file(
                  File(widget.path),
                  errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                    return const Text('Fehler beim Laden des Bildes');
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}