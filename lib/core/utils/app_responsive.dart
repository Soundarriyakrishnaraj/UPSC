import 'package:flutter/material.dart';

class AppResponsive {
  AppResponsive._();

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  static double screenWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height;
  }

  static bool isMobile(BuildContext context) {
    return screenWidth(context) < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = screenWidth(context);

    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= desktopBreakpoint;
  }

  static double horizontalPadding(BuildContext context) {
    final width = screenWidth(context);

    if (width < mobileBreakpoint) {
      return 20;
    }

    if (width < desktopBreakpoint) {
      return 32;
    }

    return 48;
  }

  static double contentWidth(BuildContext context) {
    final width = screenWidth(context);

    if (width >= desktopBreakpoint) {
      return 1100;
    }

    return width;
  }

  static double gridColumns(BuildContext context) {
    final width = screenWidth(context);

    if (width >= desktopBreakpoint) return 4;
    if (width >= tabletBreakpoint) return 3;
    if (width >= mobileBreakpoint) return 2;

    return 2;
  }
}
