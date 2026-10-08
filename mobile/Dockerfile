FROM ghcr.io/cirruslabs/flutter:latest

WORKDIR /app

# Copy pubspec and configuration first for Docker layer caching
COPY pubspec.yaml pubspec.lock l10n.yaml ./
RUN flutter pub get

# Copy full mobile source
COPY . .

# Generate Drift and code assets
RUN dart run build_runner build --delete-conflicting-outputs
RUN flutter gen-l10n

# Build release APK with ABI splits and obfuscation
CMD ["flutter", "build", "apk", "--flavor", "prod", "-t", "lib/main_prod.dart", "--split-per-abi", "--obfuscate", "--split-debug-info=build/symbols"]
