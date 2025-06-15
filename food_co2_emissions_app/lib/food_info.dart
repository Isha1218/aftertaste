import 'package:flutter/material.dart';

class FoodInfo extends StatefulWidget {
  FoodInfo({super.key, required this.co2Food});

  final Map<String, List<double>> co2Food;

  @override
  State<FoodInfo> createState() => _FoodInfoState();
}

class _FoodInfoState extends State<FoodInfo> {
  ScrollController controller = ScrollController();
  double totalCo2 = 0.0;
  double totalLandUse = 0.0;
  double totalWaterUse = 0.0;

  @override
  void initState() {
    calculateAboveInfo();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFCEACC),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: MediaQuery.of(context).size.width / 2,
              child: Image.asset(
                'assets/food_dish.png',
                height: MediaQuery.of(context).size.height * 0.4,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context, <String, List<double>>{});
                    },
                    child: const CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 28,
                      child: Icon(Icons.arrow_back),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(32, 8, 0, 16),
                  child: Text(
                    'Emissions\nSummary',
                    style: TextStyle(fontSize: 24),
                  ),
                ),
                infoWidget(Colors.green, totalCo2, ' kg CO2e'),
                infoWidget(Colors.blue, totalWaterUse, 'L Water'),
                infoWidget(Colors.brown, totalLandUse, 'm^2 Land Use'),
                SizedBox(
                  height: 10,
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ingredients',
                            style: TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${widget.co2Food.length} carbon-intensive ingredients',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              controller: controller,
                              children: widget.co2Food.entries.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child:
                                      ingredientCard(entry.key, entry.value[0]),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget ingredientCard(String food, double emissions) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xffF7F6F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset('assets/' +
                    food.toLowerCase().replaceAll(' ', '_') +
                    '.png'),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 4,
                      backgroundColor: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    RichText(
                      text: TextSpan(
                        style:
                            const TextStyle(color: Colors.black, fontSize: 12),
                        children: [
                          TextSpan(text: emissions.toStringAsFixed(2)),
                          TextSpan(
                            text: ' kg CO2e',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget infoWidget(Color color, double stat, String units) {
    Widget unitWidget;

    if (units == 'm^2 Land Use') {
      unitWidget = RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          children: [
            const TextSpan(text: 'm'),
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: Transform.translate(
                offset: const Offset(0, -4),
                child: Text(
                  '2',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ),
            ),
            const TextSpan(text: ' Land Use'),
          ],
        ),
      );
    } else {
      unitWidget = Text(
        units,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 0, 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            stat.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
          const SizedBox(width: 10),
          unitWidget,
        ],
      ),
    );
  }

  void calculateAboveInfo() {
    double co2Emissions = 0.0;
    double landUse = 0.0;
    double waterUse = 0.0;

    for (var entry in widget.co2Food.entries) {
      List<double> values = entry.value;
      co2Emissions += values[0];
      waterUse += values[1];
      landUse += values[2];
    }

    setState(() {
      totalCo2 = co2Emissions;
      totalWaterUse = waterUse;
      totalLandUse = landUse;
    });
  }
}
