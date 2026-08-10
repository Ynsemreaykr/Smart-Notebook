import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/photo_note.dart';
import '../../application/providers/photo_note_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../widgets/bounce_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Transfer Modu
// ─────────────────────────────────────────────────────────────────────────────
enum TransferMode { move, tag, clone }

extension TransferModeExt on TransferMode {
  String get label {
    switch (this) {
      case TransferMode.move:
        return 'Taşı';
      case TransferMode.tag:
        return 'Etiketle';
      case TransferMode.clone:
        return 'Kopyala';
    }
  }

  IconData get icon {
    switch (this) {
      case TransferMode.move:
        return Icons.drive_file_move_rounded;
      case TransferMode.tag:
        return Icons.label_rounded;
      case TransferMode.clone:
        return Icons.copy_rounded;
    }
  }

  String get description {
    switch (this) {
      case TransferMode.move:
        return 'Mevcut üniteden çıkar, yeni üniteye taşı';
      case TransferMode.tag:
        return 'Her iki ünitede de görünsün (ortak)';
      case TransferMode.clone:
        return 'Bağımsız yeni bir kopyasını oluştur';
    }
  }

  Color get color {
    switch (this) {
      case TransferMode.move:
        return const Color(0xFF8B5CF6);
      case TransferMode.tag:
        return const Color(0xFF14B8A6);
      case TransferMode.clone:
        return const Color(0xFFF59E0B);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Genel API — dışarıdan çağrılacak fonksiyon
// ─────────────────────────────────────────────────────────────────────────────

/// Belirtilen [note] için hiyerarşik transfer panelini açar.
/// Kullanım: showTransferSheet(context, note);
Future<void> showTransferSheet(BuildContext context, PhotoNote note) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<PhotoNoteProvider>(),
      child: _TransferSheet(note: note),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Transfer Sheet — Ana Widget
// ─────────────────────────────────────────────────────────────────────────────

class _TransferSheet extends StatefulWidget {
  final PhotoNote note;
  const _TransferSheet({required this.note});

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet>
    with SingleTickerProviderStateMixin {
  /// Navigasyon adımı: 0 = Ana Klasörler, 1 = Alt Üniteler, 2 = Hedef Seçimi
  int _step = 0;
  String? _selectedTopLevel;
  String? _selectedFullPath; // hedef tam yol (ör. "Matematik / Ünite 2")

  TransferMode _mode = TransferMode.move;

  late final AnimationController _animController;
  late Animation<double> _fadeAnim;

  final _newCatController = TextEditingController();
  bool _showNewCatInput = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _newCatController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    _animController.forward(from: 0);
    setState(() {
      _step = step;
      _showNewCatInput = false;
      _newCatController.clear();
    });
  }

  // ── Renk & İkon yardımcıları ──

  Color _getCategoryColor(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('matematik') || c.contains('geometri')) return const Color(0xFFEC4899);
    if (c.contains('fizik') || c.contains('kimya')) return const Color(0xFF8B5CF6);
    if (c.contains('biyoloji')) return const Color(0xFF10B981);
    if (c.contains('tarih')) return const Color(0xFFD97706);
    if (c.contains('coğrafya') || c.contains('cografya')) return const Color(0xFF0EA5E9);
    if (c.contains('edebiyat') || c.contains('türkçe')) return const Color(0xFFF43F5E);
    return const Color(0xFF14B8A6);
  }

  IconData _getCategoryIcon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('matematik') || c.contains('geometri')) return Icons.calculate_rounded;
    if (c.contains('fizik') || c.contains('kimya')) return Icons.science_rounded;
    if (c.contains('biyoloji')) return Icons.biotech_rounded;
    if (c.contains('tarih')) return Icons.history_edu_rounded;
    if (c.contains('coğrafya') || c.contains('cografya')) return Icons.map_rounded;
    if (c.contains('edebiyat') || c.contains('türkçe')) return Icons.menu_book_rounded;
    return Icons.folder_rounded;
  }

  // ── Transfer işlemini gerçekleştir ──

  Future<void> _executeTransfer() async {
    if (_selectedFullPath == null) return;

    final provider = context.read<PhotoNoteProvider>();
    final target = _selectedFullPath!;
    final noteId = widget.note.id;

    Navigator.pop(context);

    String message;
    Color color;

    switch (_mode) {
      case TransferMode.move:
        await provider.movePhotoNote(noteId, target);
        message = '✅ Taşındı → $target';
        color = const Color(0xFF8B5CF6);
        break;
      case TransferMode.tag:
        await provider.tagPhotoNote(noteId, target);
        message = '🏷️ Etiketlendi → $target';
        color = const Color(0xFF14B8A6);
        break;
      case TransferMode.clone:
        await provider.clonePhotoNote(noteId, target);
        message = '📋 Kopyalandı → $target';
        color = const Color(0xFFF59E0B);
        break;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Tutma çubuğu ──
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Başlık + Geri + Kapat ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (_step > 0)
                  GestureDetector(
                    onTap: () => _goToStep(_step - 1),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.arrow_back_ios_rounded,
                          size: 18, color: Colors.white70),
                    ),
                  ),
                Expanded(child: _buildBreadcrumb()),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child:
                      const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── Kart önizleme ──
          _buildNotePreview(),

          // ── Mod Seçici ──
          _buildModeSelector(),

          const Divider(height: 1, color: Colors.white12),

          // ── Adıma göre içerik ──
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: SingleChildScrollView(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildStepContent(key: ValueKey(_step)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Breadcrumb ──

  Widget _buildBreadcrumb() {
    final parts = <String>['Ana Klasörler'];
    if (_selectedTopLevel != null) parts.add(_selectedTopLevel!);
    if (_step == 2 &&
        _selectedFullPath != null &&
        _selectedFullPath!.contains(' / ')) {
      parts.add(_selectedFullPath!.split(' / ').last);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: parts.asMap().entries.map((e) {
          final isLast = e.key == parts.length - 1;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                e.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isLast ? FontWeight.bold : FontWeight.normal,
                  color: isLast ? Colors.white : Colors.white54,
                ),
              ),
              if (!isLast)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 16, color: Colors.white38),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Kart Önizlemesi ──

  Widget _buildNotePreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: widget.note.imagePaths.isNotEmpty &&
                      File(widget.note.imagePaths.first).existsSync()
                  ? Image.file(
                      File(widget.note.imagePaths.first),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.white12,
                      child: const Icon(Icons.image_rounded,
                          color: Colors.white38),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.note.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.note.category.isEmpty ? 'Genel' : widget.note.category,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${widget.note.imagePaths.length} Görsel',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mod Seçici ──

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: TransferMode.values.map((mode) {
          final isSelected = _mode == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? mode.color.withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? mode.color : Colors.white12,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      mode.icon,
                      color: isSelected ? mode.color : Colors.white38,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? mode.color : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Adım İçeriği ──

  Widget _buildStepContent({required Key key}) {
    switch (_step) {
      case 0:
        return _buildTopLevelGrid(key: key);
      case 1:
        return _buildSubCategoryList(key: key);
      case 2:
        return _buildDestinationSelector(key: key);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Adım 0: Ana Klasörler Grid'i
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTopLevelGrid({required Key key}) {
    return Consumer<PhotoNoteProvider>(
      key: key,
      builder: (ctx, provider, _) {
        final topCats = provider.topLevelCategories;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hedef Klasörü Seçin',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              if (topCats.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: const [
                        Icon(Icons.folder_open_rounded,
                            color: Colors.white24, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'Henüz klasör yok.\nAşağıdan yeni klasör oluşturun.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: topCats.length,
                  itemBuilder: (_, i) {
                    final cat = topCats[i];
                    final color = _getCategoryColor(cat);
                    final icon = _getCategoryIcon(cat);
                    final count = provider.getNoteCountForCategory(cat);
                    final subCount =
                        provider.getSubCategories(cat).length;

                    return BounceButton(
                      onTap: () {
                        setState(() => _selectedTopLevel = cat);
                        final subs = provider.getSubCategories(cat);
                        if (subs.isEmpty) {
                          setState(() => _selectedFullPath = cat);
                          _goToStep(2);
                        } else {
                          _goToStep(1);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: color.withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                  Icon(icon, color: color, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    subCount > 0
                                        ? '$subCount ünite · $count not'
                                        : '$count not',
                                    style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (subCount > 0)
                              Icon(Icons.chevron_right_rounded,
                                  color: color, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 12),
              _buildAddNewInput(
                hint: 'Yeni klasör adı...',
                icon: Icons.create_new_folder_rounded,
                onAdd: (name) async {
                  await provider.addCategory(name);
                  setState(() {
                    _selectedTopLevel = name;
                    _selectedFullPath = name;
                  });
                  _goToStep(2);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Adım 1: Alt Üniteler Listesi
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSubCategoryList({required Key key}) {
    return Consumer<PhotoNoteProvider>(
      key: key,
      builder: (ctx, provider, _) {
        final subs =
            provider.getSubCategories(_selectedTopLevel ?? '');
        final topColor =
            _getCategoryColor(_selectedTopLevel ?? '');

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ana klasörün kendisine ekle seçeneği
              _buildUnitTile(
                icon: Icons.folder_special_rounded,
                color: topColor,
                label: _selectedTopLevel ?? '',
                subtitle: 'Ana klasöre doğrudan ekle',
                onTap: () {
                  setState(() => _selectedFullPath = _selectedTopLevel);
                  _goToStep(2);
                },
              ),
              if (subs.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Üniteler',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
                  ),
                ),
                ...subs.map((sub) {
                  final fullPath = '$_selectedTopLevel / $sub';
                  final count =
                      provider.getNoteCountForCategory(fullPath);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildUnitTile(
                      icon: Icons.bookmark_rounded,
                      color: const Color(0xFF14B8A6),
                      label: sub,
                      subtitle: '$count Görsel Not',
                      onTap: () {
                        setState(() => _selectedFullPath = fullPath);
                        _goToStep(2);
                      },
                    ),
                  );
                }),
              ],
              const SizedBox(height: 4),
              _buildAddNewInput(
                hint: 'Yeni ünite adı...',
                icon: Icons.add_rounded,
                onAdd: (name) async {
                  await provider.addSubCategory(
                      _selectedTopLevel ?? '', name);
                  final newPath = '$_selectedTopLevel / $name';
                  setState(() => _selectedFullPath = newPath);
                  _goToStep(2);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnitTile({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return BounceButton(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withOpacity(0.6), size: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Adım 2: Hedef Onay & Aktar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDestinationSelector({required Key key}) {
    final modeColor = _mode.color;

    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Özet kutusu
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: modeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: modeColor.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(_mode.icon, color: modeColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _mode.label,
                        style: TextStyle(
                            color: modeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      Text(
                        _mode.description,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Hedef yol
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded,
                    color: Colors.white54, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedFullPath ?? '—',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Onay butonu
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: modeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed:
                _selectedFullPath != null ? _executeTransfer : null,
            icon: Icon(_mode.icon, size: 20),
            label: Text(
              'Onayla ve ${_mode.label}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Yeni Kategori / Ünite Ekleme Giriş Kutusu
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAddNewInput({
    required String hint,
    required IconData icon,
    required Future<void> Function(String name) onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_showNewCatInput)
          TextButton.icon(
            onPressed: () => setState(() => _showNewCatInput = true),
            icon: Icon(icon, size: 16, color: Colors.white38),
            label: Text(
              '+ $hint',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newCatController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle:
                        const TextStyle(color: Colors.white38),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final name = _newCatController.text.trim();
                  if (name.isNotEmpty) await onAdd(name);
                },
                icon: const Icon(Icons.check_rounded,
                    color: Color(0xFF14B8A6)),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _showNewCatInput = false;
                  _newCatController.clear();
                }),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white38),
              ),
            ],
          ),
      ],
    );
  }
}
