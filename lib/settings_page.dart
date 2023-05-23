import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  final String defaultDocumentName;
  final Function(String) onDefaultNameChanged;
  final String emailTemplate;
  final Function(String) onEmailTemplateChanged;
  final bool imageCompression;
  final Function(bool) onImageCompressionChanged;

  SettingsPage({
    required this.defaultDocumentName,
    required this.onDefaultNameChanged,
    required this.emailTemplate,
    required this.onEmailTemplateChanged,
    required this.imageCompression,
    required this.onImageCompressionChanged,
  });

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  TextEditingController _defaultNameController = TextEditingController();
  TextEditingController _emailTemplateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _defaultNameController.text = widget.defaultDocumentName;
    _emailTemplateController.text = widget.emailTemplate;
    getImageCompression().then((value) {
      setState(() {
        widget.onImageCompressionChanged(value);
      });
    });
  }

  void setImageCompression(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('imageCompression', value);
  }

  Future<bool> getImageCompression() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('imageCompression') ?? false;
  }

  void _onDefaultNameChanged(String newDefaultName) {
    widget.onDefaultNameChanged(newDefaultName);
  }

  void _onEmailTemplateChanged(String newEmailTemplate) {
    widget.onEmailTemplateChanged(newEmailTemplate);
  }

  void exportData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> allData = prefs.getKeys().toList().asMap().map((key, value) => MapEntry(value, prefs.get(value)));
      String jsonData = jsonEncode(allData);
      Directory? downloadsDirectory = await getDownloadsDirectory();
      if (downloadsDirectory != null) {
        File backupFile = File('${downloadsDirectory.path}/backup.json');
        await backupFile.writeAsString(jsonData);
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Exportieren der Daten: $error'),
        ),
      );
    }
  }

  void importData() async {
    try {
      Directory? downloadsDirectory = await getDownloadsDirectory();
      if (downloadsDirectory != null) {
        File backupFile = File('${downloadsDirectory.path}/backup.json');
        if(await backupFile.exists()){
          String jsonData = await backupFile.readAsString();
          Map<String, dynamic> allData = jsonDecode(jsonData);
          SharedPreferences prefs = await SharedPreferences.getInstance();
          allData.forEach((key, value) async {
            if(value is bool){
              await prefs.setBool(key, value);
            } else if(value is String){
              await prefs.setString(key, value);
            } else if(value is int){
              await prefs.setInt(key, value);
            } else if(value is double){
              await prefs.setDouble(key, value);
            } else if(value is List<String>){
              await prefs.setStringList(key, value);
            }
          });
        }
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Importieren der Daten: $error'),
        ),
      );
    }
  }

  void _confirmAndDeleteAllData(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Datenlöschung'),
          content: Text('Sind Sie sicher, dass Sie alle Daten löschen möchten?'),
          actions: <Widget>[
            TextButton(
              child: Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Löschen'),
              onPressed: () {
                _deleteAllData();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteAllData() async {
    try {
      // Löschen Sie die Daten aus den SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Löschen Sie alle Dateien in einem bestimmten Pfad
      Directory directory = await getApplicationDocumentsDirectory();  // oder einen anderen Pfad
      var files = directory.listSync();
      for (var file in files) {
        if (file is File) {
          print('Deleting file ${file.path}');
          await file.delete();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alle Daten wurden erfolgreich gelöscht'),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Löschen der Daten: $error'),
        ),
      );
    }
  }


  void _sendFeedbackEmail() async {
    final Email email = Email(
      body: widget.emailTemplate,
      subject: 'DocScan Feedback',
      recipients: ['christoph.boettcher.app@gmail.com'],
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('E-Mail-Client kann nicht geöffnet werden.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xff005874),
        title: const Text('Einstellungen'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Standardname Scandatei',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            TextField(
                              controller: _defaultNameController,
                              decoration: const InputDecoration(
                                hintText: 'Standardname eingeben',
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _onDefaultNameChanged(_defaultNameController.text);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Standardname gespeichert.')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                primary: Color(0xff235276), // Background color
                              ),
                              child: const Text('Speichern'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: Image.asset(
                            'assets/like_app.png',
                            width: 100,  // Sie können die Größe des Bildes hier anpassen
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(
                          width: 80,  // Optional, fügt etwas Platz zwischen dem Bild und der Karte hinzu
                        ),
                        Expanded(
                          flex: 3,
                          child: Card(
                            elevation: 4.0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Bewertung',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ElevatedButton(
                                      onPressed: _sendFeedbackEmail,
                                      style: ElevatedButton.styleFrom(
                                        primary: Color(0xff235276), // Background color
                                      ),
                                      child: const Text('Feedback'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Card(
                      elevation: 4.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'E-Mail Vorlage',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            TextField(
                              controller: _emailTemplateController,
                              decoration: const InputDecoration(
                                hintText: 'Standard E-Mail Text eingeben',
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _onEmailTemplateChanged(_emailTemplateController.text);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('E-Mail Vorlage gespeichert.')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                primary: Color(0xff235276), // Background color
                              ),
                              child: const Text('Speichern'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2, // Hier können Sie die Breite der Karte anpassen.
                          child: Card(
                            elevation: 4.0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Datenlöschung',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ElevatedButton(
                                      onPressed: () => _confirmAndDeleteAllData(context),
                                      style: ElevatedButton.styleFrom(
                                        primary: Color(0xff235276), // Background color
                                      ),
                                      child: const Text('Alles löschen'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 120.0,
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset('assets/setting_icon.png'),
                          ),
                        ),
                      ],
                    ),
                    Card(
                      elevation: 4.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sicherung',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ElevatedButton(
                                      onPressed: exportData,
                                      style: ElevatedButton.styleFrom(
                                        primary: Color(0xff235276), // Background color
                                      ),
                                      child: const Text('Daten exportieren'),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ElevatedButton(
                                      onPressed: importData,
                                      style: ElevatedButton.styleFrom(
                                        primary: Color(0xff235276), // Background color
                                      ),
                                      child: const Text('Daten importieren'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 4.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bildkomprimierung',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            ListTile(
                              title: const Text('Für neue Scans'),
                              trailing: Switch(
                                value: widget.imageCompression,
                                onChanged: (bool value) {
                                  setState(() {
                                    widget.onImageCompressionChanged(value);
                                    setImageCompression(value);
                                  });
                                },
                                activeColor: Color(0xff235276),  // Ändert die Farbe, wenn der Switch aktiv ist
                                inactiveThumbColor: Colors.grey,  // Ändert die Farbe des Daumens, wenn der Switch inaktiv ist
                                inactiveTrackColor: Colors.grey[300],  // Ändert die Farbe der Schiene, wenn der Switch inaktiv ist
                              ),
                            ),
                            if (!widget.imageCompression)
                              const Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text(
                                  "Scans mit größeren Speicherverbrauch, führen zu längeren Ladezeiten",
                                  style: TextStyle(fontSize: 14, color: Colors.red),
                                ),
                              ),
                            ListTile(
                              title: const Text('Für alte Scans'),
                              trailing: Switch(
                                value: widget.imageCompression,
                                onChanged: (bool value) {
                                  setState(() {
                                    widget.onImageCompressionChanged(value);
                                    setImageCompression(value);
                                  });
                                },
                                activeColor: Color(0xff235276),  // Ändert die Farbe, wenn der Switch aktiv ist
                                inactiveThumbColor: Colors.grey,  // Ändert die Farbe des Daumens, wenn der Switch inaktiv ist
                                inactiveTrackColor: Colors.grey[300],
                              ),
                            ),
                            if (!widget.imageCompression)
                              const Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text(
                                  "Scans mit größeren Speicherverbrauch, führen zu längeren Ladezeiten",
                                  style: TextStyle(fontSize: 14, color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
      Expanded(
      child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
      onPressed: _sendFeedbackEmail,
        style: ElevatedButton.styleFrom(
          primary: Color(0xff235276), // Background color
        ),
      child: const Text('Feedback'),
      ),
      ),
      ),
      SizedBox(width: 16), // Dies erzeugt einen horizontalen Abstand zwischen den Buttons
      Expanded(
      child: Padding(
      padding: const EdgeInsets.all(8.0),
    child: ElevatedButton(
    onPressed: _sendFeedbackEmail,
      style: ElevatedButton.styleFrom(
        primary: Color(0xff235276), // Background color
      ),
    child: const Text('Datenschutz'),
                    ),
                  ),
                    ),
                    ],
              ),
            ),
            ),
          ],
      ),
    )
            )
          )
        ]
      )
    );
  }
}

