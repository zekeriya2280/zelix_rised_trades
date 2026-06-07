import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import 'core/enums/resource_type.dart';
import 'core/models/warehouse.dart';
import 'screens/warehouse_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum WarehouseAction {
  none,
  autoLumber,
  autoFurniture,
  autoSell,
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zelix Rised Trades',
      theme: ThemeData(useMaterial3: true),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // MONEY
  int money = 100000;

  // RESOURCES
  int wood = 0;
  int lumber = 0;
  int furniture = 0;

  // BUILDINGS
  int forests = 0;
  int lumberMills = 0;
  int furnitureFactories = 0;

  // STATS
  int totalWoodProduced = 0;
  int totalLumberProduced = 0;
  int totalFurnitureProduced = 0;
  int totalFurnitureSold = 0;

  late Warehouse warehouse;

  WarehouseAction activeWarehouseAction = WarehouseAction.none;
  String selectedSource = 'Warehouse';
  String selectedProduct = 'Wood';
  String selectedDestination = 'Lumber Mill';
  String activeRouteDescription = 'No active warehouse route';

  final int productionInterval = 30;
  int woodProductionTimer = 0;
  int lumberProductionTimer = 0;
  int furnitureProductionTimer = 0;
  int sellTimer = 0;

  Timer? timer;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;


  @override
  void initState()  {
    super.initState();
    Future.microtask(() async {
    await logToFirestore("Game started");
  }); 
    warehouse = Warehouse(
      id: 'main_warehouse',
      name: 'Main Warehouse',
      capacity: 100000,
      stock: {
        ResourceType.wood: 0,
        ResourceType.lumber: 0,
        ResourceType.furniture: 0,
      },
    );

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      gameTick();
    });
  }
  Future<void> logToFirestore(String message) async {
  try {
    final doc = await firestore.collection('activity_logs').add({
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });

    print('SUCCESS: ${doc.id}');
  } catch (e) {
    print('FIRESTORE ERROR: $e');
  }
}
  void gameTick() {
    // Only advance each production timer when the corresponding building exists.
    if (forests > 0) {
      woodProductionTimer++;
      if (woodProductionTimer >= productionInterval) {
        produceWood();
        woodProductionTimer = 0;
      }
    } else {
      woodProductionTimer = 0;
    }

    // Lumber production only advances if the warehouse route is active and there are mills.
    if (activeWarehouseAction == WarehouseAction.autoLumber && lumberMills > 0 && warehouse.get(ResourceType.wood) >= 10) {
      lumberProductionTimer++;
      if (lumberProductionTimer >= productionInterval) {
        produceLumber();
        lumberProductionTimer = 0;
      }
    } else {
      lumberProductionTimer = 0;
    }

    // Furniture production only advances if the warehouse route is active and there are factories.
    if (activeWarehouseAction == WarehouseAction.autoFurniture && furnitureFactories > 0 && warehouse.get(ResourceType.lumber) >= 10) {
      furnitureProductionTimer++;
      if (furnitureProductionTimer >= productionInterval) {
        produceFurniture();
        furnitureProductionTimer = 0;
      }
    } else {
      furnitureProductionTimer = 0;
    }

    // Furniture selling happens only when the warehouse route is set to sell.
    if (activeWarehouseAction == WarehouseAction.autoSell) {
      sellTimer++;
      if (sellTimer >= productionInterval) {
        sellFurniture();
        sellTimer = 0;
      }
    } else {
      sellTimer = 0;
    }

    setState(() {});
  }

  // =========================
  // BUILDINGS
  // =========================

  void buildForest() {
    const cost = 5000;

    if (money < cost) {
      warehouse.log("❌ Not enough money for Forest");
      setState(() {});
      return;
    }

    money -= cost;
    forests++;

    warehouse.log("🌲 Forest built (-$cost¥)");

    setState(() {});
  }

  void buildLumberMill() {
    const cost = 15000;

    if (money < cost) {
      warehouse.log("❌ Not enough money for Lumber Mill");
      setState(() {});
      return;
    }

    money -= cost;
    lumberMills++;

    warehouse.log("🪚 Lumber Mill built (-$cost¥)");

    setState(() {});
  }

  void buildFurnitureFactory() {
    const cost = 30000;

    if (money < cost) {
      warehouse.log("❌ Not enough money for Furniture Factory");
      setState(() {});
      return;
    }

    money -= cost;
    furnitureFactories++;

    warehouse.log("🪑 Furniture Factory built (-$cost¥)");

    setState(() {});
  }

  // =========================
  // PRODUCTION
  // =========================

  void produceWood() {
    if (forests == 0) return;

    final produced = forests * 5;

    warehouse.add(
      ResourceType.wood,
      produced,
      reason: 'Forest production',
      log: false,
    );
    wood += produced;
    totalWoodProduced += produced;

    warehouse.log("🌲 +$produced Wood", type: ResourceType.wood);
  }

  void produceLumber() {
    if (lumberMills == 0) return;

    for (int i = 0; i < lumberMills; i++) {
      // Ensure warehouse has enough wood before consuming.
      if (warehouse.get(ResourceType.wood) >= 10) {
        warehouse.remove(
          ResourceType.wood,
          10,
          reason: 'Lumber mill input',
          log: false,
        );
        // Keep local counters in sync for UI
        if (wood >= 10) {
          wood -= 10;
        } else {
          // If local value is out of sync, read from warehouse
          wood = warehouse.get(ResourceType.wood);
        }

        warehouse.add(
          ResourceType.lumber,
          5,
          reason: 'Lumber mill output',
          log: false,
        );
        lumber += 5;

        totalLumberProduced += 5;

        warehouse.log("🪚 10 Wood → 5 Lumber", type: ResourceType.lumber);
      }
    }
  }

  void produceFurniture() {
    if (furnitureFactories == 0) return;

    for (int i = 0; i < furnitureFactories; i++) {
      // Ensure warehouse has enough lumber before consuming.
      if (warehouse.get(ResourceType.lumber) >= 10) {
        warehouse.remove(
          ResourceType.lumber,
          10,
          reason: 'Furniture factory input',
          log: false,
        );
        if (lumber >= 10) {
          lumber -= 10;
        } else {
          lumber = warehouse.get(ResourceType.lumber);
        }

        warehouse.add(
          ResourceType.furniture,
          2,
          reason: 'Furniture factory output',
          log: false,
        );
        furniture += 2;

        totalFurnitureProduced += 2;

        warehouse.log(
          "🪑 10 Lumber → 2 Furniture",
          type: ResourceType.furniture,
        );
      }
    }
  }

  void sellFurniture() {
    while (furniture >= 2) {
      warehouse.remove(
        ResourceType.furniture,
        2,
        reason: 'Furniture sale',
        log: false,
      );
      furniture -= 2;

      money += 500;

      totalFurnitureSold += 2;

      warehouse.log(
        "💰 Sold 2 Furniture (+500¥)",
        type: ResourceType.furniture,
      );
    }
  }

  WarehouseAction getSelectedWarehouseAction() {
    if (selectedProduct == 'Wood' && selectedDestination == 'Lumber Mill') {
      return WarehouseAction.autoLumber;
    }
    if (selectedProduct == 'Lumber' && selectedDestination == 'Furniture Factory') {
      return WarehouseAction.autoFurniture;
    }
    if (selectedProduct == 'Furniture' && selectedDestination == 'Tokyo') {
      return WarehouseAction.autoSell;
    }
    return WarehouseAction.none;
  }

  bool get hasValidWarehouseRoute {
    return getSelectedWarehouseAction() != WarehouseAction.none;
  }

  void startWarehouseRoute() {
    final action = getSelectedWarehouseAction();
    if (action == WarehouseAction.none) {
      warehouse.log('❌ Invalid warehouse route');
      setState(() {});
      return;
    }

    activeWarehouseAction = action;
    activeRouteDescription = '$selectedProduct from $selectedSource → $selectedDestination';
    warehouse.log('▶️ Started route: $activeRouteDescription');
    setState(() {});
  }

  void stopWarehouseRoute() {
    activeWarehouseAction = WarehouseAction.none;
    activeRouteDescription = 'No active warehouse route';
    warehouse.log('⏹️ Stopped warehouse route');
    setState(() {});
  }

  Widget statCard(String title, String value) {
    return Card(
      color: Color(0xFF8B5A2B),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontStyle: FontStyle.italic,
          ),
        ),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget statCard3(String title, String value) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 3 - 8,
      child: Card(
        color: Color(0xFF8B5A2B),
        child: Column(
          children: [
            Container(
              color: Colors.grey[700],
              alignment: Alignment.center,
              //padding: const EdgeInsets.all(8.0),
              child: ListTile(
                title: Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.3,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget productionFlowCard({
    required String title,
    required int buildingCount,
    required int timer,
    required ResourceType? requiredType,
    required int requiredAmount,
    Color? color,
  }) {
    final hasBuilding = buildingCount > 0;
    final hasInput =
        requiredType == null || warehouse.get(requiredType) >= requiredAmount;
    final enabled = hasBuilding && hasInput;
    final labelText = enabled
        ? '${productionInterval - timer}s'
        : (hasBuilding ? 'Insufficient input' : 'No ${title.toLowerCase()}');
    final subtitleText = enabled
        ? 'Next ${title.toLowerCase()} in ${productionInterval - timer}s'
        : (hasBuilding
              ? 'Insufficient ${requiredType?.name ?? 'input'} in warehouse'
              : 'No ${title.toLowerCase()} installed');

    final subtitleStyle = color != null
        ? const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Colors.white,
            fontStyle: FontStyle.italic,
          )
        : const TextStyle(fontSize: 12, color: Colors.grey);
    final baseColor = color ?? Colors.blue;

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontStyle: FontStyle.italic,
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: enabled
                    ? Color.fromRGBO(
                        (baseColor.r * 255).round().clamp(0, 255),
                        (baseColor.g * 255).round().clamp(0, 255),
                        (baseColor.b * 255).round().clamp(0, 255),
                        0.95,
                      )
                    : Colors.orange[100],
                inactiveTrackColor: enabled
                    ? Color.fromRGBO(
                        (baseColor.r * 255).round().clamp(0, 255),
                        (baseColor.g * 255).round().clamp(0, 255),
                        (baseColor.b * 255).round().clamp(0, 255),
                        0.4,
                      )
                    : Colors.orange[100],
                thumbColor: enabled
                    ? Color.fromRGBO(
                        (baseColor.r * 255).round().clamp(0, 255),
                        (baseColor.g * 255).round().clamp(0, 255),
                        (baseColor.b * 255).round().clamp(0, 255),
                        0.95,
                      )
                    : Colors.white54,
                overlayColor: Color.fromRGBO(
                  (baseColor.r * 255).round().clamp(0, 255),
                  (baseColor.g * 255).round().clamp(0, 255),
                  (baseColor.b * 255).round().clamp(0, 255),
                  0.2,
                ),
                disabledActiveTrackColor: Colors.blue,
                disabledInactiveTrackColor: Colors.yellow[100],
                disabledThumbColor: Colors.red,
              ),
              child: Slider(
                value: enabled ? timer.toDouble() : 0.0,
                min: 0,
                max: productionInterval.toDouble(),
                divisions: productionInterval,
                label: labelText,
                onChanged: null,
              ),
            ),
            Text(subtitleText, style: subtitleStyle),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = warehouse.getLogs();

    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: const Text(
            "Zelix Rised Trades",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.brown,
              fontSize: 24,
              letterSpacing: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              statCard("Money", "¥$money"),

              const SizedBox(height: 8),
              productionFlowCard(
                title: 'Wood production flow',
                buildingCount: forests,
                timer: woodProductionTimer,
                requiredType: null,
                requiredAmount: 0,
                color: Colors.green[300],
              ),
              productionFlowCard(
                title: 'Lumber production flow',
                buildingCount: lumberMills,
                timer: lumberProductionTimer,
                requiredType: ResourceType.wood,
                requiredAmount: 10,
                color: Colors.orange[300],
              ),
              productionFlowCard(
                title: 'Furniture production flow',
                buildingCount: furnitureFactories,
                timer: furnitureProductionTimer,
                requiredType: ResourceType.lumber,
                requiredAmount: 10,
                color: Colors.blue[300],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WarehouseScreen(
                        warehouse: warehouse,
                        lumberMills: lumberMills,
                        furnitureFactories: furnitureFactories,
                        activeActionLabel: activeWarehouseAction.name,
                        lumberProductionTimer: lumberProductionTimer,
                        furnitureProductionTimer: furnitureProductionTimer,
                        sellTimer: sellTimer,
                        productionInterval: productionInterval,
                        selectedSource: selectedSource,
                        selectedProduct: selectedProduct,
                        selectedDestination: selectedDestination,
                        routeDescription: activeRouteDescription,
                        onSourceChanged: (value) {
                          selectedSource = value;
                        },
                        onProductChanged: (value) {
                          selectedProduct = value;
                        },
                        onDestinationChanged: (value) {
                          selectedDestination = value;
                        },
                        onStartRoute: startWarehouseRoute,
                        onStopRoute: stopWarehouseRoute,
                      ),
                    ),
                  );
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(12),
                child: Card(
                  color: Colors.brown[200],
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 10,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: const Text(
                              'Warehouse Stock (Tap to configure)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Wood: ${warehouse.get(ResourceType.wood)}',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                          Center(
                            child: Text(
                              'Lumber: ${warehouse.get(ResourceType.lumber)}',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                          Center(
                            child: Text(
                              'Furniture: ${warehouse.get(ResourceType.furniture)}',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              activeRouteDescription,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  statCard3("Wood", "$wood"),
                  statCard3("Lumber", "$lumber"),
                  statCard3("Furniture", "$furniture"),
                ],
              ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  statCard3("Forests", "$forests"),

                  statCard3("Lumber Mills", "$lumberMills"),

                  statCard3("Furniture Factories", "$furnitureFactories"),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  statCard3("Total Wood Produced", "$totalWoodProduced"),

                  statCard3("Total Lumber Produced", "$totalLumberProduced"),

                  statCard3(
                    "Total Furniture Produced",
                    "$totalFurnitureProduced",
                  ),
                ],
              ),

              statCard("Total Furniture Sold", "$totalFurnitureSold"),

              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: buildForest,
                    child: const Text(
                      "🌲 Forest\n5000¥",
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: buildLumberMill,
                    child: const Text(
                      "🪚 Lumber Mill\n15000¥",
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: buildFurnitureFactory,
                    child: const Text(
                      "🪑 Furniture Factory\n30000¥",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const Text(
                "Activity Log",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              SizedBox(
                height: 300,
                child: Card(
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Padding(
                        padding: const EdgeInsets.all(6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                log.reason,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              DateFormat('HH:mm:ss').format(log.timestamp),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
