[app]
title = WormKit
package.name = wormkit
package.domain = org.wormgpt
source.dir = .
source.include_exts = py,png,jpg,kv,atlas
version = 1.0.0
requirements = python3,kivy==2.2.1,requests
orientation = portrait
fullscreen = 0
android.api = 31
android.minapi = 21
android.ndk = 25.2.9519653
android.gradle_dependencies = 'androidx.core:core:1.9.0'
android.permissions = INTERNET
android.accept_sdk_license = True

[buildozer]
log_level = 2
warn_on_root = 1
