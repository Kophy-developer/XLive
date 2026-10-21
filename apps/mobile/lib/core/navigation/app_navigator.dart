import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();

NavigatorState? get rootNavigator => rootNavigatorKey.currentState;

BuildContext? get rootNavigatorContext => rootNavigatorKey.currentContext;
