import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class SettingsPage extends StatefulWidget {
  final String defaultDocumentName;
  final Function(String) onDefaultNameChanged;
  final String emailTemplate;
  final Function(String) onEmailTemplateChanged;

  SettingsPage({
    required this.defaultDocumentName,
    required this.onDefaultNameChanged,
    required this.emailTemplate,
    required this.onEmailTemplateChanged,
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
                ElevatedButton(
                  onPressed: () {
                    _onDefaultNameChanged(_defaultNameController.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Standardname gespeichert.')),
                    );
                  },
                  child: Text('Speichern'),
                ),
                SizedBox(height: 20),
                Text(
                  'E-Mail Vorlage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _emailTemplateController,
                  decoration: InputDecoration(
                    hintText: 'Standard E-Mail Text eingeben',
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _onEmailTemplateChanged(_emailTemplateController.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('E-Mail Vorlage gespeichert.')),
                    );
                  },
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
