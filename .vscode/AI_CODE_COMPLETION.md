# 🤖 AI Kod Tamamlama Eklentileri - Yazmadan Öneren Araçlar

## 🎯 En İyi 5 AI Kod Tamamlama Aracı

### 1. 🏆 **GitHub Copilot** (En Güçlü - Ücretli)

**Özellikler:**
- ✅ Tam kod blokları önerir
- ✅ Fonksiyon içeriğini tahmin eder
- ✅ Yorum satırlarından kod üretir
- ✅ Çoklu dil desteği (Dart/Flutter dahil)
- ✅ Context-aware (dosyanın tamamını anlar)

**Kurulum:**
1. VS Code'da Extensions'a git (`Ctrl+Shift+X`)
2. "GitHub Copilot" ara
3. Install → Sign in with GitHub
4. Ücretli plan başlat (öğrenciler için ücretsiz!)

**Fiyat:** 
- $10/ay veya $100/yıl
- Öğrenciler/Öğretmenler için ÜCRETSIZ
- 30 gün ücretsiz deneme

**Kullanım:**
```dart
// Yorum yazın, Copilot kodu üretsin:

// Create a stateless widget for truck card
// [Tab'a basın, kod gelecek!]

// Function to calculate total price
// [Tab'a basın]
```

---

### 2. 💎 **Amazon CodeWhisperer** (Ücretsiz!)

**Özellikler:**
- ✅ Tamamen ÜCRETSIZ
- ✅ Real-time kod önerileri
- ✅ Security scan (güvenlik kontrolü)
- ✅ AWS servisleri için optimize
- ✅ Dart/Flutter desteği

**Kurulum:**
1. VS Code Extensions → "AWS Toolkit" ara
2. Install
3. AWS Toolkit → CodeWhisperer → Start
4. Ücretsiz hesap oluştur

**Fiyat:** ÜCRETSIZ ✨

**Kullanım:**
```dart
// Yazmaya başlayın, otomatik öneriler gelecek
class TruckCard
// [Bekleyin, öneri gelecek]
```

---

### 3. 🔷 **Tabnine** (Ücretsiz/Premium)

**Özellikler:**
- ✅ Ücretsiz versiyon var
- ✅ Lokal AI (internetsiz çalışır)
- ✅ Takım için öğrenme modu
- ✅ Hızlı ve hafif
- ✅ Privacy-focused

**Kurulum:**
1. Extensions → "Tabnine" ara
2. Install
3. Sign up (ücretsiz)

**Fiyat:**
- Ücretsiz: Temel özellikler
- Pro: $12/ay - Gelişmiş AI
- Enterprise: $39/ay - Takım özellikleri

**Kullanım:**
- Otomatik çalışır
- Yazmaya başlayın, gri renkli öneriler görün
- `Tab` ile kabul edin

---

### 4. 🧠 **Visual Studio IntelliCode** (Microsoft - Ücretsiz)

**Özellikler:**
- ✅ Tamamen ÜCRETSIZ
- ✅ Microsoft'tan
- ✅ Context-aware suggestions
- ✅ API usage examples
- ✅ Dart/Flutter desteği sınırlı

**Kurulum:**
1. Extensions → "IntelliCode" ara
2. Install (otomatik aktif)

**Fiyat:** ÜCRETSIZ

**Kullanım:**
- Otomatik çalışır
- ⭐ işaretli öneriler AI tabanlı

---

### 5. 🚀 **Kite** (Kapandı ama alternatifler var)

⚠️ Kite artık aktif değil. Yerine:
- **Codeium** - Yeni ve ücretsiz
- **AskCodi** - AI kod asistanı

---

## 📊 Karşılaştırma Tablosu

| Özellik | Copilot | CodeWhisperer | Tabnine | IntelliCode |
|---------|---------|---------------|---------|-------------|
| **Fiyat** | $10/ay | ÜCRETSIZ | Ücretsiz/Pro | ÜCRETSIZ |
| **Kod Kalitesi** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Flutter Desteği** | Mükemmel | İyi | İyi | Orta |
| **Context Anlama** | Çok iyi | İyi | Orta | Orta |
| **Tam Fonksiyon** | ✅ | ✅ | ✅ | ❌ |
| **Offline Çalışma** | ❌ | ❌ | ✅ (Pro) | ❌ |
| **Privacy** | Orta | Orta | Yüksek | Yüksek |

---

## 🎓 Öğrenci/Öğretmen İçin Ücretsiz!

### GitHub Copilot Ücretsiz Nasıl Alınır?

1. **GitHub Student Pack** edinin:
   - https://education.github.com/pack
   - .edu email adresi gerekli
   - Öğrenci belgenizi yükleyin

2. **Copilot aktif olacak:**
   - Student Pack onaylandıktan sonra
   - Copilot otomatik ücretsiz

3. **Öğretmenler için:**
   - https://education.github.com/teachers
   - GitHub Teacher Toolbox

---

## ⚙️ Kurulum Sonrası Ayarlar

### settings.json'a Ekleyin:

```json
{
  // Copilot
  "github.copilot.enable": {
    "*": true,
    "dart": true
  },
  
  // IntelliCode
  "vsintellicode.modify.editor.suggestSelection": "automaticallyOverrodeDefaultValue",
  
  // Tabnine
  "tabnine.experimentalAutoImports": true,
  
  // Editor settings
  "editor.suggestOnTriggerCharacters": true,
  "editor.acceptSuggestionOnCommitCharacter": true,
  "editor.acceptSuggestionOnEnter": "on",
  "editor.quickSuggestions": {
    "other": true,
    "comments": true,
    "strings": true
  },
  "editor.inlineSuggest.enabled": true
}
```

---

## 💡 Kullanım İpuçları

### 1. **Comment-Driven Development**
```dart
// Create a function that fetches trucks from Firebase
// Filter by status and sort by name
// Return a list of trucks
// [Tab'a basın, Copilot yazacak!]
```

### 2. **Fonksiyon Signature Yazın**
```dart
Future<List<Truck>> fetchActiveTrucks() async {
  // [Tab'a basın, body gelecek]
}
```

### 3. **Pattern Tanımlayın**
```dart
// İlk widget
class TruckCard extends StatelessWidget {
  final Truck truck;
  // ... kod yazıldı

// İkinci widget (AI öğrendi)
class WarehouseCard extends StatelessWidget {
  // [Tab'a basın, benzer pattern gelecek!]
}
```

### 4. **Multi-Line Suggestions**
```dart
// Başlangıç yazın:
if (truck.status == TruckStatus.moving) {
  // [AI tüm bloku önerecek]
```

---

## 🔧 Sorun Giderme

### Copilot Çalışmıyor?
1. GitHub hesabı bağlı mı? (Alt bar'da kontrol et)
2. Lisans aktif mi? (GitHub hesabında kontrol et)
3. VS Code restart deneyin

### Öneriler Gelmiyor?
1. `Ctrl+Space` ile manuel tetikle
2. `settings.json` → `"editor.inlineSuggest.enabled": true`
3. Extension'ı disable/enable deneyin

### Çok Yavaş?
1. Tek bir AI tool kullanın (çoklu AI çakışabilir)
2. `"editor.suggest.showStatusBar": false`
3. Internet bağlantınızı kontrol edin

---

## 🎯 Hangi AI Tool'u Seçmeliyim?

### Yeni Başlayanlar:
→ **IntelliCode** (ücretsiz, kolay)

### Para Harcamak İstemeyenler:
→ **CodeWhisperer** (ücretsiz, güçlü)

### En İyi Kalite İsteyenler:
→ **Copilot** (ücretli ama en iyi)

### Öğrenciler:
→ **Copilot** (Student Pack ile ücretsiz!)

### Privacy Önemliyse:
→ **Tabnine** (lokal AI seçeneği var)

---

## 📚 Ek Kaynaklar

- [Copilot Docs](https://docs.github.com/en/copilot)
- [CodeWhisperer Docs](https://aws.amazon.com/codewhisperer/)
- [Tabnine Docs](https://www.tabnine.com/docs)
- [IntelliCode Docs](https://visualstudio.microsoft.com/services/intellicode/)

---

## ✨ Sonuç

AI kod tamamlama araçları **3-5x daha hızlı** kod yazmanızı sağlar!

**Önerimiz:**
1. Önce **IntelliCode** deneyin (ücretsiz)
2. **CodeWhisperer** ekleyin (ücretsiz)
3. Beğendiyseniz **Copilot** alın (en iyisi)

Hepsini birlikte kullanabilirsiniz! 🚀
