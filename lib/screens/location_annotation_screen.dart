import 'package:flutter/material.dart';

import 'city_search_screen.dart';

class LocationAnnotationResult {
  final City? city;
  final String detailAddress;

  const LocationAnnotationResult({
    required this.city,
    required this.detailAddress,
  });
}

class LocationAnnotationScreen extends StatefulWidget {
  final City? initialCity;
  final String? initialDetailAddress;

  const LocationAnnotationScreen({
    super.key,
    this.initialCity,
    this.initialDetailAddress,
  });

  @override
  State<LocationAnnotationScreen> createState() =>
      _LocationAnnotationScreenState();
}

class _LocationAnnotationScreenState extends State<LocationAnnotationScreen> {
  late final TextEditingController _detailController;
  City? _selectedCity;

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.initialCity == null
        ? null
        : City(name: widget.initialCity!.name, code: widget.initialCity!.code);
    _detailController = TextEditingController(
      text: widget.initialDetailAddress?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _openCitySelector() async {
    final selectedCity = await Navigator.push<City>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CitySearchScreen(selectedCity: _selectedCity?.name),
      ),
    );
    if (!mounted || selectedCity == null) return;
    setState(() => _selectedCity = selectedCity);
  }

  void _complete() {
    Navigator.pop(
      context,
      LocationAnnotationResult(
        city: _selectedCity,
        detailAddress: _detailController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCityName = _selectedCity?.name.trim() ?? '';
    final cityText = selectedCityName.isEmpty ? '未标注地点' : selectedCityName;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FBF4),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF2D5D35),
          ),
        ),
        title: const Text(
          '地点标注',
          style: TextStyle(
            color: Color(0xFF2D5D35),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '地点选择',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF3B6B42),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _openCitySelector,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7E7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFAED0AE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF2F663A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cityText,
                          style: const TextStyle(
                            color: Color(0xFF2D5D35),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_right_rounded,
                        color: Color(0xFF5B7F62),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '具体位置（可空）',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF3B6B42),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _detailController,
                maxLength: 40,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: '例如：朝阳区三里屯街道',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFBED9BE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFBED9BE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF5B9966),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '可输入街道、区县、门牌号等详细位置信息',
                style: TextStyle(fontSize: 12, color: Color(0xFF6A816E)),
              ),
              const Spacer(),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _complete,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2F663A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '完成',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
