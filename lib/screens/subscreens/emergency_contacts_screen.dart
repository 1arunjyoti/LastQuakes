import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Emergency Contacts")),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildContactTile("National Emergency", "112"),
          _buildContactTile("Fire Department", "101"),
          _buildContactTile("Ambulance", "102"),
          _buildContactTile("Local Disaster Relief", "108"),
        ],
      ),
    );
  }

  Widget _buildContactTile(String name, String phone) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.phone, color: Colors.red),
        title: Text(name),
        subtitle: Text("Call: $phone"),
        onTap: () => launchUrl(Uri.parse("tel://$phone")),
      ),
    );
  }
}
