#!/usr/bin/env pwsh

# Build script for production flavor with Firebase integration
# This script builds the prod flavor of LastQuakes with full Firebase services

param(
    [Parameter(Mandatory=$false)]
    [switch]$IncrementBuild,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("apk", "appbundle", "both")]
    [string]$BuildType = "apk"
)

Write-Host "🚀 Building LastQuakes Production Flavor" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Increment build number if requested
if ($IncrementBuild) {
    Write-Host "🔨 Incrementing build number..." -ForegroundColor Green
    dart run scripts/increment_build_number.dart

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to increment build number" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Build number incremented" -ForegroundColor Green
}

# Check for required files
Write-Host "🔍 Checking Firebase configuration..." -ForegroundColor Yellow
$googleServicesFile = "android\app\src\prod\google-services.json"
if (-not (Test-Path $googleServicesFile)) {
    Write-Host "⚠️  Warning: $googleServicesFile not found!" -ForegroundColor Red
    Write-Host "   Firebase services may not work properly." -ForegroundColor Red
    Write-Host "   Please add your google-services.json file to android\app\src\prod\" -ForegroundColor Red
}

# Build APK if requested
if ($BuildType -eq "apk" -or $BuildType -eq "both") {
    Write-Host "📦 Building Production APK..." -ForegroundColor Green
    flutter build apk --release --flavor prod --dart-define=FLAVOR=prod -t lib/main_prod.dart

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Production APK built successfully!" -ForegroundColor Green
        Write-Host "   Output: build\app\outputs\flutter-apk\LastQuakes-*.apk" -ForegroundColor Cyan
    } else {
        Write-Host "❌ Production APK build failed" -ForegroundColor Red
        exit 1
    }
}

# Build App Bundle if requested
if ($BuildType -eq "appbundle" -or $BuildType -eq "both") {
    Write-Host "📦 Building Production App Bundle..." -ForegroundColor Green
    flutter build appbundle --release --flavor prod --dart-define=FLAVOR=prod -t lib/main_prod.dart

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Production App Bundle built successfully!" -ForegroundColor Green
        Write-Host "   Output: build\app\outputs\bundle\prodRelease\app-prod-release.aab" -ForegroundColor Cyan
    } else {
        Write-Host "❌ Production App Bundle build failed" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "🎉 Production build complete!" -ForegroundColor Green
Write-Host "   This build includes Firebase Analytics and Push Notifications" -ForegroundColor Cyan
