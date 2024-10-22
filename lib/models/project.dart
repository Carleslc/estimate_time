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
    colorValue = color.value;
    update();
  }

  @ignore
  Color get labelColor => _labelColor;

  void update() {
    _color = Color(colorValue);
    _labelColor =
        _color.computeLuminance() >= 0.5 ? Colors.black : Colors.white;
  }
}
