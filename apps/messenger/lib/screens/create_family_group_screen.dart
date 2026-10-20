import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:messenger_core/messenger_core.dart';

/// Screen 4: Create Family Group Screen with visual selection of family members.
class CreateFamilyGroupScreen extends StatefulWidget {
  final FamilyMessengerController controller;

  const CreateFamilyGroupScreen({
    super.key,
    required this.controller,
  });

  @override
  State<CreateFamilyGroupScreen> createState() =>
      _CreateFamilyGroupScreenState();
}

class _CreateFamilyGroupScreenState extends State<CreateFamilyGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final Set<String> _selectedUserIds = {};
  List<FamilyMember> _familyMembers = const [];
  bool _loadingMembers = true;
  bool _creating = false;
  String? _errorMessage;

  static const _quickPresets = [
    'Команда',
    'Планы и идеи',
    'Уютный чат',
    'Семья',
  ];

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyMembers() async {
    final list = await widget.controller.getFamilyDirectory();
    if (mounted) {
      setState(() {
        _familyMembers = list;
        _loadingMembers = false;
      });
    }
  }

  Future<void> _createGroup() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Введите название группы.';
      });
      return;
    }

    setState(() {
      _creating = true;
      _errorMessage = null;
    });

    try {
      final roomId = await widget.controller.createEncryptedRoom(
        name: name,
        topic: _topicCtrl.text.trim(),
        inviteUserIds:
            _selectedUserIds.isEmpty ? null : _selectedUserIds.toList(),
      );
      if (mounted) {
        Navigator.pop(context, roomId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _errorMessage = FriendlyErrorMapper.toUserMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать группу'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FamilySpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(FamilySpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'О группе',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: FamilySpacing.md),
                          TextField(
                            key: const Key('group_name_field'),
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Название группы',
                              hintText: 'Например: Команда, Друзья, Планы',
                              prefixIcon: Icon(Icons.groups_2_outlined),
                            ),
                          ),
                          const SizedBox(height: FamilySpacing.sm),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final preset in _quickPresets)
                                ActionChip(
                                  label: Text(preset),
                                  onPressed: () {
                                    setState(() => _nameCtrl.text = preset);
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: FamilySpacing.md),
                          TextField(
                            controller: _topicCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Тема или описание (по желанию)',
                              hintText: 'Например: Общие планы, фото и обсуждения',
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: FamilySpacing.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(FamilySpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Пригласить участников',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ),
                              if (_selectedUserIds.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.verifiedBadgeBg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Выбрано: ${_selectedUserIds.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: palette.verifiedBadgeFg,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: FamilySpacing.xs),
                          Text(
                            'Выберите близких из списка, чтобы отправить им приглашение в группу.',
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: FamilySpacing.md),
                          if (_loadingMembers)
                            const Padding(
                              padding: EdgeInsets.all(FamilySpacing.lg),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_familyMembers.isEmpty)
                            Text(
                              'Список членов семьи пуст.',
                              style: TextStyle(color: palette.textMuted),
                            )
                          else
                            for (final member in _familyMembers)
                              CheckboxListTile(
                                value: _selectedUserIds.contains(member.userId),
                                contentPadding: EdgeInsets.zero,
                                secondary: FamilyAvatar(
                                  title: member.displayName,
                                  radius: 20,
                                ),
                                title: Text(
                                  member.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  member.roleHint,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: palette.textSecondary,
                                  ),
                                ),
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedUserIds.add(member.userId);
                                    } else {
                                      _selectedUserIds.remove(member.userId);
                                    }
                                  });
                                },
                              ),
                        ],
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: FamilySpacing.md),
                    Container(
                      padding: const EdgeInsets.all(FamilySpacing.md),
                      decoration: BoxDecoration(
                        color: palette.dangerBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: palette.dangerFg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: FamilySpacing.xl),
                  FilledButton.icon(
                    key: const Key('create_group_submit_button'),
                    onPressed: _creating ? null : _createGroup,
                    icon: _creating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _creating ? 'Создаём группу...' : 'Создать группу',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
