import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

part 'project.g.dart';

@Collection()
class Project {
  Id id = Isar.autoIncrement;

  late String name;

  late int colorValue; // ARGB

  @ignore
  Color get color => Color(colorValue);

  set color(Color color) {
    this.colorValue = color.value;
  }

  // TODO: La función computeLuminance es costosa, estaría bien calcularla solo
  // cuando cambie el colorValue, y no siempre que se llama a labelColor.
  // Lo mismo se puede hacer con el getter color.
  // colorValue debe poderse asignar para que el código siga funcionando con Isar
  @ignore
  Color get labelColor =>
      color.computeLuminance() >= 0.5 ? Colors.black : Colors.white;
}
