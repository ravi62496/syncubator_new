import 'package:flutter/material.dart';

import '../widgets/baby_info_card.dart';
import '../widgets/custom_header.dart';
import '../widgets/weight_card.dart';
import '../widgets/bed_control_card.dart';
import '../widgets/climate_card.dart';
import '../widgets/oxygen_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const CustomHeader(
            title: "Syncubator",
            subtitle: "Where Care Meets Innovation",
            icon: Icons.child_friendly_rounded,
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: const [
                BabyInfoCard(
                  babyId: "NICU-001",
                  babyName: "Baby A",
                  age: "6 Days",
                ),
                SizedBox(height: 12),
                ClimateCard(),
                SizedBox(height: 12),
                OxygenCard(),
                SizedBox(height: 12),
                WeightCard(),
                SizedBox(height: 12),
                BedControlCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
