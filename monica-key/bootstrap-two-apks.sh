#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

TARGET="${TARGET:-bspippi1337/monica-key}"
WORK="${WORK:-$HOME/monica-key}"
SOURCE_REPO="https://github.com/bspippi1337/blckswan.git"
SOURCE_BRANCH="agent/monica-key-live"
VISIBILITY="${VISIBILITY:-private}"
LOG="${LOG:-$HOME/monica-key-bootstrap.log}"

exec > >(tee "$LOG") 2>&1

step() { printf '\n\033[1;32m[%s] %s\033[0m\n' "$1" "$2"; }
die() { printf '\n\033[1;31mFEIL: %s\033[0m\n' "$*" >&2; exit 1; }

command -v git >/dev/null || die "git mangler"
command -v gh >/dev/null || die "gh mangler"
command -v zip >/dev/null || die "zip mangler"
gh auth status >/dev/null 2>&1 || die "Kjør først: gh auth login"

step 1 "Henter kildekoden"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth=1 --branch "$SOURCE_BRANCH" "$SOURCE_REPO" "$TMP/source"

if [[ -e "$WORK" ]]; then
  BACKUP="${WORK}.backup.$(date +%Y%m%d-%H%M%S)"
  mv "$WORK" "$BACKUP"
  echo "Eksisterende mappe flyttet til $BACKUP"
fi

mkdir -p "$WORK"
cp -a "$TMP/source/monica-key/." "$WORK/"
cd "$WORK"

step 2 "Lager Pippi Key og Monica Key"

cat > app/build.gradle.kts <<'GRADLE'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "no.blckswan.monicakey"
    compileSdk = 35

    defaultConfig {
        applicationId = "no.blckswan.keypair"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.2.0"
    }

    flavorDimensions += "owner"

    productFlavors {
        create("pippi") {
            dimension = "owner"
            applicationId = "no.blckswan.pippikey"
            versionNameSuffix = "-pippi"
            buildConfigField("String", "APP_ROLE", "\"PIPPI\"")
            resValue("string", "app_name", "Pippi Key")
        }

        create("monica") {
            dimension = "owner"
            applicationId = "no.blckswan.monicakey"
            versionNameSuffix = "-monica"
            buildConfigField("String", "APP_ROLE", "\"MONICA\"")
            resValue("string", "app_name", "Monica Key")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    packaging {
        resources.excludes += setOf("META-INF/AL2.0", "META-INF/LGPL2.1")
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}
GRADLE

cat > app/src/main/AndroidManifest.xml <<'MANIFEST'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <application
        android:allowBackup="false"
        android:fullBackupContent="false"
        android:icon="@drawable/ic_launcher"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@style/Theme.MonicaKey"
        android:usesCleartextTraffic="true">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".LocationTrackingService"
            android:exported="false"
            android:foregroundServiceType="location" />
    </application>
</manifest>
MANIFEST

mkdir -p app/src/pippi app/src/monica

cat > app/src/pippi/AndroidManifest.xml <<'PIPPI_MANIFEST'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" />
PIPPI_MANIFEST

cat > app/src/monica/AndroidManifest.xml <<'MONICA_MANIFEST'
<?xml version="1.0" encoding="utf-8"?>
<manifest
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <application>
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter android:autoVerify="false">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="monicakey" android:host="join" />
            </intent-filter>
        </activity>

        <service
            android:name=".LocationTrackingService"
            tools:node="remove" />
    </application>
</manifest>
MONICA_MANIFEST

MAIN_ACTIVITY="app/src/main/java/no/blckswan/monicakey/MainActivity.kt"
grep -q 'config.role = Role.valueOf(BuildConfig.APP_ROLE)' "$MAIN_ACTIVITY" || \
  sed -i '/config = AppConfig(this)/a\        config.role = Role.valueOf(BuildConfig.APP_ROLE)' "$MAIN_ACTIVITY"

step 3 "Lager GitHub Actions-workflow"
mkdir -p .github/workflows

cat > .github/workflows/build.yml <<'WORKFLOW'
name: Build Pippi Key and Monica Key

on:
  workflow_dispatch:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  android:
    runs-on: ubuntu-24.04
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: "8.9"
      - name: Build both APKs
        run: |
          gradle --no-daemon --console=plain --stacktrace \
            :app:assemblePippiDebug \
            :app:assembleMonicaDebug
      - name: Verify APKs
        run: |
          test -s app/build/outputs/apk/pippi/debug/app-pippi-debug.apk
          test -s app/build/outputs/apk/monica/debug/app-monica-debug.apk
          sha256sum \
            app/build/outputs/apk/pippi/debug/app-pippi-debug.apk \
            app/build/outputs/apk/monica/debug/app-monica-debug.apk
      - uses: actions/upload-artifact@v4
        with:
          name: PippiKey-debug-apk
          path: app/build/outputs/apk/pippi/debug/app-pippi-debug.apk
          if-no-files-found: error
          retention-days: 30
      - uses: actions/upload-artifact@v4
        with:
          name: MonicaKey-debug-apk
          path: app/build/outputs/apk/monica/debug/app-monica-debug.apk
          if-no-files-found: error
          retention-days: 30

  relay:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    defaults:
      run:
        working-directory: server
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: "1.23.x"
          cache-dependency-path: server/go.mod
      - name: Test and build relay
        run: |
          gofmt -w .
          go mod tidy
          go test ./...
          CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o monica-key-relay .
      - uses: actions/upload-artifact@v4
        with:
          name: MonicaKey-relay-linux-amd64
          path: server/monica-key-relay
          if-no-files-found: error
          retention-days: 30
WORKFLOW

cat > .gitignore <<'GITIGNORE'
.gradle/
build/
**/build/
local.properties
.idea/
*.iml
*.jks
*.keystore
data/
server/monica-key-relay
GITIGNORE

cat > README.md <<'README'
# Monica Key

To separate native Android-apper fra samme private kodebase.

- `Pippi Key`: logger og sender live-posisjon.
- `Monica Key`: mottar, setter hjem og holder revokasjonsnøkkelen.
- Begge viser ETA, chat og lyd.
- Ingen Google Maps, Firebase eller Google-konto.
README

rm -f create-new-repo.sh create-standalone-repo.sh bootstrap-two-apks.sh
rm -rf .git

git init -b main
git config user.name "${GIT_NAME:-Anders Pippi Tednes}"
git config user.email "${GIT_EMAIL:-bspippi1337@gmail.com}"
git add -A
git commit -m "Initial standalone release with Pippi Key and Monica Key"

step 4 "Oppretter eget GitHub-repo"
if gh repo view "$TARGET" >/dev/null 2>&1; then
  git ls-remote "https://github.com/$TARGET.git" refs/heads/main | grep -q . && \
    die "$TARGET har allerede en main-branch"
  git remote add origin "https://github.com/$TARGET.git"
  git push -u origin main
else
  case "$VISIBILITY" in
    public)
      gh repo create "$TARGET" --public --source=. --remote=origin --push \
        --description "Private Android live location, ETA, chat and voice"
      ;;
    private)
      gh repo create "$TARGET" --private --source=. --remote=origin --push \
        --description "Private Android live location, ETA, chat and voice"
      ;;
    *) die "VISIBILITY må være private eller public" ;;
  esac
fi

step 5 "Følger bygget og laster ned begge APK-ene"
SHA="$(git rev-parse HEAD)"
RUN_ID=""
for _ in $(seq 1 60); do
  RUN_ID="$(gh run list --repo "$TARGET" --workflow build.yml --branch main --limit 10 \
    --json databaseId,headSha --jq ".[] | select(.headSha == \"$SHA\") | .databaseId" | head -n1)"
  [[ -n "$RUN_ID" ]] && break
  sleep 2
done

[[ -n "$RUN_ID" ]] || die "Fant ikke GitHub Actions-runnen"
gh run watch "$RUN_ID" --repo "$TARGET" --exit-status

OUT="$(mktemp -d)"
gh run download "$RUN_ID" --repo "$TARGET" --name PippiKey-debug-apk --dir "$OUT/pippi"
gh run download "$RUN_ID" --repo "$TARGET" --name MonicaKey-debug-apk --dir "$OUT/monica"

DOWNLOADS="$HOME/storage/downloads"
[[ -d "$DOWNLOADS" ]] || DOWNLOADS="$HOME"

PIPPI_APK="$(find "$OUT/pippi" -type f -name '*.apk' -print -quit)"
MONICA_APK="$(find "$OUT/monica" -type f -name '*.apk' -print -quit)"

[[ -s "$PIPPI_APK" ]] || die "Pippi Key APK mangler"
[[ -s "$MONICA_APK" ]] || die "Monica Key APK mangler"

cp -f "$PIPPI_APK" "$DOWNLOADS/PippiKey-debug.apk"
cp -f "$MONICA_APK" "$DOWNLOADS/MonicaKey-debug.apk"

sha256sum "$DOWNLOADS/PippiKey-debug.apk" "$DOWNLOADS/MonicaKey-debug.apk"
printf '\nRepo: https://github.com/%s\nPippi: %s\nMonica: %s\nLogg: %s\n' \
  "$TARGET" "$DOWNLOADS/PippiKey-debug.apk" "$DOWNLOADS/MonicaKey-debug.apk" "$LOG"
