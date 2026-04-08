import 'package:flutter/material.dart';

/// Soft mask over the lower-mid area of [AppConstants.loaderBackgroundAsset] where
/// the wordmark is baked into the PNG, so it does not read as a second brand layer
/// above the app UI.
class LoaderBgWordmarkCover extends StatelessWidget {
  const LoaderBgWordmarkCover({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, 0.52),
            radius: 0.34,
            colors: [
              Color(0x66D32F2F),
              Color(0x00FFFFFF),
            ],
            stops: [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
