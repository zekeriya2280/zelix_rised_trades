# VS Code Flutter Snippets & Shortcuts

## 📦 Kurulum

1. VS Code'u açın
2. `Ctrl+Shift+P` -> "Extensions: Show Recommended Extensions"
3. Önerilen extension'ları yükleyin

## 🚀 Kod Snippet'leri

### Widget Snippets
- `stl` → Stateless Widget
- `stf` → Stateful Widget
- `build` → Build Method

### Layout Widgets
- `scaffold` → Scaffold
- `cont` → Container
- `pad` → Padding
- `center` → Center
- `col` → Column
- `row` → Row
- `lvb` → ListView.builder
- `gvb` → GridView.builder

### Material Widgets
- `card` → Card
- `elb` → ElevatedButton
- `txtb` → TextButton
- `icb` → IconButton
- `tf` → TextField

### Navigation
- `navpush` → Navigator.push
- `navpop` → Navigator.pop
- `navreplace` → Navigator.pushReplacement

### State Management
- `sets` → setState
- `inits` → initState
- `disp` → dispose

### Async
- `futm` → Future Method
- `futb` → FutureBuilder
- `strb` → StreamBuilder

### Common Patterns
- `dialog` → ShowDialog
- `snack` → SnackBar
- `mapp` → MaterialApp

### Game-Specific
- `gprov` → Game Provider
- `tcard` → Truck Card
- `witem` → Warehouse Item

## ⌨️ Klavye Kısayolları

### Flutter Specific
- `Ctrl+Shift+R` → Hot Reload
- `Ctrl+Shift+F5` → Hot Restart
- `Ctrl+Alt+W` → Wrap with Widget
- `Ctrl+Alt+C` → Wrap with Center
- `Ctrl+Alt+P` → Wrap with Padding
- `Ctrl+Alt+R` → Wrap with Row
- `Ctrl+Alt+L` → Wrap with Column
- `Ctrl+Alt+S` → Wrap with StreamBuilder
- `Ctrl+Shift+Delete` → Remove Widget

### General
- `Ctrl+Shift+O` → Organize Imports
- `Ctrl+.` → Quick Fix
- `F2` → Rename
- `Ctrl+Space` → Trigger Suggestions

## 🛠️ Tasks

VS Code'da `Ctrl+Shift+P` -> "Tasks: Run Task" ile erişebilirsiniz:

- **Flutter: Clean** - Projeyi temizle
- **Flutter: Pub Get** - Paketleri indir
- **Flutter: Build APK** - APK oluştur
- **Flutter: Analyze** - Kodu analiz et
- **Flutter: Test** - Testleri çalıştır
- **Flutter: Format** - Kodu formatla
- **Flutter: Doctor** - Flutter durumunu kontrol et

## 🎯 Debug Configurations

F5 ile debug başlatın veya Debug panelinden seçin:

- **Flutter: Run** - Normal debug mode
- **Flutter: Profile** - Performance profiling
- **Flutter: Release** - Release mode
- **Flutter: Run (Chrome)** - Chrome'da çalıştır
- **Flutter: Run (Edge)** - Edge'de çalıştır
- **Flutter: Attach to Process** - Çalışan process'e bağlan

## 💡 İpuçları

1. **Auto-complete**: Yazmaya başladığınızda otomatik öneriler gelecek
2. **Quick Fix**: Hata olan satırda `Ctrl+.` ile hızlı düzeltme
3. **Widget Wrapping**: Widget seçip `Ctrl+Alt+W` ile başka widget ile sar
4. **Hot Reload**: Kod değişikliğinden sonra `Ctrl+Shift+R` ile anında görün
5. **Import Organization**: `Ctrl+Shift+O` ile import'ları düzenle
6. **Format on Save**: Dosyayı kaydettiğinizde otomatik formatlanır

## 🔧 Ayarlar

Tüm ayarlar `.vscode/settings.json` dosyasında. Özelleştirmek için:

1. `Ctrl+,` ile Settings'i aç
2. "Workspace" tab'ına geç
3. Ayarları düzenle

## 📚 Kaynaklar

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev/guides)
- [VS Code Flutter Extension](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter)
