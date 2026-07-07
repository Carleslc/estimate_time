import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

part 'project.g.dart';

@Collection()
class Project {
  Id id = Isar.autoIncrement;

  /// Nombre del proyecto
  late String name;

  /// Fecha de creación del proyecto
  DateTime createdAt = DateTime.now();

  /// Color del proyecto en ARGB
  int get colorValue => _colorValue;
  @ignore
  late int _colorValue;

  set colorValue(int value) {
    _colorValue = value;
    _color = Color(colorValue);
    _updateLuminance();
  }

  /// Color del proyecto
  @ignore
  Color get color => _color;
  @ignore
  Color _color = Colors.blue;

  set color(Color color) {
    _colorValue = color.toARGB32();
    _color = color;
    _updateLuminance();
  }

  /// Color del texto sobre el color del proyecto
  @ignore
  Color get labelColor => _labelColor;
  @ignore
  Color _labelColor = Colors.white;

  /// Actualiza el color del proyecto
  void _updateLuminance() {
    _labelColor =
        _color.computeLuminance() >= 0.5 ? Colors.black : Colors.white;
  }

  @override
  String toString() {
    return 'Project(id: $id, name: $name, colorValue: $_colorValue)';
  }
}
