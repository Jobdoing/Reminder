import 'package:flutter_contacts/flutter_contacts.dart';
import 'contact_store.dart';

/// Wraps flutter_contacts (2.x API): requests permission, fetches display
/// names, and replaces ContactStore with the current device snapshot.
/// All flutter_contacts usage is isolated here.
class ContactImporter {
  /// Returns the number of names stored after import, or -1 if permission denied.
  static Future<int> importFromDevice() async {
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      return -1;
    }

    final contacts = await FlutterContacts.getAll();
    final newNames = contacts
        .map((c) => (c.displayName ?? '').trim())
        .where((n) => n.isNotEmpty)
        .toList();

    await ContactStore.setNames(newNames);
    return ContactStore.names().length;
  }

  static Future<void> openSettings() =>
      FlutterContacts.permissions.openSettings();
}
