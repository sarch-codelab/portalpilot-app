import 'package:flutter/material.dart';

class FadeThroughTransition extends PageRouteBuilder {
  final Widget child;

  FadeThroughTransition({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
}

class SharedAxisTransition extends PageRouteBuilder {
  final Widget child;
  final SharedAxisTransitionType type;

  SharedAxisTransition({
    required this.child,
    this.type = SharedAxisTransitionType.horizontal,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _buildTransition(type, animation, secondaryAnimation, child);
          },
        );

  static Widget _buildTransition(
    SharedAxisTransitionType type,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    switch (type) {
      case SharedAxisTransitionType.horizontal:
        return _buildHorizontalTransition(animation, secondaryAnimation, child);
      case SharedAxisTransitionType.vertical:
        return _buildVerticalTransition(animation, secondaryAnimation, child);
      case SharedAxisTransitionType.scaled:
        return _buildScaledTransition(animation, secondaryAnimation, child);
    }
  }

  static Widget _buildHorizontalTransition(Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero);
    final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    
    return SlideTransition(
      position: tween.animate(curvedAnimation),
      child: FadeTransition(
        opacity: curvedAnimation,
        child: child,
      ),
    );
  }

  static Widget _buildVerticalTransition(Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero);
    final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    
    return SlideTransition(
      position: tween.animate(curvedAnimation),
      child: FadeTransition(
        opacity: curvedAnimation,
        child: child,
      ),
    );
  }

  static Widget _buildScaledTransition(Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final scaleTween = Tween(begin: 0.8, end: 1.0);
    final fadeTween = Tween(begin: 0.0, end: 1.0);
    final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    
    return ScaleTransition(
      scale: scaleTween.animate(curvedAnimation),
      child: FadeTransition(
        opacity: fadeTween.animate(curvedAnimation),
        child: child,
      ),
    );
  }
}

enum SharedAxisTransitionType {
  horizontal,
  vertical,
  scaled,
}

class MaterialFadeUpwardsTransition extends PageRouteBuilder {
  final Widget child;

  MaterialFadeUpwardsTransition({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: child,
              ),
            );
          },
        );
}

class ZoomInTransition extends PageRouteBuilder {
  final Widget child;

  ZoomInTransition({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        );
}

class SlideFromRightTransition extends PageRouteBuilder {
  final Widget child;

  SlideFromRightTransition({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
              child: child,
            );
          },
        );
}

class SlideFromLeftTransition extends PageRouteBuilder {
  final Widget child;

  SlideFromLeftTransition({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
              child: child,
            );
          },
        );
}

class ScaleFadeTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const ScaleFadeTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOut,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class StaggeredAnimationBuilder extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Duration staggerDelay;
  final Duration animationDuration;

  const StaggeredAnimationBuilder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.staggerDelay = const Duration(milliseconds: 100),
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: animationDuration,
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: itemBuilder(context, index),
        );
      },
    );
  }
}