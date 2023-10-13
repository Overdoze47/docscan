import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class RoundedAppBar extends StatelessWidget with PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget leading; // Neues Attribut hinzufügen

  RoundedAppBar({required this.title, this.actions, required this.leading}); // Konstruktor aktualisieren

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(0)),
      child: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: AppBar(
          leading: leading, // Fügen Sie das leading-Attribut zur AppBar hinzu
          title: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Text(
                title,
                style: GoogleFonts.roboto(
                  textStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
          centerTitle: true,
          actions: actions,
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: title,
        style: GoogleFonts.roboto(
          textStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      maxLines: 1,
      textScaleFactor: WidgetsBinding.instance!.window.devicePixelRatio,
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout(minWidth: 0, maxWidth: double.infinity);
    return Size.fromHeight(textPainter.height + 1.0);
  }
}