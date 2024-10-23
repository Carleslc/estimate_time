import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  ColorPickerDialog({required this.initialColor});

  @override
  _ColorPickerDialogState createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
  }

  // Implementa un selector de color usando flutter_colorpicker
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Selecciona un color'),
      content: SingleChildScrollView(
        child: BlockPicker(
          pickerColor: _currentColor,
          onColorChanged: (color) => setState(() => _currentColor = color),
        ),
      ),
      actions: [
        TextButton(
          child: Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: Text('Seleccionar'),
          onPressed: () => Navigator.pop(context, _currentColor),
        ),
      ],
    );
  }
}
