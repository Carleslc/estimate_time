import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/project_provider.dart';
import '../utils/message.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/required_field_label.dart';

class AddProjectDialog extends StatefulWidget {
  @override
  _AddProjectDialogState createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<AddProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  Color _selectedColor = Colors.blue;

  @override
  Widget build(BuildContext context) {
    final projectProvider = Provider.of<ProjectProvider>(context);

    return AlertDialog(
      title: const Text('Añadir proyecto'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nombre
            TextFormField(
              autofocus: true,
              decoration: InputDecoration(
                label: RequiredFieldLabel(
                  labelText: 'Nombre',
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es obligatorio';
                }
                return null;
              },
              onSaved: (value) {
                _name = value!.trim();
              },
              onTapOutside: (_) {
                FocusScope.of(context).unfocus();
              },
            ),
            SizedBox(height: 10),
            // Selector de Color
            Row(
              children: [
                Text('Color:'),
                SizedBox(width: 10),
                GestureDetector(
                  onTap: () async {
                    Color? color = await showDialog(
                      context: context,
                      builder: (_) =>
                          ColorPickerDialog(initialColor: _selectedColor),
                    );
                    if (color != null) {
                      setState(() {
                        _selectedColor = color;
                      });
                    }
                  },
                  child: CircleAvatar(
                    backgroundColor: _selectedColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('Añadir'),
          ),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();

              await tryOrShowError(context, () async {
                await projectProvider.createProject(_name, _selectedColor);
                Navigator.pop(context);
              }, 'No se ha podido crear el proyecto');
            }
          },
        ),
      ],
    );
  }
}
