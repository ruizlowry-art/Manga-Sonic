import 'dart:io';
import 'package:flutter/material.dart';

/// Represents a single page in the chapter reader.
/// Can be either an image from a URL or a local file.
class ReaderPage {
  final String chapterUrl;
  final String chapterTitle;
  final String? url;
  final File? file;
  final bool isSeparator;
  final GlobalKey key = GlobalKey();

  double? aspectRatio;

  ReaderPage({
    required this.chapterUrl,
    required this.chapterTitle,
    this.url,
    this.file,
    this.isSeparator = false,
  });
}
