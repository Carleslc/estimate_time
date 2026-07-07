# EstimateTime

🇪🇸 **Estima y cuenta el tiempo de tus tareas y proyectos**

Estimate and track the time of your tasks and projects.

<!-- toc -->

- [Features](#features)
- [Install](#install)
- [App structure](#app-structure)
- [Development](#development)
  * [Visual Studio Code](#visual-studio-code)
  * [Code generation](#code-generation)
  * [Analyze and test](#analyze-and-test)
  * [Build](#build)
    + [Android](#android)
    + [iOS](#ios)
    + [Web](#web)
  * [Upgrade](#upgrade)
- [Resources](#resources)
- [Libraries](#libraries)

<!-- tocstop -->

This app helps you estimate how long your tasks will take and track the actual time spent on them,
so you can compare your estimations against reality and improve your future estimations.

## Features

- **Tasks with a built-in stopwatch**: create tasks and start / pause / resume their timer.
  Multiple tasks can run at the same time, and running timers are resumed when the app is reopened.
- **Time estimations**: set an estimated time for each task and see the estimated progress,
  the estimated end time while the timer is running, and the deviation percentage
  when the actual time exceeds the estimation (underestimated tasks).
- **Projects**: group related tasks into projects to accumulate their total time,
  average time per task, total estimated time and average deviation,
  helping you estimate similar tasks in the future.
- **Time charts**: bar charts with the daily time history of each task
  and each project (aggregating the time of all its tasks).
- **Daily time tracking**: the time of each task is stored per day (time entries).
  If a timer runs past midnight, the elapsed time is correctly split between days,
  even if the app is closed in between.
  The time registered today can also be edited manually.
- **Archive**: archive finished tasks to keep your active list clean.
  An archived task can be copied into a new task, restored (unarchived) or permanently deleted.
- **Local persistence**: everything is stored locally on your device with the [Isar](https://github.com/isar-community/isar-community) database.

## Install

1. [Install Flutter SDK](https://docs.flutter.dev/get-started/install).

2. Clone the repository:

```sh
git clone https://github.com/Carleslc/estimate_time.git
# GitHub CLI: gh repo clone Carleslc/estimate_time

cd estimate_time
```

3. Install dependencies:

```sh
flutter pub get
```

Check your environment and connected devices:

```sh
flutter doctor
```

Run the app:

```sh
flutter run # -h
```

## App structure

```
lib
├── models
├── providers
├── screens
├── services
├── styles
├── utils
├── widgets
└── main.dart
```

Flutter app code is at `lib/`.

The starting point is at `main.dart`.

`models`: the models of the application domain, persisted with the [Isar](https://pub.dev/packages/isar_community) database:
`Task` (with its time estimation and stopwatch state), `Project` (grouping tasks) and `TimeEntry` (time registered per day for a task).
Their `*.g.dart` files are [generated](#code-generation) by the Isar generator.
`ChartData` holds the processed points and labels for the time charts.

`providers`: data providers ([provider](https://pub.dev/packages/provider)) to manage the state of tasks, projects and navigation.
`TaskProvider` is the core of the app: it manages the task timers with ticks every second,
updates the daily time entries (splitting time between days when a timer crosses midnight)
and emits the chart data streams.

`screens`: the different screens of the application, starting with the `HomeScreen`,
which contains the three main pages (active tasks with timers, projects and archived tasks),
plus the task and project details screens and the dialogs to create tasks and projects.

`services`: `IsarService` opens the local database and `TimerService` manages the periodic timers
used by the stopwatches, synced to the second.

`styles`: the main styles of the application, with themes for different widgets in `AppStyles`.

`utils`: utility classes and extensions for dates, durations, strings, logging, platform checks
and `message.dart` to show snackbar messages.

`widgets`: reusable widgets like the time bar chart ([fl_chart](https://pub.dev/packages/fl_chart)),
the timer button, the time picker and the color picker dialog.

## Development

### Visual Studio Code

[Install Flutter extension](https://docs.flutter.dev/tools/vs-code)

Run the app at `lib/main.dart` (`Run | Debug`).

Open Flutter DevTools with `Cmd+Shift+P` → `Flutter: Open DevTools`

### Code generation

The models `project.dart`, `task.dart` and `time_entry.dart` are Isar collections.

To generate their corresponding code (`*.g.dart` files), run:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Run this command whenever you change the models' persisted fields.

### Analyze and test

Statically analyze the code for errors, warnings and lints:

```sh
flutter analyze
```

Run the tests at `test/`:

```sh
flutter test
```

Tests open a real Isar database in a temporary directory.
The first run downloads the Isar Core native binary (`libisar.dylib` / `libisar.so`)
to the project root, which is ignored by git.
If you upgrade the Isar version, delete the old binary so tests can download the matching one.

### Build

#### Android

Build the app in debug or release mode:

```sh
flutter build apk --debug
flutter build apk --release
```

Install the app in your device:

```sh
# Check connected devices
adb devices

# Default connected device
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Specific device (serial device-ID, e.g. emulator-5554)
adb -s device-ID install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s device-ID install -r build/app/outputs/flutter-apk/app-release.apk
```

#### iOS

Build the app in debug or release mode:

```sh
flutter build ios --debug
flutter build ios --release
```

#### Web

```sh
flutter build web
```

### Upgrade

Upgrade Flutter to the latest stable version:

```sh
flutter upgrade
```

Then check the environment and dependencies:

```sh
flutter doctor
flutter pub outdated
flutter pub upgrade
```

After upgrading Flutter or Isar, regenerate the model files ([Code generation](#code-generation))
and run `flutter analyze` and `flutter test` to verify everything still works.

## Resources

- [Flutter Docs](https://docs.flutter.dev/)
- [Flutter API](https://api.flutter.dev/)
- [Material Widgets](https://docs.flutter.dev/ui/widgets/material)
- [Dart Style Guide](https://dart.dev/effective-dart)
- [Isar v3 Documentation](https://isar-community.dev/v3/)
- [fl_chart Documentation](https://github.com/imaNNeo/fl_chart/blob/main/repo_files/documentations/index.md)
- [Simple app state management with provider](https://docs.flutter.dev/data-and-backend/state-mgmt/simple)
- [Android API Levels](https://apilevels.com/)

## Libraries

### Database

- [isar_community](https://pub.dev/packages/isar_community): fast NoSQL local database for Flutter,
  with links between collections and queries. Community-maintained continuation of [Isar](https://github.com/isar/isar) v3.
- [isar_community_flutter_libs](https://pub.dev/packages/isar_community_flutter_libs): Isar Core native binaries.
- [path_provider](https://pub.dev/packages/path_provider): platform-specific application directories, to locate the database.

### State management

- [provider](https://pub.dev/packages/provider)

### Design

- [fl_chart](https://pub.dev/packages/fl_chart): time history bar charts.
- [flutter_colorpicker](https://pub.dev/packages/flutter_colorpicker): project color picker.
- [cupertino_icons](https://pub.dev/packages/cupertino_icons)

### Localization

- [intl](https://pub.dev/packages/intl): date and time formatting (English and Spanish).

### Development

`--dev`

- [isar_community_generator](https://pub.dev/packages/isar_community_generator): Isar collections code generation.
- [build_runner](https://pub.dev/packages/build_runner)
- [flutter_lints](https://pub.dev/packages/flutter_lints)
