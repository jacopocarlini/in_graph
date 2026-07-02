# InGraph - Modern Graph Editor

**InGraph** is a modern, fast, and intuitive graph editor designed to help you visualize your ideas with precision. Create diagrams, logic schemas, and complex graphs directly in your browser.

[Try the Web App](https://jacopocarlini.github.io/in_graph/app/) | [Landing Page](https://jacopocarlini.github.io/in_graph/)

![InGraph Banner](landing/favicon.png) <!-- Replace with a real banner if available -->

## ✨ Features

- **Intuitive Interface**: Drag-and-drop nodes, effortless connections, and deep customization.
- **Cloud Speed**: No installation required. Access your projects from any device thanks to the power of Flutter Web.
- **Open Source**: Built with transparency and community collaboration in mind.
- **Dynamic Assets**: Supports a wide range of SVG icons (Azure, AWS, etc.) for technical diagrams.

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable channel)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/jacopocarlini/in_graph.git
   cd in_graph
   ```
2. Get dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run -d chrome
   ```

## 🎨 Asset Management

### SVG Icons
SVG icons are loaded dynamically from `assets/`. When adding new SVG icons (e.g., Azure or AWS sets), update the `pubspec.yaml` automatically using the provided tool:

```bash
dart run tool/sync_svg_assets.dart
flutter pub get
```

## 🛠 Build Instructions

To build the web application for production (e.g., for GitHub Pages):

```bash
flutter build web --base-href /in_graph/ --no-tree-shake-icons
```

> **Note**: The `--no-tree-shake-icons` flag is required because the project handles some icons dynamically at runtime.

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Web)
- **Language**: [Dart](https://dart.dev/)
- **State Management**: [Provider](https://pub.dev/packages/provider)

## 🤝 Contributing

Contributions are welcome! If you'd like to improve InGraph, feel free to fork the repo and create a pull request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

Created with passion by **Jacopo Carlini**.
- GitHub: [@jacopocarlini](https://github.com/jacopocarlini)
