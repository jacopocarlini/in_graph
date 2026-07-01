import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NodeIcon extends StatelessWidget {
  final IconData? materialIcon;
  final String? iconAssetPath;
  final Color color;
  final double size;

  const NodeIcon({
    Key? key,
    required this.materialIcon,
    required this.iconAssetPath,
    required this.color,
    required this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (iconAssetPath != null && iconAssetPath!.isNotEmpty) {
      final isNetwork =
          iconAssetPath!.startsWith('http://') ||
          iconAssetPath!.startsWith('https://');
      if (isNetwork) {
        return SvgPicture.network(
          iconAssetPath!,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => SizedBox(
            width: size,
            height: size,
            child: Icon(
              materialIcon ?? Icons.widgets,
              size: size,
              color: color,
            ),
          ),
        );
      }

      return SvgPicture.asset(
        iconAssetPath!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => SizedBox(
          width: size,
          height: size,
          child: Icon(materialIcon ?? Icons.widgets, size: size, color: color),
        ),
      );
    }

    return Icon(materialIcon ?? Icons.widgets, size: size, color: color);
  }
}
