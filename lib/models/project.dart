import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

part 'project.g.dart';

@Collection()
class Project {
  Id id = Isar.autoIncrement;

  late String name;

  late int colorValue; // ARGB

  @ignore
  Color _color = Colors.blue;

  @ignore
  Color _labelColor = Colors.white;

  @ignore
  Color get color => _color;

  set color(Color color) {
    this.colorValue = color.value;
    _color = color;
    _labelColor =
        _color.computeLuminance() >= 0.5 ? Colors.black : Colors.white;
  }

  @ignore
  Color get labelColor => _labelColor;
}
