import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/form_outcome.dart';
import '../widgets/state_views.dart';
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
  bool _saving = false;
  String? _loadError;
  bool _dirty = false;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      StudioHall? hall;
      if (widget.id != null) {
        hall = await context.read<HallRepository>().findById(widget.id!);
      }
      if (!mounted) return;
      setState(() {
        _hall = hall;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  List<FieldSpec> _fields(CatalogNotifier catalog) {
    final hall = _hall;
    return [
      FieldSpec(
        name: 'name',
        serverError: _serverErrors['name'],
        label: 'Название зала',
        initialValue: hall?.name,
        validators: [V.required(), V.length(min: 2, max: 80)],
      ),
      FieldSpec(
        name: 'code',
        serverError: _serverErrors['code'],
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
        width: 240,
      ),
      FieldSpec(
        name: 'style',
        serverError: _serverErrors['style'],
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
        width: 320,
      ),
      FieldSpec(
        name: 'capacity',
        serverError: _serverErrors['capacity'],
        label: 'Вместимость, чел.',
        type: FieldType.number,
        initialValue: hall?.capacity ?? 5,
        validators: [V.positive(label: 'Вместимость')],
        width: 200,
      ),
      FieldSpec(
        name: 'hourlyRate',
        serverError: _serverErrors['hourlyRate'],
        label: 'Цена за час, ₽',
        type: FieldType.number,
        initialValue: hall?.hourlyRate ?? 2000,
        validators: [V.integer(min: 500, max: 100000, label: 'Цена')],
        width: 220,
      ),
      FieldSpec(
          name: 'description',
          label: 'Описание',
          type: FieldType.multiline,
          initialValue: hall?.description,
          validators: [V.length(max: 500)],
          serverError: _serverErrors['description']),
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
    context.go('/halls');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogNotifier>();
    return DirtyGuard(
      isDirty: () => _dirty,
      fallbackLocation: '/halls',
      message: 'Есть несохранённые изменения в зале. Выйти без сохранения?',
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/halls')),
          title: Text(_hall == null ? 'Новый зал' : 'Редактирование зала'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? ErrorView(message: _loadError!, onRetry: _load)
                : widget.id != null && _hall == null
                    ? const Center(child: Text('Запись не найдена'))
                    : EntityForm(
                        key: _entityFormKey,
                        formKey: _formKey,
                        saving: _saving,
                        fields: _fields(catalog),
                        rebuildToken: _revision,
                        saveLabel: _hall == null
                            ? 'Создать зал'
                            : 'Сохранить изменения',
                        onSubmit: _save,
                        onCancel: _cancel,
                        onChanged: () => setState(() => _dirty = true),
                      ),
      ),
    );
  }
}
