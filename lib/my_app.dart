import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter/material.dart' show Colors, MaterialColor;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:doc/ad_helper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:collection/collection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'settings_page.dart';
import 'search_page.dart';
import 'fullscreen_image.dart';
import 'rounded_appbar.dart';



class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<_PictureData> _pictures = [];
  Set<int> _sharedPictures = {};
  int _documentCounter = 1;
  String _defaultDocumentName = 'DocScan';
  int _emailSentPictures = 0;
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;
  String _emailTemplate = "Hier ist Ihre Standard-E-Mail-Vorlage.";

  List<_PictureData> _filteredPictures() {
    if (_searchQuery.isEmpty) {
      return _pictures;
    }

    return _pictures.where((_PictureData picture) {
      return picture.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _saveEmailTemplate(String newEmailTemplate) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('emailTemplate', newEmailTemplate);
  }

  Future<void> _loadEmailTemplate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedEmailTemplate = prefs.getString('emailTemplate');
    print('Gespeicherte E-Mail-Vorlage: $storedEmailTemplate'); // Debug-Ausgabe hinzugefügt
    setState(() {
      _emailTemplate = storedEmailTemplate ?? "Hier ist Ihre Standard-E-Mail-Vorlage.";
    });
  }


  @override
  void initState() {
    super.initState();
    _loadEmailTemplate();
    initPlatformState();

    _loadDefaultDocumentName().then((value) {
      setState(() {
        _defaultDocumentName = value;
      });
    });

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
  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  void _updateSearchQuery() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      onChanged: (value) => _updateSearchQuery(),
      decoration: InputDecoration(
        hintText: 'Suche...',
        border: InputBorder.none,
      ),
    );
  }

  void _startSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchPage(
          onSearch: (String searchQuery) {
            setState(() {
              _searchQuery = searchQuery;
            });
          },
        ),
      ),
    );
  }

  Future<void> _saveDefaultDocumentName(String defaultDocumentName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('defaultDocumentName', defaultDocumentName);
  }

  Future<String> _loadDefaultDocumentName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('defaultDocumentName') ?? 'DocScan';
  }


  Future<String> getDCIMCameraPath() async {
    List<Directory>? extDirs = await getExternalStorageDirectories(type: StorageDirectory.dcim);
    String? dcimPath;

    if (extDirs != null && extDirs.isNotEmpty) {
      dcimPath = '${extDirs.first.path}/Camera';
    } else {
      throw Exception('Kein externer Speicher gefunden');
    }

    return dcimPath;
  }



  Future<String> _changeFileName(String oldPath, String newName) async {
    try {
      final oldFile = File(oldPath);
      final newPath = '${await getDCIMCameraPath()}/$newName.jpg';

      // Erstelle den Zielordner, falls er noch nicht existiert
      final newDirectory = Directory(await getDCIMCameraPath());
      if (!await newDirectory.exists()) {
        await newDirectory.create(recursive: true);
      }

      // Kopiere die Datei an den neuen Pfad
      final newFile = await oldFile.copy(newPath);

      // Lösche die Originaldatei
      await oldFile.delete();

      return newFile.path;
    } catch (e) {
      print('Fehler beim Umbenennen der Datei: $e');
      // Sie können hier auch einen benutzerfreundlichen Fehler anzeigen
      return oldPath; // Geben Sie den alten Pfad zurück, um den aktuellen Zustand beizubehalten
    }
  }

  Future<void> _requestStoragePermission() async {
    // Stellen Sie sicher, dass Sie die richtige Berechtigung für Ihre API-Version anfordern
    Permission permission = Platform.isAndroid && await Permission.storage.isRestricted ? Permission.manageExternalStorage : Permission.storage;

    PermissionStatus status = await permission.status;

    if (!status.isGranted) {
      PermissionStatus result = await permission.request();
      if (!result.isGranted) {
        // Zeige eine Benachrichtigung oder Meldung an, dass die Berechtigung nicht gewährt wurde
      }
    }
  }


  Future<void> initPlatformState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _documentCounter = prefs.getInt('documentCounter') ?? 1;
      _pictures = (prefs.getStringList('pictures') ?? []).map<_PictureData>((item) {
        List<String> data = item.split('|');
        return _PictureData(name: data[0], date: data[1], path: data[2]);
      }).toList();
    });
  }

  void _showUploadDialog(BuildContext context) {
    final _MyAppState state = context.findAncestorStateOfType<_MyAppState>()!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Upload Optionen'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fügen Sie hier weitere Buttons hinzu
                Column(
                  children: [
                    InkWell(
                      onTap: () async {
                        List<String> attachmentFilePaths = state._pictures
                            .where((pictureData) => !pictureData.shared)
                            .map((pictureData) => pictureData.path)
                            .toList();
                        bool emailSent = await state._sendEmailWithAttachments(context, attachmentFilePaths);
                        if (emailSent) {
                          state.setState(() {
                            state._emailSentPictures = state._pictures.length;
                          });
                        }
                        Navigator.of(context).pop();
                      },
                      child: Image.asset(
                        'assets/mail_logo.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Text('E-Mail'),
                  ],
                ),
                SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    await state._shareFiles(context);
                    Navigator.of(context).pop();
                  },
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/share.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                      Text('Teilen'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Abbrechen'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareFiles(BuildContext context) async {
    try {
      List<String> attachmentFilePaths = _pictures
          .where((pictureData) => !pictureData.shared)
          .map((pictureData) => pictureData.path)
          .toList();

      await Share.shareFiles(attachmentFilePaths, text: 'Hier sind die angehängten Bilder:');
      setState(() {
        for (_PictureData picture in _pictures) {
          if (attachmentFilePaths.contains(picture.path)) {
            picture.shared = true;
          }
        }
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dokumente wurden schon geteilt.')),
      );
    }
  }

  Future<void> savePictures() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('documentCounter', _documentCounter);
    prefs.setStringList('pictures', _pictures.map<String>((item) {
      return '${item.name}|${item.date}|${item.path}';
    }).toList());
  }

  Future<void> _shareFile(BuildContext context, String filePath) async {
    try {
      await Share.shareFiles([filePath], text: 'Hier ist das angehängte Bild:');
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beim Teilen der Datei ist ein Fehler aufgetreten.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          double screenWidth = MediaQuery.of(context).size.width;
          return Scaffold(
            appBar: AppBar(
              title: _isSearching
                  ? Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Suche...',
                    border: InputBorder.none,
                  ),
                ),
              )
                  : Text('DocScan'),
              leading: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>
                        SettingsPage(
                          defaultDocumentName: _defaultDocumentName,
                          onDefaultNameChanged: (String newDefaultName) {
                            setState(() {
                              _defaultDocumentName = newDefaultName;
                            });
                            _saveDefaultDocumentName(newDefaultName);
                          },
                          emailTemplate: _emailTemplate,
                          onEmailTemplateChanged: (String newEmailTemplate) {
                            setState(() {
                              _emailTemplate = newEmailTemplate;
                            });
                            _saveEmailTemplate(newEmailTemplate);
                          },
                        ),
                    ),
                  );
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.file_upload),
                  onPressed: () => _showUploadDialog(context),
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
                  child: SingleChildScrollView(
                    child: Column(
                      children: _filteredPictures().map<Widget>((pictureData) {
                        return Dismissible(
                          key: UniqueKey(),
                          onDismissed: (direction) {
                            setState(() {
                              _pictures.remove(pictureData);
                            });
                            savePictures();
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.only(left: 20),
                            color: Colors.red,
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                          child: Card(
                            elevation: 8.0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            margin: EdgeInsets.all(8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Colors.white
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Builder(
                                builder: (BuildContext context) {
                                  return InkWell(
                                    onTap: () {
                                      _openPicture(context, pictureData.path, pictureData.name);
                                    },
                                    child: Container(
                                      margin: EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8.0),
                                            child: Image.file(
                                              File(pictureData.path),
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          Expanded(
                                            child: Container(
                                              margin: EdgeInsets.only(left: 16.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(pictureData.name),
                                                  Text('${pictureData.date}'),
                                                ],
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.share),
                                            onPressed: () => _shareFile(context, pictureData.path),
                                          ),
                                          if (pictureData.shared)
                                            Padding(
                                              padding: EdgeInsets.only(right: 8.0),
                                              child: Icon(Icons.cloud_done, size: 24, color: Colors.green),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _onCameraButtonPressed,
              child: const Icon(Icons.camera_alt),
              tooltip: 'Bilder hinzufügen',
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
  }

  Future<bool> _sendEmailWithAttachments(BuildContext context, List<String> attachmentFilePaths) async {
    print('Versenden der Dateien: $attachmentFilePaths');
    final Email email = Email(
      body: _emailTemplate,
      subject: 'Betreff der E-Mail',
      recipients: [''],
      attachmentPaths: attachmentFilePaths,
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
      setState(() {
        for (_PictureData picture in _pictures) {
          if (attachmentFilePaths.contains(picture.path)) {
            picture.shared = true;
          }
        }
      });
      return true;
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte keinen Email-Client öffnen.')),
      );
      return false;
    }
  }

  void _onNameChanged(String oldPath, String newPath, String newName) {
    setState(() {
      int? pictureIndex = _pictures.indexWhere((item) => item.path == oldPath);
      if (pictureIndex != null && pictureIndex != -1) {
        _PictureData updatedPicture = _pictures[pictureIndex].updatePath(newPath);
        updatedPicture.name = newName;
        _pictures[pictureIndex] = updatedPicture;
        savePictures();
      }
    });
  }

  Future<void> _onCameraButtonPressed() async {
    final date = DateTime.now();
    final formattedDate = DateFormat('yyyyMMdd_HHmmss').format(date);
    final imageName = '${_defaultDocumentName}_${_documentCounter - 1}_$formattedDate';

    try {
      final List<String>? documentPaths = await CunningDocumentScanner.getPictures(); // Verwenden Sie die getPictures-Methode

      if (documentPaths != null && documentPaths.isNotEmpty) {
        for (String path in documentPaths) {
          final newPath = await _changeFileName(path, imageName);
          setState(() {
            _pictures.add(_PictureData(
              name: imageName,
              date: formattedDate,
              path: newPath,
            ));
          });
          savePictures();
          _documentCounter++;
        }
      }
    } catch (e) {
      print('Fehler beim Scannen des Dokuments: $e');
    }
  }



  void _openPicture(BuildContext context, String path, String name) {
    _requestStoragePermission().then((_) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenImage(
            path: path,
            name: ValueNotifier<String>(name),
            onNameChanged: (newName) {
              _requestStoragePermission().then((_) {
                _changeFileName(path, newName).then((newPath) {
                  setState(() {
                    _PictureData? picture = _pictures.firstWhereOrNull((item) => item.path == path);
                    if (picture != null) {
                      int index = _pictures.indexOf(picture);
                      _pictures[index] = picture.updatePath(newPath);
                      _pictures[index].name = newName;
                      savePictures();
                    }
                  });
                });
              });
            },
          ),
        ),
      );
    });
  }
}

  void _showUploadDialog(BuildContext context) {
  final _MyAppState state = context.findAncestorStateOfType<_MyAppState>()!;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Upload Optionen'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fügen Sie hier weitere Buttons hinzu
              Column(
                children: [
                  InkWell(
                    onTap: () async {
                      List<String> attachmentFilePaths = state._pictures
                          .where((pictureData) => !pictureData.shared)
                          .map((pictureData) => pictureData.path)
                          .toList();
                      bool emailSent = await state._sendEmailWithAttachments(context, attachmentFilePaths);
                      if (emailSent) {
                        state.setState(() {
                          state._emailSentPictures = state._pictures.length;
                        });
                      }
                      Navigator.of(context).pop();
                    },
                    child: Image.asset(
                      'assets/mail_logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Text('E-Mail'),
                ],
              ),
              TextButton(
                onPressed: () {
                  // Implementieren Sie die gewünschte Aktion für diesen Button
                  Navigator.of(context).pop();
                },
                child: Text('Option 2'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Abbrechen'),
          ),
        ],
      );
    },
  );
}


class _PictureData {
  String name;
  final String date;
  final String path;
  bool shared;

  _PictureData({required this.name, required this.date, required this.path, this.shared = false});

  _PictureData updatePath(String newPath) {
    return _PictureData(name: name, date: date, path: newPath, shared: shared);
  }
}

