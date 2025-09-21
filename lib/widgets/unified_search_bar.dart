import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class UnifiedSearchBar extends HookWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String? hintText;
  final bool showClearButton;
  final FocusNode? focusNode;

  const UnifiedSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.onClear,
    this.hintText,
    this.showClearButton = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final localController = useTextEditingController();
    final textController = controller ?? localController;
    final localFocusNode = useFocusNode();
    final searchFocusNode = focusNode ?? localFocusNode;
    final isFocused = useState(false);

    // Listen to focus changes
    useEffect(() {
      void listener() {
        isFocused.value = searchFocusNode.hasFocus;
      }

      searchFocusNode.addListener(listener);
      return () => searchFocusNode.removeListener(listener);
    }, [searchFocusNode]);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(
          color: isFocused.value
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withOpacity(0.5),
          width: isFocused.value ? 1.5 : 1.25,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 5,
            spreadRadius: 0.5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        // Override the input decoration theme to ensure consistent appearance
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(),
        ),
        child: TextField(
          controller: textController,
          focusNode: searchFocusNode,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText ?? 'ابحث عن دواء، مادة فعالة...',
            hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
            prefixIcon: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.primary,
              size: 25,
            ),
            suffixIcon: showClearButton && textController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      textController.clear();
                      onClear?.call();
                      onChanged?.call('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }
}