import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/form_outcome.dart';
import '../core/validators.dart';
import '../models/studio_hall.dart';
import '../repositories/hall_repository.dart';
import '../state/catalog_notifier.dart';
import '../widgets/dirty_guard.dart';
import '../widgets/entity_form.dart';

class HallFormScreen extends StatefulWidget {
  final int? id;
  const HallFormScreen({super.key, this.id});
  bool get isEditing => id != null;

  @override
  State<HallFormScreen> createState() => _HallFormScreenState();
}

class _HallFormScreenState extends State<HallFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _entityFormKey = GlobalKey<EntityFormState>();
  StudioHall? _hall;
  final Map<String, String?> _serverErrors = {};
  bool _loading = true;
  bool _dirty = false;
  bool _saving = false;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    StudioHall? hall;
    if (widget.id != null) {
      hall = await context.read<HallRepository>().findById(widget.id!);
    }
    if (!mounted) return;
    setState(() {
      _hall = hall;
      _loading = false;
    });
  }

  List<FieldSpec> _fields(CatalogNotifier catalog) {
    final hall = _hall;
    return [
      FieldSpec(
        name: 'name',
        label: 'Название зала',
        initialValue: hall?.name,
        validators: [V.required(), V.length(min: 2, max: 80)],
        serverError: _serverErrors['name'],
      ),
      FieldSpec(
        name: 'code',
        label: 'Код зала',
        initialValue: hall?.code,
        hint: 'Уникальный код, например A-01',
        validators: [
          V.required(),
          V.length(min: 2, max: 12),
          (value) => RegExp(r'^[A-Za-z0-9-]+$').hasMatch(value?.trim() ?? '')
              ? null
              : 'Допустимы латинские буквы, цифры и дефис',
        ],
        serverError: _serverErrors['code'],
        width: 240,
      ),
      FieldSpec(
        name: 'style',
        label: 'Стиль съёмки',
        type: catalog.hallStyles.isEmpty
            ? FieldType.text
            : FieldType.dropdownText,
        initialValue: hall?.style,
        hint: catalog.hallStyles.isEmpty ? 'Стиль съёмки' : null,
        textOptions: [
          for (final style in catalog.hallStyles)
            TextDropdownEntry(style, style),
        ],
        validators: [V.required(), V.length(min: 3, max: 40)],
        serverError: _serverErrors['style'],
        width: 320,
      ),
      FieldSpec(
        name: 'capacity',
        label: 'Вместимость, чел.',
        type: FieldType.number,
        initialValue: hall?.capacity ?? 5,
        validators: [V.positive(label: 'Вместимость')],
        serverError: _serverErrors['capacity'],
        width: 200,
      ),
      FieldSpec(
        name: 'hourlyRate',
        label: 'Цена за час, ₽',
        type: FieldType.number,
        initialValue: hall?.hourlyRate ?? 2000,
        validators: [V.integer(min: 500, max: 100000, label: 'Цена')],
        serverError: _serverErrors['hourlyRate'],
        width: 220,
      ),
      FieldSpec(
        name: 'description',
        label: 'Описание',
        type: FieldType.multiline,
        initialValue: hall?.description ?? '',
        hint: 'Необязательно: особенности зала, техника, условия',
        validators: [V.length(max: 300)],
        serverError: _serverErrors['description'],
      ),
    ];
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final form = _entityFormKey.currentState;
    if (form == null) return;
    if (_saving) return;

    setState(() {
      _saving = true;
      _serverErrors.clear();
      _revision++;
    });
    try {
      await context.read<HallRepository>().save(StudioHall(
            id: _hall?.id ?? 0,
            name: form.string('name'),
            code: form.string('code'),
            style: form.string('style'),
            capacity: form.number('capacity'),
            hourlyRate: form.number('hourlyRate'),
            description: form.string('description'),
            equipmentIds: _hall?.equipmentIds ?? const [],
            bookingIds: _hall?.bookingIds ?? const [],
            deletedAt: _hall?.deletedAt,
          ));
      _dirty = false;
      if (!mounted) return;
      await context.read<CatalogNotifier>().load(force: true);
      if (mounted) context.go('/halls');
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

  void _cancel() {
    _dirty = false;
    context.go('/halls');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogNotifier>();
    return DirtyGuard(
      dirty: _dirty,
      message: 'Есть несохранённые изменения в зале. Выйти без сохранения?',
      child: Scaffold(
        appBar: AppBar(
          title: Text(_hall == null ? 'Новый зал' : 'Редактирование зала'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : EntityForm(
                key: _entityFormKey,
                formKey: _formKey,
                fields: _fields(catalog),
                rebuildToken: _revision,
                saveLabel:
                    _hall == null ? 'Создать зал' : 'Сохранить изменения',
                saving: _saving,
                onSubmit: _save,
                onCancel: _cancel,
                onChanged: () => _dirty = true,
              ),
      ),
    );
  }
}
