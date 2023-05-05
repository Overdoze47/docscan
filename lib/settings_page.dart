import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class SettingsPage extends StatefulWidget {
  final String defaultDocumentName;
  final Function(String) onDefaultNameChanged;

  SettingsPage({required this.defaultDocumentName, required this.onDefaultNameChanged});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  TextEditingController _defaultNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _defaultNameController.text = widget.defaultDocumentName;
  }

  void _onDefaultNameChanged(String newDefaultName) {
    widget.onDefaultNameChanged(newDefaultName); // Fügen Sie diese Zeile hinzu
  }

  void _sendFeedbackEmail() async {
    final Email email = Email(
      body: '',
      subject: 'DocScan Feedback',
      recipients: ['christoph.boettcher.app@gmail.com'],
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('E-Mail-Client kann nicht geöffnet werden.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Einstellungen'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Standardname Scandatei',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _defaultNameController,
                  decoration: InputDecoration(
                    hintText: 'Standardname eingeben',
                  ),
                ),
                ElevatedButton( // Hinzufügen der "Speichern"-Schaltfläche
                  onPressed: () => _onDefaultNameChanged(_defaultNameController.text),
                  child: Text('Speichern'),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _sendFeedbackEmail,
                child: Text('Feedback senden'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

