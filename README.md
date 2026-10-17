# Glass Music (Flutter)

## Option A: GitHub se APK (laptop ki zarurat nahi)
1. GitHub pe naya repo banao, ye saari files upload karo (`.github` folder samet).
2. Repo -> Actions -> "Build APK" -> Run workflow.
3. Khatam hone par Artifacts se `glass-music-apk` download karo, zip kholo, APK install karo.

## Option B: Local
```
flutter create . --platforms=android
flutter pub get
flutter run --release        # ya: flutter build apk --release
```
Liquid glass refraction ke liye Impeller chahiye (naye Flutter me Android pe default hai).
