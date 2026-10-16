# 🏦 JoyBank (조이뱅크)

> **교육 및 시연 목적의 Flutter 모바일 뱅킹 시뮬레이션 애플리케이션**  
> 모바일 뱅킹의 핵심 기능(계좌 관리, 간편 송금, 보안 인증, 자산 포트폴리오, 금융 상품 등)을 현대적이고 세련된 UI/UX와 Firebase 백엔드로 구현한 프로젝트입니다.

---

## 📱 주요 기능 (Key Features)

### 1. 🔐 인증 & 보안 (Authentication & Security)
- **회원가입 & 로그인**: Firebase Authentication 기반의 사용자 계정 관리
- **보안 키패드 & 6자리 PIN 인증**: 금융 거래 및 로그인 시 난수 배열 보안 키패드 제공
- **생체 인증 (Biometrics)**: 지문 / Face ID 지원 (`local_auth`)
- **PIN 재설정**: 본인 인증을 통한 간편 비밀번호 재설정 흐름

### 2. 💸 계좌 및 송금 서비스 (Transfer & Payments)
- **실시간 계좌 잔액 & 내역 조회**: Firebase Firestore 연동 실시간 동기화
- **스마트 송금**: 
  - 최근 이체 / 자주 쓰는 계좌 / 연락처 기반 빠른 이체
  - QR 코드 스캔 및 생성 기반 즉시 송금
  - 금액 빠른 입력 칩 (+1만, +5만, +10만, 전액)
- **거래 내역 & 상세 영수증**: 거래 유형별(입금, 출금 등) 필터링, 기간별 검색, 상세 영수증 확인

### 3. 📊 자산 관리 & 포트폴리오 (Asset Management)
- **통합 자산 현황**: 현금, 펀드, 주식, 외화 자산의 포트폴리오 구성 비율 차트
- **소비 분석**: 카테고리별(식비, 쇼핑, 문화, 교통 등) 월간 소비 리포트
- **실시간 연동**: Firestore의 서브 컬렉션(`funds`, `stocks`, `foreign_assets`)과 연계

### 4. 💳 카드 & 간편 결제 (Cards & JoyPay)
- **My Card**: 보유 카드 목록, 카드 상세 혜택 및 사용 한도 관리
- **JoyPay**: 바코드/QR 결제 인터페이스 시뮬레이션

### 5. 📑 금융 상품 & 알림 (Financial Products & Alerts)
- **금융 상품 둘러보기**: 대출, 보험, 펀드 상품 상세 소개 및 가입 프로세스 시뮬레이션
- **알림 센터**: 실시간 거래 알림 및 공지사항 수신

---

## 🛠 기술 스택 (Tech Stack)

| 분류 | 기술 및 라이브러리 |
|---|---|
| **Framework** | Flutter (Dart SDK >=3.0.0) |
| **Backend / DB** | Firebase Core, Firebase Auth, Cloud Firestore |
| **인증 & 보안** | `local_auth` (생체인증), Custom Secure PIN Keypad |
| **UI & 차트** | `fl_chart`, `intl`, `flutter_spinkit`, Google Fonts |
| **유틸리티 & 센서** | `qr_flutter`, `mobile_scanner`, `image_picker`, `vibration` |

---

## 🚀 시작하기 (Getting Started)

### 사전 요구 사항
- Flutter SDK (최신 안정 버전)
- Android Studio / Xcode (모바일 에뮬레이터 또는 실제 기기)
- Firebase 프로젝트 설정 (`google-services.json` / `GoogleService-Info.plist` 또는 FlutterFire CLI)

### 설치 및 실행

```bash
# 1. 저장소 클론
git clone https://github.com/joeyKor/joybank.git

# 2. 프로젝트 폴더로 이동
cd joybank

# 3. 의존성 패키지 설치
flutter pub get

# 4. 앱 실행
flutter run
```

---

## 📁 디렉토리 구조 (Directory Structure)

```text
lib/
├── main.dart                      # 앱 진입점 및 전역 설정/워터마크
├── main_screen.dart               # 홈 메인 화면 및 탭 네비게이션
├── login_screen.dart              # 로그인 화면
├── sign_up_screen.dart            # 회원가입 화면
├── pin_screen.dart                # PIN 인증 화면
├── pin_input_dialog.dart          # 송금/결제용 PIN 다이얼로그
├── pin_reset_screen.dart          # PIN 재설정 화면
├── send_money_screen.dart         # 계좌 송금 및 QR 송금
├── transaction_history_screen.dart# 거래 내역 화면
├── transaction_detail_screen.dart # 거래 상세 영수증
├── asset_management_screen.dart   # 자산 관리 및 소비 분석
├── fund_screen.dart               # 펀드 상품 및 상세
├── loan_screen.dart               # 대출 상품
├── insurance_screen.dart          # 보험 상품
├── joy_pay_screen.dart            # JoyPay 간편 결제
├── my_card_screen.dart            # 카드 관리 화면
├── settings_screen.dart           # 설정 및 보안 관리
└── firebase_options.dart          # Firebase 구성 설정
```

---

## ⚠️ 라이선스 & 주의사항 (Disclaimer)

본 애플리케이션은 **학습 및 시연을 목적으로 제작된 시뮬레이션 뱅킹 앱**입니다. 실제 은행 결제망이나 금융 시스템과 연동되지 않으며, 화면에 표시되는 금융 정보 및 거래 데이터는 테스트용 데이터입니다.

