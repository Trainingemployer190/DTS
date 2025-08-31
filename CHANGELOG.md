# DTS App - Beta Release Notes

## Beta 2 (v1.0.1 Build 2) - December 2024

### 🔧 Critical Fixes

- **Fixed Pricing Calculation Discrepancy**: Resolved issue where Jobber quotes showed $200+ less than app calculations
  - Root cause: API was sending base costs instead of final marked-up prices
  - Solution: Implemented proportional price distribution logic to maintain accurate pricing ratios
  - Impact: Jobber quotes now match app calculations exactly (e.g., $624.02 total now correctly reflected in Jobber)

- **Fixed Settings Not Applied to New Quotes**: Profit margin % and markup % now correctly use current app settings
  - Root cause: QuoteDraft model was using hardcoded default values instead of user settings
  - Solution: Updated initialization logic to apply current AppSettings values
  - Impact: New quotes automatically use configured profit margins and markup percentages

### 🎯 Technical Improvements

- Enhanced API integration with comprehensive debug logging for price verification
- Improved quote initialization workflow for better user experience
- Added robust error handling for Jobber API communication

### 📱 User Experience

- Quotes now accurately reflect configured pricing settings from first use
- Seamless sync between app calculations and Jobber CRM quotes
- More reliable quote creation process with better error feedback

### 🧪 Testing Notes

- All pricing calculations verified through comprehensive logging
- Build tested successfully on iOS Simulator
- API integration tested with live Jobber environment

---

## Beta 1 (v1.0.0 Build 1) - November 2024

### ✨ Initial Features

- Jobber CRM integration with OAuth authentication
- Advanced quote calculator with markup and commission tracking
- Photo capture with GPS watermarking
- Professional PDF quote generation
- SwiftData local storage with sync capabilities
- Core Location services for job documentation

### 🏗️ Technical Foundation

- SwiftUI iOS 18+ app architecture
- GraphQL API integration with Jobber
- Modern data persistence with SwiftData
- Secure authentication flow

---

## Development Notes

### API Integration Status

- ✅ OAuth authentication flow complete
- ✅ Job fetching and synchronization
- ✅ Quote creation with accurate pricing
- ✅ Product details integration
- ✅ Error handling and logging

### Known Issues

- None currently identified for Beta 2

### Next Planned Features

- Enhanced photo organization
- Batch quote processing
- Advanced reporting features
- Offline mode improvements

---

*For technical support or feature requests, contact the development team.*
