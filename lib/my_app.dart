import 'dart:async';
import 'dart:io';
import 'dart:convert';
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
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdfWidgets;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf_merger/pdf_merger.dart';

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<_PictureData> _pictures = [];
  List<_PictureData> _displayedPictures = [];
  Set<int> _sharedPictures = {};
  int _documentCounter = 1;
  int _emailSentPictures = 0;
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;
  String _defaultDocumentName = 'DocScan';
  String _emailTemplate = 'Anbei sende ich dir die gescannten Dokumente \n\n\n Von der App DocScan gescannt.';
  List<Folder> _folders = [];
  bool _isFolderViewMode = true;
  Folder? _selectedFolder;
  String? currentFolderName;
  List<_PictureData> _currentViewPictures = [];

  List<_PictureData> getFolderPictures(String folderName) {
    return _pictures.where((picture) => picture.folderName == folderName).toList();
  }

  bool _imageCompression = false; // Sie können den Standardwert nach Bedarf festlegen.
  void _onImageCompressionChanged(bool newValue) {
    setState(() {
      _imageCompression = newValue;
    });
    // Hier können Sie weitere Aktionen durchführen, wenn sich der Zustand ändert, z.B. die Einstellung speichern.
  }

  void _onDefaultNameChanged(String newName) {
    setState(() {
      _defaultDocumentName = newName;
    });
  }


  void _onFolderNameClicked(Folder folder) {
    setState(() {
      _selectedFolder = folder;
    });
  }

  void addScan(_PictureData scan) {
    setState(() {
      _pictures.add(scan);
      if (currentFolderName == null) {
        _displayedPictures.add(scan);
      }
    });
  }

  void _showFolderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ordner'),
        content: SingleChildScrollView(
          child: ListBody(
            children: _folders.map((folder) {
              return Card(
                elevation: 5,
                child: ListTile(
                  leading: Icon(Icons.folder),
                  title: Text(folder.name),
                  onTap: () {
                    setState(() {
                      currentFolderName = folder.name;
                      if (currentFolderName != null) {
                        _displayedPictures = getFolderPictures(currentFolderName!);
                      } else {
                        _displayedPictures = [];
                      }
                    });
                    Navigator.of(context).pop();
                  },
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Ordner löschen'),
                          content: Text('Sind Sie sicher, dass Sie diesen Ordner löschen möchten?'),
                          actions: [
                            TextButton(
                              child: Text('Abbrechen'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            TextButton(
                              child: Text('Löschen'),
                              onPressed: () {
                                setState(() {
                                  _folders.remove(folder);
                                });
                                _saveFolders();
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                                _showFolderDialog(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Ordner hinzufügen'),
            onPressed: () async {
              var folderName = await _showFolderNameDialog(context);
              if (folderName != null) {
                setState(() {
                  _folders.add(Folder(name: folderName, images: []));
                });
                _saveFolders();
                Navigator.of(context).pop();
                _showFolderDialog(context);
              }
            },
          ),
          TextButton(
            child: Text('Schließen'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<String?> _showFolderNameDialog(BuildContext context) async {
    String? folderName;
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Neuen Ordner erstellen'),
          content: TextField(
            onChanged: (value) {
              folderName = value;
            },
            decoration: InputDecoration(
              hintText: "Ordnername",
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Abbrechen'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text('Speichern'),
              onPressed: () {
                Navigator.pop(context, folderName);
              },
            ),
          ],
        );
      },
    );
    return folderName;
  }

  void _loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = prefs.getString('folders');
    if (foldersJson != null) {
      final List<dynamic> folderList = jsonDecode(foldersJson);
      _folders = folderList.map((folder) => Folder.fromJson(folder)).toList();
    }
  }

  void updateDisplayedPictures(String folderName) {
    setState(() {
      if (folderName == _defaultDocumentName) {
        _displayedPictures = _pictures;
      } else {
        _displayedPictures = getFolderPictures(folderName);
      }
    });
  }

  void _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = jsonEncode(_folders.map((folder) => folder.toJson()).toList());
    prefs.setString('folders', foldersJson);
  }

  void _onEmailTemplateChanged(String newTemplate) {
    setState(() {
      _emailTemplate = newTemplate;
    });
  }

  List<_PictureData> _filteredPictures() {
    List<_PictureData> displayedPictures;

    // Display only pictures without a folder if no folder is selected
    if (currentFolderName == null) {
      displayedPictures = _pictures.where((picture) => picture.folderName == null).toList();
    } else {
      displayedPictures = _pictures.where((picture) => picture.folderName == currentFolderName).toList();
    }

    if (_searchQuery?.isEmpty != false) {
      return displayedPictures;
    }

    return displayedPictures
        .where((pictureData) => pictureData.name.toLowerCase().contains(_searchQuery!.toLowerCase()))
        .toList();
  }

  Future<void> _saveEmailTemplate(String newEmailTemplate) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('emailTemplate', newEmailTemplate);
  }

  Future<void> _loadEmailTemplate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedEmailTemplate = prefs.getString('emailTemplate');
    setState(() {
      _emailTemplate = storedEmailTemplate ?? "Anbei sende ich dir die gescannten Dokumente \n\n\n Von der App DocScan gescannt.";
    });
  }


  @override
  void initState() {
    super.initState();
    _loadFolders();
    _loadEmailTemplate();
    initPlatformState();
    loadPictures();

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

  Future<void> loadPictures() async {
    final prefs = await SharedPreferences.getInstance();
    final picturesList = prefs.getStringList('pictures') ?? [];
    print('Loaded ${picturesList.length} pictures from SharedPreferences');

    setState(() {
      _pictures = picturesList.map((item) {
        Map<String, dynamic> data = jsonDecode(item);
        return _PictureData.fromJson(data);
      }).toList();

      // Erzeugt eine Liste von Folder Objekten aus den Bildern
      _folders = _foldersFromPictures(_pictures);

      print('Generated ${_folders.length} folders from pictures');
      for (Folder folder in _folders) {
        print('Folder ${folder.name} contains ${folder.images.length} pictures');
      }

      // Wenn kein Ordner ausgewählt ist, zeige alle Bilder
      if (currentFolderName == null) {
        _displayedPictures = _pictures;
      }
    });
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
          title: Text('Upload Optionen\n'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fügen Sie hier weitere Buttons hinzu
                Row(
                  children: [
                    InkWell(
                      onTap: () async {
                        bool emailSent = await state._sendEmailWithAttachments(context);
                        if (emailSent) {
                          state.setState(() {
                            state._emailSentPictures = state._pictures.length;
                          });
                        }
                        Navigator.of(context).pop();
                      },
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/new-email.png',
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'E-Mail',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    InkWell(
                      onTap: () async {
                        await state._shareFiles(context);
                        Navigator.of(context).pop();
                      },
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/data-share.png',
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Teilen',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text('DATEV Export'),
                              content: Text('Sind Sie an unserem DATEV Export interessiert?\n\nDann besuchen Sie unsere Hompage.'),
                              actions: [
                                TextButton(
                                  onPressed: () async {
                                    // Aktion für den "Mehr Informationen" Button
                                    Navigator.of(context).pop();
                                    final url = 'https://google.com'; // Die URL der Homepage
                                    if (await canLaunch(url)) {
                                      await launch(url);
                                    } else {
                                      throw 'Konnte $url nicht öffnen.';
                                    }
                                  },
                                  child: Text('Zur Homepage'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // Aktion für den "Schließen" Button
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Schließen'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/datev.png',
                            width: 66,
                            height: 66,
                            fit: BoxFit.cover,
                          ),
                          Text(
                            'Export',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
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

  List<Folder> _foldersFromPictures(List<_PictureData> pictures) {
    // Erstellt eine Map von Ordnernamen zu ihren Bildern
    Map<String, List<_PictureData>> folderMap = {};
    for (_PictureData picture in pictures) {
      // Ignoriert Bilder ohne Ordner
      if (picture.folderName != null) {
        String folderName = picture.folderName!;
        if (!folderMap.containsKey(folderName)) {
          folderMap[folderName] = [];
        }
        folderMap[folderName]!.add(picture);
      }
    }

    // Erzeugt eine Liste von Folder Objekten aus der Map
    List<Folder> folders = [];
    for (String folderName in folderMap.keys) {
      Folder folder = Folder(name: folderName, images: []);
      folder.addImages(folderMap[folderName]!);
      folders.add(folder);
    }

    return folders;
  }


  Future<void> savePictures() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('documentCounter', _documentCounter);
    prefs.setStringList('pictures', _pictures.map<String>((item) {
      return jsonEncode(item.toJson());
    }).toList());
  }

  Future<void> _addPictureToExistingDocument(BuildContext context, _PictureData existingDocument) async {
    try {
      final List<String>? documentPaths = await CunningDocumentScanner.getPictures();

      if (documentPaths != null && documentPaths.isNotEmpty) {
        for (String path in documentPaths) {
          final newPath = await _changeFileName(path, existingDocument.name);
          setState(() {
            _pictures.add(_PictureData(
              name: existingDocument.name,
              date: existingDocument.date,
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

  Future<void> _shareFile(BuildContext context, String filePath) async {
    try {
      await Share.shareFiles([filePath], text: _emailTemplate);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beim Teilen der Datei ist ein Fehler aufgetreten.')),
      );
    }
  }

  void _assignPictureToFolder(_PictureData picture, BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ordner auswählen'),
          content: SingleChildScrollView(
            child: Column(
              children: _folders.map((folder) {
                return Card(
                  elevation: 10.0,  // Stärkerer Schatten
                  margin: EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: Icon(Icons.folder),
                    title: Text(folder.name),
                    onTap: () {
                      Navigator.of(context).pop();
                      _updatePictureFolder(picture, folder.name);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ordner hinzufügen'),
              onPressed: () async {
                var folderName = await _showFolderNameDialog(context);
                if (folderName != null) {
                  setState(() {
                    _folders.add(Folder(name: folderName, images: []));
                  });
                  _saveFolders();
                  Navigator.of(context).pop();
                  _showFolderDialog(context);
                }
              },
            ),
            TextButton(
              child: Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    ).then((_) {
      // Erzwingen Sie ein erneutes Rendering, um sicherzustellen, dass die Änderungen angezeigt werden
      setState(() {});
    });
  }

  void _updatePictureFolder(_PictureData picture, String folderName) {
    setState(() {
      _currentViewPictures = _pictures.where((picture) => picture.folderName == folderName).toList();
      int pictureIndex = _pictures.indexWhere((item) => item.path == picture.path);
      if (pictureIndex != -1) {
        _pictures[pictureIndex].folderName = folderName;
        savePictures();
      }
    });
  }

  List<_PictureData> _selectedPictures = [];
  bool _isPdfConversionMode = false;

  @override
  Widget build(BuildContext context) {
    List<_PictureData> displayedPictures = [];
    if (currentFolderName != null) {
      displayedPictures = getFolderPictures(currentFolderName!);
    } else {   // Wenn kein Ordner ausgewählt ist, zeigen Sie die Bilder im "Unsorted"-Ordner an
      displayedPictures = getFolderPictures("Unsorted");
    }
    return MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          double screenWidth = MediaQuery.of(context).size.width;
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Color(0xff005874),
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
                  : (currentFolderName == null ? Text('DocScan') : Text('Ordner: $currentFolderName')),
              leading: currentFolderName == null
                  ? IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsPage(
                        defaultDocumentName: _defaultDocumentName,
                        onDefaultNameChanged: _onDefaultNameChanged,
                        emailTemplate: _emailTemplate,
                        onEmailTemplateChanged: _onEmailTemplateChanged,
                        imageCompression: _imageCompression,
                        onImageCompressionChanged: _onImageCompressionChanged,
                      ),
                    ),
                  );
                },
              )
                  : IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    currentFolderName = null;
                  });
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
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  onPressed: () {
                    setState(() {
                      _isPdfConversionMode = true;
                    });
                  },
                ),
                if (_isPdfConversionMode)
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () {
                      _convertSelectedImagesToPdf();
                      setState(() {
                        _isPdfConversionMode = false;
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
                            if (direction == DismissDirection.startToEnd) {
                              _assignPictureToFolder(pictureData, context);
                            } else {
                              setState(() {
                                _pictures.remove(pictureData);
                              });
                              savePictures();
                            }
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.only(left: 20),
                            color: Color(0xff235276),
                            child: Icon(Icons.folder_copy_rounded, color: Colors.white),
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
                                      _openPicture(context, pictureData.path, pictureData.name, pictureData.fileType);
                                      print(pictureData.path);
                                    },
                                    child: Container(
                                      margin: EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8.0),
                                            child: pictureData.fileType == FileType.jpg
                                                ? Image.file(
                                              File(pictureData.path),
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                            )
                                                : Image.asset(
                                              'assets/pdf_logo.png',
                                              width: 56,
                                              height: 56,
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
                                          if (_isPdfConversionMode)
                                            Checkbox(
                                              value: pictureData.selected,
                                              onChanged: !_isPdfConversionMode || pictureData.fileType != FileType.jpg ? null : (bool? value) {
                                                setState(() {
                                                  pictureData.selected = value!;
                                                });
                                              },
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
            floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
            floatingActionButton: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Builder(
                builder: (BuildContext context) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FloatingActionButton(
                        onPressed: () => _showFolderDialog(context),
                        tooltip: 'Ordner anzeigen',
                        child: Icon(Icons.folder),
                        backgroundColor: Color(0xff235276),
                      ),
                      SizedBox(height: 16),  // Abstand zwischen den Buttons
                      FloatingActionButton(
                        onPressed: _onCameraButtonPressed,
                        tooltip: 'Bilder hinzufügen',
                        child: Icon(Icons.camera_alt),
                        backgroundColor: Color(0xff235276),
                      ),
                    ],
                  );
                },
              ),
            ),
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

  void _convertSelectedImagesToPdf() async {
    // Erstellen Sie eine Liste von ausgewählten Bildern
    _selectedPictures = _pictures.where((picture) => picture.selected).toList();

    for (var picture in _selectedPictures) {
      // Erstellen Sie ein neues PDF-Dokument für jedes Bild
      final pdf = pdfWidgets.Document();

      // Überprüfen Sie, ob die Datei existiert und das Format unterstützt wird
      final file = File(picture.path);
      if (await file.exists()) {
        final imageBytes = file.readAsBytesSync();
        final decoder = await decodeImageFromList(imageBytes);
        if (decoder != null) {
          final image = pdfWidgets.MemoryImage(imageBytes);

          pdf.addPage(
            pdfWidgets.Page(
              build: (pdfWidgets.Context context) => pdfWidgets.Center(
                child: pdfWidgets.Image(image),
              ),
            ),
          );

          final output = await getTemporaryDirectory();
          final pdfFile = File("${output.path}/${picture.name}.pdf");
          await pdfFile.writeAsBytes(await pdf.save());

          // Speichern Sie den alten Pfad vor der Aktualisierung
          final oldPath = picture.path;

          // Aktualisieren Sie den Pfad und den Dateityp in Ihrer pictureData-Instanz
          setState(() {
            picture.path = pdfFile.path;
            picture.fileType = FileType.pdf;

            // Überprüfen, ob das konvertierte Bild in der aktuellen Ansicht angezeigt wird
            int? currentViewIndex = _currentViewPictures.indexWhere((item) => item.path == oldPath);
            if (currentViewIndex != null && currentViewIndex != -1) {
              _currentViewPictures[currentViewIndex] = picture;
            }
          });
        } else {
          print("Unsupported image format");
        }
      } else {
        print("File does not exist");
      }
    }
  }


  Future<bool> _sendEmailWithAttachments(BuildContext context) async {
    List<String> attachmentFilePaths = _currentViewPictures
        .where((pic) => !pic.shared)
        .map((pic) => pic.path)
        .toList();

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
        for (_PictureData picture in _currentViewPictures) {
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

  void _onNameChanged(_PictureData picture, String newPath, String newName) {
    setState(() {
      int? pictureIndex = _pictures.indexWhere((item) => item.path == picture.path);
      if (pictureIndex != null && pictureIndex != -1) {
        _PictureData updatedPicture = _pictures[pictureIndex].updatePath(newPath);
        updatedPicture.name = newName;
        _pictures[pictureIndex] = updatedPicture;

        // Überprüfen, ob das aktualisierte Bild in der aktuellen Ansicht angezeigt wird
        int? currentViewIndex = _currentViewPictures.indexWhere((item) => item.path == picture.path);
        if (currentViewIndex != null && currentViewIndex != -1) {
          _currentViewPictures[currentViewIndex] = updatedPicture;
        }

        savePictures();
      }
    });
  }

  Future<void> _addPictureToDocument(_PictureData picture) async {
    try {
      final List<String>? documentPaths = await CunningDocumentScanner.getPictures();

      if (documentPaths != null && documentPaths.isNotEmpty) {
        for (String path in documentPaths) {
          final newPath = await _changeFileName(path, picture.name);
          setState(() {
            var pictureData = _PictureData(
              name: picture.name,
              date: picture.date,
              path: newPath,
              shared: picture.shared,
              selected: picture.selected,
              fileType: picture.fileType,
              folderName: currentFolderName,
            );

            _pictures.add(pictureData);

            if (currentFolderName == picture.folderName) {
              _currentViewPictures.add(pictureData);
            }

            _folders = _foldersFromPictures(_pictures);
          });
          savePictures();
          _documentCounter++;
        }
      }
    } catch (e) {
      print('Fehler beim Scannen des Dokuments: $e');
    }
  }

  Future<void> _onCameraButtonPressed() async {
    final date = DateTime.now();
    final formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(date);
    final imageName = '${_defaultDocumentName}_${_documentCounter - 1}_$formattedDate';

    try {
      final List<String>? documentPaths = await CunningDocumentScanner.getPictures();

      if (documentPaths != null && documentPaths.isNotEmpty) {
        for (String path in documentPaths) {
          final newPath = await _changeFileName(path, imageName);
          setState(() {
            // Bild zur Gesamtliste hinzufügen
            _pictures.add(_PictureData(
              name: imageName,
              date: formattedDate,
              path: newPath,
              folderName: currentFolderName,
            ));

            // Bild zur aktuellen Ansicht hinzufügen, wenn es zum geöffneten Ordner gehört
            if (currentFolderName == _pictures.last.folderName) {
              _currentViewPictures.add(_PictureData(
                name: imageName,
                date: formattedDate,
                path: newPath,
                folderName: currentFolderName,
              ));
            }

            _folders = _foldersFromPictures(_pictures);
          });
          savePictures();
          _documentCounter++;
        }
      }
    } catch (e) {
      print('Fehler beim Scannen des Dokuments: $e');
    }
  }


  void _openPicture(BuildContext context, String path, String name, FileType fileType) {
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
            fileType: fileType,
          ),
        ),
      );
    });
  }
}

class Folder {
  String name;
  List<String> images;

  void addImages(List<_PictureData> images) {
    this.images.addAll(images.map((image) => image.path));
  }

  Folder({required this.name, required this.images});

  Folder.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        images = List<String>.from(json['images']);

  Map<String, dynamic> toJson() => {
    'name': name,
    'images': images,
  };
}
// Erstellt Folder aus Map
Folder fromMap(Map<String, dynamic> map) {
  return Folder(
    name: map['name'],
    images: List<String>.from(map['images']),
  );
}

enum FileType { jpg, pdf }

class _PictureData {
  String name;
  final String date;
  String path;
  bool shared;
  bool selected;
  FileType fileType;
  String? folderName;

  _PictureData({
    required this.name,
    required this.date,
    required this.path,
    this.shared = false,
    this.selected = false,
    this.fileType = FileType.jpg,// Default file type is jpg
    this.folderName,
  });

  _PictureData.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        date = json['date'],
        path = json['path'],
        shared = json['shared'] ?? false,
        selected = json['selected'] ?? false,
        fileType = FileType.values[json['fileType'] ?? 0],
        folderName = json['folderName'];

  Map<String, dynamic> toJson() => {
    'name': name,
    'date': date,
    'path': path,
    'shared': shared,
    'selected': selected,
    'fileType': fileType.index,
    'folderName': folderName,
  };

  _PictureData updatePath(String newPath) {
    return _PictureData(
        name: this.name,
        date: this.date, // Fügen Sie das aktuelle date hinzu
        path: newPath,
        shared: this.shared, // Fügen Sie den aktuellen shared Status hinzu
        selected: this.selected, // Fügen Sie den aktuellen selected Status hinzu
        fileType: this.fileType,
        folderName: this.folderName
    );
  }
}