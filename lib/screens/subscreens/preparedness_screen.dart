import 'package:flutter/material.dart';

class PreparednessScreen extends StatelessWidget {
  const PreparednessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Earthquake Preparedness")),
      body: _PreparednessList(),
    );
  }
}

class _PreparednessList extends StatelessWidget {
  final List<PreparednessSectionData> _preparednessData = [
    PreparednessSectionData(
      title: "Before an Earthquake",
      tips: [
        "Secure heavy furniture and appliances.",
        "Have an emergency kit ready.",
        "Identify safe spots at home/work.",
      ],
    ),
    PreparednessSectionData(
      title: "During an Earthquake",
      tips: [
        "Drop, Cover, and Hold On!",
        "Stay away from windows and furniture.",
        "If outside, move to an open area.",
      ],
    ),
    PreparednessSectionData(
      title: "After an Earthquake",
      tips: [
        "Check yourself and others for injuries.",
        "Be prepared for aftershocks.",
        "Use text messages instead of calls.",
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sectionData.title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        Icons.check_circle_outline,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(tip, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class PreparednessSectionData {
  final String title;
  final List<String> tips;

  const PreparednessSectionData({required this.title, required this.tips});
}
