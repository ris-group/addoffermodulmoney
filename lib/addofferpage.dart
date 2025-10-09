// lib/add_offer_page.dart
import 'dart:async';
import 'dart:convert'; // JSON для ссылок/описаний по вариантам
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _ruMoneyFmt = NumberFormat('#,##0', 'ru_RU');
String formatSpaced(num v) => _ruMoneyFmt.format(v);
num parseSpaced(String s) =>
    num.tryParse(s.replaceAll('\u00A0', '').replaceAll(' ', '')) ?? 0;

class ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldV, TextEditingValue newV) {
    final raw = newV.text.replaceAll('\u00A0', '').replaceAll(' ', '');
    if (raw.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }
    if (!RegExp(r'^\d+$').hasMatch(raw)) return oldV;

    final numStr = _ruMoneyFmt.format(int.parse(raw));
    final offsetFromEnd = newV.text.length - newV.selection.end;
    final newOffset = numStr.length - offsetFromEnd;
    return TextEditingValue(
      text: numStr,
      selection: TextSelection.collapsed(offset: newOffset.clamp(0, numStr.length)),
    );
  }
}

const _kLabels = <String>[
  '— нет —',
  'Лучшее предложение',
  'Надёжная компания',
  'Мы рекомендуем',
  'Народный выбор',
];

const _kCategories = <String, String>{
  'Займы': 'loan',
  'Кредитные карты': 'credit_card',
  'Дебетовые карты': 'debit_card',
  'Оформление': 'apply',
};

class AddOfferPage extends StatefulWidget {
  const AddOfferPage({Key? key}) : super(key: key);
  @override
  State<AddOfferPage> createState() => _AddOfferPageState();
}

class _AddOfferPageState extends State<AddOfferPage> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _sortOrderController  = TextEditingController();
  String? _categoryCode;
  final _brandController      = TextEditingController();
  String _labelValue          = _kLabels.first;

  final _subtitleController   = TextEditingController();

  final _amountController     = TextEditingController();
  final _termController       = TextEditingController();
  final _ageController        = TextEditingController();

  final _buttonLinkController = TextEditingController();

  final _productInfoCtrl      = TextEditingController();
  final _requirementsCtrl     = TextEditingController();

  String? _logoUrl;

  final _tbankBlackCtrl        = TextEditingController();
  final _tbankJuniorCtrl       = TextEditingController();
  final _tbankDriveCtrl        = TextEditingController();
  final _tbankAllAirlinesCtrl  = TextEditingController();
  final _tbankBlackPremiumCtrl = TextEditingController();

  final _tbankBlackDescCtrl        = TextEditingController();
  final _tbankJuniorDescCtrl       = TextEditingController();
  final _tbankDriveDescCtrl        = TextEditingController();
  final _tbankAllAirlinesDescCtrl  = TextEditingController();
  final _tbankBlackPremiumDescCtrl = TextEditingController();

  bool _isLoading = false;

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

    _tbankBlackDescCtrl.dispose();
    _tbankJuniorDescCtrl.dispose();
    _tbankDriveDescCtrl.dispose();
    _tbankAllAirlinesDescCtrl.dispose();
    _tbankBlackPremiumDescCtrl.dispose();

    super.dispose();
  }

  bool _isTinkoffBrand(String brand) {
    final b = brand.toLowerCase();
    return b.contains('т-банк') || b.contains('тинькофф') || b.contains('t-bank') || b.contains('tinkoff');
  }

  bool get _isTinkoffDebit =>
      _categoryCode == 'debit_card' && _isTinkoffBrand(_brandController.text);

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

  Map<String, String> _collectTinkoffDescriptions() {
    final map = <String, String>{};
    void put(String k, TextEditingController c) {
      final v = c.text.trim();
      if (v.isNotEmpty) map[k] = v;
    }
    put('black', _tbankBlackDescCtrl);
    put('junior', _tbankJuniorDescCtrl);
    put('drive', _tbankDriveDescCtrl);
    put('all_airlines', _tbankAllAirlinesDescCtrl);
    put('black_premium', _tbankBlackPremiumDescCtrl);
    return map;
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
      final fileName = 'uploads/${DateTime.now().millisecondsSinceEpoch}_${f.name}';

      await _supabase.storage.from(bucket).uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(
          contentType: _mimeFromExt(ext),
          upsert: false,
          cacheControl: 'public, max-age=31536000',
        ),
      );

      return _supabase.storage.from(bucket).getPublicUrl(fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _pickLogo() async {
    final url = await _pickAndUploadToBucket(bucket: 'logos');
    if (url == null) return;
    setState(() => _logoUrl = url);
  }

  Future<void> _saveOffer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_logoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, выберите логотип')));
      return;
    }
    if (_categoryCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите категорию')));
      return;
    }

    final isCard = _categoryCode == 'credit_card' || _categoryCode == 'debit_card';

    setState(() => _isLoading = true);
    try {
      // Ссылка: обычная или JSON по вариантам
      String buttonLink = _buttonLinkController.text.trim();
      if (_isTinkoffDebit) {
        final tmap = _collectTinkoffLinks();
        if (tmap.isNotEmpty) buttonLink = jsonEncode(tmap);
      }

      // Описание: строка или JSON по вариантам (кладём и default из _productInfoCtrl)
      String productInfoToStore = _productInfoCtrl.text.trim();
      Map<String, String> piMap = const {};
      if (_isTinkoffDebit) {
        final dmap = _collectTinkoffDescriptions();
        if (dmap.isNotEmpty) {
          final map = <String, String>{};
          if (productInfoToStore.isNotEmpty) map['default'] = productInfoToStore;
          map.addAll(dmap);
          productInfoToStore = jsonEncode(map);
          piMap = dmap; // для совместимости сохраним ещё и product_info_map
        }
      }

      final payload = <String, dynamic>{
        'sort_order'   : int.tryParse(_sortOrderController.text) ?? 0,
        'category'     : _categoryCode!,
        'brand'        : _brandController.text.trim(),
        'label'        : _labelValue == _kLabels.first ? '' : _labelValue,
        'logo'         : _logoUrl!,
        'button_link'  : buttonLink,
        'advertisement': _subtitleController.text.trim(),
      };

      if (isCard) {
        // Для Т-Банк дебет: требований нет (и map чистим).
        final borrowerReqToStore = _isTinkoffDebit ? '' : _requirementsCtrl.text.trim();

        payload.addAll({
          'product_info'          : productInfoToStore,
          'borrower_requirements' : borrowerReqToStore,
          'product_info_map'      : _isTinkoffDebit && piMap.isNotEmpty ? jsonEncode(piMap) : null,
          'borrower_requirements_map' : null, // явный сброс
          // чистим старые "займовые" поля
          'term' : '',
          'age'  : '',
          'amount_up'         : 0,
          'rate_annual_from'  : null,
          'decision_sec_from' : null,
        });
      } else {
        payload.addAll({
          'amount_up' : parseSpaced(_amountController.text).toDouble(),
          'term'      : _termController.text.trim(),
          'age'       : _ageController.text.trim(),
          'rate_annual_from'  : null,
          'decision_sec_from' : null,
        });
      }

      await _supabase.from('offerfromapi').insert(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Предложение успешно добавлено!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCard = _categoryCode == 'credit_card' || _categoryCode == 'debit_card';
    final logoPreview = _logoUrl == null
        ? const Icon(Icons.add_photo_alternate, size: 50)
        : (_logoUrl!.toLowerCase().endsWith('.svg') || _logoUrl!.toLowerCase().endsWith('.svgz')
        ? SvgPicture.network(_logoUrl!, fit: BoxFit.cover)
        : ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(_logoUrl!, fit: BoxFit.cover),
    ));

    return Scaffold(
      appBar: AppBar(title: const Text('Добавить предложение')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              value: _categoryCode,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _kCategories.entries
                  .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
                  .toList(),
              onChanged: (v) => setState(() => _categoryCode = v),
              validator: (v) => v == null ? 'Выберите категорию' : null,
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
                  child: Center(child: logoPreview),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: 'Бренд',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Введите бренд' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _labelValue,
              decoration: const InputDecoration(
                labelText: 'Ярлык (плашка)',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: _kLabels
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _labelValue = v ?? _kLabels.first),
            ),
            const SizedBox(height: 16),

            if (isCard) ...[
              TextFormField(
                controller: _subtitleController,
                decoration: const InputDecoration(
                  labelText: 'Подпись под брендом (банк/организация)',
                  border: OutlineInputBorder(),
                  helperText: 'Коротко: «Т-Банк», «ПАО «Совкомбанк»»',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _buttonLinkController,
                decoration: const InputDecoration(
                  labelText: 'Ссылка на кнопку (общая)',
                  border: OutlineInputBorder(),
                  helperText: 'Для Т-Банк можно задать отдельные ссылки ниже',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Введите ссылку' : null,
              ),
              const SizedBox(height: 16),

              // ── ССЫЛКИ по вариантам Т-Банк
              if (_isTinkoffDebit) ...[
                const Text('Ссылки по картам Т-Банк',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(controller: _tbankBlackCtrl, decoration: const InputDecoration(labelText: 'Black', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextFormField(controller: _tbankJuniorCtrl, decoration: const InputDecoration(labelText: 'Junior', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextFormField(controller: _tbankDriveCtrl, decoration: const InputDecoration(labelText: 'Drive', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextFormField(controller: _tbankAllAirlinesCtrl, decoration: const InputDecoration(labelText: 'All Airlines', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextFormField(controller: _tbankBlackPremiumCtrl, decoration: const InputDecoration(labelText: 'Black Premium', border: OutlineInputBorder())),
                const SizedBox(height: 16),

                const Text('Описания по картам Т-Банк',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(controller: _tbankBlackDescCtrl, decoration: const InputDecoration(labelText: 'Black — описание', border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 8),
                TextFormField(controller: _tbankJuniorDescCtrl, decoration: const InputDecoration(labelText: 'Junior — описание', border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 8),
                TextFormField(controller: _tbankDriveDescCtrl, decoration: const InputDecoration(labelText: 'Drive — описание', border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 8),
                TextFormField(controller: _tbankAllAirlinesDescCtrl, decoration: const InputDecoration(labelText: 'All Airlines — описание', border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 8),
                TextFormField(controller: _tbankBlackPremiumDescCtrl, decoration: const InputDecoration(labelText: 'Black Premium — описание', border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _productInfoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Информация о продукте (общая / fallback)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 6,
              ),
              const SizedBox(height: 16),

              // Требования показываем ТОЛЬКО если это не дебетовая карта Т-Банк
              if (!_isTinkoffDebit)
                TextFormField(
                  controller: _requirementsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Требования к заемщику',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
            ],

            if (!isCard) ...[
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Сумма кредита «до»',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorFormatter()],
                validator: (v) =>
                (parseSpaced(v ?? '') <= 0) ? 'Введите сумму' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _termController,
                decoration: const InputDecoration(
                  labelText: 'Срок кредита «до»',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                v == null || v.isEmpty ? 'Введите срок' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: 'Проценты',
                  border: OutlineInputBorder(),
                  helperText: 'Например: 0.01% или 1% в день — любой текст',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _buttonLinkController,
                decoration: const InputDecoration(
                  labelText: 'Ссылка на кнопку',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Введите ссылку' : null,
              ),
            ],

            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _saveOffer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text('Сохранить'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
