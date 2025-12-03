import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lastquakes/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  String _selectedCountry = "Global";
  List<Map<String, String>> _contacts = [];
  List<Map<String, String>> _customContacts = [];

  // Initialize state and load saved preferences
  @override
  void initState() {
    super.initState();
    _loadSavedCountry();
    _loadCustomContacts();
  }

  // Load last selected country from secure storage
  Future<void> _loadSavedCountry() async {
    try {
      // Try to load from secure storage first
      String? savedCountry =
          await SecureStorageService.retrieveSelectedCountry();

      if (savedCountry == null) {
        // Migrate from SharedPreferences if not found in secure storage
        SharedPreferences prefs = await SharedPreferences.getInstance();
        savedCountry = prefs.getString("selected_country");

        if (savedCountry != null) {
          // Save to secure storage and remove from SharedPreferences
          await SecureStorageService.storeSelectedCountry(savedCountry);
          await prefs.remove("selected_country");
          if (kDebugMode) {
            print('Migrated selected country to secure storage: $savedCountry');
          }
        }
      }

      setState(() {
        _selectedCountry = savedCountry ?? "Global";
        _contacts = emergencyNumbers[_selectedCountry]!;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading saved country: $e');
      }
      setState(() {
        _selectedCountry = "Global";
        _contacts = emergencyNumbers[_selectedCountry]!;
      });
    }
  }

  // Save the selected country to secure storage
  Future<void> _saveCountry(String country) async {
    try {
      await SecureStorageService.storeSelectedCountry(country);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving country: $e');
      }
      // Fallback to SharedPreferences on error
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString("selected_country", country);
    }
  }

  // Load custom contacts from secure storage
  Future<void> _loadCustomContacts() async {
    try {
      // Try to load from secure storage first
      List<Map<String, String>> savedContacts =
          await SecureStorageService.retrieveEmergencyContacts();

      if (savedContacts.isEmpty) {
        // Migrate from SharedPreferences if not found in secure storage
        SharedPreferences prefs = await SharedPreferences.getInstance();
        List<String>? legacyContacts = prefs.getStringList("custom_contacts");

        if (legacyContacts != null) {
          savedContacts =
              legacyContacts.map((contact) {
                List<String> parts = contact.split('|');
                // Add validation in case the split doesn't yield two parts
                if (parts.length == 2) {
                  return {"name": parts[0], "number": parts[1]};
                }
                return {"name": "Invalid Contact", "number": ""};
              }).toList();

          // Filter out invalid contacts
          savedContacts.removeWhere(
            (contact) => contact["name"] == "Invalid Contact",
          );

          // Save to secure storage and remove from SharedPreferences
          if (savedContacts.isNotEmpty) {
            await SecureStorageService.storeEmergencyContacts(savedContacts);
            await prefs.remove("custom_contacts");
            if (kDebugMode) {
              print(
                'Migrated ${savedContacts.length} emergency contacts to secure storage',
              );
            }
          }
        }
      }

      setState(() {
        _customContacts = savedContacts;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading custom contacts: $e');
      }
      setState(() {
        _customContacts = [];
      });
    }
  }

  // Save custom contacts to secure storage
  Future<void> _saveCustomContacts() async {
    try {
      await SecureStorageService.storeEmergencyContacts(_customContacts);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving custom contacts: $e');
      }
      // Fallback to SharedPreferences on error
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> contactsToSave =
          _customContacts
              .map((contact) => "${contact['name']}|${contact['number']}")
              .toList();
      await prefs.setStringList("custom_contacts", contactsToSave);
    }
  }

  // Add a custom contact
  void _addCustomContact(String name, String number) {
    setState(() {
      _customContacts.add({"name": name, "number": number});
    });
    _saveCustomContacts();
  }

  // Delete a custom contact
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
      appBar: AppBar(title: const Text("Emergency Contacts")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select Your Country:",
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Country Dropdown Menu
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
            ),
          );
        },
      ),

      // Floating Action Buttons for adding contact and SOS
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            onPressed: () => _showAddContactDialog(context),
            heroTag: "add_contact_button",
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () => _callEmergencyNumber(),
            heroTag: "sos_button",
            backgroundColor: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
            child: const Icon(Icons.sos),
          ),
        ],
      ),
    );
  }

  // Function to get the main emergency number for the selected country
  void _callEmergencyNumber() {
    if (emergencyNumbers.containsKey(_selectedCountry) &&
        emergencyNumbers[_selectedCountry]!.isNotEmpty &&
        emergencyNumbers[_selectedCountry]![0].containsKey("number")) {
      String emergencyNumber =
          emergencyNumbers[_selectedCountry]![0]["number"]!;
      try {
        launchUrl(Uri.parse("tel://$emergencyNumber"));
      } catch (e) {
        if (kDebugMode) {
          print("Could not launch dialer: $e");
        }
        /* ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open dialer.")),
        ); */
      }
    } else {
      // Handle cases where the number is not found
      if (kDebugMode) {
        print("Emergency number not found for $_selectedCountry");
      }
      /* ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text("Emergency number not found for $_selectedCountry.")),
      ); */
    }
  }

  // Build a contact tile using Material 3 styling
  Widget _buildContactTile(BuildContext context, String name, String phone) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(Icons.phone, color: colorScheme.primary),
        title: Text(name, style: textTheme.titleMedium),
        subtitle: Text(
          "Call: $phone",
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: () => launchUrl(Uri.parse("tel://$phone")),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Build a custom contact tile using Material 3 styling
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
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(Icons.contact_emergency, color: colorScheme.secondary),
        title: Text(contact['name']!, style: textTheme.titleMedium),
        subtitle: Text(
          "Call: ${contact['number']}",
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: colorScheme.error),
          tooltip: "Delete Contact",
          onPressed: () => _deleteCustomContact(index),
        ),
        onTap: () => launchUrl(Uri.parse("tel://${contact['number']}")),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Show Add Contact Dialog - web-optimized for web, simple for mobile
  void _showAddContactDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    TextEditingController nameController = TextEditingController();
    TextEditingController numberController = TextEditingController();

    // Use web-optimized dialog for web, simple dialog for mobile
    if (kIsWeb) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return _WebAddContactDialog(
            nameController: nameController,
            numberController: numberController,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isWeb: true,
            onAddContact: (name, number) {
              _addCustomContact(name, number);
              Navigator.of(dialogContext).pop();
            },
          );
        },
      );
    } else {
      // Simple mobile dialog
      showDialog(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Add Custom Contact", style: textTheme.headlineSmall),
                  const SizedBox(height: 16),

                  // Name TextField
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Contact Name",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(
                        Icons.person,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Phone Number TextField
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
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          final number = numberController.text.trim();
                          if (name.isNotEmpty && number.isNotEmpty) {
                            // Basic phone number validation
                            if (RegExp(
                              r'^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\\s\\./0-9]*$',
                            ).hasMatch(number)) {
                              _addCustomContact(name, number);
                              Navigator.of(dialogContext).pop();
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
}

/// Web-optimized Add Contact Dialog Widget
/// Features: Real-time validation, glassmorphic design, enhanced UX for web
class _WebAddContactDialog extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController numberController;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isWeb;
  final Function(String name, String number) onAddContact;

  const _WebAddContactDialog({
    required this.nameController,
    required this.numberController,
    required this.colorScheme,
    required this.textTheme,
    required this.isWeb,
    required this.onAddContact,
  });

  @override
  State<_WebAddContactDialog> createState() => _WebAddContactDialogState();
}

class _WebAddContactDialogState extends State<_WebAddContactDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  String? _nameError;
  String? _numberError;
  bool _isNameValid = false;
  bool _isNumberValid = false;

  final _phoneRegex = RegExp(r'^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\s\./0-9]*$');

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    // Add listeners for real-time validation
    widget.nameController.addListener(_validateName);
    widget.numberController.addListener(_validateNumber);
  }

  @override
  void dispose() {
    _animationController.dispose();
    widget.nameController.removeListener(_validateName);
    widget.numberController.removeListener(_validateNumber);
    widget.nameController.dispose();
    widget.numberController.dispose();
    super.dispose();
  }

  void _validateName() {
    final name = widget.nameController.text.trim();
    setState(() {
      if (name.isEmpty) {
        _nameError = null;
        _isNameValid = false;
      } else if (name.length < 2) {
        _nameError = "Name must be at least 2 characters";
        _isNameValid = false;
      } else {
        _nameError = null;
        _isNameValid = true;
      }
    });
  }

  void _validateNumber() {
    final number = widget.numberController.text.trim();
    setState(() {
      if (number.isEmpty) {
        _numberError = null;
        _isNumberValid = false;
      } else if (!_phoneRegex.hasMatch(number)) {
        _numberError = "Please enter a valid phone number";
        _isNumberValid = false;
      } else if (number.length < 5) {
        _numberError = "Phone number is too short";
        _isNumberValid = false;
      } else {
        _numberError = null;
        _isNumberValid = true;
      }
    });
  }

  void _handleSubmit() {
    _validateName();
    _validateNumber();

    if (_isNameValid && _isNumberValid) {
      widget.onAddContact(
        widget.nameController.text.trim(),
        widget.numberController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = widget.isWeb ? 560.0 : 400.0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: widget.colorScheme.surface,
          surfaceTintColor: widget.colorScheme.surfaceTint,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(widget.isWeb ? 32.0 : 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.contact_emergency,
                            size: 28,
                            color: widget.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Add Emergency Contact",
                                style: widget.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: widget.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Add a trusted contact for emergencies",
                                style: widget.textTheme.bodyMedium?.copyWith(
                                  color: widget.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: widget.isWeb ? 32.0 : 24.0),

                    // Divider
                    Divider(
                      color: widget.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                      height: 1,
                    ),

                    SizedBox(height: widget.isWeb ? 32.0 : 24.0),

                    // Name TextField with enhanced styling
                    TextField(
                      controller: widget.nameController,
                      decoration: InputDecoration(
                        labelText: "Contact Name *",
                        helperText: "Full name of your emergency contact",
                        helperStyle: widget.textTheme.bodySmall?.copyWith(
                          color: widget.colorScheme.onSurfaceVariant,
                        ),
                        errorText: _nameError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: widget.colorScheme.outline,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: widget.colorScheme.outline,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: widget.colorScheme.primary,
                            width: 2.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: widget.colorScheme.error,
                            width: 2.0,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: widget.colorScheme.error,
                            width: 2.5,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          color:
                              _isNameValid
                                  ? widget.colorScheme.primary
                                  : widget.colorScheme.onSurfaceVariant,
                        ),
                        suffixIcon:
                            _isNameValid
                                ? Icon(
                                  Icons.check_circle,
                                  color: widget.colorScheme.primary,
                                  size: 24,
                                )
                                : null,
                        filled: true,
                        fillColor: widget.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                      ),
                      textInputAction: TextInputAction.next,
                      style: widget.textTheme.bodyLarge,
                    ),

                    SizedBox(height: widget.isWeb ? 24.0 : 20.0),

                    // Phone Number TextField with enhanced styling
                    TextField(
                      controller: widget.numberController,
                      decoration: InputDecoration(
                        labelText: "Phone Number *",
                        helperText: "Include country code (e.g., +1 555-0100)",
                        helperStyle: widget.textTheme.bodySmall?.copyWith(
                          color: widget.colorScheme.onSurfaceVariant,
                        ),
                        errorText: _numberError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: widget.colorScheme.outline,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: widget.colorScheme.outline,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: widget.colorScheme.primary,
                            width: 2.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: widget.colorScheme.error,
                            width: 2.0,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: widget.colorScheme.error,
                            width: 2.5,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color:
                              _isNumberValid
                                  ? widget.colorScheme.primary
                                  : widget.colorScheme.onSurfaceVariant,
                        ),
                        suffixIcon:
                            _isNumberValid
                                ? Icon(
                                  Icons.check_circle,
                                  color: widget.colorScheme.primary,
                                  size: 24,
                                )
                                : null,
                        filled: true,
                        fillColor: widget.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleSubmit(),
                      style: widget.textTheme.bodyLarge,
                    ),

                    SizedBox(height: widget.isWeb ? 32.0 : 24.0),

                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.colorScheme.secondaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.colorScheme.secondary.withValues(
                            alpha: 0.2,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: widget.colorScheme.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "This contact will be saved securely and can be quickly accessed during emergencies",
                              style: widget.textTheme.bodySmall?.copyWith(
                                color: widget.colorScheme.onSecondaryContainer,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: widget.isWeb ? 32.0 : 24.0),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.isWeb ? 24 : 16,
                              vertical: widget.isWeb ? 16 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Cancel",
                            style: widget.textTheme.labelLarge,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed:
                              _isNameValid && _isNumberValid
                                  ? _handleSubmit
                                  : null,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.isWeb ? 28 : 20,
                              vertical: widget.isWeb ? 18 : 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _isNameValid && _isNumberValid ? 2 : 0,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: Text(
                            "Add Contact",
                            style: widget.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Emergency Numbers Database
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
