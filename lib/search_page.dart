import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  final Function(String) onSearch;

  SearchPage({required this.onSearch});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            widget.onSearch(value); // Rufen Sie die onSearch-Funktion auf, die von der my_app.dart übergeben wurde
          },
        ),
      ),
      body: Container(),
    );
  }
}
