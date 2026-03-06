import 'package:flutter/foundation.dart';

class PostcardDataRefreshBus {
  PostcardDataRefreshBus._();

  static final ValueNotifier<int> _version = ValueNotifier<int>(0);

  static ValueListenable<int> get listenable => _version;

  static void notifySaved() {
    _version.value = _version.value + 1;
  }
}
