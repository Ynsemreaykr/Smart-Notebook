import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/providers/theme_provider.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_radius.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common/app_text.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_container.dart';
import 'library/library_screen.dart';
import 'notes/notes_screen.dart';
import 'calendar/calendar_screen.dart';
import 'planner/planner_screen.dart';
import 'settings/settings_screen.dart';
import 'calculator/calculator_screen.dart';
import 'planner/pomodoro_screen.dart';
import 'scanner/scanner_screen.dart';
import 'notes/speech_text_screen.dart';
import 'notes/links_screen.dart';
import 'photo_notes/photo_notes_screen.dart';
import '../widgets/bounce_button.dart';
import '../widgets/fade_slide_entrance.dart';

class HomeScreen extends StatelessWidget {
  static final ValueNotifier<int> selectedIndex = ValueNotifier(0);
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 650;

    return AppContainer(
      hasGradient: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Icon(Icons.menu_book_rounded, size: 26),
              ),
              AppSpacing.gapWSm,
              ShaderMask(
                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const AppText(
                  'Smart Notebook',
                  styleType: AppTextStyleType.headingMedium,
                  styleOverride: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Ayarlar',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            AppSpacing.gapWSm,
          ],
        ),
        body: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? AppSpacing.xxl : AppSpacing.xl,
            vertical: AppSpacing.xl,
          ),
          children: [
            // Header Welcome Card
            FadeSlideEntrance(
              delay: const Duration(milliseconds: 100),
              child: _buildWelcomeCard(context, isTablet),
            ),
            const SizedBox(height: 28),

            // Section header 1
            FadeSlideEntrance(
              delay: const Duration(milliseconds: 150),
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 14),
                child: AppText(
                  'ANA MENÜ',
                  styleType: AppTextStyleType.caption,
                  styleOverride: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),

            // Primary Feature Cards
            isTablet
                ? GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 2.3,
                    children: _buildPrimaryFeatureList(context),
                  )
                : Column(children: _buildPrimaryFeatureList(context)),

            const SizedBox(height: 28),

            // Section header 2
            FadeSlideEntrance(
              delay: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 14),
                child: AppText(
                  'DİĞER ARAÇLAR',
                  styleType: AppTextStyleType.caption,
                  styleOverride: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),

            // Secondary Feature Cards
            isTablet
                ? GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 2.3,
                    children: _buildSecondaryFeatureList(context),
                  )
                : Column(children: _buildSecondaryFeatureList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, bool isTablet) {
    return AppCard(
      padding: EdgeInsets.all(isTablet ? AppSpacing.xxl : AppSpacing.xl),
      margin: EdgeInsets.zero,
      gradient: const LinearGradient(
        colors: [Color(0xFF1A2550), Color(0xFF0D1435)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: AppColors.primary.withOpacity(0.25),
      shadowColor: AppColors.primary,
      child: Stack(
        children: [
          // Decorative glow orb top-right
          Positioned(
            top: -20,
            right: -10,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      boxShadow: AppColors.glowShadow(intensity: 0.5),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                  ),
                  AppSpacing.gapWMd,
                  const AppText(
                    'Hoş Geldiniz 👋',
                    styleType: AppTextStyleType.headingLarge,
                    color: Colors.white,
                  ),
                ],
              ),
              AppSpacing.gapHMd,
              AppText(
                'Çalışma alanınızı düzenlemek ve notlarınızı yönetmek için aşağıdaki özelliklerden birini seçin.',
                styleType: AppTextStyleType.bodyMedium,
                color: AppColors.textSecondary.withOpacity(0.9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPrimaryFeatureList(BuildContext context) {
    final List<Map<String, dynamic>> features = [
      {
        'title': 'Belge Tarayıcı',
        'subtitle': 'A4 belgelerinizi kamerayla tarayıp kütüphaneye aktarın.',
        'icon': Icons.document_scanner_rounded,
        'color': const Color(0xFF06B6D4),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())),
      },
      {
        'title': 'Ses & Metin',
        'subtitle': 'Konuşmalarınızı anlık olarak yazılı nota dönüştürün.',
        'icon': Icons.mic_rounded,
        'color': const Color(0xFFA855F7),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeechTextScreen())),
      },
      {
        'title': 'Kütüphanem',
        'subtitle': 'Defterlerinizi, PDF belgelerinizi ve çizimlerinizi yönetin.',
        'icon': Icons.library_books_rounded,
        'color': AppColors.primary,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryScreen())),
      },
      {
        'title': 'Linklerim',
        'subtitle': 'Etkinlikler, notlar ve alışkanlıklar arası tüm bağlantılar.',
        'icon': Icons.link_rounded,
        'color': const Color(0xFF2DD4BF),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LinksScreen())),
      },
    ];

    return List.generate(features.length, (index) {
      final item = features[index];
      return FadeSlideEntrance(
        delay: Duration(milliseconds: 150 + (index * 55)),
        child: BounceButton(
          onTap: item['onTap'],
          child: _buildFeatureCard(
            context,
            title: item['title'] as String,
            subtitle: item['subtitle'] as String,
            icon: item['icon'] as IconData,
            color: item['color'] as Color,
          ),
        ),
      );
    });
  }

  List<Widget> _buildSecondaryFeatureList(BuildContext context) {
    final List<Map<String, dynamic>> features = [
      {
        'title': 'Planlayıcı',
        'subtitle': 'Günlük alışkanlıklarınızı ve görevlerinizi takip edin.',
        'icon': Icons.assignment_rounded,
        'color': AppColors.accent,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlannerScreen())),
      },
      {
        'title': 'Pomodoro',
        'subtitle': 'Pomodoro ve odaklanma seanslarınızı başlatın.',
        'icon': Icons.timer_rounded,
        'color': const Color(0xFFEF4444),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PomodoroScreen())),
      },
      {
        'title': 'Takvim',
        'subtitle': 'Planlarınızı, etkinliklerinizi ve randevularınızı takip edin.',
        'icon': Icons.calendar_month_rounded,
        'color': const Color(0xFF3B82F6),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
      },
      {
        'title': 'Not Defteri',
        'subtitle': 'Hızlıca notlar alın, düzenleyin ve hatırlatıcılar kurun.',
        'icon': Icons.sticky_note_2_rounded,
        'color': const Color(0xFFF59E0B),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesScreen())),
      },
      {
        'title': 'Hesap Makinesi',
        'subtitle': 'Gelişmiş bilimsel işlemler ve parantezli formülleri hesaplayın.',
        'icon': Icons.calculate_rounded,
        'color': const Color(0xFFEC4899),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalculatorScreen())),
      },
      {
        'title': 'Görsel Notlar',
        'subtitle': 'Görsellerinizi etiketleyip ders konu kartı olarak sınıflandırın.',
        'icon': Icons.photo_library_rounded,
        'color': const Color(0xFF14B8A6),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoNotesScreen())),
      },
    ];

    return List.generate(features.length, (index) {
      final item = features[index];
      return FadeSlideEntrance(
        delay: Duration(milliseconds: 200 + (index * 55)),
        child: BounceButton(
          onTap: item['onTap'],
          child: _buildFeatureCard(
            context,
            title: item['title'] as String,
            subtitle: item['subtitle'] as String,
            icon: item['icon'] as IconData,
            color: item['color'] as Color,
          ),
        ),
      );
    });
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      borderColor: color.withOpacity(0.22),
      shadowColor: color,
      child: Row(
        children: [
          // Icon box with matching glow
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: color.withOpacity(0.28), width: 1),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.20),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          AppSpacing.gapWLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppText(
                  title,
                  styleType: AppTextStyleType.headingSmall,
                ),
                AppSpacing.gapHXs,
                AppText(
                  subtitle,
                  styleType: AppTextStyleType.bodySmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          AppSpacing.gapWSm,
          Icon(
            Icons.chevron_right_rounded,
            color: color.withOpacity(0.7),
            size: 22,
          ),
        ],
      ),
    );
  }
}
