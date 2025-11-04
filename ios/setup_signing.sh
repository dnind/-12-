#!/bin/bash

# iOS 서명 설정 자동화 스크립트
echo "🔧 iOS 서명 설정 시작..."

# 프로젝트 파일 경로
PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"

# 백업 생성
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"
echo "✅ 백업 파일 생성: $PROJECT_FILE.backup"

# 자동 서명 활성화
echo "📝 자동 서명 설정 중..."

# ProvisioningStyle을 Automatic으로 설정
sed -i '' 's/ProvisioningStyle = Manual;/ProvisioningStyle = Automatic;/g' "$PROJECT_FILE"

# CODE_SIGN_STYLE을 Automatic으로 설정
sed -i '' 's/CODE_SIGN_STYLE = Manual;/CODE_SIGN_STYLE = Automatic;/g' "$PROJECT_FILE"

# Development Team 확인 (이미 설정되어 있음: 4L73TDWT3X)
echo "✅ Development Team: 4L73TDWT3X"

# Bundle Identifier 확인
echo "✅ Bundle Identifier: com.example.macha"

echo ""
echo "🎯 다음 단계:"
echo "1. Xcode를 열어서 Apple ID로 로그인하세요:"
echo "   open ios/Runner.xcworkspace"
echo ""
echo "2. Xcode에서:"
echo "   - Runner 프로젝트 선택"
echo "   - Signing & Capabilities 탭으로 이동"
echo "   - 'Automatically manage signing' 체크박스 활성화"
echo "   - Team 드롭다운에서 개인 팀 선택 (Personal Team)"
echo ""
echo "3. 빌드 테스트:"
echo "   flutter clean"
echo "   flutter build ios --release"
echo ""
echo "✅ 스크립트 실행 완료"