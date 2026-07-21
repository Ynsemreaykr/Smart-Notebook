import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../application/providers/calendar_provider.dart';
import '../../../application/providers/book_provider.dart';
import '../../../application/providers/page_provider.dart';
import '../../widgets/bounce_button.dart';

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _hasReminder = false;
  DateTime? _reminderTime;
  String? _linkedBookId;
  String? _linkedPageId;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _selectedTime);
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _pickReminderTime() async {
    final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
    if (date != null && mounted) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        setState(() {
          _reminderTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final eventDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);

    await context.read<CalendarProvider>().addEvent(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      dateTime: eventDateTime,
      linkedPageId: _linkedPageId,
      linkedBookId: _linkedBookId,
      hasReminder: _hasReminder,
      reminderTime: _reminderTime,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etkinlik oluşturuldu!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = context.watch<BookProvider>().books;

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Etkinlik')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Etkinlik Başlığı', prefixIcon: Icon(Icons.event)),
              validator: (v) => v == null || v.trim().isEmpty ? 'Başlık gerekli' : null,
            ),
            const SizedBox(height: 16),
            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Açıklama (opsiyonel)', prefixIcon: Icon(Icons.description)),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            // Date & Time
            Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    icon: Icons.calendar_today,
                    label: 'Tarih',
                    value: DateFormat('dd.MM.yyyy').format(_selectedDate),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoCard(
                    icon: Icons.access_time,
                    label: 'Saat',
                    value: _selectedTime.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Link to note
            const Text('Not Bağlantısı (opsiyonel)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _linkedBookId,
              decoration: const InputDecoration(labelText: 'Kitap Seçin', prefixIcon: Icon(Icons.book)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Seçim yok')),
                ...books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.title))),
              ],
              onChanged: (v) {
                setState(() {
                  _linkedBookId = v;
                  _linkedPageId = null;
                });
              },
            ),
            if (_linkedBookId != null) ...[
              const SizedBox(height: 12),
              Builder(builder: (_) {
                context.read<PageProvider>().loadPages(_linkedBookId!);
                final availablePages = context.read<PageProvider>().pages;
                return DropdownButtonFormField<String>(
                  value: _linkedPageId,
                  decoration: const InputDecoration(labelText: 'Sayfa Seçin', prefixIcon: Icon(Icons.article)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Seçim yok')),
                    ...availablePages.map((p) => DropdownMenuItem(value: p.id, child: Text(p.title))),
                  ],
                  onChanged: (v) => setState(() => _linkedPageId = v),
                );
              }),
            ],
            const SizedBox(height: 20),
            // Reminder
            SwitchListTile(
              title: const Text('Hatırlatıcı', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Bildirim gönder'),
              value: _hasReminder,
              activeColor: Theme.of(context).primaryColor,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() {
                _hasReminder = v;
                if (!v) _reminderTime = null;
              }),
            ),
            if (_hasReminder)
              _InfoCard(
                icon: Icons.notifications_active,
                label: 'Hatırlatıcı Zamanı',
                value: _reminderTime != null ? DateFormat('dd.MM.yyyy HH:mm').format(_reminderTime!) : 'Seçilmedi',
                onTap: _pickReminderTime,
              ),
            const SizedBox(height: 32),
            // Save button
            SizedBox(
              height: 52,
              child: BounceButton(
                onTap: _save,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Etkinlik Oluştur'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _InfoCard({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BounceButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
