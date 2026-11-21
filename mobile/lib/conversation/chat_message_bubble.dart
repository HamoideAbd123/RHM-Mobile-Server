import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../markdown_table_theme.dart';
import '../rhm_theme.dart';
import 'chat_message.dart';

class RhmChatMessageBubble extends StatelessWidget {
  const RhmChatMessageBubble({
    super.key,
    required this.message,
    required this.textDirection,
    required this.onCopy,
    this.onSpeak,
  });

  final RhmChatMessage message;
  final TextDirection textDirection;
  final VoidCallback onCopy;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final bubbleColor = isUser ? colorScheme.primary : colorScheme.surface;
    final textColor = isUser ? colorScheme.onPrimary : colorScheme.onSurface;
    final maxWidth = MediaQuery.sizeOf(context).width >= RhmDesignTokens.tabletBreakpoint
        ? 760.0
        : MediaQuery.sizeOf(context).width * .82;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 42 : 0,
        right: isUser ? 0 : 42,
        top: 5,
        bottom: 7,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 20),
              ),
              boxShadow: isUser
                  ? const []
                  : [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: .08),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
              border: isUser
                  ? null
                  : Border.all(
                      color: Theme.of(context).extension<RhmUiTokens>()!.border,
                    ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Directionality(
                    textDirection: textDirection,
                    child: isUser
                        ? SelectableText(
                            message.text,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.55,
                              color: textColor,
                            ),
                          )
                        : MarkdownBody(
                            data: message.text,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              a: TextStyle(color: colorScheme.primary),
                              pPadding: EdgeInsets.zero,
                              p: TextStyle(
                                fontSize: 15,
                                height: 1.6,
                                color: colorScheme.onSurface,
                              ),
                              h1: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                              h2: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                              h3: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                              code: TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                color: colorScheme.primary,
                              ),
                              h1Padding: EdgeInsets.zero,
                              h2Padding: EdgeInsets.zero,
                              h3Padding: EdgeInsets.zero,
                              h4: Theme.of(context).textTheme.bodyLarge,
                              h5: Theme.of(context).textTheme.bodyLarge,
                              h6: Theme.of(context).textTheme.bodyLarge,
                              h4Padding: EdgeInsets.zero,
                              h5Padding: EdgeInsets.zero,
                              h6Padding: EdgeInsets.zero,
                              em: const TextStyle(fontStyle: FontStyle.italic),
                              strong: const TextStyle(fontWeight: FontWeight.bold),
                              del: const TextStyle(decoration: TextDecoration.lineThrough),
                              blockquote: Theme.of(context).textTheme.bodyMedium,
                              img: Theme.of(context).textTheme.bodyMedium,
                              checkbox: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.primary,
                              ),
                              blockSpacing: 8,
                              listIndent: 24,
                              listBullet: Theme.of(context).textTheme.bodyMedium,
                              listBulletPadding: const EdgeInsets.only(right: 4),
                              tableHead: const TextStyle(fontWeight: FontWeight.w600),
                              tableBody: Theme.of(context).textTheme.bodyMedium,
                              tableHeadAlign: TextAlign.center,
                              tableBorder: buildRhmMarkdownTableBorder(Theme.of(context)),
                              tablePadding: const EdgeInsets.only(bottom: 4),
                              tableCellsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              tableCellsDecoration: const BoxDecoration(),
                              blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              blockquoteDecoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(3),
                                border: Border(
                                  left: BorderSide(
                                    color: colorScheme.primary,
                                    width: 3,
                                  ),
                                ),
                              ),
                              codeblockPadding: const EdgeInsets.all(8),
                              codeblockDecoration: BoxDecoration(
                                color: Theme.of(context).cardTheme.color ?? colorScheme.surface,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              horizontalRuleDecoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    width: 1,
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isUser) ...[
                        Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            message.provider ?? 'RHM',
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (onSpeak != null)
                          IconButton(
                            visualDensity: VisualDensity.standard,
                            constraints: const BoxConstraints(
                              minWidth: RhmDesignTokens.minimumTouchTarget,
                              minHeight: RhmDesignTokens.minimumTouchTarget,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: 'قراءة الرد',
                            onPressed: onSpeak,
                            icon: Icon(
                              Icons.volume_up_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                          ),
                      ],
                      IconButton(
                        visualDensity: VisualDensity.standard,
                        constraints: const BoxConstraints(
                          minWidth: RhmDesignTokens.minimumTouchTarget,
                          minHeight: RhmDesignTokens.minimumTouchTarget,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: 'نسخ الرسالة',
                        onPressed: onCopy,
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
