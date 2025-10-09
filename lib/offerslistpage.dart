import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'editofferpage.dart';

class OffersListPage extends StatefulWidget {
  const OffersListPage({super.key});
  @override
  _OffersListPageState createState() => _OffersListPageState();
}

class _OffersListPageState extends State<OffersListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _offers = [];
  bool _isLoading = true;

  final _ruMoneyFmt = NumberFormat('#,##0', 'ru_RU');

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  String _ruCategory(String? code) {
    switch ((code ?? '').toLowerCase()) {
      case 'loan':
        return 'Займы';
      case 'credit_card':
        return 'Кредитные карты';
      case 'debit_card':
        return 'Дебетовые карты';
      case 'apply':
        return 'Оформление';
      default:
        return code ?? '';
    }
  }

  bool _truthy(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  Future<void> _loadOffers() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('offerfromapi')
          .select()
          .order('sort_order', ascending: true)
          .order('brand', ascending: true);

      setState(() {
        ScaffoldMessenger.of(context).clearSnackBars();
        _offers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  bool _looksLikeSvgUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final u = url.toLowerCase();
    return u.contains('.svg') || u.contains('image/svg+xml') || u.endsWith('.svgz');
  }

  Widget _logoWidget(String? url, {double width = 100, double height = 56}) {
    if (url == null || url.isEmpty) {
      return const Icon(Icons.image_not_supported);
    }
    final isSvg = _looksLikeSvgUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: isSvg
          ? SvgPicture.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      )
          : Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
      ),
    );
  }

  Future<void> _toggleHidden(Map<String, dynamic> offer) async {
    final id = offer['id'] as int;
    final currentHidden =
    _truthy(offer['is_hidden'] ?? offer['hidden'] ?? offer['hide']);
    final newHidden = !currentHidden;

    try {
      await supabase
          .from('offerfromapi')
          .update({'is_hidden': newHidden})
          .eq('id', id);

      if (!mounted) return;
      setState(() {
        final idx = _offers.indexWhere((o) => o['id'] == id);
        if (idx != -1) _offers[idx]['is_hidden'] = newHidden;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newHidden ? 'Оффер скрыт' : 'Оффер показан'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось изменить видимость: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список финансовых предложений'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOffers,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _offers.isEmpty
          ? const Center(child: Text('Нет доступных предложений'))
          : SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('№')),
              DataColumn(label: Text('Категория')),
              DataColumn(label: Text('Логотип')),
              DataColumn(label: Text('Бренд')),
              DataColumn(label: Text('Ярлык')),
              DataColumn(label: Text('Сумма до')),
              DataColumn(label: Text('Срок / Требования')),
              DataColumn(label: Text('Ссылка')),
              DataColumn(label: Text('Инфо о продукте')),
              DataColumn(label: Text('Действия')),
            ],
            rows: _offers.map((offer) {
              final num amount = offer['amount_up'] is num
                  ? offer['amount_up']
                  : (num.tryParse('${offer['amount_up']}') ?? 0);

              final category = (offer['category'] ?? '') as String;
              final isCard =
                  category == 'credit_card' || category == 'debit_card';

              // Новые поля для карт
              final borrowerRequirements =
              (offer['borrower_requirements'] ?? '') as String;
              final productInfo =
              (offer['product_info'] ?? '') as String;

              // Для таблицы:
              final termOrRequirements = isCard
                  ? borrowerRequirements
                  : (offer['term']?.toString() ?? '');

              final infoText =
              isCard ? productInfo : (offer['age']?.toString() ?? '');

              final label = (offer['label'] ?? '') as String;

              final hidden = _truthy(
                offer['is_hidden'] ?? offer['hidden'] ?? offer['hide'],
              );

              return DataRow(
                color: hidden
                    ? MaterialStateProperty.all(
                  Colors.black12.withOpacity(0.05),
                )
                    : null,
                cells: [
                  DataCell(Text('${offer['sort_order'] ?? ''}')),
                  DataCell(Text(_ruCategory(category))),
                  DataCell(_logoWidget(offer['logo'])),
                  DataCell(Text(offer['brand'] ?? '')),
                  DataCell(Text(label.isEmpty ? '—' : label)),
                  DataCell(Text(_ruMoneyFmt.format(amount))),
                  DataCell(
                    SizedBox(
                      width: 220,
                      child: Text(
                        termOrRequirements,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 160,
                      child: Text(
                        offer['button_link'] ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 260,
                      child: Text(
                        infoText,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditPage(offer),
                          tooltip: 'Редактировать',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () =>
                              _deleteOffer(offer['id'] as int),
                          tooltip: 'Удалить',
                        ),
                        IconButton(
                          icon: Icon(
                            hidden
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: hidden
                                ? Colors.redAccent
                                : Colors.green,
                          ),
                          onPressed: () => _toggleHidden(offer),
                          tooltip:
                          hidden ? 'Показать оффер' : 'Скрыть оффер',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.pushNamed(context, '/add_offer');
          if (created == true) _loadOffers();
        },
        tooltip: 'Добавить предложение',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showEditPage(Map<String, dynamic> offer) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditOfferPage(offer: offer),
      ),
    );
    if (updated == true) _loadOffers();
  }

  Future<void> _deleteOffer(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение'),
        content: const Text('Вы действительно хотите удалить это предложение?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('offerfromapi').delete().eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Предложение удалено!')),
          );
        }
        _loadOffers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления: $e')),
          );
        }
      }
    }
  }
}
