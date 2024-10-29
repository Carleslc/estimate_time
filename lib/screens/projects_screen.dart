import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';
import '../providers/project_provider.dart';
import 'add_project_dialog.dart';

// TODO: Reordenar proyectos

class ProjectsScreen extends StatefulWidget {
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarga los proyectos
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
                        context
                            .read<NavigationProvider>()
                            .navigateToProjectDetails(project)
                            .then((_) {
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
              heroTag: 'add_project_fab',
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
