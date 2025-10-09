// lib/edit_offer_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _ruMoneyFmt = NumberFormat('#,##0', 'ru_RU');
String formatSpaced(num v) => _ruMoneyFmt.format(v);
num parseSpaced(String s) =>
    num.tryParse(s.replaceAll('\u00A0', '').replaceAll(' ', '')) ?? 0;

class ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldV, TextEditingValue newV) {
    final raw = newV.text.replaceAll('\u00A0', '').replaceAll(' ', '');
    if (raw.isEmpty) {
      return const TextEditingValue(
          text: '', selection: TextSelection.collapsed(offset: 0));
    }
    if (!RegExp(r'^\d+$').hasMatch(raw)) return oldV;

    final formatted = _ruMoneyFmt.format(int.parse(raw));
    final offsetFromEnd = newV.text.length - newV.selection.end;
    final newOffset =
    (formatted.length - offsetFromEnd).clamp(0, formatted.length);
    return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: newOffset));
  }
}

const _kLabels = <String>[
  '— нет —',
  'Лучшее предложение',
  'Надёжная компания',
  'Мы рекомендуем',
  'Народный выбор',
];

class EditOfferPage extends StatefulWidget {
  final Map<String, dynamic> offer;

  const EditOfferPage({Key? key, required this.offer}) : super(key: key);

  @override
  State<EditOfferPage> createState() => _EditOfferPageState();
}

class _EditOfferPageState extends State<EditOfferPage> {
  final _formKey = GlobalKey<FormState>();
  SupabaseClient get _sb => Supabase.instance.client;

  // основные
  late final TextEditingController _sortOrderController;
  String _category = 'loan';
  final _brandController = TextEditingController();
  String _labelValue = _kLabels.first;

  // подпись под брендом (advertisement)
  final _subtitleController = TextEditingController();

  // займы
  final _amountController = TextEditingController();
  final _termController = TextEditingController();
  final _ageController = TextEditingController();

  // общее
  final _buttonLinkController = TextEditingController();

  // карточки: базовые тексты
  final _productInfoCtrl = TextEditingController();
  final _requirementsCtrl = TextEditingController(); // дефолт, оставляем

  // ── Т-Банк: ссылки по вариантам ──
  final _tbankBlackCtrl = TextEditingController();
  final _tbankJuniorCtrl = TextEditingController();
  final _tbankDriveCtrl = TextEditingController();
  final _tbankAllAirlinesCtrl = TextEditingController();
  final _tbankBlackPremiumCtrl = TextEditingController();

  // ── Т-Банк: ОПИСАНИЯ по вариантам (product_info) ──
  final _piBlackCtrl = TextEditingController();
  final _piJuniorCtrl = TextEditingController();
  final _piDriveCtrl = TextEditingController();
  final _piAllAirlinesCtrl = TextEditingController();
  final _piBlackPremiumCtrl = TextEditingController();

  String? _logoUrl;
  bool _isLoading = false;

  bool _isTinkoffBrand(String brand) {
    final b = brand.toLowerCase();
    return b.contains('т-банк') ||
        b.contains('тинькофф') ||
        b.contains('t-bank') ||
        b.contains('tinkoff');
  }

  bool get _isTinkoffDebit =>
      _category == 'debit_card' && _isTinkoffBrand(_brandController.text);

  // 🔹 Безопасно прочитать число из БД (num/строка с пробелами)
  num _numFrom(dynamic v) {
    try {
      if (v == null) return 0;
      if (v is num) return v;
      if (v is String) return parseSpaced(v);
    } catch (_) {}
    return 0;
  }

  @override
  void initState() {
    super.initState();

    _sortOrderController =
        TextEditingController(text: (widget.offer['sort_order'] ?? '').toString());

    _category = (widget.offer['category'] as String?) ?? 'loan';
    _brandController.text = widget.offer['brand'] ?? '';
    _labelValue = (widget.offer['label'] ?? '').isEmpty
        ? _kLabels.first
        : (widget.offer['label'] as String);

    _logoUrl = widget.offer['logo'] as String?;
    _buttonLinkController.text = widget.offer['button_link'] ?? '';

    // подпись под брендом
    _subtitleController.text = widget.offer['advertisement'] ?? '';

    // карточки: читаем base product_info и borrower_requirements
    final prodRaw = widget.offer['product_info'] ?? widget.offer['term'];
    final reqRaw = widget.offer['borrower_requirements'] ?? widget.offer['age'];
    _productInfoCtrl.text = (prodRaw == null) ? '' : '$prodRaw';
    _requirementsCtrl.text = (reqRaw == null) ? '' : '$reqRaw';

    // ссылки Т-Банк (если button_link — JSON)
    _initTbankLinks(widget.offer['button_link']);

    // NEW: подтянем карты описаний по вариантам (только product_info):
    _initVariantPIControllers(
      prodMapRaw: widget.offer['product_info_map'] ?? widget.offer['product_info'],
    );

    // ✅ ВАЖНО: заполняем поля ЗАЙМА из оффера
    final amt = _numFrom(widget.offer['amount_up']);
    _amountController.text = amt > 0 ? formatSpaced(amt) : '';
    _termController.text = (widget.offer['term'] ?? '').toString();
    _ageController.text = (widget.offer['age'] ?? '').toString();
  }

  void _initTbankLinks(dynamic rawLink) {
    try {
      if (rawLink == null) return;
      final obj = (rawLink is String) ? jsonDecode(rawLink) : rawLink;
      if (obj is Map) {
        final map = obj.map((k, v) => MapEntry('$k'.toLowerCase(), '$v'));
        _tbankBlackCtrl.text = (map['black'] ?? '').toString();
        _tbankJuniorCtrl.text = (map['junior'] ?? '').toString();
        _tbankDriveCtrl.text = (map['drive'] ?? '').toString();
        _tbankAllAirlinesCtrl.text = (map['all_airlines'] ?? '').toString();
        _tbankBlackPremiumCtrl.text =
            (map['black_premium'] ?? '').toString();
      }
    } catch (_) {/* ignore */}
  }

  void _initVariantPIControllers({dynamic prodMapRaw}) {
    Map<String, dynamic> _coerceToMap(dynamic raw) {
      try {
        if (raw == null) return const {};
        if (raw is Map) return raw.map((k, v) => MapEntry('$k'.toLowerCase(), v));
        if (raw is String && raw.trim().isNotEmpty) {
          final obj = jsonDecode(raw);
          if (obj is Map) {
            return obj.map((k, v) => MapEntry('$k'.toLowerCase(), v));
          }
        }
      } catch (_) {/* ignore */}
      return const {};
    }

    final p = _coerceToMap(prodMapRaw);

    _piBlackCtrl.text = (p['black'] ?? '').toString();
    _piJuniorCtrl.text = (p['junior'] ?? '').toString();
    _piDriveCtrl.text = (p['drive'] ?? '').toString();
    _piAllAirlinesCtrl.text = (p['all_airlines'] ?? '').toString();
    _piBlackPremiumCtrl.text = (p['black_premium'] ?? '').toString();
  }

  @override
  void dispose() {
    _sortOrderController.dispose();
    _brandController.dispose();
    _subtitleController.dispose();
    _amountController.dispose();
    _termController.dispose();
    _ageController.dispose();
    _buttonLinkController.dispose();
    _productInfoCtrl.dispose();
    _requirementsCtrl.dispose();

    _tbankBlackCtrl.dispose();
    _tbankJuniorCtrl.dispose();
    _tbankDriveCtrl.dispose();
    _tbankAllAirlinesCtrl.dispose();
    _tbankBlackPremiumCtrl.dispose();

    _piBlackCtrl.dispose();
    _piJuniorCtrl.dispose();
    _piDriveCtrl.dispose();
    _piAllAirlinesCtrl.dispose();
    _piBlackPremiumCtrl.dispose();

    super.dispose();
  }

  bool _looksLikeSvgUrl(String? url) {
    if (url == null) return false;
    final u = url.toLowerCase();
    return u.contains('.svg') ||
        u.contains('.svgz') ||
        u.contains('image/svg+xml');
  }

  Future<Uint8List?> _fileBytes(PlatformFile f) async {
    if (f.bytes != null) return f.bytes!;
    if (f.readStream != null) {
      final completer = Completer<Uint8List>();
      final chunks = <int>[];
      f.readStream!.listen(
            (data) => chunks.addAll(data),
        onDone: () => completer.complete(Uint8List.fromList(chunks)),
        onError: (e) => completer.completeError(e),
        cancelOnError: true,
      );
      return completer.future;
    }
    return null;
  }

  String _detectExt(String nameOrPath) {
    final i = nameOrPath.lastIndexOf('.');
    return (i == -1) ? '' : nameOrPath.substring(i + 1).toLowerCase();
  }

  String _mimeFromExt(String ext) {
    switch (ext) {
      case 'svg':
      case 'svgz':
        return 'image/svg+xml';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String?> _pickAndUploadToBucket({required String bucket}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowMultiple: false,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'svg', 'svgz'],
      );
      if (result == null || result.files.isEmpty) return null;

      final f = result.files.single;
      final bytes = await _fileBytes(f);
      if (bytes == null) throw Exception('Не удалось прочитать файл');

      final ext = _detectExt(f.name);
      final fileName =
          'uploads/${DateTime.now().millisecondsSinceEpoch}_${f.name}';

      await _sb.storage.from(bucket).uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(
          contentType: _mimeFromExt(ext),
          upsert: false,
          cacheControl: 'public, max-age=31536000',
        ),
      );

      return _sb.storage.from(bucket).getPublicUrl(fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
      }
      return null;
    }
  }

  Future<void> _pickLogo() async {
    final url = await _pickAndUploadToBucket(bucket: 'logos');
    if (url == null) return;
    setState(() => _logoUrl = url);
  }

  Map<String, String> _collectTinkoffLinks() {
    final map = <String, String>{};
    void put(String k, TextEditingController c) {
      final v = c.text.trim();
      if (v.isNotEmpty) map[k] = v;
    }

    put('black', _tbankBlackCtrl);
    put('junior', _tbankJuniorCtrl);
    put('drive', _tbankDriveCtrl);
    put('all_airlines', _tbankAllAirlinesCtrl);
    put('black_premium', _tbankBlackPremiumCtrl);
    return map;
  }

  Map<String, String> _collectVariantPI() {
    final m = <String, String>{};
    void put(String k, TextEditingController c) {
      final v = c.text.trim();
      if (v.isNotEmpty) m[k] = v;
    }

    put('black', _piBlackCtrl);
    put('junior', _piJuniorCtrl);
    put('drive', _piDriveCtrl);
    put('all_airlines', _piAllAirlinesCtrl);
    put('black_premium', _piBlackPremiumCtrl);
    return m;
  }

  Future<void> _updateOffer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_logoUrl == null || _logoUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пожалуйста, выберите логотип')));
      return;
    }

    final isCard = _category == 'credit_card' || _category == 'debit_card';

    setState(() => _isLoading = true);
    try {
      // Ссылка для кнопки: обычная или JSON по вариантам (Т-Банк)
      String buttonLink = _buttonLinkController.text.trim();
      if (_isTinkoffDebit) {
        final tmap = _collectTinkoffLinks();
        if (tmap.isNotEmpty) {
          buttonLink = jsonEncode(tmap);
        }
      }

      final updateData = <String, dynamic>{
        'sort_order': int.tryParse(_sortOrderController.text) ?? 0,
        'category': _category,
        'brand': _brandController.text.trim(),
        'label': _labelValue == _kLabels.first ? '' : _labelValue,
        'logo': _logoUrl!,
        'button_link': buttonLink,
        'advertisement': _subtitleController.text.trim(),
      };

      if (isCard) {
        // БАЗА
        final basePI = _productInfoCtrl.text.trim();
        final baseRQ = _requirementsCtrl.text.trim();

        // Подготавливаем product_info: дефолт + per-variant (для Т-Банк).
        String productInfoToStore = basePI;

        if (_isTinkoffDebit) {
          final piMap = _collectVariantPI(); // описания по вариантам

          // Кладём варианты прямо в product_info (JSON), плюс отдельно в product_info_map для совместимости
          final piCombined = <String, String>{};
          if (basePI.isNotEmpty) piCombined['default'] = basePI;
          piCombined.addAll(piMap);
          productInfoToStore = jsonEncode(piCombined);

          updateData['product_info_map'] =
          piMap.isEmpty ? null : jsonEncode(piMap);

          // ВАЖНО: borrower_requirements_map больше НЕ используем
          updateData['borrower_requirements_map'] = null;
        } else {
          updateData['product_info_map'] = null;
          updateData['borrower_requirements_map'] = null;
        }

        updateData.addAll({
          'product_info': productInfoToStore,
          'borrower_requirements': baseRQ, // дефолт (для других банков)
          // чистим старые "займовые" поля
          'term': '',
          'age': '',
          'amount_up': 0,
          'rate_annual_from': null,
          'decision_sec_from': null,
        });
      } else {
        // Для займов — классические поля
        updateData.addAll({
          'amount_up': parseSpaced(_amountController.text).toDouble(),
          'term': _termController.text.trim(),
          'age': _ageController.text.trim(),
          'rate_annual_from': null,
          'decision_sec_from': null,
          // на всякий случай очищаем карточные расширения
          'product_info_map': null,
          'borrower_requirements_map': null,
        });
      }

      await _sb
          .from('offerfromapi')
          .update(updateData)
          .eq('id', widget.offer['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Предложение обновлено')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка при обновлении: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCard = _category == 'credit_card' || _category == 'debit_card';
    final isTinkoffDebit = _isTinkoffDebit;

    return Scaffold(
      appBar: AppBar(title: const Text('Редактировать предложение')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Порядковый номер в выдаче',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _sortOrderController,
                decoration: const InputDecoration(
                  labelText: 'sort_order',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),

              const Text('Категория',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _category,
                decoration:
                const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'loan', child: Text('Займы')),
                  DropdownMenuItem(
                      value: 'credit_card',
                      child: Text('Кредитные карты')),
                  DropdownMenuItem(
                      value: 'debit_card',
                      child: Text('Дебетовые карты')),
                  DropdownMenuItem(
                      value: 'apply', child: Text('Оформление')),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'loan'),
                validator: (v) =>
                v == null || v.isEmpty ? 'Выберите категорию' : null,
              ),
              const SizedBox(height: 16),

              const Text('Логотип',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Center(
                      child: _logoUrl == null || _logoUrl!.isEmpty
                          ? const Icon(Icons.add_photo_alternate, size: 50)
                          : (_looksLikeSvgUrl(_logoUrl)
                          ? SvgPicture.network(
                        _logoUrl!,
                        width: 150,
                        height: 150,
                        fit: BoxFit.contain,
                      )
                          : Image.network(
                        _logoUrl!,
                        width: 150,
                        height: 150,
                        fit: BoxFit.contain,
                      )),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                    labelText: 'Бренд', border: OutlineInputBorder()),
                validator: (v) =>
                v == null || v.isEmpty ? 'Введите бренд' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _labelValue,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Ярлык (плашка)',
                    border: OutlineInputBorder()),
                items: _kLabels
                    .map((l) =>
                    DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _labelValue = v ?? _kLabels.first),
              ),
              const SizedBox(height: 16),

              // Подпись под брендом — для всех категорий
              TextFormField(
                controller: _subtitleController,
                decoration: const InputDecoration(
                  labelText: 'Подпись под брендом (банк/организация)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // ====== КАРТЫ ======
              if (isCard) ...[
                TextFormField(
                  controller: _buttonLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Ссылка на кнопку (общая)',
                    border: OutlineInputBorder(),
                    helperText:
                    'Для Т-Банк можно задать отдельные ссылки ниже',
                  ),
                  validator: (v) =>
                  v == null || v.isEmpty ? 'Введите ссылку' : null,
                ),
                const SizedBox(height: 16),

                // Ссылки Т-Банк
                if (isTinkoffDebit) ...[
                  const Text('Ссылки по картам Т-Банк',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _variantLinkField('Black', _tbankBlackCtrl),
                  const SizedBox(height: 8),
                  _variantLinkField('Junior', _tbankJuniorCtrl),
                  const SizedBox(height: 8),
                  _variantLinkField('Drive', _tbankDriveCtrl),
                  const SizedBox(height: 8),
                  _variantLinkField('All Airlines', _tbankAllAirlinesCtrl),
                  const SizedBox(height: 8),
                  _variantLinkField(
                      'Black Premium', _tbankBlackPremiumCtrl),
                  const SizedBox(height: 16),

                  // NEW: ТОЛЬКО ОПИСАНИЯ ПО ВАРИАНТАМ (без требований)
                  const Text('Тексты по картам Т-Банк',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _variantPIEditor(title: 'Black', pi: _piBlackCtrl),
                  const SizedBox(height: 12),
                  _variantPIEditor(title: 'Junior', pi: _piJuniorCtrl),
                  const SizedBox(height: 12),
                  _variantPIEditor(title: 'Drive', pi: _piDriveCtrl),
                  const SizedBox(height: 12),
                  _variantPIEditor(
                      title: 'All Airlines', pi: _piAllAirlinesCtrl),
                  const SizedBox(height: 12),
                  _variantPIEditor(
                      title: 'Black Premium', pi: _piBlackPremiumCtrl),
                  const SizedBox(height: 16),
                ],

                // Базовые тексты для карт
                TextFormField(
                  controller: _productInfoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Информация о продукте (дефолт)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 6,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _requirementsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Требования к заемщику (дефолт)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
              ],

              // ====== ЗАЙМЫ ======
              if (!isCard) ...[
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                      labelText: 'Сумма «до»',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorFormatter()],
                  validator: (v) => (parseSpaced(v ?? '') <= 0)
                      ? 'Введите сумму'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _termController,
                  decoration: const InputDecoration(
                      labelText: 'Срок', border: OutlineInputBorder()),
                  validator: (v) =>
                  v == null || v.isEmpty ? 'Введите срок' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(
                    labelText: 'Проценты',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _buttonLinkController,
                  decoration: const InputDecoration(
                      labelText: 'Ссылка на кнопку',
                      border: OutlineInputBorder()),
                  validator: (v) =>
                  v == null || v.isEmpty ? 'Введите ссылку' : null,
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                        onPressed: _updateOffer,
                        child: const Text('Обновить')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───── helpers (UI) ─────
  Widget _variantLinkField(String title, TextEditingController c) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(
        labelText: title,
        border: const OutlineInputBorder(),
      ),
    );
  }

  // Только редактор product_info для варианта
  Widget _variantPIEditor({
    required String title,
    required TextEditingController pi,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E1D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          TextFormField(
            controller: pi,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Описание (product_info) для этой карты',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
