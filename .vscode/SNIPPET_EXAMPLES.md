# Flutter Snippet Kullanım Örnekleri

## 🎓 Nasıl Kullanılır?

1. Yeni bir `.dart` dosyası açın
2. Snippet kısaltmasını yazın (örn: `stl`)
3. `Tab` veya `Enter` tuşuna basın
4. Tab tuşuyla placeholder'lar arasında geçiş yapın

---

## 📝 Örnekler

### Örnek 1: Yeni Bir Ekran Oluşturma

```dart
// 1. "stl" yazıp Tab'a basın
// 2. "TruckDetailScreen" yazın
// 3. Tab'a basıp widget türünü seçin

class TruckDetailScreen extends StatelessWidget {
  const TruckDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Truck Details'),
      ),
      body: Container(),
    );
  }
}
```

### Örnek 2: Liste Oluşturma

```dart
// "lvb" yazıp Tab'a basın

ListView.builder(
  itemCount: trucks.length,
  itemBuilder: (context, index) {
    final truck = trucks[index];
    return ListTile(
      leading: const Icon(Icons.local_shipping),
      title: Text(truck.name),
      subtitle: Text('Status: ${truck.status}'),
    );
  },
)
```

### Örnek 3: Card ile Widget

```dart
// "card" yazıp Tab'a basın

Card(
  child: ListTile(
    leading: const Icon(Icons.warehouse),
    title: const Text('Warehouse'),
    trailing: const Icon(Icons.chevron_right),
  ),
)
```

### Örnek 4: Stateful Widget

```dart
// "stf" yazıp Tab'a basın

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(),
    );
  }
}
```

### Örnek 5: FutureBuilder

```dart
// "futb" yazıp Tab'a basın

FutureBuilder<List<Truck>>(
  future: loadTrucks(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();
    }
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    final trucks = snapshot.data!;
    return ListView.builder(
      itemCount: trucks.length,
      itemBuilder: (context, index) {
        return TruckCard(truck: trucks[index]);
      },
    );
  },
)
```

### Örnek 6: Dialog Gösterme

```dart
// "dialog" yazıp Tab'a basın

showDialog(
  context: context,
  builder: (context) {
    return AlertDialog(
      title: const Text('Confirm'),
      content: const Text('Are you sure?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // Action here
            Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    );
  },
);
```

### Örnek 7: Navigation

```dart
// "navpush" yazıp Tab'a basın

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TruckDetailScreen(),
  ),
);
```

### Örnek 8: TextField

```dart
// "tf" yazıp Tab'a basın

TextField(
  decoration: const InputDecoration(
    labelText: 'Truck Name',
    hintText: 'Enter truck name',
  ),
  onChanged: (value) {
    // Handle change
  },
)
```

---

## 🎨 Widget Wrapping Örnekleri

Mevcut widget'ı seçin ve:

### Center ile Sar
```dart
// Seçili widget'ta Ctrl+Alt+C

Text('Hello')
// Becomes:
Center(
  child: Text('Hello'),
)
```

### Padding ile Sar
```dart
// Ctrl+Alt+P

Text('Hello')
// Becomes:
Padding(
  padding: const EdgeInsets.all(8.0),
  child: Text('Hello'),
)
```

### Column ile Sar
```dart
// Ctrl+Alt+L

Text('Hello')
// Becomes:
Column(
  children: [
    Text('Hello'),
  ],
)
```

---

## 🔥 Hızlı İpuçları

### 1. Multi-cursor ile Snippet
- `Ctrl+Alt+Down` ile alt satıra cursor ekle
- Snippet yaz
- Hepsi birden oluşsun!

### 2. Snippet Chain
```dart
// "stl" + Tab
// "build" + Tab içine
// "scaffold" + Tab
// "col" + Tab body'ye
// "elb" + Tab children'a
```

### 3. Custom Snippet Oluşturma
1. `.vscode/flutter.code-snippets` dosyasını aç
2. Yeni snippet ekle:
```json
"My Custom Snippet": {
  "prefix": "mycustom",
  "body": [
    "// Your code here",
    "${1:placeholder}"
  ],
  "description": "My custom snippet"
}
```

---

## 🎯 Oyun-Spesifik Örnekler

### Provider Pattern
```dart
// "gprov" yazıp Tab'a basın

class TruckProvider extends ChangeNotifier {
  List<Truck> _trucks = [];

  List<Truck> get trucks => _trucks;

  void addTruck(Truck truck) {
    _trucks.add(truck);
    notifyListeners();
  }

  void removeTruck(String id) {
    _trucks.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}
```

### Truck Card
```dart
// "tcard" yazıp Tab'a basın

Card(
  margin: const EdgeInsets.only(bottom: 12),
  child: ListTile(
    leading: const Icon(Icons.local_shipping),
    title: Text('Truck 1'),
    subtitle: Text('Status: moving'),
    trailing: IconButton(
      icon: const Icon(Icons.chevron_right),
      onPressed: () {
        // Navigate to details
      },
    ),
  ),
)
```

---

## 📚 Daha Fazla Bilgi

- Tüm snippet'leri görmek için: `.vscode/flutter.code-snippets`
- Snippet eklemek için aynı dosyayı düzenleyin
- VS Code snippet syntax: [Snippet Guide](https://code.visualstudio.com/docs/editor/userdefinedsnippets)
