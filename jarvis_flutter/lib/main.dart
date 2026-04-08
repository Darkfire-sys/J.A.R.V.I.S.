import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:path/path.dart' as p;
import 'package:screen_capturer/screen_capturer.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();
  const options = WindowOptions(
    size: Size(1360, 880),
    center: true,
    backgroundColor: Color(0xFF121417),
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.maximize();
    await windowManager.focus();
  });
  runApp(JarvisApp(startupLaunch: args.contains('--startup')));
}

enum AppThemeMode { light, dark }

enum MessageRole { user, assistant }

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.protocolModeEnabled,
    required this.launchAtLogin,
    required this.startMinimizedToTray,
    required this.closeToTrayEnabled,
    required this.minimizeToTrayEnabled,
    required this.hotkeyId,
  });

  static const defaults = AppSettings(
    themeMode: AppThemeMode.dark,
    protocolModeEnabled: false,
    launchAtLogin: false,
    startMinimizedToTray: false,
    closeToTrayEnabled: true,
    minimizeToTrayEnabled: false,
    hotkeyId: 'ctrl_shift_j',
  );

  final AppThemeMode themeMode;
  final bool protocolModeEnabled;
  final bool launchAtLogin;
  final bool startMinimizedToTray;
  final bool closeToTrayEnabled;
  final bool minimizeToTrayEnabled;
  final String hotkeyId;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? protocolModeEnabled,
    bool? launchAtLogin,
    bool? startMinimizedToTray,
    bool? closeToTrayEnabled,
    bool? minimizeToTrayEnabled,
    String? hotkeyId,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    protocolModeEnabled: protocolModeEnabled ?? this.protocolModeEnabled,
    launchAtLogin: launchAtLogin ?? this.launchAtLogin,
    startMinimizedToTray: startMinimizedToTray ?? this.startMinimizedToTray,
    closeToTrayEnabled: closeToTrayEnabled ?? this.closeToTrayEnabled,
    minimizeToTrayEnabled: minimizeToTrayEnabled ?? this.minimizeToTrayEnabled,
    hotkeyId: hotkeyId ?? this.hotkeyId,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'themeMode': themeMode.name,
    'protocolModeEnabled': protocolModeEnabled,
    'launchAtLogin': launchAtLogin,
    'startMinimizedToTray': startMinimizedToTray,
    'closeToTrayEnabled': closeToTrayEnabled,
    'minimizeToTrayEnabled': minimizeToTrayEnabled,
    'hotkeyId': hotkeyId,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    themeMode: json['themeMode'] == 'light'
        ? AppThemeMode.light
        : AppThemeMode.dark,
    protocolModeEnabled: json['protocolModeEnabled'] as bool? ?? false,
    launchAtLogin: json['launchAtLogin'] as bool? ?? false,
    startMinimizedToTray: json['startMinimizedToTray'] as bool? ?? false,
    closeToTrayEnabled: json['closeToTrayEnabled'] as bool? ?? true,
    minimizeToTrayEnabled: json['minimizeToTrayEnabled'] as bool? ?? false,
    hotkeyId: json['hotkeyId'] as String? ?? 'ctrl_shift_j',
  );
}

class JarvisPalette extends ThemeExtension<JarvisPalette> {
  const JarvisPalette({
    required this.isDark,
    required this.windowBackground,
    required this.windowBackgroundSecondary,
    required this.shell,
    required this.sidebar,
    required this.surface,
    required this.surfaceElevated,
    required this.inputFill,
    required this.overlay,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentMuted,
    required this.accentSoft,
    required this.accentDark,
    required this.success,
    required this.warning,
    required this.userBubble,
    required this.userBubbleBorder,
    required this.assistantBubble,
  });

  final bool isDark;
  final Color windowBackground;
  final Color windowBackgroundSecondary;
  final Color shell;
  final Color sidebar;
  final Color surface;
  final Color surfaceElevated;
  final Color inputFill;
  final Color overlay;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentMuted;
  final Color accentSoft;
  final Color accentDark;
  final Color success;
  final Color warning;
  final Color userBubble;
  final Color userBubbleBorder;
  final Color assistantBubble;

  Color get text => textPrimary;
  Color get muted => textMuted;
  Color get panel => surface;
  Color get panelAlt => surfaceElevated;

  static JarvisPalette dark() => const JarvisPalette(
    isDark: true,
    windowBackground: Color(0xFF0F1115),
    windowBackgroundSecondary: Color(0xFF191C22),
    shell: Color(0xFF14171C),
    sidebar: Color(0xFF191C22),
    surface: Color(0xFF1B2027),
    surfaceElevated: Color(0xFF212730),
    inputFill: Color(0xFF20262E),
    overlay: Color(0xCC171B21),
    border: Color(0xFF2B323E),
    textPrimary: Color(0xFFE8EBF0),
    textSecondary: Color(0xFF929CAA),
    textMuted: Color(0xFF929CAA),
    accent: Color(0xFF8EA8FF),
    accentMuted: Color(0xFF677188),
    accentSoft: Color(0xFF263044),
    accentDark: Color(0xFF2F3B59),
    success: Color(0xFF69D2A8),
    warning: Color(0xFFE9B16D),
    userBubble: Color(0xFF20283A),
    userBubbleBorder: Color(0xFF35405A),
    assistantBubble: Color(0xFF1B2027),
  );

  static JarvisPalette light() => const JarvisPalette(
    isDark: false,
    windowBackground: Color(0xFFE6EBF3),
    windowBackgroundSecondary: Color(0xFFD9E0EC),
    shell: Color(0xFFF5F8FC),
    sidebar: Color(0xFFF0F4F8),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF0F4F8),
    inputFill: Color(0xFFF0F3F8),
    overlay: Color(0xCCEAF0FB),
    border: Color(0xFFD7DEE8),
    textPrimary: Color(0xFF182336),
    textSecondary: Color(0xFF6B7688),
    textMuted: Color(0xFF6B7688),
    accent: Color(0xFF4C69CE),
    accentMuted: Color(0xFF7A8FD4),
    accentSoft: Color(0xFFE6ECFF),
    accentDark: Color(0xFF314C9E),
    success: Color(0xFF3EAF84),
    warning: Color(0xFFD18B35),
    userBubble: Color(0xFFE9EEFF),
    userBubbleBorder: Color(0xFFD1DDFE),
    assistantBubble: Color(0xFFFFFFFF),
  );

  static JarvisPalette protocol() => const JarvisPalette(
    isDark: true,
    windowBackground: Color(0xFF050505),
    windowBackgroundSecondary: Color(0xFF120708),
    shell: Color(0xFF090909),
    sidebar: Color(0xFF100909),
    surface: Color(0xFF130C0C),
    surfaceElevated: Color(0xFF1A1010),
    inputFill: Color(0xFF170D0D),
    overlay: Color(0xCC0F0708),
    border: Color(0xFF3C1517),
    textPrimary: Color(0xFFF7ECEC),
    textSecondary: Color(0xFFC7A5A5),
    textMuted: Color(0xFFC7A5A5),
    accent: Color(0xFFFF4D4D),
    accentMuted: Color(0xFFB76363),
    accentSoft: Color(0xFF2A1012),
    accentDark: Color(0xFF7E1F24),
    success: Color(0xFFFF6A6A),
    warning: Color(0xFFFFA654),
    userBubble: Color(0xFF261014),
    userBubbleBorder: Color(0xFF5B2227),
    assistantBubble: Color(0xFF140D0D),
  );

  @override
  JarvisPalette copyWith({
    bool? isDark,
    Color? windowBackground,
    Color? windowBackgroundSecondary,
    Color? shell,
    Color? sidebar,
    Color? surface,
    Color? surfaceElevated,
    Color? inputFill,
    Color? overlay,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentMuted,
    Color? accentSoft,
    Color? accentDark,
    Color? success,
    Color? warning,
    Color? userBubble,
    Color? userBubbleBorder,
    Color? assistantBubble,
  }) {
    return JarvisPalette(
      isDark: isDark ?? this.isDark,
      windowBackground: windowBackground ?? this.windowBackground,
      windowBackgroundSecondary:
          windowBackgroundSecondary ?? this.windowBackgroundSecondary,
      shell: shell ?? this.shell,
      sidebar: sidebar ?? this.sidebar,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      inputFill: inputFill ?? this.inputFill,
      overlay: overlay ?? this.overlay,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentMuted: accentMuted ?? this.accentMuted,
      accentSoft: accentSoft ?? this.accentSoft,
      accentDark: accentDark ?? this.accentDark,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      userBubble: userBubble ?? this.userBubble,
      userBubbleBorder: userBubbleBorder ?? this.userBubbleBorder,
      assistantBubble: assistantBubble ?? this.assistantBubble,
    );
  }

  @override
  JarvisPalette lerp(ThemeExtension<JarvisPalette>? other, double t) {
    if (other is! JarvisPalette) return this;
    return JarvisPalette(
      isDark: t < 0.5 ? isDark : other.isDark,
      windowBackground: Color.lerp(
        windowBackground,
        other.windowBackground,
        t,
      )!,
      windowBackgroundSecondary: Color.lerp(
        windowBackgroundSecondary,
        other.windowBackgroundSecondary,
        t,
      )!,
      shell: Color.lerp(shell, other.shell, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      userBubbleBorder: Color.lerp(
        userBubbleBorder,
        other.userBubbleBorder,
        t,
      )!,
      assistantBubble: Color.lerp(assistantBubble, other.assistantBubble, t)!,
    );
  }
}

class HotkeyPreset {
  const HotkeyPreset(this.id, this.label, this.shortcut, this.hotKey);
  final String id;
  final String label;
  final String shortcut;
  final HotKey hotKey;
}

final hotkeyPresets = <HotkeyPreset>[
  HotkeyPreset(
    'ctrl_shift_j',
    'Default',
    'Ctrl + Shift + J',
    HotKey(
      key: PhysicalKeyboardKey.keyJ,
      modifiers: <HotKeyModifier>[HotKeyModifier.control, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    ),
  ),
  HotkeyPreset(
    'ctrl_alt_j',
    'Alternate',
    'Ctrl + Alt + J',
    HotKey(
      key: PhysicalKeyboardKey.keyJ,
      modifiers: <HotKeyModifier>[HotKeyModifier.control, HotKeyModifier.alt],
      scope: HotKeyScope.system,
    ),
  ),
  HotkeyPreset(
    'ctrl_shift_space',
    'Quick Summon',
    'Ctrl + Shift + Space',
    HotKey(
      key: PhysicalKeyboardKey.space,
      modifiers: <HotKeyModifier>[HotKeyModifier.control, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    ),
  ),
];

String workspacePath() {
  final candidates = <String>{};

  void addAncestorCandidates(String basePath) {
    var current = Directory(basePath).absolute;
    for (var depth = 0; depth < 8; depth++) {
      candidates.add(p.normalize(p.join(current.path, 'workspace')));
      if (current.parent.path == current.path) break;
      current = current.parent;
    }
  }

  addAncestorCandidates(Directory.current.path);
  addAncestorCandidates(File(Platform.resolvedExecutable).parent.path);

  final existing = candidates
      .where((candidate) => Directory(candidate).existsSync())
      .toList();
  if (existing.isNotEmpty) {
    existing.sort((a, b) {
      int score(String value) {
        final normalized = value.toLowerCase();
        final inBuild =
            normalized.contains(r'\build\') || normalized.contains('/build/');
        return (inBuild ? 100 : 0) + p.split(normalized).length;
      }

      return score(a).compareTo(score(b));
    });
    return existing.first;
  }

  return candidates.isNotEmpty
      ? candidates.first
      : p.normalize(p.join(Directory.current.path, 'workspace'));
}

String settingsFilePath() => p.join(workspacePath(), 'jarvis-settings.json');
String historyFilePath() => p.join(workspacePath(), 'chat-history.json');
String memoryFilePath() => p.join(workspacePath(), 'jarvis-memory.json');
String protocolsFilePath() => p.join(workspacePath(), 'jarvis-protocols.json');
String startupScriptPath() => p.join(
  Platform.environment['APPDATA'] ?? '',
  'Microsoft',
  'Windows',
  'Start Menu',
  'Programs',
  'Startup',
  'Jarvis Startup.cmd',
);

const JsonEncoder _prettyJsonEncoder = JsonEncoder.withIndent('  ');

String _normalizePhrase(String value) {
  final lowered = value.toLowerCase().trim();
  final cleaned = lowered.replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ');
  return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _looksLikeConversationalPrompt(String normalized) {
  if (normalized.isEmpty) return false;
  const conversationalPhrases = <String>{
    'whats up',
    'whats up jarvis',
    'what s up',
    'what s up jarvis',
    'what is up',
    'what is up jarvis',
    'sup',
    'sup jarvis',
    'hello',
    'hello jarvis',
    'hi',
    'hi jarvis',
    'hey',
    'hey jarvis',
    'yo',
    'yo jarvis',
    'how are you',
    'how are you jarvis',
    'hows it going',
    'hows it going jarvis',
    'good morning',
    'good afternoon',
    'good afternoon sir',
    'good afternoon jarvis',
    'good evening',
    'good evening sir',
    'good evening jarvis',
    'good night',
    'good night sir',
    'good night jarvis',
    'hello sir',
    'hi there',
    'hi sir',
    'hey there',
    'hey sir',
    'hello there',
    'hello there jarvis',
  };
  return conversationalPhrases.contains(normalized);
}

class _DesktopAppDefinition {
  const _DesktopAppDefinition({
    required this.id,
    required this.name,
    required this.aliases,
    required this.executableCandidates,
    required this.processNames,
    this.commandCandidates = const <String>[],
    this.launchArguments = const <String>[],
  });

  final String id;
  final String name;
  final List<String> aliases;
  final List<String> executableCandidates;
  final List<String> processNames;
  final List<String> commandCandidates;
  final List<String> launchArguments;

  String? resolveExecutablePath() {
    for (final candidate in executableCandidates) {
      if (File(candidate).existsSync()) return p.normalize(candidate);
    }
    return null;
  }
}

enum _AppActionType { launch, close }

enum _AppActionOutcome {
  launched,
  alreadyRunning,
  closed,
  notRunning,
  missingExecutable,
  unsupportedPlatform,
  failed,
}

class _AppActionResult {
  const _AppActionResult({
    required this.app,
    required this.action,
    required this.outcome,
    this.details,
  });

  final _DesktopAppDefinition app;
  final _AppActionType action;
  final _AppActionOutcome outcome;
  final String? details;
}

enum _ProtocolStepKind { launchApp, closeApp }

class _ProtocolStep {
  const _ProtocolStep({required this.kind, required this.appId});

  final _ProtocolStepKind kind;
  final String appId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': kind == _ProtocolStepKind.launchApp ? 'launchApp' : 'closeApp',
    'appId': appId,
  };

  factory _ProtocolStep.fromJson(Map<String, dynamic> json) => _ProtocolStep(
    kind: (json['type'] as String? ?? '') == 'closeApp'
        ? _ProtocolStepKind.closeApp
        : _ProtocolStepKind.launchApp,
    appId: json['appId'] as String? ?? '',
  );
}

class _ProtocolDefinition {
  const _ProtocolDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.aliases,
    required this.steps,
  });

  final String id;
  final String name;
  final String description;
  final List<String> aliases;
  final List<_ProtocolStep> steps;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'description': description,
    'aliases': aliases,
    'steps': steps.map((step) => step.toJson()).toList(),
  };

  factory _ProtocolDefinition.fromJson(Map<String, dynamic> json) {
    final rawAliases = json['aliases'] as List<dynamic>? ?? const <dynamic>[];
    final rawSteps = json['steps'] as List<dynamic>? ?? const <dynamic>[];
    final name = json['name'] as String? ?? 'Unnamed Protocol';
    return _ProtocolDefinition(
      id: json['id'] as String? ?? _normalizePhrase(name).replaceAll(' ', '_'),
      name: name,
      description: json['description'] as String? ?? '',
      aliases: rawAliases.whereType<String>().toList(),
      steps: rawSteps
          .whereType<Map>()
          .map(
            (step) => _ProtocolStep.fromJson(
              step.map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _LocalCommandOutcome {
  const _LocalCommandOutcome({
    required this.reply,
    required this.status,
    this.recordConversation = true,
    this.startFreshThread = false,
    this.clearAttachments = true,
  });

  final String reply;
  final String status;
  final bool recordConversation;
  final bool startFreshThread;
  final bool clearAttachments;
}

class _PhoneTransferTarget {
  const _PhoneTransferTarget({
    required this.deviceName,
    required this.directoryPath,
    required this.destinationLabel,
  });

  final String deviceName;
  final String directoryPath;
  final String destinationLabel;
}

Map<String, _DesktopAppDefinition> _buildDesktopApps() {
  final apps = <_DesktopAppDefinition>[
    const _DesktopAppDefinition(
      id: 'overwolf_launcher',
      name: 'Overwolf Launcher',
      aliases: <String>['overwolf', 'overwolf launcher'],
      executableCandidates: <String>[
        r'C:\Program Files (x86)\Overwolf\OverwolfLauncher.exe',
        r'C:\Program Files\Overwolf\OverwolfLauncher.exe',
      ],
      processNames: <String>['OverwolfLauncher', 'Overwolf', 'OverwolfBrowser'],
    ),
    const _DesktopAppDefinition(
      id: 'valorant',
      name: 'VALORANT',
      aliases: <String>['valorant', 'valo'],
      executableCandidates: <String>[
        r'C:\Riot Games\Riot Client\RiotClientServices.exe',
        r'C:\Riot Games\VALORANT\live\VALORANT.exe',
      ],
      processNames: <String>[
        'VALORANT',
        'VALORANT-Win64-Shipping',
        'RiotClientServices',
      ],
      launchArguments: <String>[
        '--launch-product=valorant',
        '--launch-patchline=live',
      ],
    ),
    const _DesktopAppDefinition(
      id: 'opera_gx',
      name: 'Opera GX',
      aliases: <String>['opera', 'opera gx', 'opera browser'],
      executableCandidates: <String>[
        r'C:\Users\Biswadeb\AppData\Local\Programs\Opera GX\opera.exe',
        r'C:\Users\Biswadeb\AppData\Local\Programs\Opera GX Stable\opera.exe',
      ],
      processNames: <String>['opera'],
    ),
    const _DesktopAppDefinition(
      id: 'youtube_music',
      name: 'YouTube Music Desktop App',
      aliases: <String>[
        'music',
        'play music',
        'yt music',
        'yt musics',
        'youtube music',
        'youtube music app',
        'youtube music desktop app',
      ],
      executableCandidates: <String>[
        r'C:\Users\Biswadeb\AppData\Local\youtube_music_desktop_app\youtube-music-desktop-app.exe',
        r'C:\Users\Biswadeb\AppData\Local\youtube_music_desktop_app\app-2.0.11\youtube-music-desktop-app.exe',
        r'C:\Users\Biswadeb\AppData\Local\youtube_music_desktop_app\app-2.0.5\youtube-music-desktop-app.exe',
      ],
      processNames: <String>['youtube-music-desktop-app'],
    ),
    const _DesktopAppDefinition(
      id: 'vs_code',
      name: 'VS Code',
      aliases: <String>['vs code', 'vscode', 'visual studio code', 'code'],
      executableCandidates: <String>[
        r'C:\Users\Biswadeb\AppData\Local\Programs\Microsoft VS Code\Code.exe',
        r'C:\Program Files\Microsoft VS Code\Code.exe',
        r'C:\Program Files (x86)\Microsoft VS Code\Code.exe',
      ],
      processNames: <String>['Code'],
      commandCandidates: <String>['code'],
    ),
    const _DesktopAppDefinition(
      id: 'codex',
      name: 'Codex',
      aliases: <String>['codex'],
      executableCandidates: <String>[
        r'C:\Program Files\WindowsApps\OpenAI.Codex_26.325.3894.0_x64__2p2nqsd0c76g0\app\resources\codex.exe',
      ],
      processNames: <String>['Codex', 'codex'],
      commandCandidates: <String>['codex'],
    ),
  ];

  return <String, _DesktopAppDefinition>{for (final app in apps) app.id: app};
}

List<_ProtocolDefinition>
_defaultProtocolDefinitions() => const <_ProtocolDefinition>[
  _ProtocolDefinition(
    id: 'protocol_gaming',
    name: 'Protocol Gaming',
    description:
        'Launches Overwolf Launcher, VALORANT, and YouTube Music Desktop App.',
    aliases: <String>[
      'protocol gaming',
      'activate protocol gaming',
      'run protocol gaming',
      'start protocol gaming',
      'gaming protocol',
    ],
    steps: <_ProtocolStep>[
      _ProtocolStep(
        kind: _ProtocolStepKind.launchApp,
        appId: 'overwolf_launcher',
      ),
      _ProtocolStep(kind: _ProtocolStepKind.launchApp, appId: 'valorant'),
      _ProtocolStep(kind: _ProtocolStepKind.launchApp, appId: 'youtube_music'),
    ],
  ),
  _ProtocolDefinition(
    id: 'protocol_study',
    name: 'Protocol Study',
    description:
        'Closes VALORANT and Overwolf, then opens Opera GX and YouTube Music Desktop App.',
    aliases: <String>[
      'protocol study',
      'activate protocol study',
      'run protocol study',
      'start protocol study',
      'study protocol',
    ],
    steps: <_ProtocolStep>[
      _ProtocolStep(kind: _ProtocolStepKind.closeApp, appId: 'valorant'),
      _ProtocolStep(
        kind: _ProtocolStepKind.closeApp,
        appId: 'overwolf_launcher',
      ),
      _ProtocolStep(kind: _ProtocolStepKind.launchApp, appId: 'opera_gx'),
      _ProtocolStep(kind: _ProtocolStepKind.launchApp, appId: 'youtube_music'),
    ],
  ),
  _ProtocolDefinition(
    id: 'protocol_code',
    name: 'Protocol Code',
    description: 'Opens VS Code, Codex, and Opera GX.',
    aliases: <String>[
      'protocol code',
      'activate protocol code',
      'run protocol code',
      'start protocol code',
      'code protocol',
    ],
    steps: <_ProtocolStep>[
      _ProtocolStep(kind: _ProtocolStepKind.launchApp, appId: 'vs_code'),
      _ProtocolStep(kind: _ProtocolStepKind.launchApp, appId: 'codex'),
      _ProtocolStep(kind: _ProtocolStepKind.launchApp, appId: 'opera_gx'),
    ],
  ),
];

class JarvisApp extends StatefulWidget {
  const JarvisApp({
    super.key,
    required this.startupLaunch,
    this.autoInitialize = true,
  });

  final bool startupLaunch;
  final bool autoInitialize;

  @override
  State<JarvisApp> createState() => _JarvisAppState();
}

class _JarvisAppState extends State<JarvisApp> {
  AppSettings _settings = AppSettings.defaults;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final file = File(settingsFilePath());
    if (!await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString()) as Map;
      if (!mounted) return;
      setState(
        () => _settings = AppSettings.fromJson(
          decoded.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
        ),
      );
    } catch (_) {}
  }

  Future<void> _saveSettings(AppSettings settings) async {
    setState(() => _settings = settings);
    final file = File(settingsFilePath());
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
  }

  @override
  Widget build(BuildContext context) {
    final protocolMode = _settings.protocolModeEnabled;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'J.A.R.V.I.S',
      themeMode: protocolMode
          ? ThemeMode.dark
          : _settings.themeMode == AppThemeMode.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      theme: _buildTheme(JarvisPalette.light(), Brightness.light),
      darkTheme: protocolMode
          ? _buildTheme(JarvisPalette.protocol(), Brightness.dark)
          : _buildTheme(JarvisPalette.dark(), Brightness.dark),
      home: JarvisHomePage(
        autoInitialize: widget.autoInitialize,
        startupLaunch: widget.startupLaunch,
        settings: _settings,
        onSettingsChanged: _saveSettings,
      ),
    );
  }

  ThemeData _buildTheme(JarvisPalette palette, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.accent,
        onPrimary: Colors.white,
        secondary: palette.accent,
        onSecondary: palette.textPrimary,
        error: const Color(0xFFE06A6A),
        onError: Colors.white,
        surface: palette.surface,
        onSurface: palette.textPrimary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.windowBackground,
      dividerColor: palette.border,
      extensions: <ThemeExtension<dynamic>>[palette],
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme)
          .apply(
            bodyColor: palette.textPrimary,
            displayColor: palette.textPrimary,
          )
          .copyWith(
            headlineSmall: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
            titleLarge: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        hintStyle: TextStyle(color: palette.textMuted),
        border: InputBorder.none,
      ),
    );
  }
}

class JarvisHomePage extends StatefulWidget {
  const JarvisHomePage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.startupLaunch,
    this.autoInitialize = true,
  });

  final AppSettings settings;
  final Future<void> Function(AppSettings settings) onSettingsChanged;
  final bool startupLaunch;
  final bool autoInitialize;

  @override
  State<JarvisHomePage> createState() => _JarvisHomePageState();
}

class _JarvisHomePageState extends State<JarvisHomePage>
    with TrayListener, WindowListener {
  final _backend = _JarvisBackendClient();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<_ConversationThread> _threads = <_ConversationThread>[];
  final List<_AttachmentItem> _attachments = <_AttachmentItem>[];
  final Map<String, _DesktopAppDefinition> _desktopApps = _buildDesktopApps();
  List<_ProtocolDefinition> _protocols = _defaultProtocolDefinitions();
  DateTime _now = DateTime.now();
  Timer? _clockRefreshTimer;

  String? _activeThreadId;
  bool _backendReady = false;
  bool _isThinking = false;
  bool _isDragging = false;
  bool _stopRequested = false;
  bool _quitting = false;
  String _status = 'Core systems waking up';

  bool get _protocolMode => widget.settings.protocolModeEnabled;
  bool get _dark =>
      _protocolMode || widget.settings.themeMode == AppThemeMode.dark;
  Color get _bg => _protocolMode
      ? const Color(0xFF050505)
      : _dark
      ? const Color(0xFF0F1115)
      : const Color(0xFFE6EBF3);
  Color get _bgAlt => _protocolMode
      ? const Color(0xFF120708)
      : _dark
      ? const Color(0xFF191C22)
      : const Color(0xFFD9E0EC);
  Color get _shell => _protocolMode
      ? const Color(0xFF090909)
      : _dark
      ? const Color(0xFF14171C)
      : const Color(0xFFF5F8FC);
  Color get _panel => _protocolMode
      ? const Color(0xFF130C0C)
      : _dark
      ? const Color(0xFF1B2027)
      : const Color(0xFFFFFFFF);
  Color get _panelAlt => _protocolMode
      ? const Color(0xFF1A1010)
      : _dark
      ? const Color(0xFF212730)
      : const Color(0xFFF0F4F8);
  Color get _border => _protocolMode
      ? const Color(0xFF3C1517)
      : _dark
      ? const Color(0xFF2B323E)
      : const Color(0xFFD7DEE8);
  Color get _text => _protocolMode
      ? const Color(0xFFF7ECEC)
      : _dark
      ? const Color(0xFFE8EBF0)
      : const Color(0xFF182336);
  Color get _muted => _protocolMode
      ? const Color(0xFFC7A5A5)
      : _dark
      ? const Color(0xFF929CAA)
      : const Color(0xFF6B7688);
  Color get _accent => _protocolMode
      ? const Color(0xFFFF4D4D)
      : _dark
      ? const Color(0xFF8EA8FF)
      : const Color(0xFF4C69CE);
  Color get _accentSoft => _protocolMode
      ? const Color(0xFF2A1012)
      : _dark
      ? const Color(0xFF263044)
      : const Color(0xFFE6ECFF);

  _ConversationThread? get _activeThread {
    for (final thread in _threads) {
      if (thread.id == _activeThreadId) return thread;
    }
    return _threads.isNotEmpty ? _threads.first : null;
  }

  List<_ChatMessage> get _activeMessages =>
      _activeThread?.messages ?? const <_ChatMessage>[];

  @override
  void initState() {
    super.initState();
    _startClockRefresh();
    if (widget.autoInitialize) {
      unawaited(_initialize());
    } else {
      _selectOrCreateThread();
    }
  }

  @override
  void didUpdateWidget(covariant JarvisHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      unawaited(_applySettingSideEffects(oldWidget.settings, widget.settings));
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    unawaited(hotKeyManager.unregisterAll());
    _clockRefreshTimer?.cancel();
    _backend.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _startClockRefresh() {
    _clockRefreshTimer?.cancel();
    _clockRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  Future<void> _initialize() async {
    windowManager.addListener(this);
    trayManager.addListener(this);
    await windowManager.setPreventClose(true);
    await _configureTray();
    await _registerHotkey();
    await _syncStartupScript(widget.settings);
    await _loadHistory();
    await _loadProtocolDefinitions();
    final ready = await _backend.ensureBackendRunning();
    if (!mounted) return;
    setState(() {
      _backendReady = ready;
      _status = ready ? 'J.A.R.V.I.S online' : 'Backend unavailable';
    });
    _selectOrCreateThread();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    });
    if (widget.startupLaunch && widget.settings.startMinimizedToTray) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _hideToTray(updateStatus: false);
    }
  }

  Future<void> _applySettingSideEffects(
    AppSettings previous,
    AppSettings current,
  ) async {
    if (previous.hotkeyId != current.hotkeyId) {
      await _registerHotkey();
    }
    if (previous.launchAtLogin != current.launchAtLogin) {
      await _syncStartupScript(current);
    }
    if (previous.closeToTrayEnabled != current.closeToTrayEnabled ||
        previous.minimizeToTrayEnabled != current.minimizeToTrayEnabled) {
      await _configureTray();
    }
  }

  Future<void> _configureTray() async {
    final iconCandidates = <String>[
      p.join(
        Directory.current.path,
        'windows',
        'runner',
        'resources',
        'app_icon.ico',
      ),
      p.join(
        Directory.current.path,
        'jarvis_flutter',
        'windows',
        'runner',
        'resources',
        'app_icon.ico',
      ),
    ];
    for (final candidate in iconCandidates) {
      if (File(candidate).existsSync()) {
        await trayManager.setIcon(candidate);
        break;
      }
    }
    await trayManager.setToolTip('J.A.R.V.I.S');
    await trayManager.setContextMenu(
      Menu(
        items: <MenuItem>[
          MenuItem(key: 'show', label: 'Show J.A.R.V.I.S'),
          MenuItem(key: 'capture', label: 'Capture Screenshot'),
          MenuItem.separator(),
          MenuItem(
            key: 'toggle_close',
            label: widget.settings.closeToTrayEnabled
                ? 'Disable Close To Tray'
                : 'Enable Close To Tray',
          ),
          MenuItem(
            key: 'toggle_minimize',
            label: widget.settings.minimizeToTrayEnabled
                ? 'Disable Minimize To Tray'
                : 'Enable Minimize To Tray',
          ),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: 'Exit J.A.R.V.I.S'),
        ],
      ),
    );
  }

  Future<void> _registerHotkey() async {
    await hotKeyManager.unregisterAll();
    final preset = hotkeyPresets.firstWhere(
      (item) => item.id == widget.settings.hotkeyId,
      orElse: () => hotkeyPresets.first,
    );
    await hotKeyManager.register(
      preset.hotKey,
      keyDownHandler: (_) async => _showWindow(),
    );
  }

  Future<void> _syncStartupScript(AppSettings settings) async {
    final file = File(startupScriptPath());
    if (!settings.launchAtLogin) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final exe = Platform.resolvedExecutable.replaceAll('"', '""');
    await file.writeAsString(
      '@echo off\r\nstart "" "$exe" --startup\r\n',
      flush: true,
    );
  }

  Future<void> _hideToTray({bool updateStatus = true}) async {
    await windowManager.hide();
    if (!mounted || !updateStatus) return;
    final hotkey = hotkeyPresets
        .firstWhere(
          (item) => item.id == widget.settings.hotkeyId,
          orElse: () => hotkeyPresets.first,
        )
        .shortcut;
    setState(
      () => _status =
          'J.A.R.V.I.S moved to tray. Press $hotkey to bring it back.',
    );
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.restore();
    await windowManager.maximize();
    await windowManager.focus();
    if (mounted) setState(() => _status = 'J.A.R.V.I.S online');
  }

  Future<void> _loadHistory() async {
    final file = File(historyFilePath());
    if (!await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        final threads = decoded['threads'] as List<dynamic>? ?? <dynamic>[];
        _threads
          ..clear()
          ..addAll(
            threads.whereType<Map>().map(
              (item) => _ConversationThread.fromJson(
                item.map(
                  (dynamic key, dynamic value) =>
                      MapEntry(key.toString(), value),
                ),
              ),
            ),
          );
        _activeThreadId = decoded['activeThreadId'] as String?;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Saved history could not be restored');
      }
    }
  }

  Future<_JarvisMemory> _loadMemory() async {
    final file = File(memoryFilePath());
    if (!await file.exists()) return _JarvisMemory.defaults();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return _JarvisMemory.fromJson(decoded);
      }
      if (decoded is Map) {
        return _JarvisMemory.fromJson(
          decoded.map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          ),
        );
      }
    } catch (_) {}
    return _JarvisMemory.defaults();
  }

  Future<void> _persistHistory() async {
    final file = File(historyFilePath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, dynamic>{
        'activeThreadId': _activeThreadId,
        'threads': _threads.map((thread) => thread.toJson()).toList(),
      }),
      flush: true,
    );
  }

  void _createThread({required bool select}) {
    final now = DateTime.now();
    final thread = _ConversationThread(
      id: now.microsecondsSinceEpoch.toString(),
      title: 'New thread',
      updatedAt: now,
      messages: <_ChatMessage>[],
    );
    _threads.insert(0, thread);
    if (select) _activeThreadId = thread.id;
  }

  void _selectOrCreateThread() {
    for (final thread in _threads) {
      if (thread.messages.isEmpty) {
        _activeThreadId = thread.id;
        return;
      }
    }

    _createThread(select: true);
  }

  Future<void> _clearHistory() async {
    setState(() {
      _threads.clear();
      _activeThreadId = null;
      _selectOrCreateThread();
      _status = 'Conversation history cleared';
    });
    final file = File(historyFilePath());
    if (await file.exists()) await file.delete();
  }

  List<Map<String, dynamic>> _buildRecentContext({int maxMessages = 8}) {
    final thread = _activeThread;
    if (thread == null || thread.messages.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final history = thread.messages
        .where((message) => !message.isStreaming)
        .map(
          (message) => <String, dynamic>{
            'role': message.role.name,
            'text': message.text,
          },
        )
        .toList();

    if (history.length <= maxMessages) {
      return history;
    }

    return history.sublist(history.length - maxMessages);
  }

  Future<void> _captureScreenshot() async {
    final dir = Directory(p.join(workspacePath(), 'screenshots'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final imagePath = p.join(dir.path, 'jarvis-shot-${_timestamp()}.png');
    final captured = await screenCapturer.capture(
      mode: CaptureMode.region,
      imagePath: imagePath,
      copyToClipboard: false,
      silent: true,
    );
    if (captured?.imagePath != null) {
      await _addAttachments(<String>[captured!.imagePath!]);
      if (mounted) setState(() => _status = 'Screenshot attached');
    }
  }

  Future<void> _pickAttachments() async {
    const group = XTypeGroup(
      label: 'Files',
      extensions: <String>[
        'txt',
        'md',
        'html',
        'csv',
        'json',
        'py',
        'png',
        'jpg',
        'jpeg',
        'webp',
        'bmp',
        'gif',
        'pdf',
        'docx',
      ],
    );
    final files = await openFiles(acceptedTypeGroups: <XTypeGroup>[group]);
    if (files.isEmpty) return;
    await _addAttachments(files.map((file) => file.path));
    if (mounted) setState(() => _status = 'Attachments ready');
  }

  Future<void> _addAttachments(Iterable<String> paths) async {
    final existing = _attachments.map((item) => item.path).toSet();
    final next = <_AttachmentItem>[];
    for (final pathValue in paths) {
      if (existing.contains(pathValue)) continue;
      final ext = p.extension(pathValue).toLowerCase();
      final isImage = <String>{
        '.png',
        '.jpg',
        '.jpeg',
        '.webp',
        '.bmp',
        '.gif',
      }.contains(ext);
      final file = File(pathValue);
      next.add(
        _AttachmentItem(
          path: pathValue,
          name: p.basename(pathValue),
          isImage: isImage,
          sizeBytes: await file.exists() ? await file.length() : 0,
        ),
      );
      existing.add(pathValue);
    }
    if (mounted && next.isNotEmpty) {
      setState(() => _attachments.addAll(next));
    }
  }

  Future<List<_ProtocolDefinition>> _loadProtocolDefinitions() async {
    final file = File(protocolsFilePath());
    final defaults = _defaultProtocolDefinitions();
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        _prettyJsonEncoder.convert(<String, dynamic>{
          'protocols': defaults.map((protocol) => protocol.toJson()).toList(),
        }),
        flush: true,
      );
      _protocols = defaults;
      return defaults;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      final rawProtocols = decoded is Map<String, dynamic>
          ? decoded['protocols'] as List<dynamic>? ?? <dynamic>[]
          : decoded is Map
          ? decoded['protocols'] as List<dynamic>? ?? <dynamic>[]
          : decoded is List<dynamic>
          ? decoded
          : <dynamic>[];
      final parsed = rawProtocols
          .whereType<Map>()
          .map(
            (item) => _ProtocolDefinition.fromJson(
              item.map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            ),
          )
          .where((protocol) => protocol.steps.isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) {
        _protocols = parsed;
        return parsed;
      }
    } catch (_) {}

    _protocols = defaults;
    return defaults;
  }

  Future<_LocalCommandOutcome?> _tryHandleLocalCommand(String text) async {
    final normalized = _normalizePhrase(text);
    if (normalized.isEmpty) return null;
    if (_looksLikeConversationalPrompt(normalized)) return null;

    await _loadProtocolDefinitions();

    if (_matchesPhrase(normalized, const <String>[
      'activate protocol mode',
      'engage protocol mode',
      'protocol mode',
      'enable protocol mode',
      'protocol mode on',
      'turn on protocol mode',
      'start protocol mode',
      'activate prtcl mode',
      'engage prtcl mode',
      'start prtcl mode',
      'prtcl mode',
      'prtclmd',
    ])) {
      if (!_protocolMode) {
        await _saveSettingsAndApply(
          widget.settings.copyWith(protocolModeEnabled: true),
          statusMessage: 'Protocol Mode engaged',
        );
      }
      return const _LocalCommandOutcome(
        reply: '',
        status: 'Protocol Mode engaged',
        recordConversation: false,
        startFreshThread: true,
      );
    }

    if (_matchesPhrase(normalized, const <String>[
      'deactivate protocol mode',
      'disable protocol mode',
      'protocol mode off',
      'turn off protocol mode',
      'exit protocol mode',
    ])) {
      if (_protocolMode) {
        await _saveSettingsAndApply(
          widget.settings.copyWith(protocolModeEnabled: false),
          statusMessage: 'Protocol Mode disengaged',
        );
      }
      return const _LocalCommandOutcome(
        reply:
            'Protocol Mode disengaged.\n\nJ.A.R.V.I.S is back on the standard deck.',
        status: 'Protocol Mode disengaged',
      );
    }

    if (_matchesPhrase(normalized, const <String>[
      'send these files to my phone',
      'send this file to my phone',
      'send these to my phone',
      'send this to my phone',
      'send attached files to my phone',
      'send the attached files to my phone',
      'send attachments to my phone',
      'send these attachments to my phone',
      'transfer these files to my phone',
      'transfer this file to my phone',
      'transfer these to my phone',
      'transfer this to my phone',
      'transfer attached files to my phone',
      'transfer the attached files to my phone',
      'send these files to phone',
      'transfer these files to phone',
    ])) {
      return _sendAttachmentsToPhone();
    }

    final protocol = _matchProtocol(normalized);
    if (protocol != null) {
      final results = <String>[];
      for (final step in protocol.steps) {
        final actionResult = await _performAppAction(
          step.appId,
          step.kind == _ProtocolStepKind.launchApp
              ? _AppActionType.launch
              : _AppActionType.close,
        );
        results.add(_describeActionResult(actionResult));
      }
      return _LocalCommandOutcome(
        reply: '${protocol.name} engaged.\n\n${results.join('\n')}',
        status: '${protocol.name} complete',
      );
    }

    if (_matchesPhrase(normalized, const <String>[
      'play music',
      'open yt music',
      'open yt musics',
      'open youtube music',
      'launch youtube music',
      'open youtube music desktop app',
    ])) {
      final result = await _performAppAction(
        'youtube_music',
        _AppActionType.launch,
      );
      return _LocalCommandOutcome(
        reply: _describeActionResult(result),
        status: 'Music command executed',
      );
    }

    final openTarget = _extractCommandTarget(normalized, const <String>[
      'open ',
      'launch ',
      'start ',
      'run ',
    ]);
    if (openTarget != null) {
      final app = _findAppByAlias(openTarget);
      if (app != null) {
        final result = await _performAppAction(app.id, _AppActionType.launch);
        return _LocalCommandOutcome(
          reply: _describeActionResult(result),
          status: '${app.name} command executed',
        );
      }
    }

    final closeTarget = _extractCommandTarget(normalized, const <String>[
      'close ',
      'quit ',
      'exit ',
      'stop ',
    ]);
    if (closeTarget != null) {
      final app = _findAppByAlias(closeTarget);
      if (app != null) {
        final result = await _performAppAction(app.id, _AppActionType.close);
        return _LocalCommandOutcome(
          reply: _describeActionResult(result),
          status: '${app.name} command executed',
        );
      }
    }

    return null;
  }

  Future<_LocalCommandOutcome> _sendAttachmentsToPhone() async {
    final attachments = List<_AttachmentItem>.from(_attachments);
    if (attachments.isEmpty) {
      return const _LocalCommandOutcome(
        reply:
            'Sir, attach one or more files first, then say "send these files to my phone."',
        status: 'No phone transfer attachments',
        clearAttachments: false,
      );
    }

    final target = await _resolvePhoneTransferTarget();
    if (target == null) {
      return const _LocalCommandOutcome(
        reply:
            'Sir, I could not find your linked phone in Windows right now. Make sure Phone Link file access is available, then try again.',
        status: 'Phone not available',
        clearAttachments: false,
      );
    }

    final copiedNames = <String>[];
    final failedNames = <String>[];
    for (final attachment in attachments) {
      final source = File(attachment.path);
      if (!source.existsSync()) {
        failedNames.add('${attachment.name} (missing on PC)');
        continue;
      }

      try {
        final destinationPath = await _buildUniquePhoneFilePath(
          target.directoryPath,
          attachment.name,
        );
        await source.copy(destinationPath);
        copiedNames.add(p.basename(destinationPath));
      } catch (error) {
        failedNames.add('${attachment.name} (${error.toString()})');
      }
    }

    if (copiedNames.isEmpty) {
      final details = failedNames.isEmpty
          ? ''
          : '\n\n${failedNames.join('\n')}';
      return _LocalCommandOutcome(
        reply:
            'Sir, I could not send the attached files to ${target.deviceName}.$details',
        status: 'Phone transfer failed',
        clearAttachments: false,
      );
    }

    final sentSummary = copiedNames.length == 1
        ? 'Sir, sent 1 file to ${target.deviceName}.'
        : 'Sir, sent ${copiedNames.length} files to ${target.deviceName}.';
    final fileList = copiedNames.take(3).join('\n');
    final moreCount = copiedNames.length - 3;
    final copiedBlock = fileList.isEmpty
        ? ''
        : '\n\n$fileList${moreCount > 0 ? '\n+ $moreCount more' : ''}';
    final failedBlock = failedNames.isEmpty
        ? ''
        : '\n\nSome files could not be copied:\n${failedNames.join('\n')}';
    return _LocalCommandOutcome(
      reply:
          '$sentSummary\n\nDestination: ${target.destinationLabel}.$copiedBlock$failedBlock',
      status: failedNames.isEmpty
          ? 'Phone transfer complete'
          : 'Phone transfer partially complete',
      clearAttachments: failedNames.isEmpty,
    );
  }

  Future<void> _recordLocalCommand(
    String userText,
    _LocalCommandOutcome outcome,
  ) async {
    if (outcome.startFreshThread) {
      setState(() {
        _createThread(select: true);
      });
    } else if (_activeThread == null) {
      _createThread(select: true);
    }

    if (!outcome.recordConversation) {
      if (mounted) {
        setState(() {
          if (outcome.clearAttachments) {
            _attachments.clear();
          }
          _inputController.clear();
          _status = outcome.status;
        });
      }
      await _persistHistory();
      _scrollToBottom();
      return;
    }

    final now = DateTime.now();
    final currentAttachments = List<_AttachmentItem>.from(_attachments);
    _appendToActive(
      _ChatMessage(
        role: MessageRole.user,
        text: userText,
        createdAt: now,
        attachments: currentAttachments,
      ),
    );
    _appendToActive(
      _ChatMessage(
        role: MessageRole.assistant,
        text: outcome.reply,
        createdAt: DateTime.now(),
      ),
    );
    _renameThread(userText);
    if (mounted) {
      setState(() {
        if (outcome.clearAttachments) {
          _attachments.clear();
        }
        _inputController.clear();
        _status = outcome.status;
      });
    }
    await _persistHistory();
    _scrollToBottom();
  }

  bool _matchesPhrase(String normalized, List<String> candidates) =>
      candidates.any((candidate) => normalized == _normalizePhrase(candidate));

  _ProtocolDefinition? _matchProtocol(String normalized) {
    for (final protocol in _protocols) {
      for (final alias in protocol.aliases) {
        if (normalized == _normalizePhrase(alias)) {
          return protocol;
        }
      }
    }
    return null;
  }

  String? _extractCommandTarget(String normalized, List<String> prefixes) {
    for (final prefix in prefixes) {
      if (normalized.startsWith(prefix)) {
        return normalized.substring(prefix.length).trim();
      }
    }
    return null;
  }

  _DesktopAppDefinition? _findAppByAlias(String target) {
    final normalizedTarget = _normalizePhrase(target);
    final candidates = <String>{
      normalizedTarget,
      if (normalizedTarget.startsWith('the '))
        normalizedTarget.substring(4).trim(),
    };
    for (final app in _desktopApps.values) {
      final aliases = app.aliases.map(_normalizePhrase).toSet();
      if (candidates.any(aliases.contains)) return app;
    }
    return null;
  }

  Future<_PhoneTransferTarget?> _resolvePhoneTransferTarget() async {
    if (!Platform.isWindows) return null;

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null || userProfile.trim().isEmpty) return null;

    final crossDeviceRoot = Directory(p.join(userProfile, 'CrossDevice'));
    if (!crossDeviceRoot.existsSync()) return null;

    final phoneDirectories =
        crossDeviceRoot
            .listSync()
            .whereType<Directory>()
            .where(
              (directory) =>
                  Directory(p.join(directory.path, 'storage')).existsSync(),
            )
            .toList()
          ..sort((a, b) {
            DateTime modified(Directory directory) {
              try {
                return directory.statSync().modified;
              } catch (_) {
                return DateTime.fromMillisecondsSinceEpoch(0);
              }
            }

            return modified(b).compareTo(modified(a));
          });

    for (final phoneDirectory in phoneDirectories) {
      final receivedPath = p.join(
        phoneDirectory.path,
        'storage',
        'Download',
        'Received from PC',
      );
      final downloadPath = p.join(phoneDirectory.path, 'storage', 'Download');
      final storagePath = p.join(phoneDirectory.path, 'storage');

      final receivedDir = Directory(receivedPath);
      if (receivedDir.existsSync()) {
        return _PhoneTransferTarget(
          deviceName: p.basename(phoneDirectory.path),
          directoryPath: receivedPath,
          destinationLabel: 'Download > Received from PC',
        );
      }

      final downloadDir = Directory(downloadPath);
      if (downloadDir.existsSync()) {
        try {
          await receivedDir.create(recursive: true);
          return _PhoneTransferTarget(
            deviceName: p.basename(phoneDirectory.path),
            directoryPath: receivedPath,
            destinationLabel: 'Download > Received from PC',
          );
        } catch (_) {
          return _PhoneTransferTarget(
            deviceName: p.basename(phoneDirectory.path),
            directoryPath: downloadPath,
            destinationLabel: 'Download',
          );
        }
      }

      final storageDir = Directory(storagePath);
      if (storageDir.existsSync()) {
        return _PhoneTransferTarget(
          deviceName: p.basename(phoneDirectory.path),
          directoryPath: storagePath,
          destinationLabel: 'storage',
        );
      }
    }

    return null;
  }

  Future<String> _buildUniquePhoneFilePath(
    String directoryPath,
    String fileName,
  ) async {
    final sanitizedName = fileName.trim().isEmpty
        ? 'attachment'
        : fileName.trim();
    final extension = p.extension(sanitizedName);
    final baseName = extension.isEmpty
        ? sanitizedName
        : sanitizedName.substring(0, sanitizedName.length - extension.length);

    var candidate = p.join(directoryPath, sanitizedName);
    var counter = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(directoryPath, '$baseName ($counter)$extension');
      counter++;
    }
    return candidate;
  }

  Future<_AppActionResult> _performAppAction(
    String appId,
    _AppActionType action,
  ) async {
    final app = _desktopApps[appId];
    if (app == null) {
      return _AppActionResult(
        app: _DesktopAppDefinition(
          id: appId,
          name: appId,
          aliases: const <String>[],
          executableCandidates: const <String>[],
          processNames: const <String>[],
        ),
        action: action,
        outcome: _AppActionOutcome.failed,
        details: 'Unknown app id: $appId',
      );
    }

    if (!Platform.isWindows) {
      return _AppActionResult(
        app: app,
        action: action,
        outcome: _AppActionOutcome.unsupportedPlatform,
      );
    }

    return action == _AppActionType.launch ? _launchApp(app) : _closeApp(app);
  }

  Future<_AppActionResult> _launchApp(_DesktopAppDefinition app) async {
    final executable = await _resolveAppExecutable(app);
    if (executable == null) {
      return _AppActionResult(
        app: app,
        action: _AppActionType.launch,
        outcome: _AppActionOutcome.missingExecutable,
      );
    }

    final running = await _runningProcessNames(app);
    if (running.isNotEmpty) {
      return _AppActionResult(
        app: app,
        action: _AppActionType.launch,
        outcome: _AppActionOutcome.alreadyRunning,
      );
    }

    try {
      await Process.start(
        executable,
        app.launchArguments,
        workingDirectory: p.dirname(executable),
        runInShell: true,
      );
      return _AppActionResult(
        app: app,
        action: _AppActionType.launch,
        outcome: _AppActionOutcome.launched,
      );
    } catch (error) {
      return _AppActionResult(
        app: app,
        action: _AppActionType.launch,
        outcome: _AppActionOutcome.failed,
        details: error.toString(),
      );
    }
  }

  Future<String?> _resolveAppExecutable(_DesktopAppDefinition app) async {
    final directPath = app.resolveExecutablePath();
    if (directPath != null) return directPath;

    for (final command in app.commandCandidates) {
      final resolved = await _resolveExecutableOnPath(command);
      if (resolved != null) return resolved;
    }

    return null;
  }

  Future<String?> _resolveExecutableOnPath(String name) async {
    try {
      final result = await Process.run('where', <String>[
        name,
      ], runInShell: true);
      if (result.exitCode != 0) return null;

      final output = result.stdout?.toString() ?? '';
      for (final line in const LineSplitter().convert(output)) {
        final candidate = line.trim();
        if (candidate.isEmpty) continue;
        if (File(candidate).existsSync()) return candidate;
      }
    } catch (_) {}
    return null;
  }

  Future<_AppActionResult> _closeApp(_DesktopAppDefinition app) async {
    final running = await _runningProcessNames(app);
    if (running.isEmpty) {
      return _AppActionResult(
        app: app,
        action: _AppActionType.close,
        outcome: _AppActionOutcome.notRunning,
      );
    }

    final names = app.processNames
        .map((name) => "'${name.replaceAll("'", "''").toLowerCase()}'")
        .join(',');
    final script =
        '''
\$names = @($names)
\$targets = Get-Process -ErrorAction SilentlyContinue | Where-Object { \$names -contains \$_.ProcessName.ToLower() }
if (-not \$targets) { exit 3 }
\$targets | Stop-Process -Force
\$targets | Select-Object -ExpandProperty ProcessName
''';
    try {
      final result = await Process.run('powershell', <String>[
        '-NoProfile',
        '-Command',
        script,
      ], runInShell: true);
      if (result.exitCode == 0) {
        return _AppActionResult(
          app: app,
          action: _AppActionType.close,
          outcome: _AppActionOutcome.closed,
        );
      }
      return _AppActionResult(
        app: app,
        action: _AppActionType.close,
        outcome: _AppActionOutcome.failed,
        details: result.stderr?.toString().trim(),
      );
    } catch (error) {
      return _AppActionResult(
        app: app,
        action: _AppActionType.close,
        outcome: _AppActionOutcome.failed,
        details: error.toString(),
      );
    }
  }

  Future<List<String>> _runningProcessNames(_DesktopAppDefinition app) async {
    if (!Platform.isWindows || app.processNames.isEmpty) return <String>[];
    final names = app.processNames
        .map((name) => "'${name.replaceAll("'", "''").toLowerCase()}'")
        .join(',');
    final script =
        '''
\$names = @($names)
Get-Process -ErrorAction SilentlyContinue |
  Where-Object { \$names -contains \$_.ProcessName.ToLower() } |
  Select-Object -ExpandProperty ProcessName
''';
    try {
      final result = await Process.run('powershell', <String>[
        '-NoProfile',
        '-Command',
        script,
      ], runInShell: true);
      if (result.exitCode != 0) return <String>[];
      return const LineSplitter()
          .convert(result.stdout?.toString() ?? '')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    } catch (_) {
      return <String>[];
    }
  }

  String _describeActionResult(_AppActionResult result) {
    switch (result.outcome) {
      case _AppActionOutcome.launched:
        return 'Launched ${result.app.name}.';
      case _AppActionOutcome.alreadyRunning:
        return '${result.app.name} was already open.';
      case _AppActionOutcome.closed:
        return 'Closed ${result.app.name}.';
      case _AppActionOutcome.notRunning:
        return '${result.app.name} was already closed.';
      case _AppActionOutcome.missingExecutable:
        return 'I could not find ${result.app.name} on this PC.';
      case _AppActionOutcome.unsupportedPlatform:
        return '${result.app.name} control is only available on Windows.';
      case _AppActionOutcome.failed:
        return result.details == null || result.details!.isEmpty
            ? 'I could not ${result.action == _AppActionType.launch ? 'launch' : 'close'} ${result.app.name}.'
            : 'I could not ${result.action == _AppActionType.launch ? 'launch' : 'close'} ${result.app.name}.\nDetails: ${result.details}';
    }
  }

  Future<void> _saveSettingsAndApply(
    AppSettings next, {
    String statusMessage = 'Settings updated',
  }) async {
    await widget.onSettingsChanged(next);
    if (!mounted) return;
    setState(() => _status = statusMessage);
  }

  Future<void> _toggleTheme() async {
    if (_protocolMode) {
      await _saveSettingsAndApply(
        widget.settings.copyWith(protocolModeEnabled: false),
        statusMessage: 'Protocol Mode disengaged',
      );
      return;
    }
    await _saveSettingsAndApply(
      widget.settings.copyWith(
        themeMode: _dark ? AppThemeMode.light : AppThemeMode.dark,
      ),
      statusMessage: _dark ? 'Light mode engaged' : 'Dark mode engaged',
    );
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if ((text.isEmpty && _attachments.isEmpty) || _isThinking) return;
    final localOutcome = await _tryHandleLocalCommand(text);
    if (localOutcome != null) {
      await _recordLocalCommand(
        text.isEmpty ? '[Sent with attachments]' : text,
        localOutcome,
      );
      return;
    }
    if (_activeThread == null) _createThread(select: true);
    final recentContext = _buildRecentContext();
    final memory = await _loadMemory();
    final userAttachments = List<_AttachmentItem>.from(_attachments);
    _appendToActive(
      _ChatMessage(
        role: MessageRole.user,
        text: text.isEmpty ? '[Sent with attachments]' : text,
        createdAt: DateTime.now(),
        attachments: userAttachments,
      ),
    );
    _appendToActive(
      _ChatMessage(
        role: MessageRole.assistant,
        text: 'Thinking, sir...',
        createdAt: DateTime.now(),
        isStreaming: true,
      ),
    );
    _renameThread(text);
    setState(() {
      _attachments.clear();
      _inputController.clear();
      _isThinking = true;
      _stopRequested = false;
      _status = 'Streaming response';
    });
    unawaited(_persistHistory());
    _scrollToBottom();
    try {
      await _backend.streamAsk(
        message: text,
        attachments: userAttachments,
        context: recentContext,
        memory: memory,
        onToken: (String token) {
          if (!mounted || _activeMessages.isEmpty) return;
          setState(() {
            final last = _activeMessages.last;
            _replaceLastActive(
              last.copyWith(
                text: last.text == 'Thinking, sir...'
                    ? token
                    : last.text + token,
              ),
            );
          });
        },
      );
      if (mounted && _activeMessages.isNotEmpty) {
        setState(() {
          _replaceLastActive(_activeMessages.last.copyWith(isStreaming: false));
          _isThinking = false;
          _backendReady = true;
          _status = 'Ready for your next command';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _removeLastActive();
          _appendToActive(
            _ChatMessage(
              role: MessageRole.assistant,
              text: _stopRequested
                  ? 'Stopped, sir.'
                  : 'Sir, the stream failed.\n\nDetails: $error',
              createdAt: DateTime.now(),
            ),
          );
          _isThinking = false;
          _status = _stopRequested ? 'Generation stopped' : 'Response failed';
        });
      }
    }
    unawaited(_persistHistory());
    _scrollToBottom();
  }

  Future<void> _stopGeneration() async {
    _stopRequested = true;
    _backend.cancelActiveStream();
    if (mounted) setState(() => _isThinking = false);
  }

  void _appendToActive(_ChatMessage message) {
    final thread = _activeThread;
    if (thread == null) return;
    final next = List<_ChatMessage>.from(thread.messages)..add(message);
    _replaceThread(
      thread.copyWith(messages: next, updatedAt: message.createdAt),
    );
  }

  void _replaceLastActive(_ChatMessage message) {
    final thread = _activeThread;
    if (thread == null || thread.messages.isEmpty) return;
    final next = List<_ChatMessage>.from(thread.messages);
    next[next.length - 1] = message;
    _replaceThread(
      thread.copyWith(messages: next, updatedAt: message.createdAt),
    );
  }

  void _removeLastActive() {
    final thread = _activeThread;
    if (thread == null || thread.messages.isEmpty) return;
    final next = List<_ChatMessage>.from(thread.messages)..removeLast();
    _replaceThread(thread.copyWith(messages: next));
  }

  void _replaceThread(_ConversationThread thread) {
    final index = _threads.indexWhere((item) => item.id == thread.id);
    if (index == -1) return;
    _threads[index] = thread;
    _threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  void _deleteThread(String threadId) {
    final index = _threads.indexWhere((item) => item.id == threadId);
    if (index == -1) return;
    final wasActive = _activeThreadId == threadId;
    _threads.removeAt(index);
    if (wasActive) {
      _activeThreadId = _threads.isNotEmpty ? _threads.first.id : null;
    }
    if (_threads.isEmpty) {
      _createThread(select: true);
    }
    unawaited(_persistHistory());
    if (mounted) {
      setState(() => _status = 'Chat deleted');
    }
  }

  void _renameThread(String text) {
    final thread = _activeThread;
    if (thread == null || thread.title != 'New thread' || text.trim().isEmpty) {
      return;
    }
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final title = cleaned.length > 36
        ? '${cleaned.substring(0, 36).trimRight()}...'
        : cleaned;
    _replaceThread(thread.copyWith(title: title));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Future<void> onWindowClose() async {
    if (_quitting) return;
    if (widget.settings.closeToTrayEnabled) {
      await _hideToTray();
      return;
    }
    _quitting = true;
    await windowManager.destroy();
  }

  @override
  Future<void> onWindowMinimize() async {
    if (widget.settings.minimizeToTrayEnabled && !_quitting) {
      await _hideToTray();
    }
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_showWindow());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(_showWindow());
        break;
      case 'capture':
        unawaited(_captureScreenshot());
        break;
      case 'toggle_close':
        unawaited(
          _saveSettingsAndApply(
            widget.settings.copyWith(
              closeToTrayEnabled: !widget.settings.closeToTrayEnabled,
            ),
          ),
        );
        break;
      case 'toggle_minimize':
        unawaited(
          _saveSettingsAndApply(
            widget.settings.copyWith(
              minimizeToTrayEnabled: !widget.settings.minimizeToTrayEnabled,
            ),
          ),
        );
        break;
      case 'exit':
        unawaited(_quit());
        break;
    }
  }

  Future<void> _quit() async {
    _backend.dispose();
    _quitting = true;
    await trayManager.destroy();
    await windowManager.destroy();
    exit(0);
  }

  Future<void> _openSettings() async {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _runQuickCommand(String text) {
    _inputController.text = text;
    unawaited(_sendMessage());
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) async {
        await _addAttachments(detail.files.map((item) => item.path));
        if (mounted) {
          setState(() {
            _isDragging = false;
            _status = 'Files attached';
          });
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: _SettingsDrawer(
          settings: widget.settings,
          onSettingsChanged: _saveSettingsAndApply,
          onClearHistory: _clearHistory,
        ),
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[_bg, _bgAlt],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: ColoredBox(
                color: _shell,
                child: Row(
                  children: <Widget>[
                    _buildNav(),
                    VerticalDivider(width: 1, thickness: 1, color: _border),
                    _buildThreads(),
                    VerticalDivider(width: 1, thickness: 1, color: _border),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          _buildTopBar(),
                          Expanded(
                            child: Container(
                              color: _panel,
                              child: _activeMessages.isEmpty
                                  ? _buildEmptyState()
                                  : ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.all(28),
                                      itemCount: _activeMessages.length,
                                      itemBuilder: (_, index) =>
                                          _buildMessageBubble(
                                            _activeMessages[index],
                                          ),
                                    ),
                            ),
                          ),
                          if (_attachments.isNotEmpty) _buildAttachmentStrip(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            child: Column(
                              children: <Widget>[
                                if (_activeMessages.isEmpty)
                                  _buildSuggestions(),
                                _buildComposer(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isDragging)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _accent, width: 2),
                      color: _dark
                          ? const Color(0xCC171B21)
                          : const Color(0xCCEAF0FB),
                    ),
                    child: Center(
                      child: Text(
                        'Drop files to attach them with previews',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNav() => SizedBox(
    width: 82,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Column(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[_accent, _accent.withValues(alpha: 0.65)],
              ),
            ),
            child: Icon(
              _protocolMode ? Icons.security_rounded : Icons.memory_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _navButton('Settings', Icons.settings_outlined, _openSettings),
          _navButton(
            'Hide',
            Icons.keyboard_hide_rounded,
            () => unawaited(_hideToTray()),
          ),
          const Spacer(),
          Tooltip(
            message: _status,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _protocolMode ? _accent : const Color(0xFF69D2A8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _navButton(
            'Kill App',
            Icons.power_settings_new_rounded,
            () => unawaited(_quit()),
          ),
        ],
      ),
    ),
  );

  Widget _navButton(String label, IconData icon, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: _muted),
          ),
        ),
      ),
    ),
  );

  Widget _buildThreads() => Container(
    width: 265,
    color: _panelAlt,
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Threads', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Conversation memory and quick context.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              setState(_selectOrCreateThread);
              unawaited(_persistHistory());
            },
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
            label: const Text('New thread'),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: _threads.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final thread = _threads[index];
              final selected = thread.id == _activeThreadId;
              return Material(
                color: selected ? _accentSoft : _panel,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() => _activeThreadId = thread.id);
                    unawaited(_persistHistory());
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: selected ? _accent : _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                thread.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: 'Delete',
                              child: IconButton(
                                onPressed: () => _deleteThread(thread.id),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          thread.messages.isEmpty
                              ? 'Empty thread'
                              : _clockLabel(thread.updatedAt),
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _buildTopBar() {
    final hotkey = hotkeyPresets
        .firstWhere(
          (item) => item.id == widget.settings.hotkeyId,
          orElse: () => hotkeyPresets.first,
        )
        .shortcut;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: <Widget>[
          _pill(
            _protocolMode ? 'PROTOCOL MODE' : 'J.A.R.V.I.S',
            _protocolMode ? Icons.security_rounded : Icons.auto_awesome_rounded,
          ),
          const SizedBox(width: 10),
          _pill(
            _backendReady ? 'Online' : 'Offline',
            _backendReady ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
          ),
          const Spacer(),
          _pill(hotkey, Icons.keyboard_command_key_rounded),
          const SizedBox(width: 10),
          Tooltip(
            message: _protocolMode ? 'Disable Protocol Mode' : 'Theme',
            child: IconButton(
              onPressed: _toggleTheme,
              style: IconButton.styleFrom(
                backgroundColor: _panelAlt,
                side: BorderSide(color: _border),
              ),
              icon: Icon(
                _protocolMode
                    ? Icons.power_settings_new_rounded
                    : _dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _pill(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _panelAlt,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: _accent),
        const SizedBox(width: 8),
        Text(
          label,
          style: (label == 'J.A.R.V.I.S' || label == 'PROTOCOL MODE')
              ? GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: _text,
                )
              : null,
        ),
      ],
    ),
  );

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const ThinkingOrb(size: 56),
          const SizedBox(height: 18),
          if (_protocolMode)
            Text(
              'PROTOCOL MODE',
              textAlign: TextAlign.center,
              style: GoogleFonts.orbitron(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.2,
                color: _accent,
              ),
            )
          else ...<Widget>[
            Text(
              _heroGreeting(_now),
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'How may I assist you today?',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.5),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildMessageBubble(_ChatMessage message) {
    final user = message.role == MessageRole.user;
    final bubble = user ? _accentSoft : _panelAlt;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: user ? 160 : 0,
          right: user ? 0 : 160,
          bottom: 12,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bubble,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: user ? _accent.withValues(alpha: 0.4) : _border,
            ),
          ),
          child: Column(
            crossAxisAlignment: user
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                user ? 'YOU' : 'J.A.R.V.I.S',
                style: (user ? GoogleFonts.ibmPlexMono : GoogleFonts.orbitron)(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: user ? _accent : _muted,
                ),
              ),
              if (message.attachments.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: message.attachments.map(_attachmentChip).toList(),
                ),
              ],
              const SizedBox(height: 10),
              SelectableText(
                message.text,
                style: TextStyle(color: _text, height: 1.5),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _clockLabel(message.createdAt),
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  if (!user) ...<Widget>[
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () =>
                          Clipboard.setData(ClipboardData(text: message.text)),
                      child: Icon(Icons.copy_rounded, size: 15, color: _muted),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentChip(_AttachmentItem item) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _attachmentThumb(item, 28),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(item.name, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );

  Widget _buildAttachmentStrip() => SizedBox(
    height: 98,
    child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      scrollDirection: Axis.horizontal,
      itemCount: _attachments.length,
      separatorBuilder: (context, index) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final item = _attachments[index];
        return Container(
          width: 210,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _panelAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: <Widget>[
              _attachmentThumb(item, 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.isImage ? 'Image preview' : 'File attachment',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                    Text(
                      _formatBytes(item.sizeBytes),
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _attachments.removeAt(index)),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _attachmentThumb(_AttachmentItem item, double size) {
    if (item.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          File(item.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _thumbFallback(item, size),
        ),
      );
    }
    return _thumbFallback(item, size);
  }

  Widget _thumbFallback(_AttachmentItem item, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Icon(
      item.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
      color: _muted,
    ),
  );

  Widget _buildSuggestions() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: _protocolMode
          ? <Widget>[
              _suggestion(
                'Protocol Gaming',
                Icons.sports_esports_rounded,
                () => _runQuickCommand('protocol gaming'),
              ),
              _suggestion(
                'Protocol Study',
                Icons.menu_book_rounded,
                () => _runQuickCommand('protocol study'),
              ),
              _suggestion(
                'Protocol Code',
                Icons.code_rounded,
                () => _runQuickCommand('protocol code'),
              ),
              _suggestion(
                'Play Music',
                Icons.library_music_rounded,
                () => _runQuickCommand('play music'),
              ),
              _suggestion(
                'Disable Protocol Mode',
                Icons.power_settings_new_rounded,
                () => _runQuickCommand('deactivate protocol mode'),
              ),
            ]
          : <Widget>[
              _suggestion('Play Music', Icons.library_music_rounded, () {
                _runQuickCommand('play music');
              }),
              _suggestion(
                'Open WhatsApp',
                Icons.chat_bubble_outline_rounded,
                () {
                  _runQuickCommand('open whatsapp');
                },
              ),
              _suggestion('Open Opera GX', Icons.open_in_browser_rounded, () {
                _runQuickCommand('open opera gx');
              }),
              _suggestion('Open VS Code', Icons.code_rounded, () {
                _runQuickCommand('open vs code');
              }),
            ],
    ),
  );

  Widget _suggestion(String label, IconData icon, VoidCallback onTap) =>
      Tooltip(
        message: label,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: _panelAlt,
            side: BorderSide(color: _border),
            foregroundColor: _text,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: Icon(icon, size: 16, color: _accent),
          label: Text(label),
        ),
      );

  Widget _buildComposer() => Container(
    constraints: const BoxConstraints(maxWidth: 820),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: _panelAlt,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: <Widget>[
        _iconAction(
          'Attach',
          Icons.attach_file_rounded,
          () => unawaited(_pickAttachments()),
        ),
        const SizedBox(width: 8),
        _iconAction(
          'Screenshot',
          Icons.screenshot_monitor_rounded,
          () => unawaited(_captureScreenshot()),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Focus(
            onKeyEvent: (_, KeyEvent event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter &&
                  !HardwareKeyboard.instance.isShiftPressed) {
                unawaited(_sendMessage());
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              autofocus: true,
              showCursor: true,
              minLines: 1,
              maxLines: 6,
              onTap: () => _inputFocusNode.requestFocus(),
              style: TextStyle(color: _text),
              decoration: InputDecoration(
                hintText: _protocolMode
                    ? 'Activate a protocol or control your desktop stack...'
                    : 'Ask J.A.R.V.I.S to open apps, prepare a WhatsApp message, or send files to your phone...',
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _iconAction(
          'Stop',
          Icons.stop_rounded,
          _isThinking ? () => unawaited(_stopGeneration()) : null,
        ),
        const SizedBox(width: 8),
        _iconAction(
          'Send',
          Icons.arrow_upward_rounded,
          _isThinking ? null : () => unawaited(_sendMessage()),
          filled: true,
        ),
      ],
    ),
  );

  Widget _iconAction(
    String label,
    IconData icon,
    VoidCallback? onTap, {
    bool filled = false,
  }) => Tooltip(
    message: label,
    child: IconButton(
      onPressed: onTap,
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        backgroundColor: filled ? _accent : _panel,
        foregroundColor: filled ? Colors.white : _accent,
        side: filled ? null : BorderSide(color: _border),
      ),
      icon: Icon(icon, size: 18),
    ),
  );
}

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({
    required this.settings,
    required this.onSettingsChanged,
    required this.onClearHistory,
  });

  final AppSettings settings;
  final Future<void> Function(AppSettings settings) onSettingsChanged;
  final Future<void> Function() onClearHistory;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<JarvisPalette>() ?? JarvisPalette.dark();
    return Drawer(
      width: 380,
      backgroundColor: colors.panelAlt,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Settings',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              colors,
              'Theme',
              Column(
                children: <Widget>[
                  Wrap(
                    spacing: 10,
                    children: AppThemeMode.values.map((mode) {
                      final selected = settings.themeMode == mode;
                      return ChoiceChip(
                        label: Text(
                          mode == AppThemeMode.dark
                              ? 'Dark Mode'
                              : 'Light Mode',
                        ),
                        selected: selected,
                        onSelected: (_) => onSettingsChanged(
                          settings.copyWith(themeMode: mode),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: settings.protocolModeEnabled,
                    onChanged: (value) => onSettingsChanged(
                      settings.copyWith(protocolModeEnabled: value),
                    ),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Protocol Mode'),
                    subtitle: const Text(
                      'Switch to the black-and-red command deck.',
                    ),
                  ),
                ],
              ),
            ),
            _section(
              colors,
              'Startup Behavior',
              Column(
                children: <Widget>[
                  SwitchListTile(
                    value: settings.launchAtLogin,
                    onChanged: (value) => onSettingsChanged(
                      settings.copyWith(launchAtLogin: value),
                    ),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Launch with Windows'),
                    subtitle: const Text(
                      'Create a startup entry for J.A.R.V.I.S.',
                    ),
                  ),
                  SwitchListTile(
                    value: settings.startMinimizedToTray,
                    onChanged: (value) => onSettingsChanged(
                      settings.copyWith(startMinimizedToTray: value),
                    ),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start minimized to tray'),
                    subtitle: const Text(
                      'Keep J.A.R.V.I.S out of the way at startup.',
                    ),
                  ),
                ],
              ),
            ),
            _section(
              colors,
              'Tray Behavior',
              Column(
                children: <Widget>[
                  SwitchListTile(
                    value: settings.closeToTrayEnabled,
                    onChanged: (value) => onSettingsChanged(
                      settings.copyWith(closeToTrayEnabled: value),
                    ),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Close button sends J.A.R.V.I.S to tray'),
                  ),
                  SwitchListTile(
                    value: settings.minimizeToTrayEnabled,
                    onChanged: (value) => onSettingsChanged(
                      settings.copyWith(minimizeToTrayEnabled: value),
                    ),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Minimize to tray'),
                  ),
                ],
              ),
            ),
            _section(
              colors,
              'Hotkeys',
              DropdownButtonFormField<String>(
                initialValue: settings.hotkeyId,
                decoration: const InputDecoration(
                  labelText: 'Global show hotkey',
                ),
                items: hotkeyPresets
                    .map(
                      (preset) => DropdownMenuItem<String>(
                        value: preset.id,
                        child: Text('${preset.label} (${preset.shortcut})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onSettingsChanged(settings.copyWith(hotkeyId: value));
                  }
                },
              ),
            ),
            _section(
              colors,
              'History',
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onClearHistory,
                  icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                  label: const Text('Clear history'),
                ),
              ),
            ),
            _section(
              colors,
              'WhatsApp',
              Text(
                'Type commands like "send whatsapp to Mom saying I will be late". For names, store numbers in workspace/whatsapp_contacts.json.',
                style: TextStyle(color: colors.muted, height: 1.5),
              ),
            ),
            _section(
              colors,
              'Protocols',
              Text(
                'Protocols load from jarvis-protocols.json in the active J.A.R.V.I.S workspace. See workspace/PROTOCOLS.md for the full setup guide.',
                style: TextStyle(color: colors.muted, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(JarvisPalette colors, String title, Widget child) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class ThinkingOrb extends StatefulWidget {
  const ThinkingOrb({super.key, this.size = 64});
  final double size;

  @override
  State<ThinkingOrb> createState() => _ThinkingOrbState();
}

class _ThinkingOrbState extends State<ThinkingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<JarvisPalette>() ?? JarvisPalette.dark();
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final pulse = 0.94 + (math.sin(t * 2 * math.pi) * 0.08);
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Transform.scale(
                scale: 0.95 + (t * 0.35),
                child: Container(
                  width: widget.size * 0.86,
                  height: widget.size * 0.86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: palette.accent.withValues(alpha: 0.4 * (1 - t)),
                      width: 1.8,
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: widget.size * 0.7,
                  height: widget.size * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        palette.accentSoft,
                        palette.accentMuted,
                        palette.accent,
                        palette.accentDark,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JarvisBackendClient {
  static final Uri _healthUri = Uri.parse('http://127.0.0.1:8767/health');
  static final Uri _streamUri = Uri.parse('http://127.0.0.1:8767/ask_stream');
  static const String _backendVersion = '5';
  Process? _backendProcess;
  HttpClient? _activeClient;
  bool _streamCancelled = false;
  Future<bool>? _startupTask;

  Future<bool> ensureBackendRunning() async {
    final existingTask = _startupTask;
    if (existingTask != null) return existingTask;

    final task = _ensureBackendRunning();
    _startupTask = task;
    return task.whenComplete(() {
      if (identical(_startupTask, task)) {
        _startupTask = null;
      }
    });
  }

  Future<bool> _ensureBackendRunning() async {
    if (await _isHealthy()) return true;
    await _startProcess();
    for (var i = 0; i < 40; i++) {
      if (await _isHealthy()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<void> streamAsk({
    required String message,
    required List<_AttachmentItem> attachments,
    required List<Map<String, dynamic>> context,
    required _JarvisMemory memory,
    required void Function(String token) onToken,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty && attachments.isEmpty) {
      throw Exception('Please type a message or attach a file before sending.');
    }
    if (!await ensureBackendRunning()) {
      throw Exception('Local backend did not start in time.');
    }
    final client = HttpClient();
    _streamCancelled = false;
    _activeClient = client;
    try {
      final request = await client.postUrl(_streamUri);
      final body = jsonEncode(<String, dynamic>{
        'message': trimmedMessage,
        'attachments': attachments
            .map((item) => <String, dynamic>{'path': item.path})
            .toList(),
        'context': context,
        'memory': memory.toJson(),
      });
      await _writeJsonBody(request, body);
      final response = await request.close();
      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        throw Exception('Backend returned ${response.statusCode}: $errorBody');
      }
      final lines = response
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final payload = jsonDecode(line) as Map<String, dynamic>;
        if (payload['type'] == 'token') {
          if (_streamCancelled) throw Exception('cancelled');
          onToken(payload['content'] as String? ?? '');
        } else if (payload['type'] == 'error') {
          throw Exception(
            payload['content'] as String? ?? 'Unknown stream error',
          );
        } else if (payload['type'] == 'done') {
          break;
        }
      }
    } finally {
      if (identical(_activeClient, client)) {
        _activeClient = null;
      }
      client.close(force: true);
    }
  }

  Future<void> _writeJsonBody(HttpClientRequest request, String body) async {
    final bytes = utf8.encode(body);
    request.headers.contentType = ContentType.json;
    request.contentLength = bytes.length;
    request.add(bytes);
  }

  void cancelActiveStream() {
    _streamCancelled = true;
    _activeClient?.close(force: true);
    _activeClient = null;
  }

  Future<bool> _isHealthy() async {
    try {
      final client = HttpClient();
      try {
        final request = await client.getUrl(_healthUri);
        final response = await request.close().timeout(
          const Duration(milliseconds: 800),
        );
        if (response.statusCode != 200) return false;
        final body = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded['version']?.toString() == _backendVersion;
        }
        if (decoded is Map) {
          return decoded['version']?.toString() == _backendVersion;
        }
        return false;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _terminateStaleBackend() async {
    if (!Platform.isWindows) return;
    const script = r'''
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -match 'backend_server\.py' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
''';
    try {
      await Process.run('powershell', <String>[
        '-NoProfile',
        '-Command',
        script,
      ], runInShell: true);
    } catch (_) {}
  }

  Future<void> _startProcess() async {
    if (_backendProcess != null && await _isHealthy()) return;
    await _terminateStaleBackend();
    final scriptCandidates = <String>{};
    void addBase(String basePath) {
      var current = Directory(basePath).absolute;
      for (var depth = 0; depth < 7; depth++) {
        scriptCandidates.add(p.join(current.path, 'backend_server.py'));
        scriptCandidates.add(
          p.join(current.path, 'Jarvis', 'backend_server.py'),
        );
        if (current.parent.path == current.path) break;
        current = current.parent;
      }
    }

    addBase(Directory.current.path);
    addBase(File(Platform.resolvedExecutable).parent.path);
    final pythonCommands = await _resolvePythonCommands();
    for (final script in scriptCandidates) {
      if (!File(script).existsSync()) continue;
      for (final command in pythonCommands) {
        try {
          _backendProcess = await Process.start(
            command.first,
            <String>[...command.skip(1), script],
            mode: ProcessStartMode.detachedWithStdio,
            workingDirectory: File(script).parent.path,
          );
          return;
        } catch (_) {}
      }
    }
  }

  Future<List<List<String>>> _resolvePythonCommands() async {
    if (!Platform.isWindows) {
      return <List<String>>[
        <String>['python'],
      ];
    }

    final commands = <List<String>>[];
    final candidates = <({String executable, List<String> arguments})>[
      (executable: 'pythonw', arguments: <String>[]),
      (executable: 'pyw', arguments: <String>['-3']),
      (executable: 'python', arguments: <String>[]),
      (executable: 'py', arguments: <String>['-3']),
    ];

    for (final candidate in candidates) {
      final resolved = await _resolveExecutable(candidate.executable);
      if (resolved == null) continue;
      commands.add(<String>[resolved, ...candidate.arguments]);
    }

    if (commands.isEmpty) {
      commands.addAll(<List<String>>[
        <String>['pythonw'],
        <String>['pyw', '-3'],
        <String>['python'],
        <String>['py', '-3'],
      ]);
    }

    return commands;
  }

  Future<String?> _resolveExecutable(String name) async {
    try {
      final result = await Process.run('where', <String>[
        name,
      ], runInShell: true);
      if (result.exitCode != 0) return null;

      final output = result.stdout?.toString() ?? '';
      for (final line in const LineSplitter().convert(output)) {
        final candidate = line.trim();
        if (candidate.isEmpty) continue;
        if (candidate.toLowerCase().contains(r'\windowsapps\')) continue;
        if (File(candidate).existsSync()) return candidate;
      }
    } catch (_) {}
    return null;
  }

  void dispose() {
    cancelActiveStream();
    _backendProcess?.kill();
    _backendProcess = null;
  }
}

class _ConversationThread {
  const _ConversationThread({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final List<_ChatMessage> messages;

  _ConversationThread copyWith({
    String? title,
    DateTime? updatedAt,
    List<_ChatMessage>? messages,
  }) => _ConversationThread(
    id: id,
    title: title ?? this.title,
    updatedAt: updatedAt ?? this.updatedAt,
    messages: messages ?? this.messages,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((message) => message.toJson()).toList(),
  };

  factory _ConversationThread.fromJson(Map<String, dynamic> json) =>
      _ConversationThread(
        id:
            json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] as String? ?? 'New thread',
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        messages: (json['messages'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map>()
            .map(
              (item) => _ChatMessage.fromJson(
                item.map(
                  (dynamic key, dynamic value) =>
                      MapEntry(key.toString(), value),
                ),
              ),
            )
            .toList(),
      );
}

class _AttachmentItem {
  const _AttachmentItem({
    required this.path,
    required this.name,
    required this.isImage,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final bool isImage;
  final int sizeBytes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'path': path,
    'name': name,
    'isImage': isImage,
    'sizeBytes': sizeBytes,
  };

  factory _AttachmentItem.fromJson(Map<String, dynamic> json) =>
      _AttachmentItem(
        path: json['path'] as String? ?? '',
        name: json['name'] as String? ?? '',
        isImage: json['isImage'] as bool? ?? false,
        sizeBytes: json['sizeBytes'] as int? ?? 0,
      );
}

class _JarvisMemory {
  const _JarvisMemory({
    required this.summary,
    required this.preferredTone,
    required this.defaultAppTargets,
  });

  final String summary;
  final String preferredTone;
  final Map<String, String> defaultAppTargets;

  static _JarvisMemory defaults() => const _JarvisMemory(
    summary: '',
    preferredTone: 'balanced',
    defaultAppTargets: <String, String>{},
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'summary': summary,
    'preferences': <String, dynamic>{
      'preferredTone': preferredTone,
      'defaultAppTargets': defaultAppTargets,
    },
  };

  factory _JarvisMemory.fromJson(Map<String, dynamic> json) {
    final preferences = json['preferences'];
    final prefs = preferences is Map ? preferences : const <String, dynamic>{};
    final defaultTargets = prefs['defaultAppTargets'];
    final normalizedTargets = <String, String>{};
    if (defaultTargets is Map) {
      for (final entry in defaultTargets.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value.toString().trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          normalizedTargets[key] = value;
        }
      }
    }

    return _JarvisMemory(
      summary: json['summary'] as String? ?? '',
      preferredTone: prefs['preferredTone'] as String? ?? 'balanced',
      defaultAppTargets: normalizedTargets,
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.text,
    required this.createdAt,
    this.isStreaming = false,
    this.attachments = const <_AttachmentItem>[],
  });

  final MessageRole role;
  final String text;
  final DateTime createdAt;
  final bool isStreaming;
  final List<_AttachmentItem> attachments;

  _ChatMessage copyWith({String? text, bool? isStreaming}) => _ChatMessage(
    role: role,
    text: text ?? this.text,
    createdAt: createdAt,
    isStreaming: isStreaming ?? this.isStreaming,
    attachments: attachments,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'isStreaming': isStreaming,
    'attachments': attachments.map((item) => item.toJson()).toList(),
  };

  factory _ChatMessage.fromJson(Map<String, dynamic> json) => _ChatMessage(
    role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
    text: json['text'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    attachments: (json['attachments'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map>()
        .map(
          (item) => _AttachmentItem.fromJson(
            item.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(),
  );
}

String _clockLabel(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour == 0
      ? 12
      : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $meridiem';
}

String _heroGreeting(DateTime time) {
  final hour = time.toLocal().hour;
  if (hour >= 5 && hour < 12) return 'Good morning, sir';
  if (hour >= 12 && hour < 17) return 'Good afternoon, sir';
  return 'Good evening, sir';
}

String _timestamp() {
  final now = DateTime.now().toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = <String>['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} ${units[unitIndex]}';
}
