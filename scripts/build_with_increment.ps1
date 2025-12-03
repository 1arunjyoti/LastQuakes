#!/usr/bin/env pwsh

# Auto-increment build number and build APK
Write-Host "🔨 Incrementing build number..." -ForegroundColor Green
dart run scripts/increment_build_number.dart

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to increment build number" -ForegroundColor Red
    exit 1
}

Write-Host "📦 Building APK..." -ForegroundColor Green
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ APK built successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ APK build failed" -ForegroundColor Red
    exit 1
}
