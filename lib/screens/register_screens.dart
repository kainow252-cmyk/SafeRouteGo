import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

// ══════════════════════════════════════════════════
// CADASTRO ETAPA 1 — DADOS PESSOAIS
// ══════════════════════════════════════════════════
class RegisterPersonalScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const RegisterPersonalScreen({super.key, required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          AppHeaderBar(title: 'Cadastro', onBack: onBack),
          StepIndicator(currentStep: 1, labels: const ['Pessoal', 'Veículo', 'Biometria', 'Pagamento']),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dados Pessoais', style: TextStyle(fontSize:20, fontWeight:FontWeight.w800, color:AppTheme.text)),
                  const SizedBox(height: 16),
                  AppTextField(label: 'Nome Completo', placeholder: 'Ex: Maria Silva'),
                  const SizedBox(height: 14),
                  AppTextField(label: 'CPF', placeholder: '000.000.000-00', keyboardType: TextInputType.number),
                  const SizedBox(height: 14),
                  AppTextField(label: 'Data de Nascimento', placeholder: 'DD/MM/AAAA'),
                  const SizedBox(height: 14),
                  AppTextField(label: 'CNH', placeholder: '00000000000', keyboardType: TextInputType.number),
                  const SizedBox(height: 14),
                  AppTextField(label: 'E-mail', placeholder: 'seuemail@exemplo.com', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  AppTextField(label: 'Celular', placeholder: '(27) 99999-9999', keyboardType: TextInputType.phone),
                  const SizedBox(height: 20),
                  // Divisor de seção
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppTheme.border)),
                    ),
                    child: const Text('ENDEREÇO', style: TextStyle(fontSize:12, fontWeight:FontWeight.w700, color:AppTheme.textLight, letterSpacing:0.06)),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(label: 'CEP', placeholder: '29000-000', keyboardType: TextInputType.number,
                    suffixIcon: const Icon(Icons.search_rounded, color: AppTheme.textLight, size: 18),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(label: 'Rua', placeholder: 'Rua das Palmeiras'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: AppTextField(label: 'Número', placeholder: '123')),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: AppTextField(label: 'Complemento', placeholder: 'Apto 4')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(flex: 2, child: AppTextField(label: 'Cidade', placeholder: 'Serra')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildStateSelect()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    text: 'Continuar',
                    icon: Icons.arrow_forward_rounded,
                    onTap: onNext,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ESTADO', style: TextStyle(fontSize:11, fontWeight:FontWeight.w700, color:AppTheme.textMuted, letterSpacing:0.06)),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: 'ES',
              isExpanded: true,
              items: ['ES','SP','RJ','MG','BA'].map((s) =>
                DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize:14, color:AppTheme.text)))).toList(),
              onChanged: (_) {},
              style: const TextStyle(fontSize:14, color:AppTheme.text),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════
// CADASTRO ETAPA 2 — VEÍCULO
// ══════════════════════════════════════════════════
class RegisterVehicleScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const RegisterVehicleScreen({super.key, required this.onBack, required this.onNext});

  @override
  State<RegisterVehicleScreen> createState() => _RegisterVehicleScreenState();
}

class _RegisterVehicleScreenState extends State<RegisterVehicleScreen> {
  final _placaCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anoCtrl = TextEditingController();
  final _chassiCtrl = TextEditingController();
  bool _showVehicleCard = false;
  String _selectedColorHex = '#c0392b';

  final _plateDB = {
    'abc': {'marca': 'BYD', 'modelo': 'Atto 2', 'ano': '2026'},
    'def': {'marca': 'Toyota', 'modelo': 'Corolla', 'ano': '2024'},
    'ghi': {'marca': 'Volkswagen', 'modelo': 'Polo', 'ano': '2025'},
  };

  void _onPlacaChanged(String val) {
    final clean = val.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (clean.length >= 3) {
      final key = clean.substring(0, 3);
      final data = _plateDB[key] ?? {'marca': 'Honda', 'modelo': 'Civic', 'ano': '2025'};
      setState(() {
        _marcaCtrl.text = data['marca']!;
        _modeloCtrl.text = data['modelo']!;
        _anoCtrl.text = data['ano']!;
        _showVehicleCard = true;
      });
    } else {
      setState(() => _showVehicleCard = false);
    }
  }

  final _colors = [
    {'hex': '#1a1a2e', 'color': Color(0xFF1a1a2e)},
    {'hex': '#e8e8e8', 'color': Color(0xFFe8e8e8)},
    {'hex': '#c0392b', 'color': Color(0xFFc0392b)},
    {'hex': '#2980b9', 'color': Color(0xFF2980b9)},
    {'hex': '#27ae60', 'color': Color(0xFF27ae60)},
    {'hex': '#f39c12', 'color': Color(0xFFf39c12)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          AppHeaderBar(title: 'Cadastro', onBack: widget.onBack),
          StepIndicator(currentStep: 2, labels: const ['Pessoal', 'Veículo', 'Biometria', 'Pagamento']),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dados do Veículo', style: TextStyle(fontSize:20, fontWeight:FontWeight.w800, color:AppTheme.text)),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PLACA', style: TextStyle(fontSize:11, fontWeight:FontWeight.w700, color:AppTheme.textMuted, letterSpacing:0.06)),
                      const SizedBox(height: 7),
                      TextField(
                        controller: _placaCtrl,
                        onChanged: _onPlacaChanged,
                        style: const TextStyle(fontSize:14, color:AppTheme.text),
                        decoration: InputDecoration(
                          hintText: 'ABC-1D23',
                          filled: true,
                          fillColor: AppTheme.surface,
                          suffixIcon: const Icon(Icons.search_rounded, color: AppTheme.textLight, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), borderSide: const BorderSide(color: AppTheme.border, width: 1.5)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), borderSide: const BorderSide(color: AppTheme.border, width: 1.5)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          hintStyle: const TextStyle(fontSize:14, color:AppTheme.textLight),
                        ),
                      ),
                    ],
                  ),
                  if (_showVehicleCard) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFEBF3FF), Color(0xFFDBEAFE)]),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.primary, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_marcaCtrl.text.toUpperCase(), style: const TextStyle(fontSize:11, fontWeight:FontWeight.w700, color:AppTheme.textMuted, letterSpacing:0.06)),
                                Text(_modeloCtrl.text, style: const TextStyle(fontSize:17, fontWeight:FontWeight.w800, color:AppTheme.text)),
                                Text(_anoCtrl.text, style: const TextStyle(fontSize:12, color:AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 22),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  AppTextField(label: 'Marca', placeholder: 'BYD', controller: _marcaCtrl),
                  const SizedBox(height: 14),
                  AppTextField(label: 'Modelo', placeholder: 'Atto 2', controller: _modeloCtrl),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: AppTextField(label: 'Ano', placeholder: '2026', controller: _anoCtrl, keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: AppTextField(label: 'Chassi', placeholder: '9BWZZZ377VT004251', controller: _chassiCtrl)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('COR', style: TextStyle(fontSize:11, fontWeight:FontWeight.w700, color:AppTheme.textMuted, letterSpacing:0.06)),
                  const SizedBox(height: 10),
                  Row(
                    children: _colors.map((c) {
                      final isSelected = _selectedColorHex == c['hex'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColorHex = c['hex'] as String),
                        child: Container(
                          width: 28, height: 28,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: c['color'] as Color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(text: 'Salvar Veículo', icon: Icons.arrow_forward_rounded, onTap: widget.onNext),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// CADASTRO ETAPA 3 — BIOMETRIA
// ══════════════════════════════════════════════════
class RegisterBiometricScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const RegisterBiometricScreen({super.key, required this.onBack, required this.onNext});

  @override
  State<RegisterBiometricScreen> createState() => _RegisterBiometricScreenState();
}

class _RegisterBiometricScreenState extends State<RegisterBiometricScreen> {
  bool _scanning = false;
  bool _validated = false;

  void _simulateScan() async {
    setState(() => _scanning = true);
    await Future.delayed(const Duration(milliseconds: 2200));
    if (mounted) {
      setState(() {
        _scanning = false;
        _validated = true;
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          AppHeaderBar(title: 'Cadastro', onBack: widget.onBack),
          StepIndicator(currentStep: 3, labels: const ['Pessoal', 'Veículo', 'Biometria', 'Pagamento']),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Validação de Identidade', style: TextStyle(fontSize:20, fontWeight:FontWeight.w800, color:AppTheme.text)),
                  const SizedBox(height: 4),
                  const Text('Precisamos validar sua identidade para conformidade regulatória.',
                      style: TextStyle(fontSize:13, color:AppTheme.textMuted, height:1.5)),
                  const SizedBox(height: 24),
                  // Face scan
                  Center(
                    child: Container(
                      width: 180, height: 180,
                      decoration: BoxDecoration(
                        color: AppTheme.surface2,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border, width: 2, style: BorderStyle.solid),
                      ),
                      child: Stack(
                        children: [
                          // Cantos
                          ..._buildCorners(),
                          // Ícone central
                          Center(
                            child: _validated
                                ? const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 54)
                                : _scanning
                                    ? const SizedBox(
                                        width: 40, height: 40,
                                        child: CircularProgressIndicator(color: AppTheme.primary),
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.account_circle_rounded,
                                              color: AppTheme.textLight, size: 54),
                                          const SizedBox(height: 8),
                                          const Text('Posicione seu rosto aqui',
                                              style: TextStyle(fontSize:11, color:AppTheme.textLight),
                                              textAlign: TextAlign.center),
                                        ],
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_validated) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.green, width: 1.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 20),
                          SizedBox(width: 8),
                          Text('Identidade Validada', style: TextStyle(fontSize:15, fontWeight:FontWeight.w700, color:AppTheme.green)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(text: 'Tirar Selfie', icon: Icons.camera_alt_rounded, onTap: _simulateScan),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.primary, width: 2),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.badge_rounded, color: AppTheme.primary, size: 16),
                              SizedBox(width: 6),
                              Text('Documento', style: TextStyle(fontSize:13, fontWeight:FontWeight.w600, color:AppTheme.primary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_rounded, color: AppTheme.primary, size: 14),
                        SizedBox(width: 8),
                        Expanded(child: Text('Dados biométricos criptografados e nunca compartilhados.',
                            style: TextStyle(fontSize:12, color:AppTheme.textLight))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 24.0;
    const thickness = 3.0;
    final color = AppTheme.primary;
    return [
      // TL
      Positioned(top: 10, left: 10, child: SizedBox(width: size, height: size,
        child: CustomPaint(painter: _CornerPainter(color, 'tl', thickness)))),
      // TR
      Positioned(top: 10, right: 10, child: SizedBox(width: size, height: size,
        child: CustomPaint(painter: _CornerPainter(color, 'tr', thickness)))),
      // BL
      Positioned(bottom: 10, left: 10, child: SizedBox(width: size, height: size,
        child: CustomPaint(painter: _CornerPainter(color, 'bl', thickness)))),
      // BR
      Positioned(bottom: 10, right: 10, child: SizedBox(width: size, height: size,
        child: CustomPaint(painter: _CornerPainter(color, 'br', thickness)))),
    ];
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final String corner;
  final double thickness;
  _CornerPainter(this.color, this.corner, this.thickness);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = thickness..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    switch (corner) {
      case 'tl':
        path.moveTo(size.width, 0); path.lineTo(0, 0); path.lineTo(0, size.height);
      case 'tr':
        path.moveTo(0, 0); path.lineTo(size.width, 0); path.lineTo(size.width, size.height);
      case 'bl':
        path.moveTo(0, 0); path.lineTo(0, size.height); path.lineTo(size.width, size.height);
      case 'br':
        path.moveTo(0, size.height); path.lineTo(size.width, size.height); path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════════
// CADASTRO ETAPA 4 — PAGAMENTO
// ══════════════════════════════════════════════════
class RegisterPaymentScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onComplete;
  const RegisterPaymentScreen({super.key, required this.onBack, required this.onComplete});

  @override
  State<RegisterPaymentScreen> createState() => _RegisterPaymentScreenState();
}

class _RegisterPaymentScreenState extends State<RegisterPaymentScreen> {
  int _tab = 0;
  final _cardNameCtrl = TextEditingController(text: 'NOME COMPLETO');
  final _cardNumberCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          AppHeaderBar(title: 'Cadastro', onBack: widget.onBack),
          StepIndicator(currentStep: 4, labels: const ['Pessoal', 'Veículo', 'Biometria', 'Pagamento']),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dados Financeiros', style: TextStyle(fontSize:20, fontWeight:FontWeight.w800, color:AppTheme.text)),
                  const SizedBox(height: 4),
                  const Text('Escolha como deseja pagar suas proteções.',
                      style: TextStyle(fontSize:13, color:AppTheme.textMuted)),
                  const SizedBox(height: 16),
                  // Abas de pagamento
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        _buildPayTab(0, Icons.qr_code_rounded, 'PIX'),
                        _buildPayTab(1, Icons.credit_card_rounded, 'Cartão'),
                        _buildPayTab(2, Icons.account_balance_wallet_rounded, 'Carteira'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Conteúdo da aba
                  if (_tab == 0) _buildPixTab(),
                  if (_tab == 1) _buildCardTab(),
                  if (_tab == 2) _buildWalletTab(),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    text: 'Finalizar Cadastro',
                    icon: Icons.check_circle_rounded,
                    onTap: widget.onComplete,
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, color: AppTheme.primary, size: 13),
                      SizedBox(width: 6),
                      Text('Dados protegidos com criptografia SSL 256 bits.',
                          style: TextStyle(fontSize:11, color:AppTheme.textLight)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayTab(int index, IconData icon, String label) {
    final isActive = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 3, offset: const Offset(0, 1))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? AppTheme.primary : AppTheme.textMuted),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize:12, fontWeight:FontWeight.w600,
                  color: isActive ? AppTheme.primary : AppTheme.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPixTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00BDAE), Color(0xFF00897B)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          const Text('Pagamentos instantâneos via PIX após cada viagem.',
              style: TextStyle(fontSize:13, color:AppTheme.textMuted, height:1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Chave PIX (CPF)', style: TextStyle(fontSize:13, color:AppTheme.textMuted)),
                Text('123.456.789-00', style: TextStyle(fontSize:13, fontWeight:FontWeight.w700, color:AppTheme.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTab() {
    return Column(
      children: [
        // Cartão visual
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0D1B4B), Color(0xFF1A3A7C)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFF0D1B4B).withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.memory_rounded, color: Color(0xFFFFCC00), size: 26),
              const SizedBox(height: 10),
              Text(
                _cardNumberCtrl.text.isEmpty ? '•••• •••• •••• ••••' : _cardNumberCtrl.text,
                style: const TextStyle(fontSize:16, color:Colors.white, letterSpacing:3, fontWeight:FontWeight.w500),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Titular', style: TextStyle(fontSize:10, color:Colors.white60)),
                      Text(_cardNameCtrl.text, style: const TextStyle(fontSize:13, fontWeight:FontWeight.w600, color:Colors.white)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Validade', style: TextStyle(fontSize:10, color:Colors.white60)),
                      Text(_cardExpiryCtrl.text.isEmpty ? 'MM/AA' : _cardExpiryCtrl.text,
                          style: const TextStyle(fontSize:13, fontWeight:FontWeight.w600, color:Colors.white)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppTextField(label: 'Nome no Cartão', placeholder: 'GELCI SOUZA', controller: _cardNameCtrl),
        const SizedBox(height: 12),
        AppTextField(label: 'Número do Cartão', placeholder: '0000 0000 0000 0000', controller: _cardNumberCtrl, keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: AppTextField(label: 'Validade', placeholder: 'MM/AA', controller: _cardExpiryCtrl)),
            const SizedBox(width: 10),
            Expanded(child: AppTextField(label: 'CVV', placeholder: '•••', keyboardType: TextInputType.number,
                suffixIcon: const Icon(Icons.help_outline_rounded, size: 16, color: AppTheme.textLight))),
          ],
        ),
      ],
    );
  }

  Widget _buildWalletTab() {
    final wallets = [
      {'icon': Icons.payments_rounded, 'label': 'Mercado Pago'},
      {'icon': Icons.paypal_rounded, 'label': 'PayPal'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'PicPay'},
    ];
    return Column(
      children: wallets.map((w) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(w['icon'] as IconData, color: AppTheme.primary, size: 26),
            const SizedBox(width: 12),
            Text(w['label'] as String, style: const TextStyle(fontSize:14, fontWeight:FontWeight.w600, color:AppTheme.text)),
          ],
        ),
      )).toList(),
    );
  }
}
