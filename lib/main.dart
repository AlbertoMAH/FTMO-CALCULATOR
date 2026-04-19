import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const FTMOApp());
}

class FTMOApp extends StatefulWidget {
  const FTMOApp({super.key});

  @override
  State<FTMOApp> createState() => _FTMOAppState();
}

class _FTMOAppState extends State<FTMOApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FTMO CALCULATOR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8820C),
          brightness: Brightness.light,
        ),
        fontFamily: 'Space Mono',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF7931A),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Space Mono',
      ),
      themeMode: _themeMode,
      home: _ThemeProvider(
        themeMode: _themeMode,
        child: const CalculatorPage(),
        onToggle: _toggleTheme,
      ),
    );
  }
}

class _ThemeProvider extends InheritedWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggle;

  const _ThemeProvider({
    required this.themeMode,
    required super.child,
    required this.onToggle,
  });

  static _ThemeProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ThemeProvider>()!;
  }

  @override
  bool updateShouldNotify(_ThemeProvider oldWidget) {
    return themeMode != oldWidget.themeMode;
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  String _currentAsset = 'BTC';
  final _entryController = TextEditingController();
  final _slController = TextEditingController();
  final _tpController = TextEditingController();

  String? _errorMessage;

  static const _assets = {
    'BTC': {'contractSize': 1, 'label': 'BTCUSD', 'color': Color(0xFFE8820C)},
    'ETH': {'contractSize': 10, 'label': 'ETHUSD', 'color': Color(0xFF4A6BD6)},
    'XAU': {'contractSize': 100, 'label': 'XAUUSD', 'color': Color(0xFFC9A227)},
  };
  static const _risk = 80.0;

  @override
  void dispose() {
    _entryController.dispose();
    _slController.dispose();
    _tpController.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    _ThemeProvider.of(context).onToggle();
  }

  void _selectAsset(String asset) {
    setState(() {
      _currentAsset = asset;
      _errorMessage = null;
    });
  }

  void _clearError() {
    setState(() {
      _errorMessage = null;
    });
  }

  void _calculate() {
    final entry = double.tryParse(_entryController.text);
    final sl = double.tryParse(_slController.text);
    final tp = double.tryParse(_tpController.text);

    setState(() {
      _errorMessage = null;
    });

    if (entry == null || sl == null || tp == null) {
      setState(() {
        _errorMessage = 'Veuillez remplir tous les champs.';
      });
      return;
    }

    if (entry <= 0 || sl <= 0 || tp <= 0) {
      setState(() {
        _errorMessage = 'Les prix doivent être > 0.';
      });
      return;
    }

    if (sl == entry) {
      setState(() {
        _errorMessage = "Le SL ne peut pas être égal au prix d'entrée.";
      });
      return;
    }

    if (tp == entry) {
      setState(() {
        _errorMessage = "Le TP ne peut pas être égal au prix d'entrée.";
      });
      return;
    }

    final asset = _assets[_currentAsset]!;
    final isLong = tp > entry;
    final isEth = _currentAsset == 'ETH';

    if (isLong && sl >= entry) {
      setState(() {
        _errorMessage = "LONG : SL doit être sous le prix d'entrée.";
      });
      return;
    }

    if (!isLong && sl <= entry) {
      setState(() {
        _errorMessage = "SHORT : SL doit être au-dessus du prix d'entrée.";
      });
      return;
    }

    if (isLong && tp <= entry) {
      setState(() {
        _errorMessage = "LONG : TP doit être au-dessus du prix d'entrée.";
      });
      return;
    }

    if (!isLong && tp >= entry) {
      setState(() {
        _errorMessage = "SHORT : TP doit être sous le prix d'entrée.";
      });
      return;
    }

    final slDist = (entry - sl).abs();
    final tpDist = (tp - entry).abs();
    final contractSize = asset['contractSize'] as int;
    final lotRaw = _risk / (slDist * contractSize);
    final lot = (lotRaw / 0.01).floor() * 0.01;

    if (lot < 0.01) {
      setState(() {
        _errorMessage = 'Lot calculé (${lotRaw.toStringAsFixed(4)}) < 0.01 minimum. Élargis ton SL.';
      });
      return;
    }

    final actualLoss = lot * slDist * contractSize;
    final potGain = lot * tpDist * contractSize;
    final pipVal = lot * contractSize;
    final rr = (tpDist / slDist).toStringAsFixed(2);

    final results = {
      'lot': lot.toStringAsFixed(2),
      'label': asset['label'] as String,
      'rr': rr,
      'slDist': slDist.toStringAsFixed(2),
      'tpDist': tpDist.toStringAsFixed(2),
      'maxLoss': actualLoss.toStringAsFixed(2),
      'potGain': potGain.toStringAsFixed(2),
      'pipVal': pipVal.toStringAsFixed(2),
      'direction': isLong ? 'LONG' : 'SHORT',
      'isEth': isEth ? 'true' : 'false',
      'isXau': _currentAsset == 'XAU' ? 'true' : 'false',
    };

    _showResultsBottomSheet(results, asset['color'] as Color);
  }

  void _showResultsBottomSheet(Map<String, String> results, Color assetColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ResultsBottomSheet(
        results: results,
        assetColor: assetColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final colors = isDark
        ? _DarkColors(colorScheme)
        : _LightColors(colorScheme);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildThemeToggle(colors),
              const SizedBox(height: 10),
              _buildHeader(colorScheme, colors),
              const SizedBox(height: 26),
              _buildAssetSelector(colors),
              const SizedBox(height: 10),
              _buildEntryCard(colors),
              const SizedBox(height: 10),
              _buildSLTPCard(colors),
              const SizedBox(height: 10),
              _buildRiskBar(colors),
              const SizedBox(height: 10),
              if (_errorMessage != null) _buildError(colors),
              _buildCalcButton(colorScheme),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(_Colors colors) {
    final isDark = _ThemeProvider.of(context).themeMode == ThemeMode.dark;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text('☀️', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _toggleTheme,
          child: Container(
            width: 42,
            height: 23,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A3A5A) : const Color(0xFFDDE1EA),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: colors.border),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(3),
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF627EEA) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Text('🌙', style: TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, _Colors colors) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: colors.inputBg,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0A9E5C),
boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'FTMO CHALLENGE 10K',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF7A8499),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
            children: const [
              TextSpan(text: 'LOT '),
              TextSpan(text: 'CALCULATOR', style: TextStyle(color: Color(0xFFE8820C))),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Risk fixe : \$80 / trade',
          style: TextStyle(
            fontSize: 13,
            color: colors.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildAssetSelector(_Colors colors) {
    return Column(
      children: [
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: colors.panel,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: PageView(
            onPageChanged: (index) {
              _selectAsset(['BTC', 'ETH', 'XAU'][index]);
            },
            children: [
              _AssetPage(
                icon: '₿',
                name: 'Bitcoin',
                sub: 'BTCUSD · Spot CFD',
                tag: 'BTC',
                lotInfo: 'lot × 1',
                isSelected: _currentAsset == 'BTC',
                color: const Color(0xFFE8820C),
                colors: colors,
              ),
              _AssetPage(
                icon: 'Ξ',
                name: 'Ethereum',
                sub: 'ETHUSD · Spot CFD',
                tag: 'ETH',
                lotInfo: 'lot × 10',
                isSelected: _currentAsset == 'ETH',
                color: const Color(0xFF4A6BD6),
                colors: colors,
              ),
              _AssetPage(
                icon: 'Au',
                name: 'Gold',
                sub: 'XAUUSD · Spot CFD',
                tag: 'XAU',
                lotInfo: 'lot × 100',
                isSelected: _currentAsset == 'XAU',
                color: const Color(0xFFC9A227),
                colors: colors,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DotIndicator(isSelected: _currentAsset == 'BTC', color: const Color(0xFFE8820C), onTap: () => _selectAsset('BTC')),
            const SizedBox(width: 6),
            _DotIndicator(isSelected: _currentAsset == 'ETH', color: const Color(0xFF4A6BD6), onTap: () => _selectAsset('ETH')),
            const SizedBox(width: 6),
            _DotIndicator(isSelected: _currentAsset == 'XAU', color: const Color(0xFFC9A227), onTap: () => _selectAsset('XAU')),
          ],
        ),
      ],
    );
  }

  Widget _buildEntryCard(_Colors colors) {
    return _InputCard(
      title: 'Prix d\'entrée',
      children: [
        _InputRow(
          label: 'ENTRY',
          controller: _entryController,
          tag: 'USD',
          colors: colors,
          onChanged: _clearError,
        ),
      ],
      colors: colors,
    );
  }

  Widget _buildSLTPCard(_Colors colors) {
    return _InputCard(
      title: 'Stop Loss & Take Profit',
      children: [
        _InputRow(
          label: 'SL',
          controller: _slController,
          tag: 'USD',
          colors: colors,
          borderColor: const Color(0xFFD92D44).withValues(alpha: 0.3),
          onChanged: _clearError,
        ),
        const SizedBox(height: 10),
        _InputRow(
          label: 'TP',
          controller: _tpController,
          tag: 'USD',
          colors: colors,
          borderColor: const Color(0xFF0A9E5C).withValues(alpha: 0.3),
          onChanged: _clearError,
        ),
      ],
      colors: colors,
    );
  }

  Widget _buildRiskBar(_Colors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Risque / trade',
            style: TextStyle(
              fontSize: 11,
              color: colors.muted,
              letterSpacing: 1,
            ),
          ),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colors.text,
              ),
              children: [
                const TextSpan(text: '\$80.00 '),
                TextSpan(
                  text: 'FIXE',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF0A9E5C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(_Colors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFD92D44).withValues(alpha: 0.07),
        border: Border.all(color: const Color(0xFFD92D44).withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFFD92D44),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCalcButton(ColorScheme colorScheme) {
    final assetColor = _currentAsset == 'BTC'
        ? const Color(0xFFF7931A)
        : _currentAsset == 'ETH'
            ? const Color(0xFF627EEA)
            : const Color(0xFFD4A93A);

    return ElevatedButton(
      onPressed: _calculate,
      style: ElevatedButton.styleFrom(
        backgroundColor: assetColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        shadowColor: assetColor.withValues(alpha: 0.35),
      ),
      child: const Text(
        'CALCULER LE LOT',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AssetPage extends StatelessWidget {
  final String icon;
  final String name;
  final String sub;
  final String tag;
  final String lotInfo;
  final bool isSelected;
  final Color color;
  final _Colors colors;

  const _AssetPage({
    required this.icon,
    required this.name,
    required this.sub,
    required this.tag,
    required this.lotInfo,
    required this.isSelected,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      icon,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: colors.text,
                        ),
                      ),
                      Text(
                        sub,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF7A8499),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: color),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                lotInfo,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF7A8499),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _DotIndicator({
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isSelected ? 20 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFFE1E5EB),
          borderRadius: BorderRadius.circular(isSelected ? 4 : 3),
        ),
      ),
    );
  }
}

class _AssetButton extends StatelessWidget {
  final String icon;
  final String name;
  final String sub;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final _Colors colors;

  const _AssetButton({
    required this.icon,
    required this.name,
    required this.sub,
    required this.isSelected,
    required this.color,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.panel,
          border: Border.all(
            color: isSelected ? color : colors.border,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF7A8499),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final _Colors colors;

  const _InputCard({
    required this.title,
    required this.children,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A8499),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String tag;
  final _Colors colors;
  final Color? borderColor;
  final VoidCallback? onChanged;

  const _InputRow({
    required this.label,
    required this.controller,
    required this.tag,
    required this.colors,
    this.borderColor,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? colors.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.inputBg,
        border: Border.all(color: effectiveBorderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF7A8499),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              style: TextStyle(
                fontSize: 15,
                color: colors.text,
              ),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: Color(0xFFC0C7D4),
                ),
              ),
              onChanged: (_) => onChanged?.call(),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            tag,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF7A8499),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultGrid extends StatelessWidget {
  final Map<String, String> results;
  final _Colors colors;

  const _ResultGrid({
    required this.results,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        _ResultItem(label: 'SL Distance', value: '${results['slDist']} pts', isNeutral: true, colors: colors),
        _ResultItem(label: 'TP Distance', value: '${results['tpDist']} pts', isNeutral: true, colors: colors),
        _ResultItem(label: 'Perte max', value: '-\$${results['maxLoss']}', isNegative: true, colors: colors),
        _ResultItem(label: 'Gain potentiel', value: '+\$${results['potGain']}', isPositive: true, colors: colors),
        _ResultItem(label: 'Valeur / point', value: '\$${results['pipVal']}/pt', isNeutral: true, colors: colors),
        _ResultItem(label: 'Direction', value: results['direction']!, isNeutral: true, colors: colors),
      ],
    );
  }
}

class _ResultItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isPositive;
  final bool isNegative;
  final bool isNeutral;
  final _Colors colors;

  const _ResultItem({
    required this.label,
    required this.value,
    this.isPositive = false,
    this.isNegative = false,
    this.isNeutral = false,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    Color valueColor;
    if (isPositive) {
      valueColor = const Color(0xFF0A9E5C);
    } else if (isNegative) {
      valueColor = const Color(0xFFD92D44);
    } else {
      valueColor = colors.text;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.resultItemBg,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF7A8499),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsBottomSheet extends StatelessWidget {
  final Map<String, String> results;
  final Color assetColor;

  const _ResultsBottomSheet({
    super.key,
    required this.results,
    required this.assetColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? _DarkColors(Theme.of(context).colorScheme)
        : _LightColors(Theme.of(context).colorScheme);
    final isEth = results['isEth'] == 'true';
    final isXau = results['isXau'] == 'true';

    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Taille de lot recommandée',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.muted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                results['lot']!,
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: assetColor,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'lots ${results['label']}',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.inputBg,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'R:R  1 : ${results['rr']}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildGrid(colors),
              if (isEth) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB48200).withValues(alpha: 0.07),
                    border: Border.all(color: const Color(0xFFB48200).withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '⚠️ ETH : swap = -30%/an par position.\nFerme avant 23h00 (heure Abidjan) pour éviter le rollover.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A6500),
                      height: 1.55,
                    ),
                  ),
                ),
              ],
              if (isXau) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB48200).withValues(alpha: 0.07),
                    border: Border.all(color: const Color(0xFFB48200).withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '⚠️ GOLD : swap long = -87.08 pts par lot.\nMercredi : rollover ×3. Ferme avant 23h00 pour éviter le triple swap.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A6500),
                      height: 1.55,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: assetColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'FERMER',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(_Colors colors) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.7,
      children: [
        _ResultItem(label: 'SL Distance', value: '${results['slDist']} pts', isNeutral: true, colors: colors),
        _ResultItem(label: 'TP Distance', value: '${results['tpDist']} pts', isNeutral: true, colors: colors),
        _ResultItem(label: 'Perte max', value: '-\$${results['maxLoss']}', isNegative: true, colors: colors),
        _ResultItem(label: 'Gain potentiel', value: '+\$${results['potGain']}', isPositive: true, colors: colors),
        _ResultItem(label: 'Valeur / point', value: '\$${results['pipVal']}/pt', isNeutral: true, colors: colors),
        _ResultItem(label: 'Direction', value: results['direction']!, isNeutral: true, colors: colors),
      ],
    );
  }
}

abstract class _Colors {
  Color get background;
  Color get panel;
  Color get border;
  Color get text;
  Color get muted;
  Color get inputBg;
  Color get resultItemBg;
}

class _LightColors implements _Colors {
  final ColorScheme colorScheme;
  _LightColors(this.colorScheme);

  @override Color get background => const Color(0xFFF0F2F5);
  @override Color get panel => Colors.white;
  @override Color get border => const Color(0xFFE1E5EB);
  @override Color get text => const Color(0xFF0D1117);
  @override Color get muted => const Color(0xFF7A8499);
  @override Color get inputBg => Colors.black.withValues(alpha: 0.03);
  @override Color get resultItemBg => Colors.black.withValues(alpha: 0.025);
}

class _DarkColors implements _Colors {
  final ColorScheme colorScheme;
  _DarkColors(this.colorScheme);

  @override Color get background => const Color(0xFF080C10);
  @override Color get panel => const Color(0xFF0D1117);
  @override Color get border => const Color(0xFF1C2333);
  @override Color get text => const Color(0xFFE6EDF3);
  @override Color get muted => const Color(0xFF6E7681);
  @override Color get inputBg => Colors.white.withValues(alpha: 0.03);
  @override Color get resultItemBg => Colors.white.withValues(alpha: 0.03);
}