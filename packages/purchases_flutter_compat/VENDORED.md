# RevenueCat Flutter compatibility copy

This directory contains the runtime files from `purchases_flutter` 10.11.0,
licensed under the included MIT `LICENSE`.

The Android Gradle file is adapted to AGP 9 built-in Kotlin following Flutter's
plugin migration guide. The application targets Flutter 3.47 or newer and sets
`android.builtInKotlin=true`. No Dart, iOS, macOS, web, or RevenueCat purchase
behavior is changed.

This copy is temporary until RevenueCat publishes a release that no longer
applies the legacy Kotlin Gradle Plugin. When upgrading, remove this directory,
restore the hosted dependency in the root `pubspec.yaml`, and verify the Android
build no longer emits Flutter's KGP compatibility warning.

Upstream:

- https://github.com/RevenueCat/purchases-flutter
- https://github.com/RevenueCat/purchases-flutter/issues/1759
- https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors
