import 'package:flutter/material.dart';

/// 城市数据模型，包含城市名称和行政编码
class City {
  final String name;
  final String code;

  const City({required this.name, required this.code});

  @override
  String toString() => name;
}

class CitySearchScreen extends StatefulWidget {
  final String? selectedCity;

  const CitySearchScreen({super.key, this.selectedCity});

  @override
  State<CitySearchScreen> createState() => _CitySearchScreenState();
}

class _CitySearchScreenState extends State<CitySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<City> _allCities = [
    // 直辖市
    City(name: '北京市', code: '1101'),
    City(name: '上海市', code: '3101'),
    City(name: '天津市', code: '1201'),
    City(name: '重庆市', code: '5001'),
    // 河北省
    City(name: '石家庄市', code: '1301'),
    City(name: '唐山市', code: '1302'),
    City(name: '秦皇岛市', code: '1303'),
    City(name: '邯郸市', code: '1304'),
    City(name: '邢台市', code: '1305'),
    City(name: '保定市', code: '1306'),
    City(name: '张家口市', code: '1307'),
    City(name: '承德市', code: '1308'),
    City(name: '沧州市', code: '1309'),
    City(name: '廊坊市', code: '1310'),
    City(name: '衡水市', code: '1311'),
    // 山西省
    City(name: '太原市', code: '1401'),
    City(name: '大同市', code: '1402'),
    City(name: '阳泉市', code: '1403'),
    City(name: '长治市', code: '1404'),
    City(name: '晋城市', code: '1405'),
    City(name: '朔州市', code: '1406'),
    City(name: '晋中市', code: '1407'),
    City(name: '运城市', code: '1408'),
    City(name: '忻州市', code: '1409'),
    City(name: '临汾市', code: '1410'),
    City(name: '吕梁市', code: '1411'),
    // 内蒙古自治区
    City(name: '呼和浩特市', code: '1501'),
    City(name: '包头市', code: '1502'),
    City(name: '乌海市', code: '1503'),
    City(name: '赤峰市', code: '1504'),
    City(name: '通辽市', code: '1505'),
    City(name: '鄂尔多斯市', code: '1506'),
    City(name: '呼伦贝尔市', code: '1507'),
    City(name: '巴彦淖尔市', code: '1508'),
    City(name: '乌兰察布市', code: '1509'),
    City(name: '兴安盟', code: '1522'),
    City(name: '锡林郭勒盟', code: '1525'),
    City(name: '阿拉善盟', code: '1529'),
    // 辽宁省
    City(name: '沈阳市', code: '2101'),
    City(name: '大连市', code: '2102'),
    City(name: '鞍山市', code: '2103'),
    City(name: '抚顺市', code: '2104'),
    City(name: '本溪市', code: '2105'),
    City(name: '丹东市', code: '2106'),
    City(name: '锦州市', code: '2107'),
    City(name: '营口市', code: '2108'),
    City(name: '阜新市', code: '2109'),
    City(name: '辽阳市', code: '2110'),
    City(name: '盘锦市', code: '2111'),
    City(name: '铁岭市', code: '2112'),
    City(name: '朝阳市', code: '2113'),
    City(name: '葫芦岛市', code: '2114'),
    // 吉林省
    City(name: '长春市', code: '2201'),
    City(name: '吉林市', code: '2202'),
    City(name: '四平市', code: '2203'),
    City(name: '辽源市', code: '2204'),
    City(name: '通化市', code: '2205'),
    City(name: '白山市', code: '2206'),
    City(name: '松原市', code: '2207'),
    City(name: '白城市', code: '2208'),
    City(name: '延边朝鲜族自治州', code: '2224'),
    // 黑龙江省
    City(name: '哈尔滨市', code: '2301'),
    City(name: '齐齐哈尔市', code: '2302'),
    City(name: '鸡西市', code: '2303'),
    City(name: '鹤岗市', code: '2304'),
    City(name: '双鸭山市', code: '2305'),
    City(name: '大庆市', code: '2306'),
    City(name: '伊春市', code: '2307'),
    City(name: '佳木斯市', code: '2308'),
    City(name: '七台河市', code: '2309'),
    City(name: '牡丹江市', code: '2310'),
    City(name: '黑河市', code: '2311'),
    City(name: '绥化市', code: '2312'),
    City(name: '大兴安岭地区', code: '2327'),
    // 江苏省
    City(name: '南京市', code: '3201'),
    City(name: '无锡市', code: '3202'),
    City(name: '徐州市', code: '3203'),
    City(name: '常州市', code: '3204'),
    City(name: '苏州市', code: '3205'),
    City(name: '南通市', code: '3206'),
    City(name: '连云港市', code: '3207'),
    City(name: '淮安市', code: '3208'),
    City(name: '盐城市', code: '3209'),
    City(name: '扬州市', code: '3210'),
    City(name: '镇江市', code: '3211'),
    City(name: '泰州市', code: '3212'),
    City(name: '宿迁市', code: '3213'),
    // 浙江省
    City(name: '杭州市', code: '3301'),
    City(name: '宁波市', code: '3302'),
    City(name: '温州市', code: '3303'),
    City(name: '嘉兴市', code: '3304'),
    City(name: '湖州市', code: '3305'),
    City(name: '绍兴市', code: '3306'),
    City(name: '金华市', code: '3307'),
    City(name: '衢州市', code: '3308'),
    City(name: '舟山市', code: '3309'),
    City(name: '台州市', code: '3310'),
    City(name: '丽水市', code: '3311'),
    // 安徽省
    City(name: '合肥市', code: '3401'),
    City(name: '芜湖市', code: '3402'),
    City(name: '蚌埠市', code: '3403'),
    City(name: '淮南市', code: '3404'),
    City(name: '马鞍山市', code: '3405'),
    City(name: '淮北市', code: '3406'),
    City(name: '铜陵市', code: '3407'),
    City(name: '安庆市', code: '3408'),
    City(name: '黄山市', code: '3410'),
    City(name: '滁州市', code: '3411'),
    City(name: '阜阳市', code: '3412'),
    City(name: '宿州市', code: '3413'),
    City(name: '六安市', code: '3415'),
    City(name: '亳州市', code: '3416'),
    City(name: '池州市', code: '3417'),
    City(name: '宣城市', code: '3418'),
    // 福建省
    City(name: '福州市', code: '3501'),
    City(name: '厦门市', code: '3502'),
    City(name: '莆田市', code: '3503'),
    City(name: '三明市', code: '3504'),
    City(name: '泉州市', code: '3505'),
    City(name: '漳州市', code: '3506'),
    City(name: '南平市', code: '3507'),
    City(name: '龙岩市', code: '3508'),
    City(name: '宁德市', code: '3509'),
    // 江西省
    City(name: '南昌市', code: '3601'),
    City(name: '景德镇市', code: '3602'),
    City(name: '萍乡市', code: '3603'),
    City(name: '九江市', code: '3604'),
    City(name: '新余市', code: '3605'),
    City(name: '鹰潭市', code: '3606'),
    City(name: '赣州市', code: '3607'),
    City(name: '吉安市', code: '3608'),
    City(name: '宜春市', code: '3609'),
    City(name: '抚州市', code: '3610'),
    City(name: '上饶市', code: '3611'),
    // 山东省
    City(name: '济南市', code: '3701'),
    City(name: '青岛市', code: '3702'),
    City(name: '淄博市', code: '3703'),
    City(name: '枣庄市', code: '3704'),
    City(name: '东营市', code: '3705'),
    City(name: '烟台市', code: '3706'),
    City(name: '潍坊市', code: '3707'),
    City(name: '济宁市', code: '3708'),
    City(name: '泰安市', code: '3709'),
    City(name: '威海市', code: '3710'),
    City(name: '日照市', code: '3711'),
    City(name: '临沂市', code: '3713'),
    City(name: '德州市', code: '3714'),
    City(name: '聊城市', code: '3715'),
    City(name: '滨州市', code: '3716'),
    City(name: '菏泽市', code: '3717'),
    // 河南省
    City(name: '郑州市', code: '4101'),
    City(name: '开封市', code: '4102'),
    City(name: '洛阳市', code: '4103'),
    City(name: '平顶山市', code: '4104'),
    City(name: '安阳市', code: '4105'),
    City(name: '鹤壁市', code: '4106'),
    City(name: '新乡市', code: '4107'),
    City(name: '焦作市', code: '4108'),
    City(name: '濮阳市', code: '4109'),
    City(name: '许昌市', code: '4110'),
    City(name: '漯河市', code: '4111'),
    City(name: '三门峡市', code: '4112'),
    City(name: '南阳市', code: '4113'),
    City(name: '商丘市', code: '4114'),
    City(name: '信阳市', code: '4115'),
    City(name: '周口市', code: '4116'),
    City(name: '驻马店市', code: '4117'),
    // 湖北省
    City(name: '武汉市', code: '4201'),
    City(name: '黄石市', code: '4202'),
    City(name: '十堰市', code: '4203'),
    City(name: '宜昌市', code: '4205'),
    City(name: '襄阳市', code: '4206'),
    City(name: '鄂州市', code: '4207'),
    City(name: '荆门市', code: '4208'),
    City(name: '孝感市', code: '4209'),
    City(name: '荆州市', code: '4210'),
    City(name: '黄冈市', code: '4211'),
    City(name: '咸宁市', code: '4212'),
    City(name: '随州市', code: '4213'),
    City(name: '恩施土家族苗族自治州', code: '4228'),
    // 湖南省
    City(name: '长沙市', code: '4301'),
    City(name: '株洲市', code: '4302'),
    City(name: '湘潭市', code: '4303'),
    City(name: '衡阳市', code: '4304'),
    City(name: '邵阳市', code: '4305'),
    City(name: '岳阳市', code: '4306'),
    City(name: '常德市', code: '4307'),
    City(name: '张家界市', code: '4308'),
    City(name: '益阳市', code: '4309'),
    City(name: '郴州市', code: '4310'),
    City(name: '永州市', code: '4311'),
    City(name: '怀化市', code: '4312'),
    City(name: '娄底市', code: '4313'),
    City(name: '湘西土家族苗族自治州', code: '4331'),
    // 广东省
    City(name: '广州市', code: '4401'),
    City(name: '韶关市', code: '4402'),
    City(name: '深圳市', code: '4403'),
    City(name: '珠海市', code: '4404'),
    City(name: '汕头市', code: '4405'),
    City(name: '佛山市', code: '4406'),
    City(name: '江门市', code: '4407'),
    City(name: '湛江市', code: '4408'),
    City(name: '茂名市', code: '4409'),
    City(name: '肇庆市', code: '4412'),
    City(name: '惠州市', code: '4413'),
    City(name: '梅州市', code: '4414'),
    City(name: '汕尾市', code: '4415'),
    City(name: '河源市', code: '4416'),
    City(name: '阳江市', code: '4417'),
    City(name: '清远市', code: '4418'),
    City(name: '东莞市', code: '4419'),
    City(name: '中山市', code: '4420'),
    City(name: '潮州市', code: '4451'),
    City(name: '揭阳市', code: '4452'),
    City(name: '云浮市', code: '4453'),
    // 广西壮族自治区
    City(name: '南宁市', code: '4501'),
    City(name: '柳州市', code: '4502'),
    City(name: '桂林市', code: '4503'),
    City(name: '梧州市', code: '4504'),
    City(name: '北海市', code: '4505'),
    City(name: '防城港市', code: '4506'),
    City(name: '钦州市', code: '4507'),
    City(name: '贵港市', code: '4508'),
    City(name: '玉林市', code: '4509'),
    City(name: '百色市', code: '4510'),
    City(name: '贺州市', code: '4511'),
    City(name: '河池市', code: '4512'),
    City(name: '来宾市', code: '4513'),
    City(name: '崇左市', code: '4514'),
    // 海南省
    City(name: '海口市', code: '4601'),
    City(name: '三亚市', code: '4602'),
    City(name: '三沙市', code: '4603'),
    City(name: '儋州市', code: '4604'),
    // 四川省
    City(name: '成都市', code: '5101'),
    City(name: '自贡市', code: '5103'),
    City(name: '攀枝花市', code: '5104'),
    City(name: '泸州市', code: '5105'),
    City(name: '德阳市', code: '5106'),
    City(name: '绵阳市', code: '5107'),
    City(name: '广元市', code: '5108'),
    City(name: '遂宁市', code: '5109'),
    City(name: '内江市', code: '5110'),
    City(name: '乐山市', code: '5111'),
    City(name: '南充市', code: '5113'),
    City(name: '眉山市', code: '5114'),
    City(name: '宜宾市', code: '5115'),
    City(name: '广安市', code: '5116'),
    City(name: '达州市', code: '5117'),
    City(name: '雅安市', code: '5118'),
    City(name: '巴中市', code: '5119'),
    City(name: '资阳市', code: '5120'),
    City(name: '阿坝藏族羌族自治州', code: '5132'),
    City(name: '甘孜藏族自治州', code: '5133'),
    City(name: '凉山彝族自治州', code: '5134'),
    // 贵州省
    City(name: '贵阳市', code: '5201'),
    City(name: '六盘水市', code: '5202'),
    City(name: '遵义市', code: '5203'),
    City(name: '安顺市', code: '5204'),
    City(name: '毕节市', code: '5205'),
    City(name: '铜仁市', code: '5206'),
    City(name: '黔西南布依族苗族自治州', code: '5223'),
    City(name: '黔东南苗族侗族自治州', code: '5226'),
    City(name: '黔南布依族苗族自治州', code: '5227'),
    // 云南省
    City(name: '昆明市', code: '5301'),
    City(name: '曲靖市', code: '5303'),
    City(name: '玉溪市', code: '5304'),
    City(name: '保山市', code: '5305'),
    City(name: '昭通市', code: '5306'),
    City(name: '丽江市', code: '5307'),
    City(name: '普洱市', code: '5308'),
    City(name: '临沧市', code: '5309'),
    City(name: '楚雄彝族自治州', code: '5323'),
    City(name: '红河哈尼族彝族自治州', code: '5325'),
    City(name: '文山壮族苗族自治州', code: '5326'),
    City(name: '西双版纳傣族自治州', code: '5328'),
    City(name: '大理白族自治州', code: '5329'),
    City(name: '德宏傣族景颇族自治州', code: '5331'),
    City(name: '怒江傈僳族自治州', code: '5333'),
    City(name: '迪庆藏族自治州', code: '5334'),
    // 西藏自治区
    City(name: '拉萨市', code: '5401'),
    City(name: '日喀则市', code: '5402'),
    City(name: '昌都市', code: '5403'),
    City(name: '林芝市', code: '5404'),
    City(name: '山南市', code: '5405'),
    City(name: '那曲市', code: '5406'),
    City(name: '阿里地区', code: '5425'),
    // 陕西省
    City(name: '西安市', code: '6101'),
    City(name: '铜川市', code: '6102'),
    City(name: '宝鸡市', code: '6103'),
    City(name: '咸阳市', code: '6104'),
    City(name: '渭南市', code: '6105'),
    City(name: '延安市', code: '6106'),
    City(name: '汉中市', code: '6107'),
    City(name: '榆林市', code: '6108'),
    City(name: '安康市', code: '6109'),
    City(name: '商洛市', code: '6110'),
    // 甘肃省
    City(name: '兰州市', code: '6201'),
    City(name: '嘉峪关市', code: '6202'),
    City(name: '金昌市', code: '6203'),
    City(name: '白银市', code: '6204'),
    City(name: '天水市', code: '6205'),
    City(name: '武威市', code: '6206'),
    City(name: '张掖市', code: '6207'),
    City(name: '平凉市', code: '6208'),
    City(name: '酒泉市', code: '6209'),
    City(name: '庆阳市', code: '6210'),
    City(name: '定西市', code: '6211'),
    City(name: '陇南市', code: '6212'),
    City(name: '临夏回族自治州', code: '6229'),
    City(name: '甘南藏族自治州', code: '6230'),
    // 青海省
    City(name: '西宁市', code: '6301'),
    City(name: '海东市', code: '6302'),
    City(name: '海北藏族自治州', code: '6322'),
    City(name: '黄南藏族自治州', code: '6323'),
    City(name: '海南藏族自治州', code: '6325'),
    City(name: '果洛藏族自治州', code: '6326'),
    City(name: '玉树藏族自治州', code: '6327'),
    City(name: '海西蒙古族藏族自治州', code: '6328'),
    // 宁夏回族自治区
    City(name: '银川市', code: '6401'),
    City(name: '石嘴山市', code: '6402'),
    City(name: '吴忠市', code: '6403'),
    City(name: '固原市', code: '6404'),
    City(name: '中卫市', code: '6405'),
    // 新疆维吾尔自治区
    City(name: '乌鲁木齐市', code: '6501'),
    City(name: '克拉玛依市', code: '6502'),
    City(name: '吐鲁番市', code: '6504'),
    City(name: '哈密市', code: '6505'),
    City(name: '昌吉回族自治州', code: '6523'),
    City(name: '博尔塔拉蒙古自治州', code: '6527'),
    City(name: '巴音郭楞蒙古自治州', code: '6528'),
    City(name: '阿克苏地区', code: '6529'),
    City(name: '克孜勒苏柯尔克孜自治州', code: '6530'),
    City(name: '喀什地区', code: '6531'),
    City(name: '和田地区', code: '6532'),
    City(name: '伊犁哈萨克自治州', code: '6540'),
    City(name: '塔城地区', code: '6542'),
    City(name: '阿勒泰地区', code: '6543'),
  ];

  List<City> _filteredCities = [];

  @override
  void initState() {
    super.initState();
    _filteredCities = _allCities;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      if (_searchController.text.isEmpty) {
        _filteredCities = _allCities;
      } else {
        _filteredCities = _allCities
            .where((city) => city.name.contains(_searchController.text))
            .toList();
      }
    });
  }

  void _selectCity(City city) {
    // 返回城市对象，包含名称和行政编码
    Navigator.pop(context, city);
  }

  // 关闭页面（不选择城市）
  void _closeWithoutSelection() {
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: _closeWithoutSelection,
        ),
        title: const Text(
          '选择城市',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // 搜索框
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '搜索城市',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // 城市列表
          Expanded(
            child: _filteredCities.isEmpty
                ? const Center(
                    child: Text(
                      '未找到相关城市',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredCities.length,
                    itemBuilder: (context, index) {
                      final city = _filteredCities[index];
                      final isSelected = widget.selectedCity == city.name;
                      return ListTile(
                        title: Text(
                          city.name,
                          style: TextStyle(
                            fontSize: 16,
                            color: isSelected ? Colors.blue : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '行政编码: ${city.code}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.blue)
                            : null,
                        onTap: () => _selectCity(city),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
