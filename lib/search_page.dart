import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Nach Scannamen suchen...',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            // Implementieren Sie die Suchlogik hier
          },
        ),
      ),
      body: Container(),
    );
  }
}
