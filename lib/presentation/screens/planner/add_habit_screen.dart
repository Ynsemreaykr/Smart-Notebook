import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../application/providers/habit_provider.dart';
import '../../../application/providers/note_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bounce_button.dart';
import '../../widgets/fade_slide_entrance.dart';

class AddHabitScreen extends StatefulWidget {
  final int? initialStartHour;
  const AddHabitScreen({super.key, this.initialStartHour});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _targetDaysCtrl;
  String? _selectedNoteId;
  String _selectedType = 'star';
  
  bool _isScheduled = false;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _targetDaysCtrl = TextEditingController();
    
    // Pre-fill time variables if loaded from timeline hour
    if (widget.initialStartHour != null) {
      _isScheduled = true;
      _startTime = TimeOfDay(hour: widget.initialStartHour!, minute: 0);
      _endTime = TimeOfDay(hour: (widget.initialStartHour! + 1) % 24, minute: 0);
    }

    // Load notes when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoteProvider>().loadNotes();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart 
          ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 10, minute: 0)),
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Alışkanlık Ekle'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.darkCard, AppTheme.darkBg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                // Icon Header (Animated)
                FadeSlideEntrance(
                  delay: const Duration(milliseconds: 50),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedType == 'star' ? Icons.star_rounded : Icons.timer_rounded,
                        size: 60,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Habit Name Field Card (Animated)
                FadeSlideEntrance(
                  delay: const Duration(milliseconds: 100),
                  child: Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alışkanlık İsmi',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameCtrl,
                            autofocus: true,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'örn. Günlük Kitap Okumak',
                              prefixIcon: const Icon(Icons.star_outline_rounded),
                              filled: true,
                              fillColor: AppTheme.darkCardHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                  return 'Lütfen bir alışkanlık ismi girin';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Habit Type Selector Card (Animated)
                FadeSlideEntrance(
                  delay: const Duration(milliseconds: 150),
                  child: Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alışkanlık Türü',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.star_rounded, size: 16),
                                      SizedBox(width: 6),
                                      Text('Yıldız'),
                                    ],
                                  ),
                                  selected: _selectedType == 'star',
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedType = 'star';
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.timer_rounded, size: 16),
                                      SizedBox(width: 6),
                                      Text('Sayaç (Süre)'),
                                    ],
                                  ),
                                  selected: _selectedType == 'timer',
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedType = 'timer';
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Schedule Type Card (Animated)
                FadeSlideEntrance(
                  delay: const Duration(milliseconds: 200),
                  child: Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alışkanlık Planlama Mantığı',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.watch_later_outlined, size: 16),
                                      SizedBox(width: 6),
                                      Text('Zamanlı (Saatli)'),
                                    ],
                                  ),
                                  selected: _isScheduled,
                                  onSelected: (selected) {
                                    setState(() {
                                      _isScheduled = selected;
                                      if (selected && _startTime == null) {
                                        _startTime = const TimeOfDay(hour: 9, minute: 0);
                                        _endTime = const TimeOfDay(hour: 10, minute: 0);
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.assignment_turned_in_outlined, size: 16),
                                      SizedBox(width: 6),
                                      Text('Serbest Yapılacak'),
                                    ],
                                  ),
                                  selected: !_isScheduled,
                                  onSelected: (selected) {
                                    setState(() {
                                      _isScheduled = !selected;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          
                          if (_isScheduled) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectTime(context, true),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.3)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Başlangıç Saati', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                          const SizedBox(height: 4),
                                          Text(
                                            _startTime != null ? _startTime!.format(context) : 'Seçilmedi',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectTime(context, false),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.3)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Bitiş Saati', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                          const SizedBox(height: 4),
                                          Text(
                                            _endTime != null ? _endTime!.format(context) : 'Seçilmedi',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Target Days Card (Animated)
                FadeSlideEntrance(
                  delay: const Duration(milliseconds: 250),
                  child: Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aylık Hedef Gün Sayısı (İsteğe Bağlı)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bu alışkanlığı ayda kaç gün gerçekleştirmeyi hedefliyorsunuz? Boş bırakırsanız ayın toplam gün sayısı hedef olarak alınır.',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _targetDaysCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'örn. 20',
                              prefixIcon: const Icon(Icons.outlined_flag_rounded),
                              filled: true,
                              fillColor: AppTheme.darkCardHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (val) {
                              if (val != null && val.trim().isNotEmpty) {
                                final num = int.tryParse(val.trim());
                                if (num == null || num <= 0 || num > 31) {
                                  return 'Lütfen 1 ile 31 arasında geçerli bir gün sayısı girin';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Link Note Selector Card (Animated)
                FadeSlideEntrance(
                  delay: const Duration(milliseconds: 300),
                  child: Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Not ile İlişkilendir (İsteğe Bağlı)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bu alışkanlığı bir nota bağlayarak takip tablosundan doğrudan notunuza erişebilirsiniz.',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Consumer<NoteProvider>(
                            builder: (context, noteProvider, _) {
                              final notes = noteProvider.notes;
                              
                              if (notes.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Henüz oluşturulmuş bir notunuz yok. Alışkanlığınızı bağlamak için önce bir not yazabilirsiniz.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              return DropdownButtonFormField<String?>(
                                initialValue: _selectedNoteId,
                                hint: const Text('Bağlanacak notu seçin'),
                                style: TextStyle(color: AppTheme.textPrimary),
                                dropdownColor: AppTheme.darkCardHigh,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.link_rounded),
                                  filled: true,
                                  fillColor: AppTheme.darkCardHigh,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Bağlantı Yok', style: TextStyle(color: AppTheme.textPrimary)),
                                  ),
                                  ...notes.map((note) => DropdownMenuItem<String?>(
                                    value: note.id,
                                    child: Text(
                                      note.title.isEmpty ? 'Başlıksız Not' : note.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: AppTheme.textPrimary),
                                    ),
                                  )),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedNoteId = val;
                                  });
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Save Button (Animated & Bounce Physics)
                FadeSlideEntrance(
                  delay: const Duration(milliseconds: 350),
                  child: BounceButton(
                    onTap: _saveHabit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.primaryGlow(intensity: 0.6),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Alışkanlığı Kaydet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveHabit() {
    if (_formKey.currentState!.validate()) {
      if (_isScheduled) {
        if (_startTime == null || _endTime == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lütfen başlangıç ve bitiş saatlerini seçin.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        final startMin = _startTime!.hour * 60 + _startTime!.minute;
        final endMin = _endTime!.hour * 60 + _endTime!.minute;
        if (endMin <= startMin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bitiş saati başlangıç saatinden sonra olmalıdır.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final name = _nameCtrl.text.trim();
      final targetDaysText = _targetDaysCtrl.text.trim();
      final targetDays = targetDaysText.isNotEmpty ? int.tryParse(targetDaysText) : null;
      
      final startStr = _isScheduled ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}' : null;
      final endStr = _isScheduled ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}' : null;

      context.read<HabitProvider>().addHabit(
        name,
        type: _selectedType,
        linkedNoteId: _selectedNoteId,
        targetDays: targetDays,
        startTime: startStr,
        endTime: endStr,
      );
      
      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$name" alışkanlığı başarıyla eklendi.'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    }
  }
}
