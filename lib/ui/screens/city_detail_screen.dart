import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/ui/screens/tabs/overview_tab.dart';
import 'package:zelix_rised_trades/ui/screens/tabs/factory_tab.dart';
import 'package:zelix_rised_trades/ui/screens/tabs/warehouse_tab.dart';
import 'package:zelix_rised_trades/ui/screens/tabs/truck_tab.dart';
import 'package:zelix_rised_trades/ui/screens/tabs/market_tab.dart';

class CityDetailScreen extends StatefulWidget {
  const CityDetailScreen({super.key});

  @override
  State<CityDetailScreen> createState() => _CityDetailScreenState();
}

class _CityDetailScreenState extends State<CityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController controller;

  @override
  void initState() {
    super.initState();

    controller = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff07152B),

      appBar: AppBar(
        backgroundColor: Colors.transparent,

        elevation: 0,

        title: const Text("Tokyo"),

        bottom: TabBar(
          controller: controller,

          isScrollable: true,

          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: "Overview"),

            Tab(icon: Icon(Icons.factory), text: "Factories"),

            Tab(icon: Icon(Icons.warehouse), text: "Warehouse"),

            Tab(icon: Icon(Icons.local_shipping), text: "Trucks"),

            Tab(icon: Icon(Icons.shopping_cart), text: "Market"),
          ],
        ),
      ),

      body: TabBarView(
        controller: controller,
        children: [
          OverviewTab(),
          FactoryTab(),
          WarehouseTab(),
          TruckTab(),
          MarketTab(),
        ],
      ),
    );
  }
}
