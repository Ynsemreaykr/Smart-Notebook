import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_container.dart';
import '../../../widgets/common/app_text.dart';
import '../../widgets/bounce_button.dart';
import '../../widgets/fade_slide_entrance.dart';
import '../../widgets/empty_state_widget.dart';
import '../../../data/services/links_widget_service.dart';

class LinksScreen extends StatefulWidget {
  const LinksScreen({super.key});

  @override
  State<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends State<LinksScreen> {
  List<Map<String, String>> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    // Update widget upon entry to sync any changes
    LinksWidgetService.updateWidget();
  }

  @override
  void dispose() {
    // Update widget upon exit to make sure all changes are synced
    LinksWidgetService.updateWidget();
    super.dispose();
  }

  // Load links from the Settings Hive box
  void _loadBookmarks() {
    setState(() => _isLoading = true);
    try {
      final box = Hive.box('settings');
      final List<dynamic>? saved = box.get('bookmark_links');
      if (saved != null) {
        _bookmarks = saved.map((item) => Map<String, String>.from(item as Map)).toList();
      } else {
        _bookmarks = [];
      }
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
    }
    setState(() => _isLoading = false);
  }

  // Save links list back to Settings Hive box and sync the home screen widget
  Future<void> _saveBookmarks() async {
    try {
      final box = Hive.box('settings');
      await box.put('bookmark_links', _bookmarks);
      // Sync data to Android home screen widget
      await LinksWidgetService.updateWidget();
    } catch (e) {
      debugPrint('Error saving bookmarks: $e');
    }
  }

  // Add a new link
  void _addLink(String label, String url, {bool showInWidget = true}) {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _bookmarks.add({
        'id': newId,
        'label': label,
        'url': url,
        'show_in_widget': showInWidget ? 'true' : 'false',
      });
    });
    _saveBookmarks();
  }

  // Edit link values
  void _editLink(String id, {String? label, String? url, bool? showInWidget}) {
    setState(() {
      final idx = _bookmarks.indexWhere((b) => b['id'] == id);
      if (idx != -1) {
        if (label != null) _bookmarks[idx]['label'] = label;
        if (url != null) _bookmarks[idx]['url'] = url;
        if (showInWidget != null) {
          _bookmarks[idx]['show_in_widget'] = showInWidget ? 'true' : 'false';
        }
      }
    });
    _saveBookmarks();
  }

  // Toggle visibility of a bookmark in the home screen widget
  void _toggleWidgetVisibility(String id) {
    setState(() {
      final idx = _bookmarks.indexWhere((b) => b['id'] == id);
      if (idx != -1) {
        final currentVal = _bookmarks[idx]['show_in_widget'] ?? 'true';
        _bookmarks[idx]['show_in_widget'] = currentVal == 'true' ? 'false' : 'true';
      }
    });
    _saveBookmarks();
  }

  // Delete link
  void _deleteLink(String id) {
    setState(() {
      _bookmarks.removeWhere((b) => b['id'] == id);
    });
    _saveBookmarks();
  }

  // Launch link in default app
  Future<void> _launchLink(String url) async {
    String formattedUrl = url.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    // Automatically copy the link to the clipboard
    await Clipboard.setData(ClipboardData(text: formattedUrl));
    
    // Try launching the URL directly in default browser
    try {
      final uri = Uri.parse(formattedUrl);
      final bool success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success) {
        throw Exception('launchUrl returned false');
      }
    } catch (e) {
      debugPrint('MethodChannel launch failed, showing fallback options: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlantı kopyalandı ve tarayıcıda açılmaya çalışılıyor: $formattedUrl'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Open modal bottom sheet to add/edit bookmark
  void _showLinkDialog({String? editId, String? currentLabel, String? currentUrl}) {
    final labelCtrl = TextEditingController(text: currentLabel);
    final urlCtrl = TextEditingController(text: currentUrl);
    final isEdit = editId != null;

    bool showInWidget = true;
    if (isEdit) {
      final item = _bookmarks.firstWhere((b) => b['id'] == editId, orElse: () => {});
      showInWidget = item['show_in_widget'] != 'false';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: AppText(
              isEdit ? 'Bağlantıyı Düzenle' : 'Yeni Bağlantı Ekle',
              styleType: AppTextStyleType.headingMedium,
              styleOverride: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  autofocus: !isEdit,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Etiket Adı',
                    hintText: 'örn. Google Drive',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: urlCtrl,
                  keyboardType: TextInputType.url,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Bağlantı Adresi (URL)',
                    hintText: 'örn. drive.google.com',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                CheckboxListTile(
                  title: const AppText('Widget\'ta Göster', styleType: AppTextStyleType.bodyMedium),
                  value: showInWidget,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setDialogState(() {
                      showInWidget = val ?? true;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: AppText(
                  'İptal',
                  styleType: AppTextStyleType.label,
                  color: AppColors.textSecondary,
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
                onPressed: () {
                  final label = labelCtrl.text.trim();
                  final url = urlCtrl.text.trim();
                  if (label.isEmpty || url.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lütfen tüm alanları doldurun.')),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  if (isEdit) {
                    _editLink(editId, label: label, url: url, showInWidget: showInWidget);
                  } else {
                    _addLink(label, url, showInWidget: showInWidget);
                  }
                },
                child: const AppText(
                  'Kaydet',
                  styleType: AppTextStyleType.label,
                  color: Colors.white,
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  // Info dialog for Linklerim feature
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText(
          '🔗 Linklerim Hakkında',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: AppText(
            'Bu özellik, sık kullandığınız web adreslerini (URL) etiketleriyle birlikte kaydetmenizi sağlar.\n\n'
            'Nasıl Çalışır?\n'
            '1. Sağ alttaki (+) butona basarak yeni bir etiket ve bağlantı ekleyin.\n'
            '2. Listelenen kartlara tıkladığınızda link doğrudan telefonunuzun varsayılan tarayıcısında açılır.\n'
            '3. Kartların sağındaki menüden linkleri git, etiket veya adresi düzenle veya silebilirsiniz.\n\n'
            '📱 Ana Ekran Widget Desteği:\n'
            '• Kaydettiğiniz linkleri telefonunuzun ana ekranına widget olarak ekleyebilirsiniz.\n'
            '• Kart ekleme/düzenleme ekranında "Widget\'ta Göster" seçeneğini açıp kapatarak hangi linklerin widget\'ta görüneceğini belirleyebilirsiniz.\n'
            '• Widget\'ı eklemek için ana ekrana basılı tutun, Widget\'lar menüsünden "Smart Notebook" -> "Linklerim" ögesini seçip ekranınıza yerleştirin.',
            styleType: AppTextStyleType.bodyMedium,
            styleOverride: TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: AppText(
              'Kapat',
              styleType: AppTextStyleType.label,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // Open bookmark card details bottom sheet
  void _showBookmarkDetails(Map<String, String> bookmark) {
    final bool showInWidget = bookmark['show_in_widget'] != 'false';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppText(
                  bookmark['label'] ?? '',
                  styleType: AppTextStyleType.headingSmall,
                  styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ListTile(
                leading: Icon(Icons.open_in_browser_rounded, color: AppColors.glow),
                title: const AppText('Linke Git', styleType: AppTextStyleType.bodyMedium),
                onTap: () {
                  Navigator.pop(context);
                  _launchLink(bookmark['url'] ?? '');
                },
              ),
              ListTile(
                leading: Icon(
                  showInWidget ? Icons.widgets_rounded : Icons.widgets_outlined,
                  color: showInWidget ? AppColors.primary : AppColors.textSecondary,
                ),
                title: const AppText('Widget\'ta Göster', styleType: AppTextStyleType.bodyMedium),
                trailing: Switch(
                  value: showInWidget,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    Navigator.pop(context);
                    _toggleWidgetVisibility(bookmark['id']!);
                  },
                ),
              ),
              ListTile(
                leading: Icon(Icons.edit_rounded, color: AppColors.accent),
                title: const AppText('Bağlantıyı Düzenle', styleType: AppTextStyleType.bodyMedium),
                onTap: () {
                  Navigator.pop(context);
                  _showLinkDialog(
                    editId: bookmark['id'],
                    currentLabel: bookmark['label'],
                    currentUrl: bookmark['url'],
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const AppText('Bağlantıyı Sil', styleType: AppTextStyleType.bodyMedium, color: Colors.redAccent),
                onTap: () {
                  Navigator.pop(context);
                  _deleteLink(bookmark['id'] ?? '');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return AppContainer(
      hasGradient: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const AppText(
            '🔗 Linklerim',
            styleType: AppTextStyleType.headingMedium,
            styleOverride: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: 'Bilgi',
              onPressed: () => _showInfoDialog(context),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _bookmarks.isEmpty
                ? const EmptyStateWidget(
                    icon: Icons.link_off_rounded,
                    title: 'Kayıtlı Link Yok',
                    subtitle: 'Hızlı erişmek istediğiniz bağlantıları buraya ekleyin.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                    itemCount: _bookmarks.length,
                    itemBuilder: (context, index) {
                      final bookmark = _bookmarks[index];
                      return FadeSlideEntrance(
                        delay: Duration(milliseconds: index * 40),
                        child: AppCard(
                          padding: EdgeInsets.zero,
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          borderColor: AppColors.glow.withOpacity(0.18),
                          shadowColor: AppColors.glow,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
                            title: Row(
                              children: [
                                Expanded(
                                  child: AppText(
                                    bookmark['label'] ?? 'İsimsiz Bağlantı',
                                    styleType: AppTextStyleType.headingSmall,
                                    styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (bookmark['show_in_widget'] != 'false')
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Icon(
                                      Icons.widgets_rounded,
                                      size: 14,
                                      color: AppColors.primary.withOpacity(0.8),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                              onPressed: () => _showBookmarkDetails(bookmark),
                            ),
                            onTap: () => _launchLink(bookmark['url'] ?? ''),
                          ),
                        ),
                      );
                    },
      ),
      floatingActionButton: BounceButton(
        onTap: () => _showLinkDialog(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.large),
            boxShadow: AppColors.glowShadow(intensity: 0.6),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    ),
  );
}
}
