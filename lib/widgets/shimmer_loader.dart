
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoader extends StatelessWidget {
  final double? width;
  final double? height;
  final bool isCircular;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoader({
    super.key,
    this.width,
    this.height,
    this.isCircular = false,
    this.borderRadius = 12.0,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmerBaseColor = baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final shimmerHighlightColor = highlightColor ?? theme.colorScheme.surface;

    return Shimmer.fromColors(
      baseColor: shimmerBaseColor,
      highlightColor: shimmerHighlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: shimmerBaseColor,
          borderRadius: isCircular ? null : BorderRadius.circular(borderRadius),
          shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }
}

class ShimmerText extends StatelessWidget {
  final double? width;
  final double height;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerText({
    super.key,
    this.width,
    this.height = 16.0,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmerBaseColor = baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final shimmerHighlightColor = highlightColor ?? theme.colorScheme.surface;

    return Shimmer.fromColors(
      baseColor: shimmerBaseColor,
      highlightColor: shimmerHighlightColor,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: shimmerBaseColor,
          borderRadius: BorderRadius.circular(4.0),
        ),
      ),
    );
  }
}

class ShimmerImage extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerImage({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12.0,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmerBaseColor = baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final shimmerHighlightColor = highlightColor ?? theme.colorScheme.surface;

    return Shimmer.fromColors(
      baseColor: shimmerBaseColor,
      highlightColor: shimmerHighlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: shimmerBaseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShimmerButton extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerButton({
    super.key,
    this.width,
    this.height = 48.0,
    this.borderRadius = 12.0,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmerBaseColor = baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final shimmerHighlightColor = highlightColor ?? theme.colorScheme.surface;

    return Shimmer.fromColors(
      baseColor: shimmerBaseColor,
      highlightColor: shimmerHighlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: shimmerBaseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShimmerCard extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;
  final Widget? child;
  final EdgeInsetsGeometry padding;

  const ShimmerCard({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 16.0,
    this.baseColor,
    this.highlightColor,
    this.child,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmerBaseColor = baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final shimmerHighlightColor = highlightColor ?? theme.colorScheme.surface;

    return Shimmer.fromColors(
      baseColor: shimmerBaseColor,
      highlightColor: shimmerHighlightColor,
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: shimmerBaseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      ),
    );
  }
}

// Facebook-like product card shimmer placeholder
class ProductCardShimmer extends StatelessWidget {
  const ProductCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerCard(
      borderRadius: 16.0,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          ShimmerImage(
            height: 120,
            borderRadius: 12.0,
            width: double.infinity,
          ),
          const SizedBox(height: 8),
          // Product name placeholder
          ShimmerText(height: 18, width: double.infinity),
          const SizedBox(height: 4),
          // Price placeholder
          ShimmerText(height: 16, width: 60),
          const SizedBox(height: 4),
          // Distributor placeholder
          ShimmerText(height: 10, width: 100),
        ],
      ),
    );
  }
}

// Facebook-like distributor card shimmer placeholder
class DistributorCardShimmer extends StatelessWidget {
  const DistributorCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerCard(
      borderRadius: 16.0,
      child: Row(
        children: [
          // Avatar placeholder
          ShimmerLoader(
            width: 60,
            height: 60,
            isCircular: true,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Distributor name placeholder
                ShimmerText(height: 18, width: 150),
                const SizedBox(height: 8),
                // Company name placeholder
                ShimmerText(height: 14, width: 100),
                const SizedBox(height: 4),
                // Product count placeholder
                ShimmerText(height: 12, width: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Facebook-like profile header shimmer placeholder
class ProfileHeaderShimmer extends StatelessWidget {
  const ProfileHeaderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerCard(
      borderRadius: 0,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar placeholder
          ShimmerLoader(
            width: 80,
            height: 80,
            isCircular: true,
          ),
          const SizedBox(height: 16),
          // Name placeholder
          ShimmerText(height: 24, width: 200),
          const SizedBox(height: 8),
          // Email placeholder
          ShimmerText(height: 16, width: 150),
          const SizedBox(height: 8),
          // Role placeholder
          ShimmerText(height: 16, width: 100),
          const SizedBox(height: 24),
          // Stats placeholders
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  ShimmerText(height: 20, width: 40),
                  const SizedBox(height: 4),
                  ShimmerText(height: 14, width: 60),
                ],
              ),
              Column(
                children: [
                  ShimmerText(height: 20, width: 40),
                  const SizedBox(height: 4),
                  ShimmerText(height: 14, width: 60),
                ],
              ),
              Column(
                children: [
                  ShimmerText(height: 20, width: 40),
                  const SizedBox(height: 4),
                  ShimmerText(height: 14, width: 60),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Modern e-commerce style animated splash loader with clear animations
class AttractiveSplashLoader extends StatefulWidget {
  final Color? color;
  final double size;

  const AttractiveSplashLoader({
    super.key,
    this.color,
    this.size = 40.0,
  });

  @override
  State<AttractiveSplashLoader> createState() => _AttractiveSplashLoaderState();
}

class _AttractiveSplashLoaderState extends State<AttractiveSplashLoader>
    with TickerProviderStateMixin {
  late AnimationController _dotsController;
  late List<Animation<double>> _dotsAnimations;

  @override
  void initState() {
    super.initState();

    // Dots animation controller
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Create animations for each dot - wave effect
    _dotsAnimations = List.generate(5, (index) {
      final start = index * 0.1;
      final end = start + 0.5;

      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _dotsController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loaderColor = widget.color ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: Listenable.merge([_dotsController]),
      builder: (context, child) {
        return SizedBox(
          width: widget.size * 2,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(5, (index) {
              // Use the separate animation for each dot
              final scale = 0.4 + 0.6 * _dotsAnimations[index].value;
              final opacity = 0.4 + 0.6 * _dotsAnimations[index].value;

              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: widget.size * 0.05),
                    width: widget.size * 0.2,
                    height: widget.size * 0.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: loaderColor,
                      boxShadow: [
                        BoxShadow(
                          color: loaderColor.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// Attractive catalog loading indicator
class CatalogLoadingIndicator extends StatefulWidget {
  final Color? color;
  final double size;

  const CatalogLoadingIndicator({
    super.key,
    this.color,
    this.size = 50.0,
  });

  @override
  State<CatalogLoadingIndicator> createState() => _CatalogLoadingIndicatorState();
}

class _CatalogLoadingIndicatorState extends State<CatalogLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50.0,
      ),
    ]).animate(_controller);

    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 360,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loaderColor = widget.color ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating circle
              Transform.rotate(
                angle: _rotateAnimation.value * 0.0174533,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: loaderColor.withOpacity(0.2),
                      width: 4,
                    ),
                  ),
                ),
              ),
              // Bouncing inner circle
              Transform.scale(
                scale: 0.6 + (0.4 * _bounceAnimation.value),
                child: Container(
                  width: widget.size * 0.6,
                  height: widget.size * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: loaderColor,
                    boxShadow: [
                      BoxShadow(
                        color: loaderColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.inventory_2,
                      color: Colors.white,
                      size: widget.size * 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Attractive image loading indicator
class ImageLoadingIndicator extends StatefulWidget {
  final Color? color;
  final double size;

  const ImageLoadingIndicator({
    super.key,
    this.color,
    this.size = 40.0,
  });

  @override
  State<ImageLoadingIndicator> createState() => _ImageLoadingIndicatorState();
}

class _ImageLoadingIndicatorState extends State<ImageLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loaderColor = widget.color ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: loaderColor.withOpacity(0.1),
              border: Border.all(
                color: loaderColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.image_outlined,
                color: loaderColor,
                size: widget.size * 0.6,
              ),
            ),
          ),
        );
      },
    );
  }
}
