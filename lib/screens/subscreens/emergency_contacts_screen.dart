import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatefulWidget {
  @override
  _EmergencyContactsScreenState createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  String _selectedCountry = "Global";
  List<Map<String, String>> _contacts = [];
  List<Map<String, String>> _customContacts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedCountry();
    _loadCustomContacts();
  }

  ///Load last selected country from storage
  Future<void> _loadSavedCountry() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedCountry = prefs.getString("selected_country");

    setState(() {
      _selectedCountry = savedCountry ?? "Global";
      _contacts = emergencyNumbers[_selectedCountry]!;
    });
  }

  ///Save the selected country to storage
  Future<void> _saveCountry(String country) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("selected_country", country);
  }

  Future<void> _loadCustomContacts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedContacts = prefs.getStringList("custom_contacts");
    if (savedContacts != null) {
      setState(() {
        _customContacts =
            savedContacts.map((contact) {
              List<String> parts = contact.split('|');
              return {"name": parts[0], "number": parts[1]};
            }).toList();
      });
    }
  }

  Future<void> _saveCustomContacts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> contactsToSave =
        _customContacts
            .map((contact) => "${contact['name']}|${contact['number']}")
            .toList();
    await prefs.setStringList("custom_contacts", contactsToSave);
  }

  void _addCustomContact(String name, String number) {
    setState(() {
      _customContacts.add({"name": name, "number": number});
    });
    _saveCustomContacts();
  }

  void _deleteCustomContact(int index) {
    setState(() {
      _customContacts.removeAt(index);
    });
    _saveCustomContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Emergency Contacts")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select Your Country:",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),

            ///Country Dropdown
            DropdownButton<String>(
              value: _selectedCountry,
              isExpanded: true,
              items:
                  emergencyNumbers.keys.map((String country) {
                    return DropdownMenuItem(
                      value: country,
                      child: Text(country),
                    );
                  }).toList(),
              onChanged: (String? newCountry) {
                if (newCountry != null) {
                  setState(() {
                    _selectedCountry = newCountry;
                    _contacts = emergencyNumbers[newCountry]!;
                  });
                  _saveCountry(newCountry);
                }
              },
            ),

            const SizedBox(height: 20),

            ///Emergency Contacts List
            Expanded(
              child: ListView(
                children: [
                  ..._contacts.map(
                    (contact) =>
                        _buildContactTile(contact['name']!, contact['number']!),
                  ),
                  ..._customContacts.asMap().entries.map(
                    (entry) => _buildCustomContactTile(entry.key, entry.value),
                  ),
                ],
              ),
            ),
            /* ElevatedButton(
              onPressed: () => _showAddContactDialog(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Icon(Icons.add),
              ),
            ),
            const SizedBox(height: 20), */
          ],
        ),
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            onPressed: () => _showAddContactDialog(),
            heroTag: "add_contact_button",
            child: Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () => _callEmergencyNumber(),
            heroTag: "sos_button",
            backgroundColor: Colors.red,
            child: Icon(Icons.sos, color: Colors.white),
          ),
        ],
      ),

      ///Dynamic SOS Button
      /* floatingActionButton: FloatingActionButton(
        onPressed: () => _callEmergencyNumber(),
        backgroundColor: Colors.red,
        child: Icon(Icons.sos, color: Colors.white),
      ), */
    );
  }

  ///Function to get the main emergency number for the selected country
  void _callEmergencyNumber() {
    String emergencyNumber = emergencyNumbers[_selectedCountry]![0]["number"]!;
    launchUrl(Uri.parse("tel://$emergencyNumber"));
  }

  ///Build a contact tile
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

  Widget _buildCustomContactTile(int index, Map<String, String> contact) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.contact_emergency, color: Colors.blue),
        title: Text(contact['name']!),
        subtitle: Text("Call: ${contact['number']}"),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteCustomContact(index),
        ),
        onTap: () => launchUrl(Uri.parse("tel://${contact['number']}")),
      ),
    );
  }

  void _showAddContactDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController numberController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Add Custom Contact",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Contact Name",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numberController,
                  decoration: InputDecoration(
                    labelText: "Phone Number",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        "Cancel",
                        //style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isNotEmpty &&
                            numberController.text.isNotEmpty) {
                          _addCustomContact(
                            nameController.text,
                            numberController.text,
                          );
                          Navigator.of(context).pop();
                        }
                      },

                      child: Text("Add"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

///Expanded Emergency Numbers Database
Map<String, List<Map<String, String>>> emergencyNumbers = {
  "India": [
    {"name": "Emergency", "number": "112"},
    {"name": "Fire Department", "number": "101"},
    {"name": "Ambulance", "number": "102"},
    {"name": "Disaster Relief", "number": "108"},
  ],
  "USA": [
    {"name": "Emergency Services", "number": "911"},
    {"name": "Suicide Prevention", "number": "988"},
    {"name": "Fire Department", "number": "911"},
    {"name": "Medical Emergency", "number": "911"},
  ],
  "UK": [
    {"name": "Emergency Services", "number": "999"},
    {"name": "Medical Help (Non-Emergency)", "number": "111"},
    {"name": "Police (Non-Emergency)", "number": "101"},
  ],
  "Canada": [
    {"name": "Emergency Services", "number": "911"},
    {"name": "Crisis Services", "number": "988"},
    {"name": "Police", "number": "911"},
    {"name": "Fire Department", "number": "911"},
  ],
  "Australia": [
    {"name": "Emergency Services", "number": "000"},
    {"name": "Lifeline (Mental Health)", "number": "13 11 14"},
    {"name": "Police", "number": "000"},
    {"name": "Fire Department", "number": "000"},
  ],
  "Germany": [
    {"name": "Emergency Services", "number": "112"},
    {"name": "Police", "number": "110"},
    {"name": "Fire Department", "number": "112"},
  ],
  "France": [
    {"name": "Emergency Services", "number": "112"},
    {"name": "Ambulance", "number": "15"},
    {"name": "Fire Brigade", "number": "18"},
    {"name": "Police", "number": "17"},
  ],
  "Japan": [
    {"name": "Police", "number": "110"},
    {"name": "Fire & Ambulance", "number": "119"},
  ],
  "China": [
    {"name": "Police", "number": "110"},
    {"name": "Fire", "number": "119"},
    {"name": "Ambulance", "number": "120"},
  ],
  "South Korea": [
    {"name": "Emergency Services", "number": "112"},
    {"name": "Fire & Ambulance", "number": "119"},
  ],
  "Brazil": [
    {"name": "Emergency Services", "number": "190"},
    {"name": "Fire", "number": "193"},
    {"name": "Medical Emergency", "number": "192"},
  ],
  "Russia": [
    {"name": "Emergency Services", "number": "112"},
    {"name": "Police", "number": "102"},
    {"name": "Ambulance", "number": "103"},
  ],
  "South Africa": [
    {"name": "Emergency Services", "number": "10111"},
    {"name": "Ambulance", "number": "10177"},
  ],
  "Mexico": [
    {"name": "Emergency Services", "number": "911"},
    {"name": "Fire", "number": "068"},
    {"name": "Ambulance", "number": "065"},
  ],
  "Global": [
    {"name": "General Emergency", "number": "112"},
  ],
};
