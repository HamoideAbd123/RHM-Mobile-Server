import 'package:material_ui/material_ui.dart';

@immutable
class RhmChatMessage {
  const RhmChatMessage(this.isUser, this.text, {this.provider});

  final bool isUser;
  final String text;
  final String? provider;
}
