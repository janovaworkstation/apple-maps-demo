# Quick Start Guide

Get up and running with the Apple Maps Demo audio tour application.

## Overview

This guide will help you set up the development environment, configure the application, and run your first audio tour.

## Prerequisites

Before you begin, ensure you have:

- **Xcode 15.0+** installed on macOS 14.0+
- **Apple Developer Account** for device testing
- **OpenAI API Key** for AI content generation (optional)
- **iOS Device** with GPS for best testing experience

## Installation Steps

### 1. Clone the Repository

```bash
git clone <repository-url>
cd "Apple Maps Demo"
```

### 2. Open in Xcode

```bash
open "Apple Maps Demo.xcodeproj"
```

The project uses Swift Package Manager. Dependencies will be resolved automatically:
- OpenAI Swift Client
- Reachability
- AsyncLocationKit

### 3. Configure Code Signing

1. Select the project in Xcode Navigator
2. Go to **Signing & Capabilities** tab
3. Set your **Team** and **Bundle Identifier**
4. Ensure required capabilities are enabled:
   - Location Services
   - Background Modes (Audio, Location updates)
   - CarPlay (optional, requires Apple approval)

### 4. Build and Run

1. Select a target device (physical device recommended)
2. Press **⌘+R** or click the Play button
3. Grant location permissions when prompted

## Initial Configuration

### Location Permissions

The app requires location access for core functionality:

1. When prompted, select **"Allow While Using App"** or **"Allow Always"**
2. For background features, "Always" permission is recommended
3. You can change permissions later in iOS Settings → Privacy & Security → Location Services

### OpenAI API Setup (Optional)

For AI-generated content:

1. Obtain an API key from [OpenAI Platform](https://platform.openai.com/)
2. Launch the app and navigate to **Settings** tab
3. Tap **API Configuration**
4. Enter your API key and select GPT-4 model

### Testing Location Features

Since location features work best on physical devices:

1. **Outdoor Testing**: GPS accuracy is better outdoors
2. **Movement Testing**: Walk or drive to test geofence triggers
3. **Simulator Testing**: Use Xcode's location simulation for basic testing

## First Tour Experience

1. **Open Tours Tab**: Browse available sample tours
2. **Select a Tour**: Tap on a tour to view details
3. **Start Tour**: Tap "Start Tour" to begin
4. **Grant Permissions**: Allow location access if prompted
5. **Move Around**: Walk near POI locations to trigger audio

## Verification Checklist

Ensure everything is working correctly:

- [ ] App launches without crashes
- [ ] Location permission granted
- [ ] Tour list loads with sample data
- [ ] Map displays user location
- [ ] Audio plays when tapping POI markers
- [ ] Settings can be accessed and modified

## Next Steps

Once you have the basic setup working:

- <doc:Architecture> - Understand the codebase structure
- <doc:Configuration> - Advanced configuration options
- <doc:Testing> - Run the comprehensive test suite
- <doc:Development> - Development workflow and best practices

## Troubleshooting

### Common Issues

**Location not updating:**
- Ensure GPS signal (test outdoors)
- Check location permissions in iOS Settings
- Verify location capability in project settings

**Audio not playing:**
- Check device volume and mute switch
- Verify background audio capability
- Test with headphones or external speakers

**Build errors:**
- Clean build folder (⌘+Shift+K)
- Reset package dependencies
- Verify code signing configuration

### Getting Help

- Check the <doc:Troubleshooting> guide for detailed solutions
- Review test cases for usage examples
- Create an issue in the repository for bugs

## Development Environment

For optimal development experience:

```bash
# Build for simulator
xcodebuild -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16" build

# Run tests
xcodebuild test -scheme "Apple Maps Demo" -destination "platform=iOS Simulator,name=iPhone 16"

# Build for device
xcodebuild -scheme "Apple Maps Demo" -destination "platform=iOS,name=Your Device Name" build
```

You're now ready to explore the full capabilities of the Apple Maps Demo audio tour application!