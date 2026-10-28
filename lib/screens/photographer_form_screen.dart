import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/form_outcome.dart';
import '../widgets/state_views.dart';
import '../core/validators.dart';
import '../models/photographer.dart';
import '../repositories/photographer_repository.dart';
import '../state/catalog_notifier.dart';
import '../widgets/dirty_guard.dart';
import '../widgets/entity_form.dart';

class PhotographerFormScreen extends StatefulWidget {
  final int? id;
  const PhotographerFormScreen({super.key, this.id});
  bool get isEditing => id != null;
  @override
  State<PhotographerFormScreen> createState() => _PhotographerFormScreenState();
}

class _PhotographerFormScreenState extends State<PhotographerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _entityFormKey = GlobalKey<EntityFormState>();
  Photographer? _photographer;
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
      Photographer? photographer;
      if (widget.id != null) {
        photographer =
            await context.read<PhotographerRepository>().findById(widget.id!);
      }
      if (!mounted) return;
      setState(() {
        _photographer = photographer;
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
    final item = _photographer;
    return [
      FieldSpec(
        name: 'lastName',
        serverError: _serverErrors['fullName'],
        label: 'Фамилия',
        initialValue: item?.lastName,
        validators: [V.required(), V.length(min: 2, max: 50)],
        width: 300,
      ),
      FieldSpec(
        name: 'firstName',
        serverError: _serverErrors['firstName'],
        label: 'Имя',
        initialValue: item?.firstName,
        validators: [V.required(), V.length(min: 2, max: 50)],
        width: 300,
      ),
      FieldSpec(
        name: 'specialization',
        serverError: _serverErrors['specialization'],
        label: 'Специализация',
        type: catalog.specializations.isEmpty
            ? FieldType.text
            : FieldType.dropdownText,
        initialValue: item?.specialization,
        hint: catalog.specializations.isEmpty ? 'Специализация' : null,
        textOptions: [
          for (final text in catalog.specializations)
            TextDropdownEntry(text, text),
        ],
        validators: [V.required(), V.length(min: 3, max: 40)],
        width: 300,
      ),
      FieldSpec(
        name: 'experienceYears',
        serverError: _serverErrors['experienceYears'],
        label: 'Стаж, лет',
        type: FieldType.number,
        initialValue: item?.experienceYears ?? 1,
        validators: [V.integer(min: 0, max: 60, label: 'Стаж')],
        width: 200,
      ),
      FieldSpec(
        name: 'hourlyRate',
        serverError: _serverErrors['hourlyRate'],
        label: 'Ставка, ₽/час',
        type: FieldType.number,
        initialValue: item?.hourlyRate ?? 3000,
        validators: [V.integer(min: 500, max: 100000, label: 'Ставка')],
        width: 220,
      ),
      FieldSpec(
        name: 'hallIds',
        serverError: _serverErrors['hallIds'],
        label: 'Работает в залах',
        type: FieldType.multiselect,
        initialValue: item?.hallIds ?? const [],
        hint: 'Связь «многие ко многим» с залами',
        isWideList: true,
        options: [
          for (final hall in catalog.halls) DropdownEntry(hall.id, hall.name),
        ],
        validators: [
          (value) =>
              value == null || value == '' ? 'Выберите хотя бы один зал' : null
        ],
      ),
      FieldSpec(
        name: 'bio',
        serverError: _serverErrors['bio'],
        label: 'О себе',
        type: FieldType.multiline,
        initialValue: item?.bio ?? '',
        hint: 'Необязательно',
        validators: [V.length(max: 500)],
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
      await context.read<PhotographerRepository>().save(Photographer(
            id: _photographer?.id ?? 0,
            lastName: form.string('lastName'),
            firstName: form.string('firstName'),
            specialization: form.string('specialization'),
            bio: form.string('bio'),
            experienceYears: form.number('experienceYears'),
            hourlyRate: form.number('hourlyRate'),
            hallIds: form.selection('hallIds'),
            bookingIds: _photographer?.bookingIds ?? const [],
            deletedAt: _photographer?.deletedAt,
          ));
      _dirty = false;
      if (!mounted) return;
      await context.read<CatalogNotifier>().load(force: true);
      if (mounted) context.go('/photographers');
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
    context.go('/photographers');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogNotifier>();
    return DirtyGuard(
      isDirty: () => _dirty,
      fallbackLocation: '/photographers',
      message: 'Есть несохранённые изменения. Выйти без сохранения?',
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/photographers')),
          title: Text(_photographer == null
              ? 'Новый фотограф'
              : 'Редактирование фотографа'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? ErrorView(message: _loadError!, onRetry: _load)
                : widget.id != null && _photographer == null
                    ? const Center(child: Text('Запись не найдена'))
                    : EntityForm(
                        key: _entityFormKey,
                        formKey: _formKey,
                        saving: _saving,
                        fields: _fields(catalog),
                        rebuildToken: _revision,
                        saveLabel: _photographer == null
                            ? 'Создать фотографа'
                            : 'Сохранить изменения',
                        onSubmit: _save,
                        onCancel: _cancel,
                        onChanged: () => setState(() => _dirty = true),
                      ),
      ),
    );
  }
}
