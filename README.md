# Smart Notebook v0.0

Smart Notebook, kullanıcıların dijital ortamda kitap formatında not defterleri oluşturabilmesini sağlayan çok fonksiyonlu bir mobil uygulamadır. Bu uygulama ile sayfalar halinde metin yazabilir, çizim yapabilir, sayfaları yönetebilir ve tüm kitabınızı PDF olarak dışa aktarabilirsiniz.

## Özellikler

- **Gelişmiş Metin ve Çizim Editörü:** Her sayfada hem detaylı metin araçları (kalın, italik, punto boyutu) hem de katmanlı çizim özellikleri (kalem, silgi, geri al, tümünü sil) bir arada kullanılabilir. Yazdığınız notlar veya çizimler eş zamanlı olarak alt alta (PageView mantığıyla) sıralanır.
- **Kitap ve Bölüm Hiyerarşisi:** Notlarınız "Kitaplar" altında "Bölümler" (Sayfalar) halinde tutulur. İstediğiniz kitaba sayısız bölüm ekleyebilirsiniz.
- **Kitap Okuma Modu (Reader):** "Kitabı Oku" sekmesi ile oluşturduğunuz tüm sayfaları kaydırmalı kitap okuma arayüzünde tam ekran olarak okuyabilirsiniz. Alt bardaki **"İçindekiler"** butonu ile kitabınızın bölümlerini listeleyip, dilediğiniz bölüme atlayabilirsiniz.
- **PDF Dışa Aktarma:** Tek bir sayfayı, seçtiğiniz birden fazla sayfayı veya tüm kitabınızı estetik bir başlık hiyerarşisiyle (Kitap Başlığı → Bölüm Başlığı → Çizgi → İçerik) saniyeler içinde PDF formatına dönüştürüp paylaşabilirsiniz.
- **Otomatik Kaydetme:** Editörden cihazın veya uygulamanın Geri tuşu ile çıkış yaptığınızda, tüm sayfa değişiklikleriniz güvenli bir şekilde otomatik kaydedilir. Ayrı bir kaydetme butonuna basmanıza gerek yoktur.

## Teknolojiler ve Kütüphaneler

Bu proje **Flutter** kullanılarak geliştirilmiştir. Önemli bağımlılıklar:
- `provider`: Durum (State) yönetimi için (BookProvider, PageProvider, PdfProvider).
- `flutter_drawing_board`: Sayfa içi çizim işlemlerini sağlayan ana kütüphane.
- `pdf` & `printing`: Not defterlerinin döküman ve kapak düzeniyle PDF formatında çıktı alınabilmesi için.

## Kurulum ve Çalıştırma Talimatları (Geliştiriciler İçin)

Projeyi bilgisayarınıza klonladıktan sonra aşağıdaki adımları izleyerek projeyi kendi cihazınızda derleyip çalıştırabilirsiniz:

1. **Flutter SDK'yı Kontrol Edin:** Sisteminizde Flutter'ın güncel bir sürümünün kurulu olduğundan emin olun.
   ```bash
   flutter --version
   ```
2. **Projeyi Klonlayın:**
   ```bash
   git clone <proje_github_adresi>
   cd stduio_proje
   ```
3. **Bağımlılıkları İndirin:**
   Projenin ihtiyaç duyduğu kütüphaneleri `pubspec.yaml` üzerinden yükleyin.
   ```bash
   flutter pub get
   ```
4. **Projeyi Başlatın:**
   Android/iOS emülatörünüzde veya bağlı fiziksel cihazınızda çalıştırmak için:
   ```bash
   flutter run
   ```

## Kod ve Dosya Yapısı

Proje "Clean Architecture" prensiplerine yakın, düzenli bir klasör sistemine sahiptir:
- `lib/domain/models`: Kitap (Book) ve Sayfa (PageData) veri modelleri.
- `lib/data/repositories`: Verilerin yönetilmesini (kaydetme/okuma) sağlayan servisler.
- `lib/application/providers`: Kullanıcı arayüzünden tetiklenen olayların ele alındığı Business Logic / State Management katmanı.
- `lib/presentation/screens`: Kullanıcı arayüzleri.
  - **`page_editor_screen.dart`**: Not alınan ve çizim yapılan tam ekran editör. Sayfalar arası geçişi sağlayan butonlarla, temiz bir `PageView` kullanır.
  - **`book_reader_screen.dart`**: İçindekiler kısmı (TOC Bottom Sheet) bulunan ve gelişmiş (JSON) çizim sayfalarını çözümleyerek (parse) düz bir kitap okuma akışına (ReaderPage yapısına) çeviren okunabilir ekran tasarımı.
  
---
**Smart Notebook**, not alma deneyimini zenginleştirmeyi ve dijital defterlere modern bir yorum katmayı hedefler. Sürüm 0.0 itibariyle projenin ana mimarisi oturtulmuştur.
