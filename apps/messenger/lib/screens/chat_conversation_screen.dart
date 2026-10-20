import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:design_system/design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:messenger_core/messenger_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../state/app_state.dart';

/// Screen 3: Modern Personal & Group Chat Screen with Voice, Photos, and Files.
/// - Shows human names, avatars, formatted message timestamps, and delivery checkmarks.
/// - Native voice message recording & playback with animated audio waveforms.
/// - Attachment picker for photos, camera, videos, and documents with Megolm E2EE.
/// - Preserves unsent drafts and never loses message text if sending fails.
/// - Handles Android virtual keyboard (`viewInsets`) and `SafeArea` cleanly.
class ChatConversationScreen extends StatefulWidget {
  final FamilyMessengerController controller;
  final AppPreferencesController prefs;
  final String roomId;
  final bool showBackButton;
  final VoidCallback? onBack;

  const ChatConversationScreen({
    super.key,
    required this.controller,
    required this.prefs,
    required this.roomId,
    this.showBackButton = true,
    this.onBack,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  late final TextEditingController _msgCtrl;
  StreamSubscription<SyncUpdate>? _syncSub;
  Timeline? _timeline;
  bool _loadingTimeline = true;
  bool _sending = false;
  String? _sendErrorBanner;
  String? _replyToPreview;

  AudioRecorder? _audioRecorder;
  AudioPlayer? _audioPlayer;
  bool _isRecordingVoice = false;
  int _recordingDurationSeconds = 0;
  Timer? _recordingTimer;
  String? _currentRecordingPath;

  String? _currentlyPlayingEventId;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  bool _isPlayingAudio = false;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  final Map<String, Uint8List> _decryptedMediaCache = {};
  final Set<String> _downloadingEventIds = {};

  @override
  void initState() {
    super.initState();
    _msgCtrl = TextEditingController(
      text: widget.prefs.getDraft(widget.roomId),
    );
    _msgCtrl.addListener(_onInputChanged);
    _loadTimeline();
    _initAudio();
    _syncSub = widget.controller.client.onSync.stream.listen((_) {
      _loadTimeline(silent: true);
    });
  }

  void _onInputChanged() {
    widget.prefs.setDraft(widget.roomId, _msgCtrl.text);
    if (mounted) setState(() {});
  }

  void _initAudio() {
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _posSub = _audioPlayer!.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _playbackPosition = pos);
    });
    _durSub = _audioPlayer!.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _playbackDuration = dur);
    });
    _playerStateSub = _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _currentlyPlayingEventId = null;
            _playbackPosition = Duration.zero;
          }
        });
      }
    });
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  Future<void> _startVoiceRecording() async {
    try {
      if (_audioRecorder == null) return;
      final hasPerm = await _audioRecorder!.hasPermission();
      if (!hasPerm) return;

      final tempDir = await getTemporaryDirectory();
      final path = p.join(
        tempDir.path,
        'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await _audioRecorder!.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _isRecordingVoice = true;
        _recordingDurationSeconds = 0;
        _currentRecordingPath = path;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordingDurationSeconds++);
        }
      });
    } catch (_) {}
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    try {
      await _audioRecorder?.stop();
      if (_currentRecordingPath != null) {
        final f = File(_currentRecordingPath!);
        if (f.existsSync()) f.deleteSync();
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isRecordingVoice = false;
        _recordingDurationSeconds = 0;
        _currentRecordingPath = null;
      });
    }
  }

  Future<void> _sendVoiceRecording() async {
    _recordingTimer?.cancel();
    String? path;
    try {
      path = await _audioRecorder?.stop();
    } catch (_) {}

    final finalPath = path ?? _currentRecordingPath;
    if (mounted) {
      setState(() {
        _isRecordingVoice = false;
        _sending = true;
      });
    }

    if (finalPath != null) {
      try {
        final file = File(finalPath);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty && _recordingDurationSeconds >= 1) {
            await widget.controller.sendMediaAttachment(
              widget.roomId,
              bytes: bytes,
              fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
              mimeType: 'audio/m4a',
            );
            await _loadTimeline(silent: true);
          }
          file.deleteSync();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _sendErrorBanner =
                'Не удалось отправить голосовое сообщение: ${FriendlyErrorMapper.toUserMessage(e)}';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _sending = false;
            _currentRecordingPath = null;
            _recordingDurationSeconds = 0;
          });
        }
      }
    }
  }

  Future<void> _pickAndSendPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked == null) return;

      setState(() => _sending = true);
      final bytes = await picked.readAsBytes();
      await widget.controller.sendMediaAttachment(
        widget.roomId,
        bytes: bytes,
        fileName: picked.name,
        mimeType: picked.mimeType ?? 'image/jpeg',
      );
      await _loadTimeline(silent: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendErrorBanner =
              'Не удалось отправить фото: ${FriendlyErrorMapper.toUserMessage(e)}';
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendVideo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _sending = true);
      final bytes = await picked.readAsBytes();
      await widget.controller.sendMediaAttachment(
        widget.roomId,
        bytes: bytes,
        fileName: picked.name,
        mimeType: 'video/mp4',
      );
      await _loadTimeline(silent: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendErrorBanner =
              'Не удалось отправить видео: ${FriendlyErrorMapper.toUserMessage(e)}';
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendDocument() async {
    try {
      final file = await FilePicker.pickFile();
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      setState(() => _sending = true);
      await widget.controller.sendMediaAttachment(
        widget.roomId,
        bytes: bytes,
        fileName: file.name,
        mimeType: null,
      );
      await _loadTimeline(silent: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendErrorBanner =
              'Не удалось отправить файл: ${FriendlyErrorMapper.toUserMessage(e)}';
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleVoicePlay(Event event) async {
    if (_currentlyPlayingEventId == event.eventId) {
      if (_isPlayingAudio) {
        await _audioPlayer?.pause();
      } else {
        await _audioPlayer?.resume();
      }
      return;
    }

    var bytes = _decryptedMediaCache[event.eventId];
    if (bytes == null) {
      bytes = await widget.controller.downloadAttachment(event);
      if (bytes != null && mounted) {
        setState(() => _decryptedMediaCache[event.eventId] = bytes!);
      }
    }

    if (bytes != null && mounted) {
      setState(() {
        _currentlyPlayingEventId = event.eventId;
        _playbackPosition = Duration.zero;
      });
      await _audioPlayer?.stop();
      await _audioPlayer?.play(BytesSource(bytes));
    }
  }

  void _triggerMediaDownload(Event event) {
    if (_decryptedMediaCache.containsKey(event.eventId) ||
        _downloadingEventIds.contains(event.eventId)) {
      return;
    }
    _downloadingEventIds.add(event.eventId);
    widget.controller.downloadAttachment(event).then((bytes) {
      _downloadingEventIds.remove(event.eventId);
      if (bytes != null && mounted) {
        setState(() => _decryptedMediaCache[event.eventId] = bytes);
      }
    }).catchError((_) {
      _downloadingEventIds.remove(event.eventId);
    });
  }

  void _showFullImageDialog(Uint8List bytes, String title) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(bytes),
              ),
            ),
            IconButton.filled(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildMediaForEvent(Event event, bool isMine) {
    final msgType = event.content['msgtype'] as String? ?? MessageTypes.Text;

    if (msgType == MessageTypes.Image) {
      final cached = _decryptedMediaCache[event.eventId];
      if (cached != null) {
        return GestureDetector(
          onTap: () => _showFullImageDialog(
            cached,
            event.content['body'] as String? ?? 'Фото',
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 320),
              child: Image.memory(cached, fit: BoxFit.cover),
            ),
          ),
        );
      }
      _triggerMediaDownload(event);
      return Container(
        width: 180,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (msgType == MessageTypes.Audio) {
      final isPlaying =
          _currentlyPlayingEventId == event.eventId && _isPlayingAudio;
      final progress = (_playbackDuration.inMilliseconds > 0 &&
              _currentlyPlayingEventId == event.eventId)
          ? (_playbackPosition.inMilliseconds /
                  _playbackDuration.inMilliseconds)
              .clamp(0.0, 1.0)
          : 0.0;
      final info = (event.content['info'] is Map)
          ? (event.content['info'] as Map)
          : null;
      final rawDuration = info?['duration'] as num?;
      final durationLabel = (_currentlyPlayingEventId == event.eventId &&
              _playbackPosition > Duration.zero)
          ? _formatDuration(_playbackPosition)
          : (rawDuration != null
              ? _formatDuration(Duration(milliseconds: rawDuration.toInt()))
              : '0:05');

      return FamilyVoiceBubble(
        isPlaying: isPlaying,
        durationText: durationLabel,
        progress: progress,
        isMine: isMine,
        onPlayPause: () => _toggleVoicePlay(event),
      );
    }

    if (msgType == MessageTypes.Video || msgType == MessageTypes.File) {
      final isVideo = msgType == MessageTypes.Video;
      final filename = event.content['filename'] as String? ??
          event.content['body'] as String? ??
          (isVideo ? 'Видео' : 'Документ');
      final info = (event.content['info'] is Map)
          ? (event.content['info'] as Map)
          : null;
      final sizeBytes = (info?['size'] as num?)?.toInt() ?? 0;

      return FamilyFileAttachmentBubble(
        fileName: filename,
        sizeLabel: _formatFileSize(sizeBytes),
        isMine: isMine,
        icon: isVideo ? Icons.videocam_rounded : Icons.insert_drive_file_rounded,
        onTap: () {
          _triggerMediaDownload(event);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Файл «$filename» загружается...'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      );
    }

    return null;
  }

  void _showAttachmentOptions() {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Отправить в чат',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _attachmentButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Галерея',
                      color: const Color(0xFF3B82F6),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendPhoto(ImageSource.gallery);
                      },
                    ),
                    _attachmentButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Камера',
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendPhoto(ImageSource.camera);
                      },
                    ),
                    _attachmentButton(
                      icon: Icons.videocam_rounded,
                      label: 'Видео',
                      color: const Color(0xFFEF4444),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendVideo();
                      },
                    ),
                    _attachmentButton(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Файл',
                      color: const Color(0xFF8B5CF6),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendDocument();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachmentButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTimeline({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loadingTimeline = true);
    }
    try {
      final tl = await widget.controller.openRoomTimeline(widget.roomId);
      if (mounted) {
        setState(() {
          _timeline = tl;
          _loadingTimeline = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingTimeline = false);
      }
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _recordingTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _playerStateSub?.cancel();
    _audioRecorder?.dispose();
    _audioPlayer?.dispose();
    _msgCtrl.removeListener(_onInputChanged);
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final rawText = _msgCtrl.text.trim();
    if (rawText.isEmpty || _sending) return;

    final fullPayload = _replyToPreview != null
        ? '> $_replyToPreview\n\n$rawText'
        : rawText;

    setState(() {
      _sending = true;
      _sendErrorBanner = null;
    });

    try {
      await widget.controller.sendTextMessage(widget.roomId, fullPayload);
      // Clear input ONLY after sendTextMessage succeeds so text is never lost!
      _msgCtrl.clear();
      widget.prefs.clearDraft(widget.roomId);
      setState(() {
        _replyToPreview = null;
      });
      await _loadTimeline(silent: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendErrorBanner =
              '${FriendlyErrorMapper.toUserMessage(e)} Ваш текст сохранён в поле ввода.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _showMessageActions(Event event, String senderName, String cleanBody) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Ответить на сообщение'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _replyToPreview = '$senderName: $cleanBody';
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Скопировать текст'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: cleanBody));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Текст сообщения скопирован'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChatInfoSheet(Room room) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    final title = widget.controller.getRoomHumanTitle(room);
    final participants = room.getParticipants();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              FamilySpacing.xl,
              0,
              FamilySpacing.xl,
              FamilySpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FamilyAvatar(
                  title: title,
                  radius: 34,
                  isGroup: !room.isDirectChat,
                  showProtectedDot: true,
                ),
                const SizedBox(height: FamilySpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: FamilySpacing.xs),
                const E2eeSecurityBadge(
                  encrypted: true,
                  label: 'Сообщения защищены сквозным шифрованием',
                ),
                if (room.topic.isNotEmpty) ...[
                  const SizedBox(height: FamilySpacing.md),
                  Text(
                    room.topic,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: FamilySpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Участники беседы (${participants.isEmpty ? 1 : participants.length})',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: FamilySpacing.sm),
                for (final p in participants)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: FamilyAvatar(
                      title: widget.controller.getSenderHumanName(room, p.id),
                      radius: 19,
                    ),
                    title: Text(
                      widget.controller.getSenderHumanName(room, p.id),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      p.id == widget.controller.client.userID
                          ? 'Это вы'
                          : 'Участник',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Extracts optional `> Sender: quote` prefix from a message body.
  (String? replyQuote, String bodyText) _parseReplyQuote(String rawBody) {
    if (rawBody.startsWith('> ') && rawBody.contains('\n\n')) {
      final parts = rawBody.split('\n\n');
      final quote = parts.first.substring(2).trim();
      final rest = parts.sublist(1).join('\n\n').trim();
      if (rest.isNotEmpty) {
        return (quote, rest);
      }
    }
    return (null, rawBody);
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    final room = widget.controller.client.getRoomById(widget.roomId);

    if (room == null) {
      return const Scaffold(
        body: Center(
          child: FamilyEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Беседа не выбрана',
            subtitle: 'Выберите чат из списка или начните новую семейную беседу.',
          ),
        ),
      );
    }

    final roomTitle = widget.controller.getRoomHumanTitle(room);
    final isGroup = !room.isDirectChat;
    final memberCount = room.getParticipants().length;
    final subtitleText = isGroup
        ? 'Группа${memberCount > 0 ? " • $memberCount участн." : ""}'
        : 'Личная беседа • Защищено';

    final rawEvents = (_timeline?.events ?? [])
        .where(
          (e) =>
              e.type == EventTypes.Message &&
              !e.redacted,
        )
        .toList();

    return Scaffold(
      backgroundColor: palette.cardSurface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // Conversation Header Bar
            Material(
              color: palette.sidebarSurface,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FamilySpacing.sm,
                    vertical: FamilySpacing.sm,
                  ),
                  child: Row(
                children: [
                  if (widget.showBackButton)
                    IconButton(
                      tooltip: 'Назад к списку чатов',
                      onPressed: widget.onBack ??
                          () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  else
                    const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showChatInfoSheet(room),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            FamilyAvatar(
                              title: roomTitle,
                              radius: 20,
                              isGroup: isGroup,
                              showProtectedDot: true,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    roomTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    subtitleText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'О беседе',
                    onPressed: () => _showChatInfoSheet(room),
                    icon: const Icon(Icons.info_outline_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),

        // Message List
        Expanded(
          child: _loadingTimeline
              ? const Center(child: CircularProgressIndicator())
              : rawEvents.isEmpty
                  ? FamilyEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Начните общение',
                      subtitle: isGroup
                          ? 'Напишите первое сообщение или отправьте фото/файл для «$roomTitle».'
                          : 'Напишите первое сообщение или запишите голос для «$roomTitle».',
                    )
                  : ListView.builder(
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: FamilySpacing.md,
                        vertical: FamilySpacing.md,
                      ),
                      itemCount: rawEvents.length,
                      itemBuilder: (context, index) {
                        final event = rawEvents[index];
                        final isMine =
                            event.senderId == widget.controller.client.userID;
                        final senderName = widget.controller.getSenderHumanName(
                          room,
                          event.senderId,
                        );
                        final timeText =
                            AppPreferencesController.formatMessageTime(
                          event.originServerTs,
                        );
                        final (replyQuote, bodyText) = _parseReplyQuote(
                          event.body,
                        );

                        // Determine if we should show a date separator above this message
                        var showDateHeader = false;
                        if (index == rawEvents.length - 1) {
                          showDateHeader = true;
                        } else {
                          final older = rawEvents[index + 1].originServerTs.toLocal();
                          final curr = event.originServerTs.toLocal();
                          if (older.year != curr.year ||
                              older.month != curr.month ||
                              older.day != curr.day) {
                            showDateHeader = true;
                          }
                        }

                        MessageDeliveryUiState deliveryState =
                            MessageDeliveryUiState.delivered;
                        if (event.status == EventStatus.sending) {
                          deliveryState = MessageDeliveryUiState.sending;
                        } else if (event.status == EventStatus.error) {
                          deliveryState = MessageDeliveryUiState.failed;
                        }

                        final msgType = event.content['msgtype'] as String? ??
                            MessageTypes.Text;
                        final isText = msgType == MessageTypes.Text;
                        final displayBody = isText
                            ? bodyText
                            : (event.content['body'] as String? ?? '');

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showDateHeader)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: FamilySpacing.sm,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.sidebarSurface,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    AppPreferencesController.formatDayHeader(
                                      event.originServerTs,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            FamilyMessageBubble(
                              text: isText ? displayBody : '',
                              mediaWidget: _buildMediaForEvent(event, isMine),
                              timeText: timeText,
                              isMine: isMine,
                              senderName: senderName,
                              showSenderName: isGroup,
                              replyPreviewText: replyQuote,
                              deliveryState: deliveryState,
                              onTap: () => _showMessageActions(
                                event,
                                senderName,
                                displayBody,
                              ),
                              onLongPress: () => _showMessageActions(
                                event,
                                senderName,
                                displayBody,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
        ),

        // Error Banner (when message send failed, keeping draft intact)
        if (_sendErrorBanner != null)
          Container(
            color: palette.dangerBg,
            padding: const EdgeInsets.symmetric(
              horizontal: FamilySpacing.md,
              vertical: FamilySpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: palette.dangerFg,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sendErrorBanner!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: palette.dangerFg,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _sending ? null : _sendMessage,
                  child: Text(
                    'Повторить',
                    style: TextStyle(
                      color: palette.dangerFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Reply Preview Bar
        if (_replyToPreview != null)
          Container(
            color: palette.sidebarSurface,
            padding: const EdgeInsets.symmetric(
              horizontal: FamilySpacing.md,
              vertical: 6,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.reply_rounded,
                  size: 18,
                  color: palette.primaryPine,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _replyToPreview!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Отменить ответ',
                  onPressed: () => setState(() => _replyToPreview = null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),

        const Divider(height: 1),

        // Composer Bar (SafeArea protected)
        Material(
          color: palette.sidebarSurface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: _isRecordingVoice
                  ? Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fiber_manual_record_rounded,
                            color: Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(
                              Duration(seconds: _recordingDurationSeconds),
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.red,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Отменить запись',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red,
                            ),
                            onPressed: _cancelVoiceRecording,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Отправить аудио',
                            style: IconButton.styleFrom(
                              backgroundColor: palette.primaryPine,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(
                              Icons.arrow_upward_rounded,
                              size: 20,
                            ),
                            onPressed: _sendVoiceRecording,
                          ),
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          key: const Key('chat_attach_button'),
                          tooltip: 'Прикрепить фото или файл',
                          icon: Icon(
                            Icons.attach_file_rounded,
                            color: palette.primaryPine,
                            size: 24,
                          ),
                          onPressed:
                              _sending ? null : _showAttachmentOptions,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: TextField(
                            key: const Key('chat_message_input'),
                            controller: _msgCtrl,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: 'Сообщение...',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide:
                                    BorderSide(color: palette.borderSubtle),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide:
                                    BorderSide(color: palette.borderSubtle),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                  color: palette.primaryPine,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (_msgCtrl.text.trim().isEmpty)
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton(
                              key: const Key('chat_voice_record_button'),
                              tooltip: 'Записать голос',
                              style: IconButton.styleFrom(
                                backgroundColor: palette.primaryPine,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.mic_rounded, size: 22),
                              onPressed:
                                  _sending ? null : _startVoiceRecording,
                            ),
                          )
                        else
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: FilledButton(
                              key: const Key('chat_send_button'),
                              onPressed: _sending ? null : _sendMessage,
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: const CircleBorder(),
                              ),
                              child: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 20),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    ),
  ),
);
  }
}
