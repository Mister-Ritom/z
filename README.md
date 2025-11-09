# Z – Social Media App

A modern social media app built with **Flutter** and **Firebase**, featuring posts (Zaps), Stories, Short Videos, and all essential social media functionality.

---

## 🚀 Features

- **Authentication**

  - Email/password signup & login
  - Google Sign-In integration
  - Persistent user sessions

- **User Profiles**

  - Edit profile (bio, username, profile & cover photo)
  - View other users' profiles
  - Followers/following counts
  - Follow/unfollow functionality

- **Zaps (Posts)**

  - Create text, image, and video posts
  - Like, Rezap, Reply, and Quote Zaps
  - Threaded Zaps (Zap chains)
  - Infinite scroll timeline
  - "For You" and "Following" tabs

- **Stories**

  - Short-lived photo/video stories
  - Swipe through user stories
  - Story viewing progress indicators

- **Short Videos**

  - Instagram Reels-style short video feed
  - Like, comment, and share videos
  - Auto-play and loop support

- **Search**

  - Search users and Zaps
  - Trending topics section

- **Notifications**

  - Real-time notifications for likes, replies, follows
  - Notification badges

- **Direct Messages**

  - One-to-one chat using Firebase Firestore
  - Typing indicator & seen status
  - Real-time messaging

- **Media Upload**

  - Upload profile photos, Zaps, Stories, and short videos
  - Automatic image and video compression
  - Multiple media support per post

- **UI/UX**
  - Dark and light theme support
  - System theme detection
  - Smooth animations and transitions
  - Pixel-perfect social media design

---

## 📦 Tech Stack

- **Flutter** - Latest stable version
- **State Management** - Riverpod
- **Backend** - Firebase Auth + Firestore + Firebase Storage
- **Navigation** - GoRouter
- **UI** - Material Design 3

## 🎨 Customization

- **Themes**: Modify `lib/theme/light_theme.dart` and `lib/theme/dark_theme.dart`
- **Constants**: Update `lib/utils/constants.dart` for app-wide settings
- **Colors**: Adjust color schemes in theme files to match your brand

---

## 🐛 Troubleshooting

### Firebase not initialized

- Ensure `firebase_options.dart` has valid configuration
- Run `flutterfire configure` again

### Build errors

- Run `flutter clean` and `flutter pub get`
- Ensure all dependencies are compatible with your Flutter version
