import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatars.dart';
import '../../core/models/models.dart';
import '../../core/qr/invite_codec.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../widgets/avatar_editor.dart';
import '../widgets/common.dart';

/// The identity checkpoint between scanning and joining. It is also the place
/// to change the name or avatar without opening Settings.
class JoinConfirmScreen extends ConsumerStatefulWidget {
  const JoinConfirmScreen({super.key, required this.invite});

  final String invite;

  @override
  ConsumerState<JoinConfirmScreen> createState() => _JoinConfirmScreenState();
}

class _JoinConfirmScreenState extends ConsumerState<JoinConfirmScreen> {
  late final TextEditingController _name;
  late String _avatar;
  String? _avatarPhoto;
  String? _roomId;
  bool _invalidInvite = false;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider).value ?? const AppSettings();
    _name = TextEditingController(text: settings.nickname);
    _avatar = normalizeAvatar(settings.avatar);
    _avatarPhoto = settings.avatarPhoto;
    try {
      _roomId = tryParseInvite(widget.invite).roomId;
    } on InvalidInviteException {
      _invalidInvite = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.l10n.pickNameError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final settings = ref.read(appSettingsProvider.notifier);
    final coordinator = ref.read(matchCoordinatorProvider);
    final next = (ref.read(appSettingsProvider).value ?? const AppSettings())
        .copyWith(
          nickname: name,
          avatar: _avatar,
          avatarPhoto: _avatarPhoto,
          clearAvatarPhoto: _avatarPhoto == null,
        );
    await settings.apply((_) => next);
    coordinator.updateSettings(next);
    await coordinator.joinMatch(widget.invite);
    if (!mounted) return;
    final state = coordinator.state;
    if (state.errorMessage != null) {
      setState(() {
        _busy = false;
        _error = state.errorMessage;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final errorMessage =
        _error ?? (_invalidInvite ? context.l10n.invalidInvite : null);
    ref.listen(appSettingsProvider, (previous, next) {
      final loaded = next.value;
      if (loaded == null || _name.text.isNotEmpty) return;
      setState(() {
        _name.text = loaded.nickname;
        _avatar = normalizeAvatar(loaded.avatar);
        _avatarPhoto = loaded.avatarPhoto;
      });
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _roomId == null
              ? context.l10n.joinAMatch
              : context.l10n.joinRoomTitle(_roomId!),
        ),
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.s20),
              children: <Widget>[
                Text(
                  context.l10n.joiningAs,
                  style: TextStyle(fontSize: 13, color: colors.ink2),
                ),
                const SizedBox(height: AppSpacing.s8),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: context.l10n.yourName,
                    helperText: context.l10n.nameShownAtTable,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.rControl),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s20),
                AvatarEditor(
                  avatar: _avatar,
                  photoBase64: _avatarPhoto,
                  onChanged: (avatar, photo) => setState(() {
                    _avatar = avatar;
                    _avatarPhoto = photo;
                  }),
                ),
                if (errorMessage != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.s16),
                  NoticeBanner(
                    message: errorMessage,
                    tone: StatusTone.warning,
                    icon: Icons.error_outline,
                  ),
                ],
                const SizedBox(height: AppSpacing.s24),
                PrimaryButton(
                  label: _busy
                      ? context.l10n.joining
                      : context.l10n.joinTheRoom,
                  busy: _busy,
                  onPressed: _busy ? null : () => unawaited(_join()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
