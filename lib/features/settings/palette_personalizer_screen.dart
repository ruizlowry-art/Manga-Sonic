import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:manga_sonic/services/theme_service.dart';

class PalettePersonalizerScreen extends StatefulWidget {
  const PalettePersonalizerScreen({super.key});

  @override
  State<PalettePersonalizerScreen> createState() =>
      _PalettePersonalizerScreenState();
}

class _PalettePersonalizerScreenState extends State<PalettePersonalizerScreen> {
  late Color _accentColor;
  late Color _bgColor;
  bool _isBackgroundMode = false;

  @override
  void initState() {
    super.initState();
    final themeService = context.read<ThemeService>();
    _accentColor = themeService.primaryColor;
    _bgColor = themeService.backgroundColor;
  }

  void _onColorChanged(Color color) {
    if (!mounted) return;
    setState(() {
      if (_isBackgroundMode) {
        _bgColor = color;
      } else {
        _accentColor = color;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Palette Personalizer')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Accent Color'),
                    icon: Icon(Icons.color_lens),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Background Color'),
                    icon: Icon(Icons.format_paint),
                  ),
                ],
                selected: {_isBackgroundMode},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isBackgroundMode = newSelection.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: RepaintBoundary(
                child: ColorPicker(
                  pickerColor: _isBackgroundMode ? _bgColor : _accentColor,
                  onColorChanged: _onColorChanged,
                  pickerAreaHeightPercent: 0.8,
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsvWithHue,
                  labelTypes: const [],
                  pickerAreaBorderRadius: BorderRadius.circular(200),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Preview:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 20),
                    _ColorPreviewCircle(color: _accentColor, bgColor: _bgColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () {
                  final themeService = context.read<ThemeService>();
                  themeService.setPrimaryColor(_accentColor);
                  themeService.setBackgroundColor(_bgColor);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Theme updated!')),
                  );
                },
                child: Text(
                  'Confirm Theme',
                  style: TextStyle(
                    color:
                        ThemeData.estimateBrightnessForColor(_accentColor) ==
                            Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            if (!_isBackgroundMode) ...[
              _buildPresetSection('Sunset', [
                const Color(0xFF4FC3F7),
                const Color(0xFF81D4FA),
                const Color(0xFFFFAB91),
                const Color(0xFFFFCC80),
                const Color(0xFFFF8A65),
              ]),
              _buildPresetSection('Outrun', [
                const Color(0xFFF7E018),
                const Color(0xFFFFB300),
                const Color(0xFFE91E63),
                const Color(0xFF9C27B0),
                const Color(0xFF3F51B5),
              ]),
              _buildPresetSection('Raspberry', [
                const Color(0xFFFF80AB),
                const Color(0xFFF06292),
                const Color(0xFFE91E63),
                const Color(0xFFC2185B),
                const Color(0xFF880E4F),
              ]),
            ] else ...[
              _buildPresetSection('Dark Modes', [
                const Color(0xFF121212),
                const Color(0xFF000000),
                const Color(0xFF1C1C1E),
                const Color(0xFF0F172A),
                const Color(0xFF18181B),
              ]),
              _buildPresetSection('Deep Tones', [
                const Color(0xFF1A237E),
                const Color(0xFF311B92),
                const Color(0xFF004D40),
                const Color(0xFF263238),
                const Color(0xFF3E2723),
              ]),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetSection(String title, List<Color> colors) {
    final currentColor = _isBackgroundMode ? _bgColor : _accentColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: colors.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => setState(() {
                  if (_isBackgroundMode) {
                    _bgColor = colors[index];
                  } else {
                    _accentColor = colors[index];
                  }
                }),
                child: Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: colors[index],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: currentColor == colors[index]
                          ? Colors.white
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ColorPreviewCircle extends StatelessWidget {
  final Color color;
  final Color bgColor;
  const _ColorPreviewCircle({required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: color.computeLuminance() > 0.5
              ? Colors.black26
              : Colors.white24,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}
