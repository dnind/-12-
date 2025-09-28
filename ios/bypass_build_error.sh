#!/bin/bash

echo "=== PhaseScriptExecution 오류 우회 ==="

# 1. Xcode project settings 수정
cd ios

# Bundle identifier를 유니크하게 변경
UNIQUE_SUFFIX=$(date +%s)
NEW_BUNDLE_ID="com.example.macha.${UNIQUE_SUFFIX}"

# 2. Firebase 설정 확인
if [ ! -f "Runner/GoogleService-Info.plist" ]; then
    echo "GoogleService-Info.plist 파일이 없습니다!"
    echo "Firebase 콘솔에서 다운로드하여 ios/Runner/ 폴더에 추가하세요"
fi

# 3. Build settings 정리
echo "Build settings 정리 중..."

# 4. Xcode workspace 열기
echo "Xcode workspace를 여는 중..."
open Runner.xcworkspace

echo ""
echo "=== 수동 설정 가이드 ==="
echo "1. Xcode가 열리면 Runner 프로젝트 선택"
echo "2. Signing & Capabilities 탭에서:"
echo "   - Team: 본인 Apple ID 선택"
echo "   - Bundle Identifier: ${NEW_BUNDLE_ID}"
echo "3. Build Settings 탭에서:"
echo "   - iOS Deployment Target: 13.0"
echo "   - Enable User Script Sandboxing: No"
echo "4. Product → Clean Build Folder"
echo "5. Product → Build"
echo ""
echo "여전히 오류가 발생하면 Build Phases 탭에서:"
echo "- Run Script 단계들을 임시로 비활성화해보세요"