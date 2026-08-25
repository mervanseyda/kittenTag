# kittenTag — doğrulanmış özellikler

Bu liste yalnızca mevcut uygulamada çalışan özellikleri içerir. Site metninde henüz geliştirilmemiş özellikler vaat edilmemelidir.

## Temel özellikler

- Tek tek ses dosyaları veya bütün klasörler ekleme
- Dosya ve klasörleri sürükleyip bırakarak açma
- İsteğe bağlı alt klasör taraması
- Başlık, sanatçı, albüm, albüm sanatçısı, besteci, tür, tarih/yıl ve yorum düzenleme
- Parça numarası/toplamı ve disk numarası/toplamı düzenleme
- Bir veya birden fazla dosyanın etiketlerini toplu düzenleme
- Albüm kapağı ekleme, değiştirme ve kaldırma
- Büyük kapakları kare ölçüde yeniden boyutlandırma ve JPEG/PNG olarak optimize etme
- Dosya adlarını etiket şablonlarından oluşturma ve işlem öncesi önizleme
- Dosya adından etiket çıkarma ve işlem öncesi önizleme
- Dosyaları başlık, sanatçı, albüm, tür veya dosya adına göre arama
- Yalnızca değiştirilmiş dosyaları görüntüleme
- Değişiklikleri diske yazmadan önce toplu inceleme
- Kaydetme ilerlemesini arayüzü dondurmadan gösterme
- Yeniden adlandırma çakışmalarını önceden kontrol etme ve hata durumunda işlemi geri alma
- Açık dosyalardaki mevcut etiketlerden yerel metin tamamlama
- Klavye ile alanlar ve parçalar arasında gezinme
- Etiket ve dosya listesini CSV olarak dışa aktarma
- Kaydedilmemiş değişikliklerle çıkarken veya dosyayı listeden kaldırırken uyarma
- Uygulamanın göstermediği mevcut metadata alanlarını kaydetme sırasında koruma
- Sıradan metin etiketi değişikliklerini ses dosyasını gereksiz yere kopyalamadan kaydetme
- Kapak değişikliklerini aynı diskte güvenli biçimde hazırlama; APFS'te alan tasarruflu kopyala-yaz klonu kullanma, diğer disklerde alanı önceden denetleme
- Hazırlanan dosyayı yeniden açıp etiket, kapak ve okunabilir ses bilgilerini doğrulamadan orijinal dosyanın yerine geçirmeme
- Toplu kayıtta geçici dosyaları tek tek işleyerek yüzlerce parçanın kopyasını aynı anda biriktirmeme
- Açık, koyu ve sistem görünümü
- İngilizce, Türkçe ve sistem dilini izleme seçenekleri
- Dosya listesindeki bilgi sütunlarını Ayarlar’dan açıp kapatma
- Dosya sütunu sabit kalırken diğer sütunları açma, kapatma ve yeniden sıralama
- Sütun başlıklarından sıralama; sanatçı ve albüm gruplarında disk/parça sırasını koruma

## Kesin doğrulanan formatlar

Otomatik testler gerçek ses dosyaları üretir; etiketleri yazar, yeniden okur ve ses verisinin hâlâ çözülebildiğini doğrular.

- MP3
- M4A — AAC ses içeren MPEG-4 kapsayıcısı
- AAC — ADTS
- FLAC
- OGG Vorbis
- Opus
- WAV / WAVE
- AIFF / AIF / AIFC

## Kapak görseli doğrulaması

MP3, M4A, AAC, FLAC, OGG Vorbis, Opus, WAV ve AIFF için otomatik kapak ekleme, yeniden okuma ve kaldırma testleri vardır.

## İlk sürümde bulunmayanlar

- MusicBrainz, Discogs veya başka çevrimiçi metadata araması; kittenTag offline çalışır
- Otomatik parça/disk numaralandırma sihirbazı
- Gelişmiş bul/değiştir ve düzenli ifade işlemleri
- Kaydedilebilir action grupları
- Özel metadata alanları ve özel tablo sütunları
- Playlist üretme
- Ses oynatma veya dönüştürme

## Sistem ve dağıtım

- macOS 13 veya üzeri
- Apple Silicon ve Intel Mac desteği (`arm64` + `x86_64`)
- Developer ID ile imzalanmış ve Apple tarafından notarize edilmiş DMG
- Güncel sürüm: `1.0.0 (54)`
- Ücretsiz ve açık kaynak (`MIT`)
