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
              // Add validation in case the split doesn't yield two parts
              if (parts.length == 2) {
                return {"name": parts[0], "number": parts[1]};
              }
              // Return a default or handle the error appropriately
              return {"name": "Invalid Contact", "number": ""};
            }).toList();
        // Optionally filter out invalid contacts
        _customContacts.removeWhere(
          (contact) => contact["name"] == "Invalid Contact",
        );
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Emergency Contacts"),
        // Consider adding elevation or surfaceTintColor for M3 style
        // surfaceTintColor: colorScheme.surfaceTint,
        // elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select Your Country:",
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500, // M3 Title Large Weight
              ),
            ),
            const SizedBox(height: 10),

            ///Country Dropdown - Consider using DropdownMenu for a more modern M3 feel if applicable
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
              // Style the dropdown if needed, e.g., underline color
              // underline: Container(height: 1, color: colorScheme.outline),
            ),

            const SizedBox(height: 20),

            ///Emergency Contacts List
            Expanded(
              child: ListView(
                children: [
                  ..._contacts.map(
                    (contact) => _buildContactTile(
                      context,
                      contact['name']!,
                      contact['number']!,
                    ),
                  ),
                  ..._customContacts.asMap().entries.map(
                    (entry) => _buildCustomContactTile(
                      context,
                      entry.key,
                      entry.value,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            onPressed: () => _showAddContactDialog(context),
            heroTag: "add_contact_button",
            // Use theme colors
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () => _callEmergencyNumber(),
            heroTag: "sos_button",
            // Use error colors for SOS button
            backgroundColor: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
            child: const Icon(Icons.sos),
          ),
        ],
      ),
    );
  }

  ///Function to get the main emergency number for the selected country
  void _callEmergencyNumber() {
    // Add safety check in case the list is empty or structure is unexpected
    if (emergencyNumbers.containsKey(_selectedCountry) &&
        emergencyNumbers[_selectedCountry]!.isNotEmpty &&
        emergencyNumbers[_selectedCountry]![0].containsKey("number")) {
      String emergencyNumber =
          emergencyNumbers[_selectedCountry]![0]["number"]!;
      // Consider adding error handling for launchUrl
      try {
        launchUrl(Uri.parse("tel://$emergencyNumber"));
      } catch (e) {
        // Handle potential exceptions, e.g., show a snackbar
        print("Could not launch dialer: $e");
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Could not open dialer.")),
        // );
      }
    } else {
      // Handle cases where the number is not found
      print("Emergency number not found for $_selectedCountry");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Emergency number not found for $_selectedCountry.")),
      // );
    }
  }

  ///Build a contact tile using Material 3 styling
  Widget _buildContactTile(BuildContext context, String name, String phone) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      // Use M3 card styling
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // M3 recommended radius
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.phone,
          color: colorScheme.primary,
        ), // Use primary color
        title: Text(name, style: textTheme.titleMedium),
        subtitle: Text(
          "Call: $phone",
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: () => launchUrl(Uri.parse("tel://$phone")),
        // Add visual density for tighter spacing if desired
        // visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  ///Build a custom contact tile using Material 3 styling
  Widget _buildCustomContactTile(
    BuildContext context,
    int index,
    Map<String, String> contact,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.contact_emergency,
          color: colorScheme.secondary,
        ), // Use secondary color
        title: Text(contact['name']!, style: textTheme.titleMedium),
        subtitle: Text(
          "Call: ${contact['number']}",
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: colorScheme.error), // Use error color
          tooltip: "Delete Contact",
          onPressed: () => _deleteCustomContact(index),
        ),
        onTap: () => launchUrl(Uri.parse("tel://${contact['number']}")),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Show Add Contact Dialog with M3 styling
  void _showAddContactDialog(BuildContext context) {
    // Pass context
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    TextEditingController nameController = TextEditingController();
    TextEditingController numberController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        // Use a different context name for the dialog
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28), // M3 Dialog radius
          ),
          child: Padding(
            padding: const EdgeInsets.all(24), // M3 Dialog padding
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Add Custom Contact",
                  style: textTheme.headlineSmall?.copyWith(
                    // M3 Headline Small
                    // fontWeight: FontWeight.bold, // Default weight is usually fine
                  ),
                ),
                const SizedBox(height: 16), // M3 spacing
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Contact Name",
                    border: OutlineInputBorder(
                      // M3 default border
                      borderRadius: BorderRadius.circular(
                        12,
                      ), // Consistent radius
                    ),
                    prefixIcon: Icon(
                      Icons.person,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  textInputAction: TextInputAction.next, // Improve usability
                ),
                const SizedBox(height: 16), // M3 spacing
                TextField(
                  controller: numberController,
                  decoration: InputDecoration(
                    labelText: "Phone Number",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(
                      Icons.phone,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done, // Improve usability
                ),
                const SizedBox(height: 24), // M3 spacing before actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Use TextButton for less emphasis action
                    TextButton(
                      onPressed:
                          () =>
                              Navigator.of(
                                dialogContext,
                              ).pop(), // Use dialogContext
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 8),
                    // Use FilledButton or ElevatedButton for primary action
                    FilledButton(
                      // M3 primary button
                      onPressed: () {
                        final name = nameController.text.trim();
                        final number = numberController.text.trim();
                        if (name.isNotEmpty && number.isNotEmpty) {
                          // Basic phone number validation (optional but recommended)
                          if (RegExp(
                            r'^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\s\./0-9]*$',
                          ).hasMatch(number)) {
                            _addCustomContact(name, number);
                            Navigator.of(
                              dialogContext,
                            ).pop(); // Use dialogContext
                          } else {
                            // Show error if number is invalid
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please enter a valid phone number.",
                                ),
                              ),
                            );
                          }
                        } else {
                          // Show error if fields are empty
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please fill in both fields."),
                            ),
                          );
                        }
                      },
                      child: const Text("Add"),
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
// Keep this map as is, it's data not UI
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
