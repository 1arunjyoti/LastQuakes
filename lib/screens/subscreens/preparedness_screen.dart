import 'package:flutter/material.dart';

class PreparednessScreen extends StatelessWidget {
  const PreparednessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Earthquake Preparedness"),
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      body: const _PreparednessList(),
    );
  }
}

class _PreparednessList extends StatelessWidget {
  const _PreparednessList();

  // Data for preparedness sections
  static const List<PreparednessSectionData> _preparednessData = [
    PreparednessSectionData(
      title: "Before an Earthquake",
      tips: [
        "Secure heavy furniture and appliances.",
        "Have an emergency kit ready (water, food, first aid, flashlight, batteries, whistle).",
        "Identify safe spots (under sturdy tables, against interior walls) and danger zones (windows, heavy objects) at home/work.",
        "Develop a family communication plan.",
        "Know how to turn off utilities (gas, water, electricity).",
      ],
    ),
    PreparednessSectionData(
      title: "During an Earthquake",
      tips: [
        "Indoors: Drop, Cover, and Hold On! Get under a sturdy desk or table. Protect your head and neck.",
        "Stay away from windows, glass, hanging objects, and heavy furniture.",
        "Do not use elevators.",
        "Outdoors: Move to an open area away from buildings, trees, streetlights, and utility wires.",
        "In a vehicle: Pull over safely, stop, and stay inside until shaking stops. Avoid bridges and overpasses.",
      ],
    ),
    PreparednessSectionData(
      title: "After an Earthquake",
      tips: [
        "Check yourself and others for injuries. Provide first aid if needed.",
        "Be prepared for aftershocks. Drop, Cover, and Hold On if they occur.",
        "Check for damage (gas leaks, electrical damage, structural issues). If you smell gas, open windows and leave immediately.",
        "Use phone for emergencies only. Text messages are often more reliable than calls.",
        "Listen to official information via battery-powered radio or authorities.",
        "Do not enter damaged buildings.",
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _preparednessData.length,
      itemBuilder: (context, index) {
        return _PreparednessSectionCard(sectionData: _preparednessData[index]);
      },
    );
  }
}

class _PreparednessSectionCard extends StatelessWidget {
  final PreparednessSectionData sectionData;

  const _PreparednessSectionCard({required this.sectionData});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sectionData.title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...sectionData.tips.map((tip) => _TipListTile(tip: tip)),
          ],
        ),
      ),
    );
  }
}

class _TipListTile extends StatelessWidget {
  final String tip;

  const _TipListTile({required this.tip});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PreparednessSectionData {
  final String title;
  final List<String> tips;

  const PreparednessSectionData({required this.title, required this.tips});
}
