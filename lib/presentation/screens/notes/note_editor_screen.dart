import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../application/providers/note_provider.dart';

class NoteEditorScreen extends StatefulWidget {
  final String noteId;
  const NoteEditorScreen({super.key, required this.noteId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  bool _initialized = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _contentCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final note = context.read<NoteProvider>().getNoteById(widget.noteId);
      if (note != null) {
        _titleCtrl.text = note.title;
        _contentCtrl.text = note.content;
      }
      _initialized = true;
    }
  }

  Future<void> _save() async {
    if (!_hasChanges) return;
    await context.read<NoteProvider>().updateNote(
      widget.noteId,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text,
    );
    _hasChanges = false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await _save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Not Düzenle'),
          actions: [
            if (_hasChanges)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () async {
                  await _save();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kaydedildi'), duration: Duration(seconds: 1)),
                    );
                  }
                },
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Yeni Not',
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.3))),
                ),
                onChanged: (_) { if (!_hasChanges) setState(() => _hasChanges = true); },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _contentCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                  decoration: InputDecoration(
                    hintText: 'Notunuzu buraya yazın...',
                    border: InputBorder.none,
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white.withValues(alpha: 0.05) 
                          : Colors.grey.shade200,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.3))),
                  ),
                  onChanged: (_) { if (!_hasChanges) setState(() => _hasChanges = true); },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor, 
            border: Border(
              top: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withValues(alpha: 0.05) 
                  : Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.text_snippet_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(
                '${_contentCtrl.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} kelime',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 13),
              ),
              const Spacer(),
              if (_hasChanges)
                Text('Kaydedilmemiş', style: TextStyle(color: Colors.orange.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
