import 'package:flutter/widgets.dart';

class PostFrameTrigger extends StatelessWidget {
  final VoidCallback onLayout;
  final Widget child;

  const PostFrameTrigger({
    super.key, 
    required this.onLayout, 
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    // Register callback during build phase to ensure execution after Layout/Paint completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onLayout();
    });
    return child;
  }
}
