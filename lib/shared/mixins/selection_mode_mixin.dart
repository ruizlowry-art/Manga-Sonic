import 'package:flutter/material.dart';

mixin SelectionModeMixin<T extends StatefulWidget> on State<T> {
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  bool get isSelecting => _isSelecting;
  Set<String> get selectedIds => _selectedIds;

  void toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelecting = false;
        }
      } else {
        _selectedIds.add(id);
        _isSelecting = true;
      }
    });
  }

  void exitSelectionMode() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  void selectAll(Iterable<String> ids) {
    setState(() {
      _selectedIds.addAll(ids);
      _isSelecting = true;
    });
  }
}
