import 'package:flutter_riverpod/flutter_riverpod.dart';

class CanvasSettings {
  const CanvasSettings({this.width = 800, this.height = 600});
  final double width;
  final double height;

  CanvasSettings copyWith({double? width, double? height}) =>
      CanvasSettings(width: width ?? this.width, height: height ?? this.height);
}

final canvasSettingsProvider =
    StateNotifierProvider<CanvasSettingsNotifier, CanvasSettings>(
  (ref) => CanvasSettingsNotifier(),
);

class CanvasSettingsNotifier extends StateNotifier<CanvasSettings> {
  CanvasSettingsNotifier() : super(const CanvasSettings());

  void setWidth(double width) =>
      state = state.copyWith(width: width.clamp(100, 4000));

  void setHeight(double height) =>
      state = state.copyWith(height: height.clamp(100, 4000));
}
