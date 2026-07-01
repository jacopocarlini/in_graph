# in_graph

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## SVG icon assets

Le icone SVG vengono caricate in modo generico da tutti i path sotto `assets/`.

Quando aggiungi nuove SVG (Azure, AWS o altri provider), aggiorna automaticamente
`pubspec.yaml` con:

```zsh
dart run tool/sync_svg_assets.dart
flutter pub get
```

