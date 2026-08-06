param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-Lf([string]$Path) {
    return [IO.File]::ReadAllText((Resolve-Path $Path)).Replace("`r`n", "`n")
}

function Write-Lf([string]$Path, [string]$Text) {
    $utf8NoBom = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText(
        (Resolve-Path $Path),
        $Text.Replace("`r`n", "`n"),
        $utf8NoBom
    )
}

function Replace-LiteralOnce(
    [string]$Text,
    [string]$Old,
    [string]$New,
    [string]$Label
) {
    $oldLf = $Old.Replace("`r`n", "`n")
    $newLf = $New.Replace("`r`n", "`n")
    $index = $Text.IndexOf($oldLf, [StringComparison]::Ordinal)

    if ($index -lt 0) {
        throw "Port patch failed at '$Label'. Upstream source may have changed."
    }

    return $Text.Substring(0, $index) + $newLf +
        $Text.Substring($index + $oldLf.Length)
}

$SourceDir = (Resolve-Path $SourceDir).Path
$pubspecPath = Join-Path $SourceDir 'pubspec.yaml'
$mainPath = Join-Path $SourceDir 'lib\main.dart'
$audioPath = Join-Path $SourceDir 'lib\services\audio_service.dart'

foreach ($required in @($pubspecPath, $mainPath, $audioPath)) {
    if (-not (Test-Path $required -PathType Leaf)) {
        throw "Required source file not found: $required"
    }
}

Write-Host '[1/5] Adding Windows audio implementations'

$pubspec = Read-Lf $pubspecPath
$pubspec = Replace-LiteralOnce $pubspec @'
  just_audio: ^0.10.6
'@ @'
  just_audio: ^0.10.6
  audio_service_win: ^0.0.3
  just_audio_media_kit: ^2.1.0
  media_kit_libs_windows_audio: ^1.0.9
'@ 'pubspec Windows audio dependencies'
Write-Lf $pubspecPath $pubspec

Write-Host '[2/5] Porting application startup and portable storage'

$main = Read-Lf $mainPath

$main = Replace-LiteralOnce $main @'
import 'dart:async';
'@ @'
import 'dart:async';
import 'dart:io';
'@ 'dart:io import'

$main = Replace-LiteralOnce $main @'
import 'package:hive_flutter/hive_flutter.dart';
'@ @'
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
'@ 'MediaKit import'

$main = Replace-LiteralOnce $main @'
late StreamSubscription<String?> sharingIntentSubscription;
'@ @'
StreamSubscription<String?>? sharingIntentSubscription;
'@ 'nullable sharing-intent subscription'

$main = Replace-LiteralOnce $main @'
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
'@ @'
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
'@ 'mobile SystemChrome guard'

$main = Replace-LiteralOnce $main @'
    sharingIntentSubscription = ReceiveSharingIntent.getTextStream().listen(
      (String? value) async {
        await consumeYoutubeSharedTextIntent(
          value,
          audioHandler: audioHandler,
          onError: (error, stackTrace) {
            logger.log(
              'Error while playing shared song:',
              error: error,
              stackTrace: stackTrace,
            );
          },
        );
      },
      onError: (err) {
        logger.log('getTextStream error:', error: err);
      },
    );
'@ @'
    if (Platform.isAndroid || Platform.isIOS) {
      sharingIntentSubscription = ReceiveSharingIntent.getTextStream().listen(
        (String? value) async {
          await consumeYoutubeSharedTextIntent(
            value,
            audioHandler: audioHandler,
            onError: (error, stackTrace) {
              logger.log(
                'Error while playing shared song:',
                error: error,
                stackTrace: stackTrace,
              );
            },
          );
        },
        onError: (err) {
          logger.log('getTextStream error:', error: err);
        },
      );
    }
'@ 'sharing-intent platform guard'

$main = Replace-LiteralOnce $main @'
    if (!isFdroidBuild) {
'@ @'
    if (!isFdroidBuild && !Platform.isWindows) {
'@ 'disable Android APK updater on Windows'

$main = Replace-LiteralOnce $main @'
    sharingIntentSubscription.cancel();
'@ @'
    sharingIntentSubscription?.cancel();
'@ 'nullable sharing-intent dispose'

$main = Replace-LiteralOnce $main @'
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initialisation();

  runApp(const Musify());
}
'@ @'
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized(
      windows: true,
      linux: false,
    );
  }

  await initialisation();
  runApp(const Musify());
}
'@ 'MediaKit Windows initialization'

$main = Replace-LiteralOnce $main @'
    await Hive.initFlutter();
'@ @'
    if (Platform.isWindows) {
      final executableDirectory =
          Directory(Platform.resolvedExecutable).parent;
      final hiveDirectory = Directory(
        '${executableDirectory.path}${Platform.pathSeparator}'
        'portable-data${Platform.pathSeparator}hive',
      );
      await hiveDirectory.create(recursive: true);
      Hive.init(hiveDirectory.path);
    } else {
      await Hive.initFlutter();
    }
'@ 'portable Hive initialization'

$main = Replace-LiteralOnce $main @'
  applicationDirPath = (await getApplicationDocumentsDirectory()).path;
'@ @'
  if (Platform.isWindows) {
    final executableDirectory = Directory(Platform.resolvedExecutable).parent;
    final portableDirectory = Directory(
      '${executableDirectory.path}${Platform.pathSeparator}portable-data',
    );
    await portableDirectory.create(recursive: true);
    applicationDirPath = portableDirectory.path;
  } else {
    applicationDirPath = (await getApplicationDocumentsDirectory()).path;
  }
'@ 'portable application data directory'

Write-Lf $mainPath $main

Write-Host '[3/5] Porting audio engine and disabling Android-only effects'

$audio = Read-Lf $audioPath

$audio = Replace-LiteralOnce $audio @'
    audioPlayer = AudioPlayer(
      audioPipeline: AudioPipeline(androidAudioEffects: [_androidEqualizer]),
      audioLoadConfiguration: const AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          maxBufferDuration: Duration(seconds: 60),
          bufferForPlaybackDuration: Duration(milliseconds: 500),
          bufferForPlaybackAfterRebufferDuration: Duration(seconds: 3),
        ),
      ),
    );
'@ @'
    if (Platform.isAndroid) {
      audioPlayer = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [_androidEqualizer]),
        audioLoadConfiguration: const AudioLoadConfiguration(
          androidLoadControl: AndroidLoadControl(
            maxBufferDuration: Duration(seconds: 60),
            bufferForPlaybackDuration: Duration(milliseconds: 500),
            bufferForPlaybackAfterRebufferDuration: Duration(seconds: 3),
          ),
        ),
      );
    } else {
      audioPlayer = AudioPlayer();
    }
'@ 'platform-specific AudioPlayer construction'

$audio = Replace-LiteralOnce $audio @'
    audioPlayer.setAndroidAudioAttributes(
      const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
    );
'@ @'
    if (Platform.isAndroid) {
      unawaited(
        audioPlayer.setAndroidAudioAttributes(
          const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
        ),
      );
    }
'@ 'Android audio attributes guard'

$audio = Replace-LiteralOnce $audio @'
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Always set loop mode to off - we handle all repeating through _handleSongCompletion
'@ @'
      if (!Platform.isWindows) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
      }

      // Always set loop mode to off - we handle all repeating through _handleSongCompletion
'@ 'Windows audio-session guard'

$audio = Replace-LiteralOnce $audio @'
      unawaited(_ensureEqualizerConfigured());
'@ @'
      if (Platform.isAndroid) {
        unawaited(_ensureEqualizerConfigured());
      }
'@ 'Android equalizer startup guard'

$audio = Replace-LiteralOnce $audio @'
  Future<bool> _ensureEqualizerConfigured({bool force = false}) async {
    if (_equalizerInitialized) return true;
'@ @'
  Future<bool> _ensureEqualizerConfigured({bool force = false}) async {
    if (!Platform.isAndroid) return false;
    if (_equalizerInitialized) return true;
'@ 'Android equalizer runtime guard'

Write-Lf $audioPath $audio

Write-Host '[4/5] Branding Windows executable'

$cmakePath = Join-Path $SourceDir 'windows\CMakeLists.txt'
$runnerMainPath = Join-Path $SourceDir 'windows\runner\main.cpp'
$runnerRcPath = Join-Path $SourceDir 'windows\runner\Runner.rc'

if (-not (Test-Path $cmakePath)) {
    throw 'Windows runner is missing. Run flutter create --platforms=windows first.'
}

$cmake = Read-Lf $cmakePath
$cmake = Replace-LiteralOnce $cmake @'
set(BINARY_NAME "musify")
'@ @'
set(BINARY_NAME "Musify")
'@ 'Windows executable name'
Write-Lf $cmakePath $cmake

if (Test-Path $runnerMainPath) {
    $runnerMain = Read-Lf $runnerMainPath
    $runnerMain = $runnerMain.Replace('L"musify"', 'L"Musify Portable"')
    Write-Lf $runnerMainPath $runnerMain
}

if (Test-Path $runnerRcPath) {
    $runnerRc = Read-Lf $runnerRcPath
    $runnerRc = $runnerRc.Replace(
        'VALUE "FileDescription", "musify" "\0"',
        'VALUE "FileDescription", "Musify Portable" "\0"'
    )
    $runnerRc = $runnerRc.Replace(
        'VALUE "InternalName", "musify" "\0"',
        'VALUE "InternalName", "Musify" "\0"'
    )
    $runnerRc = $runnerRc.Replace(
        'VALUE "OriginalFilename", "musify.exe" "\0"',
        'VALUE "OriginalFilename", "Musify.exe" "\0"'
    )
    $runnerRc = $runnerRc.Replace(
        'VALUE "ProductName", "musify" "\0"',
        'VALUE "ProductName", "Musify Portable" "\0"'
    )
    Write-Lf $runnerRcPath $runnerRc
}

Write-Host '[5/5] Windows portable source patch complete'
