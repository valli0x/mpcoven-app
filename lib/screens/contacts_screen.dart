import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/keygen_provider.dart';
import '../widgets/page_scaffold.dart';

String _short(String s, {int head = 8, int tail = 6}) =>
    s.length <= head + tail + 3
        ? s
        : '${s.substring(0, head)}…${s.substring(s.length - tail)}';

/// Address book: personal aliases for addresses/partners so the user isn't
/// reading raw hex everywhere.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadAliases();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final entries = provider.aliases.entries.toList()
          ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
        return PageScaffold(
          title: 'Contacts',
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add contact',
              onPressed: () => _edit(context, '', ''),
            ),
          ],
          body: entries.isEmpty
              ? _empty(context)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    return _ContactTile(
                      name: e.value,
                      address: e.key,
                      onEdit: () => _edit(context, e.key, e.value),
                      onDelete: () => provider.removeAlias(e.key),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contacts_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No contacts yet',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Add a name for an address so it shows everywhere instead of hex.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, String address, String name) async {
    final addrCtrl = TextEditingController(text: address);
    final nameCtrl = TextEditingController(text: name);
    final isNew = address.isEmpty;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? 'Add contact' : 'Edit contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addrCtrl,
              enabled: isNew,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                  labelText: 'Address', hintText: '0x… / bc1…'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != true || !context.mounted) return;
    final addr = addrCtrl.text.trim();
    final nm = nameCtrl.text.trim();
    if (addr.isEmpty) return;
    await context.read<AppProvider>().setAlias(addr, nm);
  }
}

class _ContactTile extends StatelessWidget {
  final String name;
  final String address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactTile({
    required this.name,
    required this.address,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEth = address.toLowerCase().startsWith('0x');
    final color =
        isEth ? const Color(0xFF627EEA) : const Color(0xFFF7931A);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Text(
            name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(_short(address, head: 10, tail: 8),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.edit_outlined, size: 19),
                onPressed: onEdit),
            IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 19, color: theme.colorScheme.error),
                onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
