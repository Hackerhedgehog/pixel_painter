import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the save callback. The canvas registers its capture function here.
final saveCallbackProvider = StateProvider<Future<void> Function()?>((ref) => null);
