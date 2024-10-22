import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../providers/project_provider.dart';
import '../utils/message.dart';
import 'project_details_screen.dart';

class ProjectsScreen extends StatefulWidget {
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarga los proyectos cuando la pantalla se vuelve a mostrar
    context.read<ProjectProvider>().loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (_, projectProvider, __) {
        final projects = projectProvider.projects;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Proyectos'),
          ),
          body: projects.isEmpty
              ? Center(child: const Text('No hay proyectos'))
              : ListView.builder(
                  itemCount: projects.length,
                  itemBuilder: (_, index) {
                    final project = projects[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: project.color,
                        radius: 16,
                      ),
                      title: Text(
                        project.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProjectDetailsScreen(project: project),
                          ),
                        ).then((_) {
                          // Recarga los proyectos cuando la pantalla se vuelve a mostrar
                          context.read<ProjectProvider>().loadProjects();
                        });
                      },
                    );
                  },
                ),
          floatingActionButton: Tooltip(
            message: 'Añadir proyecto',
            child: FloatingActionButton(
              child: Icon(Icons.library_add),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AddProjectDialog(),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
      title: Text('Añadir proyecto'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nombre
            TextFormField(
              decoration: InputDecoration(labelText: 'Nombre'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es obligatorio';
                }
                return null;
              },
              onSaved: (value) {
                _name = value!.trim();
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
          child: Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: Text('Añadir'),
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

  // Implementa un selector de color básico usando flutter_colorpicker
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
