# X/Twitter Clone - Flutter App

A complete Twitter/X clone built with Flutter, Firebase, and Supabase, featuring all essential social media functionality.

## 🚀 Features

- **Authentication**
  - Email/password signup & login
  - Google Sign-In integration
  - Persistent user sessions

- **User Profiles**
  - Edit profile (bio, username, profile & cover photo)
  - View others' profiles
  - Followers/following counts
  - Follow/unfollow functionality

- **Tweets**
  - Post tweets with text, images, and videos
  - Like, retweet, reply, and quote tweets
  - Threaded tweets (tweet chains)
  - Infinite scroll timeline
  - "For You" and "Following" tabs

- **Search**
  - Search users and tweets
  - Trending topics section

- **Notifications**
  - Real-time notifications for likes, replies, follows
  - Notification badges

- **Direct Messages**
  - One-to-one chat using Firestore
  - Typing indicator & seen status
  - Real-time messaging

- **Media Upload**
  - Upload profile photos, tweet images, and videos via Supabase Storage
  - Automatic image compression
  - Multiple image support per tweet

- **UI/UX**
  - Dark and light theme support
  - System theme detection
  - Shimmer loading placeholders
  - Smooth animations and transitions
  - Pixel-perfect Twitter/X design

## 📦 Tech Stack

- **Flutter** - Latest stable version
- **State Management** - Riverpod (latest)
- **Backend** - Firebase Auth + Firestore Database
- **Storage** - Supabase Storage
- **Navigation** - GoRouter
- **UI** - Material Design 3

## 🏗️ Architecture

The app follows clean architecture principles with a clear folder structure:

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── user_model.dart
│   ├── tweet_model.dart
│   ├── notification_model.dart
│   └── message_model.dart
├── services/                 # Business logic
│   ├── auth_service.dart
│   ├── tweet_service.dart
│   ├── storage_service.dart
│   ├── profile_service.dart
│   └── message_service.dart
├── providers/                # Riverpod providers
│   ├── auth_provider.dart
│   ├── tweet_provider.dart
│   ├── profile_provider.dart
│   ├── theme_provider.dart
│   └── ...
├── screens/                   # UI screens
│   ├── auth/
│   ├── home/
│   ├── profile/
│   ├── search/
│   ├── notifications/
│   └── messages/
├── widgets/                   # Reusable widgets
│   ├── tweet_card.dart
│   ├── user_card.dart
│   └── ...
├── theme/                     # Theme configuration
│   ├── light_theme.dart
│   └── dark_theme.dart
└── utils/                     # Utilities
    ├── constants.dart
    ├── helpers.dart
    ├── validators.dart
    ├── firebase_options.dart
    └── supabase_config.dart
```

## ⚙️ Setup Instructions

### 1. Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication (Email/Password and Google Sign-In)
3. Create a Firestore database
4. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```
5. Configure Firebase:
   ```bash
   flutterfire configure
   ```
6. Update `lib/utils/firebase_options.dart` with your Firebase configuration

### 2. Supabase Setup

1. Create a Supabase project at [Supabase](https://supabase.com/)
2. Create storage buckets:
   - `profile-pictures`
   - `cover-photos`
   - `tweet-media`
3. Update `lib/utils/supabase_config.dart` with your Supabase credentials:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```

### 3. Dependencies

Install all dependencies:
```bash
flutter pub get
```

### 4. Run the App

```bash
flutter run
```

## 📱 Platform Support

- ✅ iOS
- ✅ Android
- ✅ Web (with some limitations)
- ✅ macOS
- ✅ Windows
- ✅ Linux

## 🔒 Security Notes

- Never commit your Firebase or Supabase credentials to version control
- Use environment variables or secure storage for sensitive keys
- Set up proper Firestore security rules
- Configure Supabase storage bucket policies

## 📝 Firestore Security Rules (Example)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Tweets collection
    match /tweets/{tweetId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth != null && request.resource.data.userId == request.auth.uid;
    }
  }
}
```

## 🎨 Customization

- **Themes**: Modify `lib/theme/light_theme.dart` and `lib/theme/dark_theme.dart`
- **Constants**: Update `lib/utils/constants.dart` for app-wide settings
- **Colors**: Adjust color schemes in theme files to match your brand

## 🐛 Troubleshooting

### Firebase not initialized
- Ensure `firebase_options.dart` has valid configuration
- Run `flutterfire configure` again

### Supabase errors
- Verify Supabase URL and keys in `supabase_config.dart`
- Check that storage buckets are created
- Verify bucket policies allow public read

### Build errors
- Run `flutter clean` and `flutter pub get`
- Ensure all dependencies are compatible with your Flutter version

## 📄 License

This project is provided as-is for educational and development purposes.

## 🤝 Contributing

Feel free to fork, modify, and use this project for your own purposes.

---

**Built with ❤️ using Flutter**
