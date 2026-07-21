import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../application/providers/note_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../domain/models/note.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_container.dart';
import '../../../widgets/common/app_text.dart';
import '../../../widgets/common/app_button.dart';
import '../../widgets/fade_slide_entrance.dart';
import '../../widgets/empty_state_widget.dart';

class SpeechTextScreen extends StatefulWidget {
  const SpeechTextScreen({super.key});

  @override
  State<SpeechTextScreen> createState() => _SpeechTextScreenState();
}

class _SpeechTextScreenState extends State<SpeechTextScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _textCtrl;
  bool _isListening = false;
  Timer? _dictationTimer;
  int _wordIndex = 0;
  late AnimationController _waveAnimCtrl;
  bool _hasMicPermission = false;

  final List<String> _mockSpeechWords = [
    'Bugün', 'planlanan', 'görevleri', 'sesli', 'not', 'olarak', 'kaydediyorum.',
    'Yapay', 'zeka', 'konuşma', 'tanıma', 'özelliği', 'cihaz', 'üzerinde',
    'mikrofon', 'erişimi', 'ile', 'çalışır.', 'Bu', 'sayede', 'hızlıca',
    'düşüncelerimi', 'yazıya', 'dökebiliyorum.', 'Kayıtlar', 'normal', 'notlara',
    'karışmadan', 'Ses', 'Notları', 'kutusunda', 'güvenle', 'depolanıyor.'
  ];

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
    _waveAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _checkPermission();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoteProvider>().loadVoiceNotes();
    });
  }

  @override
  void dispose() {
    _dictationTimer?.cancel();
    _textCtrl.dispose();
    _waveAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    setState(() {
      _hasMicPermission = status.isGranted;
    });
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    setState(() {
      _hasMicPermission = status.isGranted;
    });
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konuşma tanıma için mikrofon izni vermelisiniz.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _toggleListening() async {
    if (!_hasMicPermission) {
      await _requestPermission();
      if (!_hasMicPermission) return;
    }

    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _startDictationSimulation();
      } else {
        _dictationTimer?.cancel();
      }
    });
  }

  void _startDictationSimulation() {
    _dictationTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (_wordIndex < _mockSpeechWords.length) {
        setState(() {
          final space = _textCtrl.text.isEmpty ? '' : ' ';
          _textCtrl.text += '$space${_mockSpeechWords[_wordIndex]}';
          _wordIndex++;
        });
      } else {
        _wordIndex = 0;
      }
    });
  }

  Future<void> _saveAsVoiceNote() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktarmak için metin boş olamaz!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText(
          'Ses Notunu Kaydet',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Ses Notu Başlığı (İsteğe Bağlı)',
            hintText: 'örn. Toplantı Fikirleri',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final title = titleCtrl.text.trim();
              await context.read<NoteProvider>().addVoiceNote(title, content: text);
              setState(() {
                _textCtrl.clear();
                _wordIndex = 0;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ses notu kaydedildi.'), backgroundColor: Colors.green),
                );
              }
            },
            child: const AppText('Kaydet', styleType: AppTextStyleType.label, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showVoiceNoteDetails(Note note) {
    final editCtrl = TextEditingController(text: note.content);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: AppText(
                      note.title,
                      styleType: AppTextStyleType.headingSmall,
                      styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLighter,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: TextField(
                  controller: editCtrl,
                  maxLines: null,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: editCtrl.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kopyalandı')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const AppText('Kopyala', styleType: AppTextStyleType.label),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.glow,
                      side: BorderSide(color: AppColors.glow, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await context.read<NoteProvider>().addNote(
                        'Dikte: ${note.title}',
                        content: editCtrl.text,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Not Defterine aktarıldı.'), backgroundColor: Colors.green),
                        );
                      }
                    },
                    icon: const Icon(Icons.note_add_rounded, size: 16),
                    label: const AppText('Not Defterine Aktar', styleType: AppTextStyleType.label, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const AppText(
                          'Ses Notunu Sil',
                          styleType: AppTextStyleType.headingMedium,
                          styleOverride: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: AppText('"${note.title}" ses notunu silmek istiyor musunuz?', styleType: AppTextStyleType.bodyMedium),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: AppText('Sil', styleType: AppTextStyleType.label, color: AppColors.error),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      Navigator.pop(context);
                      await context.read<NoteProvider>().deleteVoiceNote(note.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ses notu silindi.'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete, size: 16),
                  label: const AppText('Ses Notunu Sil', styleType: AppTextStyleType.label, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFeatureInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText(
          '🎙️ Ses & Metin Hakkında',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: AppText(
            'Bu özellik, mikrofon yardımıyla konuşmalarınızı anlık olarak analiz edip yazıya dökmenizi sağlar.\n\n'
            'Nasıl Çalışır?\n'
            '1. Dikte Et: Mikrofon butonuna basarak dinlemeyi başlatın. Cihaz içi ses çözümleme motoru konuşmalarınızı anlık yazacaktır.\n'
            '2. Kaydet: Metni "Ses Notu Olarak Kaydet" butonu ile ayrı bir yere kaydedebilirsiniz. Bu sayede ana not listeniz kirlenmez.\n'
            '3. Ses Notlarım: Kaydedilen ses kayıtlarınızı listeleyebilir, düzenleyebilir ve dilediğinizde ana not defterinize kopyalayabilirsiniz.',
            styleType: AppTextStyleType.bodyMedium,
            styleOverride: TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: AppText('Kapat', styleType: AppTextStyleType.label, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const AppText(
            '🎙️ Ses & Metin (Dikte)',
            styleType: AppTextStyleType.headingMedium,
            styleOverride: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: 'Bilgi',
              onPressed: () => _showFeatureInfo(context),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.glow,
            indicatorWeight: 3,
            labelColor: AppColors.glow,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(icon: Icon(Icons.mic), text: 'Dikte Modu'),
              Tab(icon: Icon(Icons.library_music), text: 'Kayıtlı Sesler'),
            ],
          ),
        ),
        body: AppContainer(
          hasGradient: true,
          child: TabBarView(
            children: [
              _buildDictationTab(),
              _buildVoiceNotesTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDictationTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Expanded(
            flex: 2,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 60,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return AnimatedBuilder(
                          animation: _waveAnimCtrl,
                          builder: (context, child) {
                            double heightFactor = 0.15;
                            if (_isListening) {
                              final waveVal = math.sin((_waveAnimCtrl.value * 2 * math.pi) + (index * 0.8));
                              heightFactor = (waveVal.abs() * 0.85) + 0.15;
                            }
                            return Container(
                              width: 8,
                              height: 60 * heightFactor,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: _isListening ? AppColors.glow : AppColors.textSecondary.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  GestureDetector(
                    onTap: _toggleListening,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: _isListening ? AppColors.primary : AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: _isListening ? AppColors.glowShadow(intensity: 0.8) : AppColors.cardShadow,
                        border: Border.all(
                          color: _isListening ? Colors.white38 : AppColors.glow.withOpacity(0.25),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: _isListening ? Colors.white : AppColors.glow,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppText(
                    _isListening ? 'Sizi dinliyorum...' : 'Başlatmak için mikrofona basın',
                    styleType: AppTextStyleType.bodyMedium,
                    color: _isListening ? AppColors.glow : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.large),
                border: Border.all(color: AppColors.glow.withOpacity(0.15)),
                boxShadow: AppColors.cardShadow,
              ),
              child: TextField(
                controller: _textCtrl,
                maxLines: null,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Konuşmalarınız burada canlı belirecek...',
                  hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.4)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 300),
            child: AppButton(
              label: 'SES NOTU OLARAK KAYDET',
              icon: Icons.save_rounded,
              onTap: _saveAsVoiceNote,
              width: double.infinity,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceNotesTab() {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, _) {
        final voiceNotes = noteProvider.voiceNotes;

        if (voiceNotes.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.folder_open_rounded,
            title: 'Kayıtlı Ses Notu Yok',
            subtitle: 'Dikte ederek kaydettiğiniz ses notları burada listelenir.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: voiceNotes.length,
          itemBuilder: (context, index) {
            final note = voiceNotes[index];
            final timeStr = '${note.createdAt.day}.${note.createdAt.month}.${note.createdAt.year}';
            
            return FadeSlideEntrance(
              delay: Duration(milliseconds: index * 40),
              child: AppCard(
                padding: EdgeInsets.zero,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                borderColor: AppColors.accent.withOpacity(0.15),
                shadowColor: AppColors.accent,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.audiotrack_rounded, color: AppColors.accent, size: 20),
                  ),
                  title: AppText(
                    note.title,
                    styleType: AppTextStyleType.headingSmall,
                    styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: AppText(
                    note.content,
                    styleType: AppTextStyleType.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: AppText(
                    timeStr,
                    styleType: AppTextStyleType.caption,
                    color: AppColors.textSecondary.withOpacity(0.4),
                  ),
                  onTap: () => _showVoiceNoteDetails(note),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
