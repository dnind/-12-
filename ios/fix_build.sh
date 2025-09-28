#!/bin/bash

# PhaseScriptExecution 오류 해결 스크립트

echo "=== iOS 빌드 오류 해결 시작 ==="

# 1. 모든 관련 프로세스 종료
killall Xcode 2>/dev/null
killall Simulator 2>/dev/null
killall "iOS Simulator" 2>/dev/null

# 2. 캐시 및 빌드 파일 완전 삭제
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf build/
rm -rf ios/build/
rm -rf ios/Pods/
rm -f ios/Podfile.lock

# 3. Flutter 클린
flutter clean

# 4. 의존성 재설치
flutter pub get

# 5. iOS 의존성 재설치
cd ios
pod deintegrate 2>/dev/null || true
pod install --clean-install

# 6. 권한 설정
find . -name "*.sh" -exec chmod +x {} \;

cd ..

echo "=== 해결 완료! 이제 Xcode에서 빌드하세요 ==="
echo "Runner.xcworkspace 파일을 열고 Product > Clean Build Folder 후 빌드하세요"