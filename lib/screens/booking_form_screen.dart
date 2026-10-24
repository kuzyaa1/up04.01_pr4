import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/form_outcome.dart';
import '../core/validators.dart';
import '../models/booking.dart';
import '../models/photographer.dart';
import '../repositories/booking_repository.dart';
import '../state/catalog_notifier.dart';
import '../widgets/dirty_guard.dart';
import '../widgets/entity_form.dart';

class BookingFormScreen extends StatefulWidget {
  final int? id;
  const BookingFormScreen({super.key, this.id});
  bool get isEditing => id != null;
  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _entityFormKey = GlobalKey<EntityFormState>();
  Booking? _booking;

  final Map<String, String?> _serverErrors = {};
  bool _loading = true;
  bool _dirty = false;
  bool _saving = false;
  int? _selectedHallId;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final catalog = context.read<CatalogNotifier>();
    final repository = context.read<BookingRepository>();
    if (!catalog.loaded) await catalog.load();
    Booking? booking;
    if (widget.id != null) {
      booking = await repository.findById(widget.id!);
    }
    if (!mounted) return;
    setState(() {
      _booking = booking;
      _selectedHallId = booking?.hallId;
      _loading = false;
    });
  }

  List<FieldSpec> _fields(CatalogNotifier catalog) {
    final booking = _booking;
    return [
      FieldSpec(
        name: 'clientId',
        label: 'Клиент',
        type: FieldType.dropdown,
        initialValue: booking?.clientId,
        options: [
          for (final client in catalog.clients)
            DropdownEntry(client.id, '${client.name} — ${client.email}'),
        ],
        validators: [V.notNull('Выберите клиента')],
      ),
      FieldSpec(
        name: 'email',
        label: 'Почта для связи',
        type: FieldType.email,
        initialValue: booking?.email,
        validators: [V.required(), V.email()],
        width: 320,
      ),
      FieldSpec(
        name: 'hallId',
        label: 'Зал студии',
        type: FieldType.dropdown,
        initialValue: _selectedHallId,
        hint: 'Связь «многие к одному»',
        options: [
          for (final hall in catalog.halls)
            DropdownEntry(hall.id,
                '${hall.name} — ${hall.hourlyRate} ₽/ч, до ${hall.capacity} чел.'),
        ],
        validators: [V.notNull('Выберите зал')],
        onChanged: (value) => _onHallChanged(value as int?),
      ),
      FieldSpec(
        name: 'photographerIds',
        label: 'Фотографы',
        type: FieldType.multiselect,
        initialValue: booking?.photographerIds ?? const [],
        hint: 'Связь «многие ко многим»: доступны работающие в выбранном зале',
        isWideList: true,
        options: [
          for (final photographer in _availablePhotographers(catalog))
            DropdownEntry(photographer.id, photographer.fullName),
        ],
        validators: [
          (value) => value == null || value == ''
              ? 'Выберите хотя бы одного фотографа'
              : null
        ],
      ),
      FieldSpec(
        name: 'date',
        label: 'Дата съёмки (ГГГГ-ММ-ДД)',
        type: FieldType.date,
        initialValue: booking == null
            ? _dateText(DateTime.now().add(const Duration(days: 1)))
            : _dateText(booking.date),
        validators: [V.notPast()],
        width: 300,
      ),
      FieldSpec(
        name: 'accessCode',
        label: 'Код бронирования',
        type: FieldType.text,
        initialValue: booking?.accessCode,
        hint: 'Латиница, цифры и дефис, не короче 6 символов',
        validators: [V.required(), V.accessCode()],
        serverError: _serverErrors['accessCode'],
        width: 320,
      ),
      FieldSpec(
        name: 'durationHours',
        label: 'Длительность, ч',
        type: FieldType.number,
        initialValue: booking?.durationHours ?? 2,
        validators: [V.integer(min: 1, max: 24, label: 'Длительность')],
        width: 190,
      ),
      FieldSpec(
        name: 'participants',
        label: 'Участников',
        type: FieldType.number,
        initialValue: booking?.participants ?? 1,
        validators: [V.positive(label: 'Количество участников')],
        width: 190,
      ),
      FieldSpec(
        name: 'shootingType',
        label: 'Тип съёмки',
        type: FieldType.text,
        initialValue: booking?.shootingType ?? 'Портретная',
        validators: [V.required(), V.length(min: 3, max: 40)],
        width: 320,
      ),
      FieldSpec(
        name: 'comment',
        label: 'Комментарий',
        type: FieldType.multiline,
        initialValue: booking?.comment ?? '',
        hint: 'Необязательно',
        validators: [V.length(max: 300)],
      ),
    ];
  }

  List<Photographer> _availablePhotographers(CatalogNotifier catalog) {
    final hallId = _selectedHallId;
    if (hallId == null) return catalog.photographers;
    return catalog.photographers
        .where((item) => item.hallIds.isEmpty || item.hallIds.contains(hallId))
        .toList();
  }

  void _onHallChanged(int? hallId) {
    final available = context
        .read<CatalogNotifier>()
        .photographers
        .where((item) =>
            hallId == null ||
            item.hallIds.isEmpty ||
            item.hallIds.contains(hallId))
        .map((item) => item.id)
        .toSet();
    final selected =
        _entityFormKey.currentState?.selection('photographerIds') ??
            _booking?.photographerIds ??
            const <int>[];
    final kept = selected.where(available.contains).toList();
    if (kept.length != selected.length) {
      _entityFormKey.currentState?.setValue('photographerIds', kept);
    }
    setState(() {
      _selectedHallId = hallId;
      _revision++;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final form = _entityFormKey.currentState;
    if (form == null) return;
    final catalog = context.read<CatalogNotifier>();
    final clientId = form.number('clientId');
    final client =
        catalog.clients.where((item) => item.id == clientId).firstOrNull;
    if (_saving) return;

    setState(() {
      _saving = true;
      _serverErrors.clear();
      _revision++;
    });
    try {
      await context.read<BookingRepository>().save(Booking(
            id: _booking?.id ?? 0,
            clientName: client?.name ?? 'Клиент #$clientId',
            clientId: clientId,
            email: form.string('email'),
            accessCode: form.string('accessCode'),
            hallId: form.number('hallId'),
            photographerIds: form.selection('photographerIds'),
            date: DateTime.tryParse(form.string('date')) ?? DateTime.now(),
            durationHours: form.number('durationHours'),
            participants: form.number('participants'),
            shootingType: form.string('shootingType'),
            comment: form.string('comment'),
            deletedAt: _booking?.deletedAt,
          ));
      _dirty = false;
      await catalog.load(force: true);
      if (mounted) context.go('/bookings');
    } on Object catch (error) {
      if (!mounted) return;
      final outcome = toFormOutcome(error);
      if (outcome is FormInvalid) {
        setState(() {
          _serverErrors
            ..clear()
            ..addAll(outcome.errors);
          _revision++;
        });
        _formKey.currentState?.validate();
      } else {
        showFormError(context, outcome);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _dateText(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  void _cancel() {
    _dirty = false;
    context.go('/bookings');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogNotifier>();
    return DirtyGuard(
      dirty: _dirty,
      message:
          'Есть несохранённые изменения в бронировании. Выйти без сохранения?',
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing
              ? 'Редактирование бронирования'
              : 'Новое бронирование'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : EntityForm(
                key: _entityFormKey,
                fields: _fields(catalog),
                formKey: _formKey,
                saveLabel: widget.isEditing
                    ? 'Сохранить изменения'
                    : 'Создать бронирование',
                saving: _saving,
                onSubmit: _save,
                onCancel: _cancel,
                onChanged: () => _dirty = true,
                rebuildToken: _revision,
              ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
