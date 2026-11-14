import 'package:flutter/material.dart';

import 'src/ui/home_page.dart';
import 'src/ui/pay_page.dart';

/// Launcher entrypoint: settings and request history.
void main() => runApp(const HomeApp());

/// Entrypoint of PayActivity, which receives `upi://pay` intents.
@pragma('vm:entry-point')
void payMain() => runApp(const PayApp());
