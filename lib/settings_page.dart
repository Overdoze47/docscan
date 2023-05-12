import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        title: const Text('Einstellungen'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
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
                  child: const Text('Speichern'),
                ),
                const SizedBox(height: 20),
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
                  child: const Text('Speichern'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Bildkomprimierung',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SwitchListTile(
                  title: const Text('Für neue Scans'),
                  value: widget.imageCompression,
                  onChanged: (bool value) {
                    setState(() {
                      widget.onImageCompressionChanged(value);
                      setImageCompression(value);  // Setzen Sie den neuen Wert in SharedPreferences
                    });
                  },
                ),
                if (!widget.imageCompression)
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      "Scans mit größeren Speicherverbrauch, führen zu längeren Ladezeiten.",
                      style: TextStyle(fontSize: 14, color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _sendFeedbackEmail,
                child: const Text('Feedback senden'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

