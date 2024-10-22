import 'package:flutter/material.dart';

import '../models/project.dart';

/// Label de un proyecto con el fondo del color del proyecto
class ProjectTag extends StatelessWidget {
  final Project project;
  final double? dense;
  final BorderSide? borderSide;

  const ProjectTag({
    super.key,
    required this.project,
    this.dense = null,
    this.borderSide = BorderSide.none,
  });

  double? get fontSize {
    if (dense == null) return null;
    if (dense! >= 4) return 11;
    if (dense! >= 3) return 12;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        project.name,
        style: TextStyle(
          color: project.labelColor,
          fontSize: fontSize,
        ),
      ),
      backgroundColor: project.color,
      padding: dense != null
          ? EdgeInsets.symmetric(
              horizontal: 4,
            )
          : null,
      visualDensity: dense != null
          ? VisualDensity(
              horizontal: -dense!,
              vertical: -dense!,
            )
          : null,
      side: borderSide,
    );
  }
}
