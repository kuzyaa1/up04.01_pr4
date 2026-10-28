import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/form_outcome.dart';
import '../widgets/state_views.dart';
import '../core/validators.dart';
import '../models/equipment.dart';
import '../repositories/equipment_repository.dart';
import '../state/catalog_notifier.dart';
import '../widgets/dirty_guard.dart';
import '../widgets/entity_form.dart';

class EquipmentFormScreen extends StatefulWidget {
  final int? id;
  const EquipmentFormScreen({super.key, this.id});
  bool get isEditing => id != null;
  @override
  State<EquipmentFormScreen> createState() => _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends State<EquipmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _entityFormKey = GlobalKey<EntityFormState>();
  Equipment? _equipment;
  final Map<String, String?> _serverErrors = {};
  List<String> _categories = const [];
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
      final repository = context.read<EquipmentRepository>();
      final catalog = context.read<CatalogNotifier>();
      Equipment? equipment;
      if (widget.id != null) {
        equipment = await repository.findById(widget.id!);
      }
      await catalog.load();
      if (catalog.error != null) throw StateError(catalog.error!);
      final categories = catalog.equipmentCategories;
      if (!mounted) return;
      setState(() {
        _equipment = equipment;
        _categories = categories;
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

  List<FieldSpec> _fields(CatalogNotifier catalog, List<String> categories) {
    final item = _equipment;
    final hasCategories = categories.isNotEmpty;
    return [
      FieldSpec(
        name: 'name',
        serverError: _serverErrors['name'],
        label: 'Название',
        initialValue: item?.name,
        validators: [V.required(), V.length(min: 2, max: 80)],
        width: 340,
      ),
      FieldSpec(
        name: 'category',
        serverError: _serverErrors['category'],
        label: 'Категория',
        type: hasCategories ? FieldType.dropdownText : FieldType.text,
        initialValue: item?.category,
        hint: hasCategories ? null : 'Категория оборудования',
        textOptions: [
          for (final category in categories)
            TextDropdownEntry(category, category),
        ],
        validators: [V.required(), V.length(min: 3, max: 30)],
        width: 280,
      ),
      FieldSpec(
        name: 'manufacturer',
        serverError: _serverErrors['manufacturer'],
        label: 'Производитель',
        initialValue: item?.manufacturer,
        validators: [V.length(max: 60)],
        width: 280,
      ),
      FieldSpec(
        name: 'hallId',
        serverError: _serverErrors['hallId'],
        label: 'Зал',
        type: FieldType.dropdown,
        initialValue: item?.hallId,
        hint: 'Связь «многие к одному»',
        options: [
          for (final hall in catalog.halls) DropdownEntry(hall.id, hall.name),
        ],
        validators: [V.notNull('Выберите зал')],
      ),
      FieldSpec(
        name: 'quantity',
        serverError: _serverErrors['quantity'],
        label: 'Количество, шт.',
        type: FieldType.number,
        initialValue: item?.quantity ?? 1,
        validators: [V.positive(label: 'Количество')],
        width: 200,
      ),
      FieldSpec(
        name: 'pricePerDay',
        serverError: _serverErrors['pricePerDay'],
        label: 'Цена за день, ₽',
        type: FieldType.number,
        initialValue: item?.pricePerDay ?? 0,
        validators: [V.integer(min: 0, max: 100000, label: 'Цена')],
        width: 220,
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
      await context.read<EquipmentRepository>().save(Equipment(
            id: _equipment?.id ?? 0,
            name: form.string('name'),
            category: form.string('category'),
            manufacturer: form.string('manufacturer'),
            hallId: form.number('hallId'),
            quantity: form.number('quantity'),
            pricePerDay: form.number('pricePerDay'),
            deletedAt: _equipment?.deletedAt,
          ));
      _dirty = false;
      if (!mounted) return;
      await context.read<CatalogNotifier>().load(force: true);
      if (mounted) context.go('/equipment');
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
    context.go('/equipment');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogNotifier>();
    return DirtyGuard(
      isDirty: () => _dirty,
      fallbackLocation: '/equipment',
      message: 'Есть несохранённые изменения. Выйти без сохранения?',
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/equipment')),
          title: Text(_equipment == null
              ? 'Новое оборудование'
              : 'Редактирование оборудования'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? ErrorView(message: _loadError!, onRetry: _load)
                : widget.id != null && _equipment == null
                    ? const Center(child: Text('Запись не найдена'))
                    : EntityForm(
                        key: _entityFormKey,
                        formKey: _formKey,
                        saving: _saving,
                        fields: _fields(catalog, _categories),
                        rebuildToken: _revision,
                        saveLabel: _equipment == null
                            ? 'Создать'
                            : 'Сохранить изменения',
                        onSubmit: _save,
                        onCancel: _cancel,
                        onChanged: () => setState(() => _dirty = true),
                      ),
      ),
    );
  }
}
