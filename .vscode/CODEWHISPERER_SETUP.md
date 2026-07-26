# 🚀 Amazon CodeWhisperer Kurulum Rehberi

## ✨ Neden CodeWhisperer?

- ✅ **Tamamen ÜCRETSIZ** (kredi kartı gerektirmez!)
- ✅ Real-time AI kod önerileri
- ✅ Güvenlik taraması (security scan)
- ✅ Dart/Flutter desteği
- ✅ AWS servisleri için optimize
- ✅ GitHub Copilot'a ücretsiz alternatif

---

## 📦 Kurulum (5 Dakika)

### Adım 1: AWS Toolkit Extension'ı Yükle

1. **VS Code'u Açın**

2. **Extensions Panel'i Açın:**
   - `Ctrl+Shift+X` tuşlarına basın
   - veya sol taraftaki Extensions ikonuna tıklayın

3. **"AWS Toolkit" Arayın:**
   ```
   AWS Toolkit
   ```

4. **Install Butonuna Tıklayın:**
   - Publisher: Amazon Web Services
   - Extension ID: `amazonwebservices.aws-toolkit-vscode`

5. **VS Code'u Restart Edin** (gerekirse)

---

### Adım 2: CodeWhisperer'ı Aktifleştir

1. **AWS Toolkit Panelini Açın:**
   - Sol sidebar'da AWS logosu görünecek
   - Veya `Ctrl+Shift+P` → "AWS: Focus on Toolkit View"

2. **Developer Tools → CodeWhisperer Bölümüne Gidin**

3. **"Start" veya "Continue" Butonuna Tıklayın**

---

### Adım 3: AWS Builder ID ile Giriş Yap (Ücretsiz!)

#### Seçenek A: AWS Builder ID (ÖNERİLEN - Ücretsiz)

1. **"Use for Free with AWS Builder ID" Seçin**

2. **Yeni Sekme Açılacak:**
   - AWS Builder ID oluştur
   - Email adresinizi girin
   - Onay kodu gelecek

3. **Email'den Kodu Girin:**
   - Email'inizi kontrol edin
   - 6 haneli kodu girin

4. **Profil Bilgilerinizi Doldurun:**
   - İsim
   - Ülke
   - (Kredi kartı GEREKMİYOR!)

5. **Authorize VS Code:**
   - "Allow" butonuna tıklayın
   - VS Code'a dönün

#### Seçenek B: AWS IAM Identity Center (İş/Kurumsal)

- Şirket AWS hesabı varsa kullanın
- Daha karmaşık, bireysel kullanım için gereksiz

---

### Adım 4: Ayarları Kontrol Et

1. **Settings'i Açın:** `Ctrl+,`

2. **"CodeWhisperer" Arayın**

3. **Bu Ayarları Kontrol Edin:**
   ```json
   {
     "aws.codeWhisperer.includeSuggestionsWithCodeReferences": true,
     "aws.codeWhisperer.shareCodeWhispererContentWithAWS": true,
     "editor.inlineSuggest.enabled": true,
     "editor.quickSuggestions": {
       "other": "on",
       "comments": "on",
       "strings": "on"
     }
   }
   ```

---

## ✅ Test Et!

### Test 1: Basit Fonksiyon

1. **Yeni bir Dart dosyası oluştur**

2. **Şunu yaz:**
   ```dart
   // Function to calculate total price
   double calculateTotal
   ```

3. **Bekle (1-2 saniye)**
   - Gri renkli öneri gelecek

4. **Tab tuşuna bas**
   - Kod tamamlanacak!

### Test 2: Widget Oluşturma

```dart
// Create a stateless widget for truck card
class TruckCard
```
[Bekle ve Tab'a bas]

### Test 3: Flutter Scaffold

```dart
Scaffold(
  appBar: 
```
[Bekle ve Tab'a bas]

---

## 🎯 CodeWhisperer Nasıl Kullanılır?

### 1. **Otomatik Öneriler (Preferred)**

Yazmaya başla, otomatik öneriler gelir:

```dart
Future<List<Truck>> getTrucks() async {
  // ↓ Gri metin = CodeWhisperer önerisi
  final response = await http.get(...);
  return parseTrucks(response);
}
```

**Klavye:**
- `Tab` → Öneriyi kabul et
- `Esc` → Öneriyi reddet
- `Alt+C` → Manuel öneri iste

### 2. **Comment-Driven Development**

Yorum yaz, kod gelsin:

```dart
// Fetch all trucks from database where status is active
// Sort by name ascending
// Return as a list
```
[CodeWhisperer tam fonksiyonu yazacak!]

### 3. **Context-Aware Suggestions**

CodeWhisperer dosyanın tamamını anlar:

```dart
class Truck {
  final String id;
  final String name;
  final TruckStatus status;
}

// getTrucks fonksiyonu yazarken Truck class'ını bilir
Future<List<Truck>> getTrucks() {
  // ↓ Truck tipini bilerek öneri yapar
```

---

## ⌨️ Klavye Kısayolları

| Kısayol | Açıklama |
|---------|----------|
| `Tab` | Öneriyi kabul et |
| `Esc` | Öneriyi reddet |
| `Alt+C` | Manuel öneri iste |
| `Ctrl+Space` | IntelliSense göster |
| `Ctrl+.` | Quick fix |

---

## 🛡️ Security Scan Özelliği

CodeWhisperer'ın özel özelliği: **Güvenlik Taraması**

### Nasıl Kullanılır?

1. **Dosyayı aç (Dart/Flutter)**

2. **Sağ tıkla → "Amazon Q: Scan for Security Issues"**

3. **Veya:** `Ctrl+Shift+P` → "CodeWhisperer: Run Security Scan"

4. **Sonuçlar:**
   - Güvenlik açıkları
   - Kod kalitesi sorunları
   - Öneriler

### Örnek Sorunlar:

- SQL Injection riskleri
- Hardcoded secrets
- Insecure random number generation
- Path traversal vulnerabilities

---

## 🔧 Ayarlar ve Özelleştirme

### settings.json'a Ekle:

```json
{
  // CodeWhisperer temel ayarlar
  "aws.codeWhisperer.includeSuggestionsWithCodeReferences": true,
  "aws.codeWhisperer.shareCodeWhispererContentWithAWS": true,
  
  // Önerilerin ne zaman geleceği
  "editor.inlineSuggest.enabled": true,
  "editor.quickSuggestions": {
    "other": "on",
    "comments": "on",
    "strings": "on"
  },
  
  // Öneri gecikmesi (ms)
  "editor.quickSuggestionsDelay": 10,
  
  // Tab completion
  "editor.tabCompletion": "on",
  "editor.acceptSuggestionOnEnter": "on"
}
```

---

## 💡 Pro İpuçları

### 1. **Açıklayıcı Yorumlar Yaz**

❌ Kötü:
```dart
// get data
```

✅ İyi:
```dart
// Fetch all active trucks from Firebase
// Filter by warehouse ID
// Sort by registration date descending
```

### 2. **Type Annotations Kullan**

```dart
// CodeWhisperer bu type'ları anlayacak
List<Truck> trucks = [];
Map<String, Warehouse> warehouses = {};
```

### 3. **Import'ları Ekle**

```dart
import 'package:flutter/material.dart';
import 'models/truck.dart';

// ↑ Import'lar varken CodeWhisperer daha iyi öneri yapar
```

### 4. **Örnek Veriler Göster**

```dart
// Example data:
// { "id": "t1", "name": "Truck Alpha", "status": "moving" }
final Truck truck = // CodeWhisperer format'ı öğrenecek
```

---

## 🆚 Copilot vs CodeWhisperer

| Özellik | Copilot | CodeWhisperer |
|---------|---------|---------------|
| **Fiyat** | $10/ay | **ÜCRETSIZ** |
| **Kod Kalitesi** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Flutter Desteği** | Mükemmel | İyi |
| **Security Scan** | ❌ | ✅ |
| **AWS Integration** | ❌ | ✅ |
| **Context Understanding** | Çok İyi | İyi |
| **Multi-line Suggestions** | ✅ | ✅ |
| **Comment-to-Code** | ✅ | ✅ |

**Sonuç:** CodeWhisperer ücretsiz ve güçlü bir alternatif! 🎉

---

## 🐛 Sorun Giderme

### Problem 1: "Öneriler gelmiyor"

**Çözüm:**
1. AWS Toolkit extension enabled mi?
2. CodeWhisperer active mi? (AWS Toolkit panelinden kontrol et)
3. Internet bağlantınız var mı?
4. `Ctrl+Shift+P` → "Developer: Reload Window"

### Problem 2: "Giriş yapamıyorum"

**Çözüm:**
1. Email doğru mu?
2. Spam klasörünü kontrol edin
3. Farklı browser deneyin
4. AWS Builder ID sayfasını yenileyin

### Problem 3: "Çok yavaş"

**Çözüm:**
1. Internet hızınızı kontrol edin
2. Başka AI tool disable edin (çakışma olabilir)
3. `"editor.quickSuggestionsDelay": 100` ayarını deneyin

### Problem 4: "Dart dosyalarında çalışmıyor"

**Çözüm:**
1. `.dart` uzantılı dosya olduğundan emin olun
2. Dart extension yüklü mü?
3. VS Code restart deneyin

---

## 📊 CodeWhisperer Metrics

CodeWhisperer kullanım istatistiklerini görebilirsiniz:

1. **AWS Toolkit Panelini Açın**
2. **CodeWhisperer bölümüne gidin**
3. **"View Metrics" tıklayın**

**Görebilecekleriniz:**
- Kabul edilen öneriler
- Reddedilen öneriler
- Üretkenlik artışı
- En çok kullanılan diller

---

## 🎓 Öğrenme Kaynakları

### Video Tutorials:
- [CodeWhisperer Getting Started](https://www.youtube.com/watch?v=rHNMfoda-yg)
- [CodeWhisperer for VS Code](https://www.youtube.com/watch?v=4J9LFKj9Q_c)

### Dokümantasyon:
- [AWS CodeWhisperer Docs](https://aws.amazon.com/codewhisperer/)
- [VS Code Extension Guide](https://docs.aws.amazon.com/toolkit-for-vscode/latest/userguide/codewhisperer.html)

---

## 🎯 Hızlı Başlangıç Checklist

- [ ] AWS Toolkit extension yüklendi
- [ ] AWS Builder ID oluşturuldu
- [ ] CodeWhisperer aktif edildi
- [ ] Test edildi (öneri geldi)
- [ ] Security scan denendi
- [ ] settings.json güncellendi
- [ ] İlk Flutter widget'ı AI ile yazıldı!

---

## ✨ Başarı Örnekleri

### Örnek 1: Widget Oluşturma

**Yazdığınız:**
```dart
// Create a card widget for truck with image, name, and status
class TruckCard extends StatelessWidget {
```

**CodeWhisperer'ın Önerisi:**
```dart
  final Truck truck;
  
  const TruckCard({Key? key, required this.truck}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.local_shipping),
        title: Text(truck.name),
        subtitle: Text('Status: ${truck.status}'),
      ),
    );
  }
}
```

### Örnek 2: API Call

**Yazdığınız:**
```dart
// Fetch trucks from API endpoint /api/trucks
Future<List<Truck>> fetchTrucks() async {
```

**CodeWhisperer'ın Önerisi:**
```dart
  final response = await http.get(Uri.parse('$baseUrl/api/trucks'));
  
  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Truck.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load trucks');
  }
}
```

---

## 🎉 Tebrikler!

CodeWhisperer artık hazır! Ücretsiz AI kod asistanınız ile:

- ✅ 3x daha hızlı kod yazın
- ✅ Güvenlik açıklarını bulun
- ✅ Flutter widget'ları otomatik oluşturun
- ✅ Hiçbir ücret ödemeden!

**Hemen başlayın:**
1. Yeni bir `.dart` dosyası açın
2. Yorum yazın veya kod yazmaya başlayın
3. 1-2 saniye bekleyin
4. Gri öneriyi görünce `Tab`'a basın!

**Sorularınız mı var?**
- AWS Toolkit panelinden "Help" → "View Documentation"
- Veya: https://aws.amazon.com/codewhisperer/resources/

Keyifli kodlamalar! 🚀
