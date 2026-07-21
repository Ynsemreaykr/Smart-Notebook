import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bounce_button.dart';
import '../../widgets/fade_slide_entrance.dart';

class AudioTextScreen extends StatelessWidget {
  const AudioTextScreen({super.key});

  void _showRequirements(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined, color: AppColors.primaryColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Ses & Metin Teknik Analiz',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionTitle('Gerekli Paketler'),
              _buildBulletPoint('`speech_to_text: ^6.6.0` (Cihaz içi anlık konuşma tanıma)'),
              _buildBulletPoint('`record: ^5.0.0` (Farklı formatlarda ses kaydı)'),
              _buildBulletPoint('`path_provider: ^2.1.0` (Ses dosyalarının yerel depolanması)'),
              const SizedBox(height: 12),
              _buildSectionTitle('Yapay Zeka ve ML Modelleri'),
              _buildBulletPoint('**Çevrimdışı (On-Device)**: Google ML Kit Speech-to-Text veya yerel Vosk SDK.'),
              _buildBulletPoint('**Çevrimiçi (Online Cloud)**: OpenAI Whisper API veya Google Cloud Speech-to-Text API.'),
              const SizedBox(height: 12),
              _buildSectionTitle('Çevrimiçi vs Çevrimdışı Karşılaştırması'),
              _buildBulletPoint('**Çevrimdışı**: İnternet bağlantısı gerektirmez, gizlilik odaklıdır. Ancak Türkçe doğruluk oranı daha düşüktür.'),
              _buildBulletPoint('**Çevrimiçi (Whisper)**: Olağanüstü doğruluk oranı, arka plan gürültülerini filtreleme ve noktalama işaretlerini otomatik ekleme özellikleri sunar. İnternet ve API maliyeti oluşturur.'),
              const SizedBox(height: 12),
              _buildSectionTitle('Performans Kriterleri'),
              _buildBulletPoint('Gecikme Süresi: Canlı akışta < 2.0sn yanıt süresi.'),
              _buildBulletPoint('Sıkıştırma: Kayıtlar AAC/M4A formatında 48kbps hızında tutularak depolama optimize edilir.'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Anladım', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.glowColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: AppColors.primaryColor, fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Ses & Metin', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 100),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accentColor.withValues(alpha: 0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentColor.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    size: 64,
                    color: AppColors.accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'Yapay Zeka Destekli Ses & Metin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 300),
                child: Text(
                  'Sesli notlarınızı en yüksek doğrulukla metne dökebilecek ve özetleyebilecek yapay zeka modülü çok yakında sizinle!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 400),
                child: BounceButton(
                  onTap: () => _showRequirements(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: AppTheme.primaryGlow(intensity: 0.4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Teknik Gereksinimler & Analiz',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }
}

class A4ScannerScreen extends StatelessWidget {
  const A4ScannerScreen({super.key});

  void _showRequirements(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined, color: AppColors.primaryColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Belge Tara Teknik Analiz',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionTitle('Gerekli Paketler'),
              _buildBulletPoint('`google_mlkit_document_scanner: ^0.1.0` (ML Kit Belge Tarama SDK)'),
              _buildBulletPoint('`camera: ^0.10.5` (Özel vizör/kamera kontrolleri için)'),
              _buildBulletPoint('`pdf: ^3.10.0` (Görüntüleri A4 PDF dosyasına paketlemek için)'),
              const SizedBox(height: 12),
              _buildSectionTitle('Yapay Zeka ve Görüntü İşleme Modelleri'),
              _buildBulletPoint('**Google ML Kit Document Scanner API**: Perspektif düzeltme, kenar algılama, gölge kaldırma ve siyah-beyaz filtreleme işlemlerini cihaz üzerinde yüksek hızda gerçekleştirir.'),
              _buildBulletPoint('**Cihaz İçi Kırpma Algoritması**: Görüntüyü otomatik olarak A4 en-boy oranına (1:1.414) oturtur.'),
              const SizedBox(height: 12),
              _buildSectionTitle('Çevrimiçi vs Çevrimdışı Karşılaştırması'),
              _buildBulletPoint('**Çevrimdışı (ML Kit)**: Tamamen yerel çalışır, veri sızıntılarını önler ve anında perspektif kırpma yapar. Ağ gecikmesi yoktur.'),
              _buildBulletPoint('**Çevrimiçi**: Bulut tabanlı OCR sistemleri el yazısını daha iyi tanıyabilir ancak internet hızı ve yüksek sunucu işlem maliyeti gerektirir. Bu modül için **çevrimdışı on-device** model tercih edilmiştir.'),
              const SizedBox(height: 12),
              _buildSectionTitle('Performans Kriterleri'),
              _buildBulletPoint('Otomatik kenar algılama süresi < 150ms.'),
              _buildBulletPoint('Dosya boyutu optimizasyonu: Tarama başına PDF sayfa boyutu < 250KB (kalite kaybı olmadan).'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Anladım', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.glowColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: AppColors.primaryColor, fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Belge Tara', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 100),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    size: 64,
                    color: Colors.cyan,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'Belge Tara (A4 -> PDF)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 300),
                child: Text(
                  'Fiziksel kağıtlarınızı kameranızla tarayıp otomatik kenar algılama ve perspektif düzeltme ile net A4 PDF veya notebook sayfalarına dönüştürün.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 400),
                child: BounceButton(
                  onTap: () => _showRequirements(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: AppTheme.primaryGlow(intensity: 0.4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Teknik Gereksinimler & Analiz',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
