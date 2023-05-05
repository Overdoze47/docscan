import 'dart:io';
import 'package:flutter/material.dart';

class FullScreenImage extends StatefulWidget {
  final String path;
  final String name;
  final Function(String) onNameChanged;

  const FullScreenImage({Key? key, required this.path, required this.name, required this.onNameChanged}) : super(key: key);

  @override
  FullScreenImageState createState() => FullScreenImageState();
}

class FullScreenImageState extends State<FullScreenImage> {
  late String _currentName;

  @override
  void initState() {
    super.initState();
    _currentName = widget.name;
  }

  void _showRenameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController controller = TextEditingController(text: _currentName);
        return AlertDialog(
          title: Text('Bild umbenennen'),
          content: TextField(
            controller: controller,
            autofocus: true,
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
                setState(() {
                  _currentName = controller.text;
                  widget.onNameChanged(_currentName);
                });
                Navigator.of(context).pop();
              },
              child: Text('Speichern'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentName),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _showRenameDialog(context),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(widget.path),
            errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
              return const Text('Fehler beim Laden des Bildes');
            },
          ),
        ),
      ),
    );
  }
}
