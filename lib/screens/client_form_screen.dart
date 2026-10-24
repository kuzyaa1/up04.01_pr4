import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/form_outcome.dart';
import '../core/validators.dart';
import '../models/client.dart';
import '../repositories/client_repository.dart';
import '../widgets/dirty_guard.dart';
import '../widgets/entity_form.dart';

class ClientFormScreen extends StatefulWidget {
  final int? id;
  const ClientFormScreen({super.key, this.id});
  bool get isEditing => id != null;
  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _entityFormKey = GlobalKey<EntityFormState>();
  Client? _client;
  final Map<String, String?> _serverErrors = {};
  bool _loading = true;
  bool _dirty = false;
  bool _saving = false;
  int _revision = 0;
  String _clientType = 'Частный';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Client? client;
    if (widget.id != null) {
      client = await context.read<ClientRepository>().findById(widget.id!);
    }
    if (!mounted) return;
    setState(() {
      _client = client;
      _clientType = client?.clientType ?? 'Частный';
      _loading = false;
    });
  }

  Future<List<String>> _loadTypes() async {
    final clients = await context.read<ClientRepository>().all();
    final values = clients
        .map((client) => client.clientType)
        .where((type) => type.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    for (final type in Client.clientTypes) {
      if (!values.contains(type)) values.add(type);
    }
    return values;
  }

  List<FieldSpec> _fields(List<String> types) {
    final client = _client;
    final today = DateTime.now();
    final isCorporate = _clientType == 'Корпоративный';
    return [
      FieldSpec(
        name: 'name',
        label: 'Имя клиента',
        initialValue: client?.name,
        validators: [V.required(), V.length(min: 2, max: 80)],
      ),
      FieldSpec(
        name: 'email',
        label: 'Email для связи',
        type: FieldType.email,
        initialValue: client?.email,
        hint: 'Уникальный адрес',
        validators: [V.required(), V.email()],
        serverError: _serverErrors['email'],
        width: 340,
      ),
      FieldSpec(
        name: 'phone',
        label: 'Телефон',
        type: FieldType.phone,
        initialValue: client?.phone,
        validators: [V.required(), V.phone()],
        serverError: _serverErrors['phone'],
        width: 260,
      ),
      FieldSpec(
        name: 'clientType',
        label: 'Тип клиента',
        type: FieldType.dropdownText,
        initialValue: _clientType,
        textOptions: [
          for (final type in types) TextDropdownEntry(type, type),
        ],
        validators: [V.notNull('Выберите тип клиента')],
        onChanged: (value) => _onClientTypeChanged(value as String?),
        width: 260,
      ),
      if (isCorporate)
        FieldSpec(
          name: 'company',
          label: 'Компания',
          initialValue: client?.company,
          hint: 'Название организации',
          validators: [V.required(), V.length(min: 2, max: 80)],
          width: 340,
        ),
      FieldSpec(
        name: 'cardNumber',
        label: 'Номер абонемента',
        initialValue: client?.cardNumber,
        hint: 'Уникальный номер, например AB-0001',
        groupTitle: 'Абонемент',
        validators: [
          V.required(),
          V.length(min: 4, max: 20),
          (value) =>
              RegExp(r'^[A-Za-zА-Яа-я0-9-]+$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Допустимы буквы, цифры и дефис',
        ],
        serverError: _serverErrors['cardNumber'],
        width: 260,
      ),
      FieldSpec(
        name: 'cardIssuedAt',
        label: 'Дата выдачи (ГГГГ-ММ-ДД)',
        type: FieldType.date,
        initialValue: client?.cardIssuedAt ?? _dateText(today),
        groupTitle: 'Абонемент',
        validators: [V.date(min: DateTime(today.year - 10), max: today)],
        width: 260,
      ),
      FieldSpec(
        name: 'cardExpiresAt',
        label: 'Действует до (ГГГГ-ММ-ДД)',
        type: FieldType.date,
        initialValue:
            client?.cardExpiresAt == null || client!.cardExpiresAt.isEmpty
                ? _dateText(today.add(const Duration(days: 365)))
                : client.cardExpiresAt,
        groupTitle: 'Абонемент',
        hint: 'Необязательно',
        validators: [
          V.date(min: DateTime(today.year - 10)),
          (value) {
            final issued = _entityFormKey.currentState?.string('cardIssuedAt');
            final expires = value?.trim() ?? '';
            if (issued == null || expires.isEmpty) return null;
            final issuedDate = DateTime.tryParse(issued);
            final expiresDate = DateTime.tryParse(expires);
            if (issuedDate == null || expiresDate == null) return null;
            return expiresDate.isBefore(issuedDate)
                ? 'Срок действия не может быть раньше даты выдачи'
                : null;
          },
        ],
        width: 260,
      ),
      FieldSpec(
        name: 'notes',
        label: 'Пожелания и заметки',
        type: FieldType.multiline,
        initialValue: client?.notes ?? '',
        hint: 'Необязательно: особенности съёмок, предпочтения',
        validators: [V.length(max: 500)],
      ),
    ];
  }

  void _onClientTypeChanged(String? type) {
    setState(() {
      _clientType = type ?? 'Частный';
      _revision++;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final form = _entityFormKey.currentState;
    if (form == null) return;
    final isCorporate = form.string('clientType') == 'Корпоративный';
    if (_saving) return;

    setState(() {
      _saving = true;
      _serverErrors.clear();
      _revision++;
    });
    try {
      await context.read<ClientRepository>().save(Client(
            id: _client?.id ?? 0,
            name: form.string('name'),
            email: form.string('email'),
            phone: form.string('phone'),
            clientType: form.string('clientType'),
            company: isCorporate ? form.string('company') : '',
            cardNumber: form.string('cardNumber'),
            cardIssuedAt: form.string('cardIssuedAt'),
            cardExpiresAt: form.string('cardExpiresAt'),
            notes: form.string('notes'),
            deletedAt: _client?.deletedAt,
          ));
      _dirty = false;
      if (mounted) context.go('/clients');
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
    context.go('/clients');
  }

  @override
  Widget build(BuildContext context) {
    return DirtyGuard(
      dirty: _dirty,
      message:
          'Есть несохранённые изменения в карточке клиента. Выйти без сохранения?',
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(_client == null ? 'Новый клиент' : 'Редактирование клиента'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder<List<String>>(
                future: _loadTypes(),
                builder: (context, snapshot) {
                  final types = snapshot.data ?? Client.clientTypes;
                  return EntityForm(
                    key: _entityFormKey,
                    formKey: _formKey,
                    fields: _fields(types),
                    rebuildToken: _revision,
                    saveLabel: _client == null
                        ? 'Создать клиента'
                        : 'Сохранить изменения',
                    saving: _saving,
                    onSubmit: _save,
                    onCancel: _cancel,
                    onChanged: () => _dirty = true,
                  );
                },
              ),
      ),
    );
  }
}
