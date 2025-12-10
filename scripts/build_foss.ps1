#!/usr/bin/env pwsh

# Build script for FOSS flavor without Firebase integration
# This script builds the FOSS flavor of LastQuakes without any proprietary services

param(
    [Parameter(Mandatory=$false)]
    [switch]$IncrementBuild,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("apk", "appbundle", "both")]
    [string]$BuildType = "apk"
)

Write-Host "🚀 Building LastQuakes FOSS Flavor" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

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

# Build APK if requested
if ($BuildType -eq "apk" -or $BuildType -eq "both") {
    Write-Host "📦 Building FOSS APK..." -ForegroundColor Green
    flutter build apk --release --flavor foss --dart-define=FLAVOR=foss -t lib/main.dart

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ FOSS APK built successfully!" -ForegroundColor Green
        Write-Host "   Output: build\app\outputs\flutter-apk\LastQuakes-FOSS-*.apk" -ForegroundColor Cyan
    } else {
        Write-Host "❌ FOSS APK build failed" -ForegroundColor Red
        exit 1
    }
}

# Build App Bundle if requested
if ($BuildType -eq "appbundle" -or $BuildType -eq "both") {
    Write-Host "📦 Building FOSS App Bundle..." -ForegroundColor Green
    flutter build appbundle --release --flavor foss --dart-define=FLAVOR=foss -t lib/main.dart

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ FOSS App Bundle built successfully!" -ForegroundColor Green
        Write-Host "   Output: build\app\outputs\bundle\fossRelease\app-foss-release.aab" -ForegroundColor Cyan
    } else {
        Write-Host "❌ FOSS App Bundle build failed" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "🎉 FOSS build complete!" -ForegroundColor Green
Write-Host "   This build excludes all Firebase and Google Play Services" -ForegroundColor Cyan
