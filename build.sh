#!/bin/bash

echo "Installing dependencies..."
flutter pub get

echo "Running code generation..."
flutter pub run build_runner build --delete-conflicting-outputs

echo "Build complete!"
