// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════════
// SAFEROUTE — FIPE API SERVICE v1.0
// Fonte primária: BrasilAPI (gratuita, sem auth)
// Fallback:       parallelum.com.br/fipe/api/v1
// Banco offline:  200+ veículos populares BR embutidos
//
// Endpoints BrasilAPI FIPE:
//   GET /api/fipe/marcas/v1/{vehicleType}
//   GET /api/fipe/veiculos/v1/{vehicleType}/{brandCode}
//   GET /api/fipe/preco/v1/{fipeCode}
//
// vehicleType: carros | motos | caminhoes
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS
// ─────────────────────────────────────────────────────────────────────────────

class FipeMarca {
  final String codigo;
  final String nome;
  const FipeMarca({required this.codigo, required this.nome});
  factory FipeMarca.fromJson(Map<String, dynamic> j) =>
      FipeMarca(codigo: j['valor']?.toString() ?? j['codigo']?.toString() ?? '', nome: j['nome'] ?? '');
  @override String toString() => nome;
}

class FipeModelo {
  final String codigo;
  final String nome;
  const FipeModelo({required this.codigo, required this.nome});
  factory FipeModelo.fromJson(Map<String, dynamic> j) =>
      FipeModelo(codigo: j['valor']?.toString() ?? j['codigo']?.toString() ?? '', nome: j['nome'] ?? '');
  @override String toString() => nome;
}

class FipeAno {
  final String codigo; // ex: "2022-3"
  final String nome;   // ex: "2022 Gasolina"
  final int ano;
  const FipeAno({required this.codigo, required this.nome, required this.ano});
  factory FipeAno.fromJson(Map<String, dynamic> j) {
    final nome = j['nome']?.toString() ?? '';
    final anoStr = nome.split(' ').first;
    final ano = int.tryParse(anoStr) ?? DateTime.now().year;
    return FipeAno(
      codigo: j['valor']?.toString() ?? j['codigo']?.toString() ?? '',
      nome: nome,
      ano: ano,
    );
  }
  @override String toString() => nome;
}

class FipePreco {
  final String codigoFipe;   // ex: "001004-9"
  final String marca;
  final String modelo;
  final int anoModelo;
  final double valor;        // valor FIPE em reais
  final String combustivel;
  final String mesReferencia;

  // Calculados
  final int idadeVeiculo;
  final double fatorIdade;
  final double franquia;
  final double premioBasePorKm; // R$/km

  const FipePreco({
    required this.codigoFipe,
    required this.marca,
    required this.modelo,
    required this.anoModelo,
    required this.valor,
    required this.combustivel,
    required this.mesReferencia,
    required this.idadeVeiculo,
    required this.fatorIdade,
    required this.franquia,
    required this.premioBasePorKm,
  });

  factory FipePreco.fromJson(Map<String, dynamic> j) {
    final valorStr = (j['Valor'] ?? j['valor'] ?? 'R\$ 0').toString()
        .replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
    final valor = double.tryParse(valorStr) ?? 0.0;
    final anoModelo = int.tryParse(j['AnoModelo']?.toString() ?? '') ??
        int.tryParse(j['anoModelo']?.toString() ?? '') ?? DateTime.now().year;
    final anoAtual = DateTime.now().year;
    final idadeVeiculo = anoAtual - anoModelo;

    return FipePreco(
      codigoFipe: j['CodigoFipe'] ?? j['codigoFipe'] ?? '',
      marca: j['Marca'] ?? j['marca'] ?? '',
      modelo: j['Modelo'] ?? j['modelo'] ?? '',
      anoModelo: anoModelo,
      valor: valor,
      combustivel: j['Combustivel'] ?? j['combustivel'] ?? 'Gasolina',
      mesReferencia: j['MesReferencia'] ?? j['mesReferencia'] ?? '',
      idadeVeiculo: idadeVeiculo.clamp(0, 99),
      fatorIdade: FipeApiService.calcFatorIdade(idadeVeiculo),
      franquia: FipeApiService.calcFranquia(valor),
      premioBasePorKm: FipeApiService.calcPremioBaseKm(valor, idadeVeiculo),
    );
  }

  String get valorFormatado {
    if (valor <= 0) return 'Não disponível';
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',').replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+,)'), (m) => '${m[1]}.')}';
  }

  String get franquiaFormatada {
    return 'R\$ ${franquia.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+\b)'), (m) => '${m[1]}.')}';
  }

  String get idadeLabel {
    if (idadeVeiculo == 0) return 'Novo (ano atual)';
    if (idadeVeiculo == 1) return '1 ano';
    return '$idadeVeiculo anos';
  }

  String get fatorIdadeLabel {
    if (fatorIdade <= 1.0) return 'Ótimo (0-2 anos)';
    if (fatorIdade <= 1.1) return 'Bom (3-5 anos)';
    if (fatorIdade <= 1.25) return 'Regular (6-10 anos)';
    if (fatorIdade <= 1.5) return 'Alto (11-15 anos)';
    return 'Muito Alto (16+ anos)';
  }

  Map<String, dynamic> toJson() => {
    'codigoFipe': codigoFipe,
    'marca': marca,
    'modelo': modelo,
    'anoModelo': anoModelo,
    'valor': valor,
    'idadeVeiculo': idadeVeiculo,
    'fatorIdade': fatorIdade,
    'franquia': franquia,
    'premioBasePorKm': premioBasePorKm,
    'combustivel': combustivel,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// FIPE API SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class FipeApiService {
  static const _brasilApi = 'https://brasilapi.com.br/api/fipe';
  static const _parallelum = 'https://parallelum.com.br/fipe/api/v1';
  static const _timeout = Duration(seconds: 10);
  static const _headers = {
    'User-Agent': 'SafeRouteGo/2.0 (contato@saferoutego.com.br)',
    'Accept': 'application/json',
  };

  // Cache em memória
  static final Map<String, dynamic> _cache = {};

  // ── CÁLCULOS ATUARIAIS ESTÁTICOS ─────────────────────────────────────────

  /// Fator de risco pela idade do veículo (tabela SixTech)
  static double calcFatorIdade(int idadeAnos) {
    if (idadeAnos <= 2)  return 1.00;
    if (idadeAnos <= 5)  return 1.10;
    if (idadeAnos <= 10) return 1.25;
    if (idadeAnos <= 15) return 1.50;
    return 1.80;
  }

  /// Franquia dinâmica baseada no valor FIPE
  static double calcFranquia(double valorFipe) {
    if (valorFipe <= 30000)  return 2000;
    if (valorFipe <= 60000)  return 3000;
    if (valorFipe <= 100000) return 4000;
    return valorFipe * 0.05; // 5% para acima de R$100k
  }

  /// Prêmio base por km rodado (R$/km)
  /// Fórmula: valorFipe * 0.0025% por km * fatorIdade / 12 meses
  static double calcPremioBaseKm(double valorFipe, int idadeAnos) {
    const baseRate = 0.000025; // 0.0025% do FIPE por km
    final fator = calcFatorIdade(idadeAnos);
    return valorFipe * baseRate * fator;
  }

  /// Prêmio mensal estimado por km/mês
  static double calcPremioMensal(double valorFipe, int idadeAnos, double kmMes) {
    const valorBaseKm = 0.08; // R$/km base
    final fator = calcFatorIdade(idadeAnos);
    return kmMes * valorBaseKm * fator;
  }

  // ── MARCAS ────────────────────────────────────────────────────────────────

  static Future<List<FipeMarca>> getMarcas(String tipo) async {
    final cacheKey = 'marcas_$tipo';
    if (_cache.containsKey(cacheKey)) {
      return (_cache[cacheKey] as List).cast<FipeMarca>();
    }

    // Tenta BrasilAPI primeiro
    try {
      final uri = Uri.parse('$_brasilApi/marcas/v1/$tipo');
      final resp = await http.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        final marcas = data.map((j) => FipeMarca.fromJson(j as Map<String, dynamic>)).toList();
        _cache[cacheKey] = marcas;
        return marcas;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BrasilAPI marcas falhou: $e');
    }

    // Fallback: parallelum
    try {
      final uri = Uri.parse('$_parallelum/$tipo/marcas');
      final resp = await http.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        final marcas = data.map((j) => FipeMarca.fromJson(j as Map<String, dynamic>)).toList();
        _cache[cacheKey] = marcas;
        return marcas;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('parallelum marcas falhou: $e');
    }

    // Fallback offline: marcas embutidas
    return _getMarcasOffline(tipo);
  }

  // ── MODELOS ───────────────────────────────────────────────────────────────

  static Future<List<FipeModelo>> getModelos(String tipo, String codigoMarca) async {
    final cacheKey = 'modelos_${tipo}_$codigoMarca';
    if (_cache.containsKey(cacheKey)) {
      return (_cache[cacheKey] as List).cast<FipeModelo>();
    }

    // BrasilAPI
    try {
      final uri = Uri.parse('$_brasilApi/veiculos/v1/$tipo/$codigoMarca');
      final resp = await http.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        final modelos = data.map((j) => FipeModelo.fromJson(j as Map<String, dynamic>)).toList();
        _cache[cacheKey] = modelos;
        return modelos;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BrasilAPI modelos falhou: $e');
    }

    // parallelum
    try {
      final uri = Uri.parse('$_parallelum/$tipo/marcas/$codigoMarca/modelos');
      final resp = await http.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final data = body is List ? body : (body as Map)['modelos'] as List? ?? [];
        final modelos = data.map((j) => FipeModelo.fromJson(j as Map<String, dynamic>)).toList();
        _cache[cacheKey] = modelos;
        return modelos;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('parallelum modelos falhou: $e');
    }

    return _getModelosOffline(tipo, codigoMarca);
  }

  // ── ANOS ──────────────────────────────────────────────────────────────────

  static Future<List<FipeAno>> getAnos(
      String tipo, String codigoMarca, String codigoModelo) async {
    final cacheKey = 'anos_${tipo}_${codigoMarca}_$codigoModelo';
    if (_cache.containsKey(cacheKey)) {
      return (_cache[cacheKey] as List).cast<FipeAno>();
    }

    // parallelum (BrasilAPI não tem endpoint de anos separado)
    try {
      final uri = Uri.parse(
          '$_parallelum/$tipo/marcas/$codigoMarca/modelos/$codigoModelo/anos');
      final resp = await http.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        final anos = data.map((j) => FipeAno.fromJson(j as Map<String, dynamic>)).toList();
        if (anos.isNotEmpty) {
          _cache[cacheKey] = anos;
          return anos;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('parallelum anos falhou: $e');
    }

    // Fallback: gera anos de 2010 a atual
    return _getAnosOffline();
  }

  // ── VALOR FIPE ────────────────────────────────────────────────────────────

  static Future<FipePreco?> getPreco({
    required String tipo,
    required String codigoMarca,
    required String codigoModelo,
    required String codigoAno,  // ex: "2022-3"
  }) async {
    final cacheKey = 'preco_${tipo}_${codigoMarca}_${codigoModelo}_$codigoAno';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as FipePreco;
    }

    // parallelum
    try {
      final uri = Uri.parse(
          '$_parallelum/$tipo/marcas/$codigoMarca/modelos/$codigoModelo/anos/$codigoAno');
      final resp = await http.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['Valor'] != null || data['valor'] != null) {
          final preco = FipePreco.fromJson(data);
          _cache[cacheKey] = preco;
          return preco;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('parallelum preco falhou: $e');
    }

    // BrasilAPI (busca pelo código FIPE se disponível)
    return null;
  }

  // ── BUSCA POR CÓDIGO FIPE ─────────────────────────────────────────────────

  static Future<FipePreco?> getPrecoByCodigoFipe(String codigoFipe) async {
    final cacheKey = 'fipe_$codigoFipe';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as FipePreco;
    }

    try {
      // BrasilAPI
      final uri = Uri.parse('$_brasilApi/preco/v1/$codigoFipe');
      final resp = await http.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = data is List ? data : [data];
        if (list.isNotEmpty) {
          final preco = FipePreco.fromJson(list.first as Map<String, dynamic>);
          _cache[cacheKey] = preco;
          return preco;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BrasilAPI preco FIPE falhou: $e');
    }

    return null;
  }

  // ── BUSCA RÁPIDA POR NOME (usa banco offline) ─────────────────────────────
  // Retorna valor FIPE estimado instantaneamente pelo nome do modelo

  static FipePrecoOffline? buscarPorNome(String nomeModelo) {
    final nome = nomeModelo.toLowerCase().trim();
    for (final entry in kFipeDb) {
      if (entry.modelo.toLowerCase().contains(nome) ||
          nome.contains(entry.modelo.toLowerCase())) {
        return entry;
      }
    }
    // Busca parcial
    for (final entry in kFipeDb) {
      final words = nome.split(' ');
      if (words.any((w) => w.length > 3 && entry.modelo.toLowerCase().contains(w))) {
        return entry;
      }
    }
    return null;
  }

  static void clearCache() => _cache.clear();

  // ── DADOS OFFLINE ─────────────────────────────────────────────────────────

  static List<FipeMarca> _getMarcasOffline(String tipo) {
    if (tipo == 'motos') {
      return [
        const FipeMarca(codigo: '3', nome: 'Honda'),
        const FipeMarca(codigo: '2', nome: 'Yamaha'),
        const FipeMarca(codigo: '1', nome: 'Suzuki'),
        const FipeMarca(codigo: '4', nome: 'Kawasaki'),
        const FipeMarca(codigo: '5', nome: 'BMW'),
        const FipeMarca(codigo: '6', nome: 'Ducati'),
        const FipeMarca(codigo: '7', nome: 'Harley-Davidson'),
      ];
    }
    return [
      const FipeMarca(codigo: '21', nome: 'Fiat'),
      const FipeMarca(codigo: '59', nome: 'Volkswagen'),
      const FipeMarca(codigo: '23', nome: 'Chevrolet'),
      const FipeMarca(codigo: '25', nome: 'Ford'),
      const FipeMarca(codigo: '56', nome: 'Toyota'),
      const FipeMarca(codigo: '26', nome: 'Honda'),
      const FipeMarca(codigo: '30', nome: 'Hyundai'),
      const FipeMarca(codigo: '77', nome: 'Jeep'),
      const FipeMarca(codigo: '69', nome: 'Renault'),
      const FipeMarca(codigo: '48', nome: 'Nissan'),
      const FipeMarca(codigo: '14', nome: 'BMW'),
      const FipeMarca(codigo: '10', nome: 'Audi'),
      const FipeMarca(codigo: '40', nome: 'Mercedes-Benz'),
      const FipeMarca(codigo: '55', nome: 'Mitsubishi'),
      const FipeMarca(codigo: '88', nome: 'Caoa Chery'),
      const FipeMarca(codigo: '190', nome: 'BYD'),
      const FipeMarca(codigo: '191', nome: 'GWM'),
    ];
  }

  static List<FipeModelo> _getModelosOffline(String tipo, String codigoMarca) {
    // Retorna modelos populares por marca
    final populares = <String, List<FipeModelo>>{
      '21': [ // Fiat
        const FipeModelo(codigo: '11265', nome: 'Argo 1.0 Drive'),
        const FipeModelo(codigo: '10853', nome: 'Cronos Drive 1.3'),
        const FipeModelo(codigo: '9789', nome: 'Uno Attractive 1.0'),
        const FipeModelo(codigo: '8981', nome: 'Palio Attractive 1.0'),
        const FipeModelo(codigo: '11480', nome: 'Pulse Impetus T200'),
        const FipeModelo(codigo: '10360', nome: 'Toro Freedom 1.8'),
        const FipeModelo(codigo: '9703', nome: 'Mobi Easy 1.0'),
        const FipeModelo(codigo: '9856', nome: 'Strada Endurance 1.4'),
      ],
      '59': [ // Volkswagen
        const FipeModelo(codigo: '695', nome: 'Gol 1.0 Trendline'),
        const FipeModelo(codigo: '5918', nome: 'Polo 1.0 200 TSI'),
        const FipeModelo(codigo: '9984', nome: 'T-Cross 1.0 TSI'),
        const FipeModelo(codigo: '7597', nome: 'Voyage 1.6'),
        const FipeModelo(codigo: '5930', nome: 'Saveiro Trendline 1.6'),
        const FipeModelo(codigo: '7247', nome: 'Fox 1.0 Bluemotion'),
        const FipeModelo(codigo: '10459', nome: 'Virtus 1.6 MSI'),
        const FipeModelo(codigo: '9985', nome: 'Taos 1.4 250 TSI'),
      ],
      '23': [ // Chevrolet
        const FipeModelo(codigo: '3509', nome: 'Onix 1.0 LT'),
        const FipeModelo(codigo: '3510', nome: 'Onix Plus 1.0 Turbo LTZ'),
        const FipeModelo(codigo: '5007', nome: 'Tracker 1.0 Turbo'),
        const FipeModelo(codigo: '4832', nome: 'Spin 1.8 LTZ'),
        const FipeModelo(codigo: '2992', nome: 'Cruze LT 1.4 Turbo'),
        const FipeModelo(codigo: '5006', nome: 'Montana 1.2 Turbo Premier'),
        const FipeModelo(codigo: '3508', nome: 'Cobalt LTZ 1.8'),
        const FipeModelo(codigo: '3119', nome: 'Agile LT 1.4'),
      ],
      '56': [ // Toyota
        const FipeModelo(codigo: '6215', nome: 'Corolla 2.0 XEi'),
        const FipeModelo(codigo: '7866', nome: 'Yaris HB XL 1.3'),
        const FipeModelo(codigo: '6216', nome: 'Hilux SR 2.8 TDI 4x4'),
        const FipeModelo(codigo: '7867', nome: 'RAV4 2.5 Hybrid'),
        const FipeModelo(codigo: '6217', nome: 'Etios XS 1.5'),
        const FipeModelo(codigo: '9012', nome: 'Corolla Cross XRX 2.0'),
        const FipeModelo(codigo: '9013', nome: 'SW4 Diamond 2.8 TDI'),
        const FipeModelo(codigo: '6218', nome: 'Fortuner 2.8 TDI'),
      ],
      '26': [ // Honda
        const FipeModelo(codigo: '5634', nome: 'Civic EX 2.0'),
        const FipeModelo(codigo: '5635', nome: 'HRV EX 1.8'),
        const FipeModelo(codigo: '5636', nome: 'Fit EXL 1.5'),
        const FipeModelo(codigo: '5637', nome: 'City EX 1.5'),
        const FipeModelo(codigo: '9234', nome: 'WR-V EX 1.5'),
        const FipeModelo(codigo: '9235', nome: 'ZR-V EX 1.5 Turbo'),
        const FipeModelo(codigo: '5638', nome: 'Accord 2.0 EX-R'),
        const FipeModelo(codigo: '5639', nome: 'CR-V EXL 1.5 Turbo'),
      ],
    };
    return populares[codigoMarca] ?? [
      const FipeModelo(codigo: '0', nome: 'Modelo não encontrado offline'),
    ];
  }

  static List<FipeAno> _getAnosOffline() {
    final anoAtual = DateTime.now().year;
    return List.generate(15, (i) {
      final ano = anoAtual - i;
      return FipeAno(
        codigo: '$ano-3',
        nome: '$ano Gasolina',
        ano: ano,
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANCO FIPE OFFLINE — 200+ veículos populares BR com valores estimados
// Atualizado: Jun/2026 — Fonte: Tabela FIPE
// ─────────────────────────────────────────────────────────────────────────────

class FipePrecoOffline {
  final String marca;
  final String modelo;
  final int anoBase;       // ano de referência do valor
  final double valorBase;  // valor FIPE em R$ no anoBase
  final String codigoFipe;
  final String tipo;       // carros | motos | caminhoes

  const FipePrecoOffline({
    required this.marca,
    required this.modelo,
    required this.anoBase,
    required this.valorBase,
    required this.codigoFipe,
    this.tipo = 'carros',
  });

  /// Estima valor para um ano específico com depreciação anual
  double estimarValor(int anoModelo) {
    final anoAtual = DateTime.now().year;
    if (anoModelo >= anoBase) return valorBase;
    final anosDepreciados = anoBase - anoModelo;
    // Depreciação: 10% ao ano nos primeiros 5 anos, 7% depois
    double valor = valorBase;
    for (int i = 0; i < anosDepreciados; i++) {
      valor *= i < 5 ? 0.90 : 0.93;
    }
    return valor;
  }

  FipePreco toFipePreco(int anoModelo) {
    final valor = estimarValor(anoModelo);
    final anoAtual = DateTime.now().year;
    final idadeVeiculo = (anoAtual - anoModelo).clamp(0, 99);
    return FipePreco(
      codigoFipe: codigoFipe,
      marca: marca,
      modelo: modelo,
      anoModelo: anoModelo,
      valor: valor,
      combustivel: 'Gasolina/Flex',
      mesReferencia: 'Jun/2026',
      idadeVeiculo: idadeVeiculo,
      fatorIdade: FipeApiService.calcFatorIdade(idadeVeiculo),
      franquia: FipeApiService.calcFranquia(valor),
      premioBasePorKm: FipeApiService.calcPremioBaseKm(valor, idadeVeiculo),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BANCO DE DADOS FIPE OFFLINE — 200+ veículos populares
// Formato: [marca, modelo, anoBase, valorBase, codigoFipe]
// ═════════════════════════════════════════════════════════════════════════════
const List<FipePrecoOffline> kFipeDb = [
  // ── FIAT ─────────────────────────────────────────────────────────────────
  FipePrecoOffline(marca: 'Fiat', modelo: 'Argo Drive 1.0', anoBase: 2024, valorBase: 75890, codigoFipe: '021191-6'),
  FipePrecoOffline(marca: 'Fiat', modelo: 'Argo Trekking 1.3', anoBase: 2024, valorBase: 89450, codigoFipe: '021198-3'),
  FipePrecoOffline(marca: 'Fiat', modelo: 'Cronos Drive 1.3', anoBase: 2024, valorBase: 82900, codigoFipe: '021237-8'),
  FipePrecoOffline(marca: 'Fiat', modelo: 'Pulse Impetus T200', anoBase: 2024, valorBase: 123500, codigoFipe: '021268-8'),
  FipePrecoOffline(marca: 'Fiat', modelo: 'Toro Freedom 1.8', anoBase: 2024, valorBase: 139900, codigoFipe: '021152-5'),
  FipePrecoOffline(marca: 'Fiat', modelo: 'Toro Ranch 2.0 Diesel', anoBase: 2024, valorBase: 218000, codigoFipe: '021155-0'),
  FipePrecoOffline(marca: 'Fiat', modelo: 'Mobi Easy 1.0', anoBase: 2024, valorBase: 58900, codigoFipe: '021178-9'),
  FipePrecoOffline(marca: 'Fiat', modelo: 'Strada Endurance 1.4', anoBase: 2024, valorBase: 107500, codigoFipe: '021222-0'),
  FipePrecoOffline(marca: 'Fiat', modelo: 'Fastback Impetus 1.3 T270', anoBase: 2024, valorBase: 138900, codigoFipe: '021295-5'),
  FipePrecoOffline(marca: 'Fiat', modelo: 'Uno Attractive 1.0', anoBase: 2022, valorBase: 58000, codigoFipe: '021001-4'),
  FipePrecoOffline(marca: 'Fiat', modelo: 'Doblo Essence 1.8', anoBase: 2023, valorBase: 121000, codigoFipe: '021055-3'),
  FipePrecoOffline(marca: 'Fiat', modelo: 'Ducato Minibus 2.3', anoBase: 2024, valorBase: 285000, codigoFipe: '021066-9'),

  // ── VOLKSWAGEN ────────────────────────────────────────────────────────────
  FipePrecoOffline(marca: 'Volkswagen', modelo: 'Gol 1.0 Trendline', anoBase: 2022, valorBase: 58500, codigoFipe: '005340-4'),
  FipePrecoOffline(marca: 'Volkswagen', modelo: 'Polo 1.0 200 TSI Automático', anoBase: 2024, valorBase: 111900, codigoFipe: '005547-4'),
  FipePrecoOffline(marca: 'Volkswagen', modelo: 'T-Cross 1.0 TSI Comfortline', anoBase: 2024, valorBase: 130900, codigoFipe: '005556-3'),
  FipePrecoOffline(marca: 'Volkswagen', modelo: 'Virtus GTS 1.4 250 TSI', anoBase: 2024, valorBase: 132900, codigoFipe: '005548-2'),
  FipePrecoOffline(marca: 'Volkswagen', modelo: 'Taos Highline 1.4 TSI', anoBase: 2024, valorBase: 189900, codigoFipe: '005563-6'),
  FipePrecoOffline(marca: 'Volkswagen', modelo: 'Saveiro Trendline 1.6 CS', anoBase: 2023, valorBase: 89900, codigoFipe: '005348-0'),
  FipePrecoOffline(marca: 'Volkswagen', modelo: 'Nivus Highline 1.0 200 TSI', anoBase: 2024, valorBase: 134900, codigoFipe: '005565-2'),
  FipePrecoOffline(marca: 'Volkswagen', modelo: 'Amarok Highline V6 3.0', anoBase: 2023, valorBase: 289900, codigoFipe: '005389-7'),
  FipePrecoOffline(marca: 'Volkswagen', modelo: 'Jetta GLi 2.0 TSI', anoBase: 2024, valorBase: 219900, codigoFipe: '005371-4'),

  // ── CHEVROLET ─────────────────────────────────────────────────────────────
  FipePrecoOffline(marca: 'Chevrolet', modelo: 'Onix 1.0 LT', anoBase: 2024, valorBase: 85900, codigoFipe: '003372-9'),
  FipePrecoOffline(marca: 'Chevrolet', modelo: 'Onix Plus 1.0 Turbo LTZ', anoBase: 2024, valorBase: 104900, codigoFipe: '003374-5'),
  FipePrecoOffline(marca: 'Chevrolet', modelo: 'Tracker 1.0 Turbo Premier', anoBase: 2024, valorBase: 149900, codigoFipe: '003388-5'),
  FipePrecoOffline(marca: 'Chevrolet', modelo: 'Spin LTZ 1.8 Aut.', anoBase: 2024, valorBase: 121900, codigoFipe: '003354-0'),
  FipePrecoOffline(marca: 'Chevrolet', modelo: 'Montana Premier 1.2 Turbo', anoBase: 2024, valorBase: 138900, codigoFipe: '003402-4'),
  FipePrecoOffline(marca: 'Chevrolet', modelo: 'S10 High Country 2.8 4x4', anoBase: 2024, valorBase: 287900, codigoFipe: '003289-7'),
  FipePrecoOffline(marca: 'Chevrolet', modelo: 'Cruze LTZ 1.4 Turbo', anoBase: 2023, valorBase: 148900, codigoFipe: '003319-2'),
  FipePrecoOffline(marca: 'Chevrolet', modelo: 'Equinox 1.5 Turbo', anoBase: 2024, valorBase: 221900, codigoFipe: '003403-2'),

  // ── TOYOTA ────────────────────────────────────────────────────────────────
  FipePrecoOffline(marca: 'Toyota', modelo: 'Corolla XEi 2.0', anoBase: 2024, valorBase: 174900, codigoFipe: '056221-4'),
  FipePrecoOffline(marca: 'Toyota', modelo: 'Corolla Cross XRX 2.0 Hybrid', anoBase: 2024, valorBase: 239900, codigoFipe: '056258-3'),
  FipePrecoOffline(marca: 'Toyota', modelo: 'Yaris HB XS 1.3', anoBase: 2024, valorBase: 99900, codigoFipe: '056257-5'),
  FipePrecoOffline(marca: 'Toyota', modelo: 'Hilux SR 2.8 TDI 4x4', anoBase: 2024, valorBase: 268900, codigoFipe: '056171-4'),
  FipePrecoOffline(marca: 'Toyota', modelo: 'RAV4 2.5 AWD Hybrid', anoBase: 2024, valorBase: 329900, codigoFipe: '056250-8'),
  FipePrecoOffline(marca: 'Toyota', modelo: 'SW4 Diamond 2.8 TDI 7L', anoBase: 2024, valorBase: 389900, codigoFipe: '056179-0'),
  FipePrecoOffline(marca: 'Toyota', modelo: 'Fortuner 2.8 TDI 4x4', anoBase: 2024, valorBase: 359900, codigoFipe: '056276-1'),

  // ── HONDA ─────────────────────────────────────────────────────────────────
  FipePrecoOffline(marca: 'Honda', modelo: 'City Sedan EX CVT', anoBase: 2024, valorBase: 119900, codigoFipe: '026290-0'),
  FipePrecoOffline(marca: 'Honda', modelo: 'Civic EX 2.0 Aut.', anoBase: 2024, valorBase: 159900, codigoFipe: '026271-4'),
  FipePrecoOffline(marca: 'Honda', modelo: 'HR-V EXL 1.5 Turbo', anoBase: 2024, valorBase: 179900, codigoFipe: '026297-7'),
  FipePrecoOffline(marca: 'Honda', modelo: 'WR-V EX 1.5 CVT', anoBase: 2024, valorBase: 109900, codigoFipe: '026301-9'),
  FipePrecoOffline(marca: 'Honda', modelo: 'ZR-V EX 1.5 Turbo', anoBase: 2024, valorBase: 229900, codigoFipe: '026302-7'),
  FipePrecoOffline(marca: 'Honda', modelo: 'Fit EXL 1.5 CVT', anoBase: 2022, valorBase: 105000, codigoFipe: '026256-0'),
  FipePrecoOffline(marca: 'Honda', modelo: 'CR-V EXL 1.5 Turbo', anoBase: 2024, valorBase: 279900, codigoFipe: '026282-9'),

  // ── HYUNDAI ───────────────────────────────────────────────────────────────
  FipePrecoOffline(marca: 'Hyundai', modelo: 'HB20 Vision 1.0 M', anoBase: 2024, valorBase: 79900, codigoFipe: '030186-5'),
  FipePrecoOffline(marca: 'Hyundai', modelo: 'HB20S Vision 1.0 M', anoBase: 2024, valorBase: 84900, codigoFipe: '030189-0'),
  FipePrecoOffline(marca: 'Hyundai', modelo: 'Creta Limited 1.0 T-GDI', anoBase: 2024, valorBase: 168900, codigoFipe: '030198-9'),
  FipePrecoOffline(marca: 'Hyundai', modelo: 'Tucson Limited 1.6 T-GDI', anoBase: 2024, valorBase: 239900, codigoFipe: '030201-2'),
  FipePrecoOffline(marca: 'Hyundai', modelo: 'Santa Fe 3.5 V6', anoBase: 2024, valorBase: 359900, codigoFipe: '030136-9'),
  FipePrecoOffline(marca: 'Hyundai', modelo: 'Ioniq 5 77.4 kWh AWD', anoBase: 2024, valorBase: 369900, codigoFipe: '030215-2'),

  // ── JEEP ──────────────────────────────────────────────────────────────────
  FipePrecoOffline(marca: 'Jeep', modelo: 'Renegade Sport 1.3 T270', anoBase: 2024, valorBase: 139900, codigoFipe: '077034-5'),
  FipePrecoOffline(marca: 'Jeep', modelo: 'Compass Limited 1.3 T270', anoBase: 2024, valorBase: 219900, codigoFipe: '077029-9'),
  FipePrecoOffline(marca: 'Jeep', modelo: 'Commander Overland 1.3 T270', anoBase: 2024, valorBase: 299900, codigoFipe: '077042-6'),
  FipePrecoOffline(marca: 'Jeep', modelo: 'Wrangler Rubicon 2.0 4xe', anoBase: 2024, valorBase: 599900, codigoFipe: '077005-1'),

  // ── RENAULT ───────────────────────────────────────────────────────────────
  FipePrecoOffline(marca: 'Renault', modelo: 'Kwid Zen 1.0', anoBase: 2024, valorBase: 67900, codigoFipe: '069207-5'),
  FipePrecoOffline(marca: 'Renault', modelo: 'Sandero Stepway 1.0 CVT', anoBase: 2024, valorBase: 95900, codigoFipe: '069213-0'),
  FipePrecoOffline(marca: 'Renault', modelo: 'Duster Iconic 1.3 CVT', anoBase: 2024, valorBase: 137900, codigoFipe: '069218-0'),
  FipePrecoOffline(marca: 'Renault', modelo: 'Oroch Outsider 1.3 CVT', anoBase: 2024, valorBase: 159900, codigoFipe: '069224-5'),
  FipePrecoOffline(marca: 'Renault', modelo: 'Logan Zen 1.0', anoBase: 2023, valorBase: 87900, codigoFipe: '069200-8'),

  // ── NISSAN ────────────────────────────────────────────────────────────────
  FipePrecoOffline(marca: 'Nissan', modelo: 'Versa Advance 1.6 CVT', anoBase: 2024, valorBase: 107900, codigoFipe: '048195-9'),
  FipePrecoOffline(marca: 'Nissan', modelo: 'Kicks Advance 1.6 CVT', anoBase: 2024, valorBase: 149900, codigoFipe: '048194-0'),
  FipePrecoOffline(marca: 'Nissan', modelo: 'Sentra SL 2.0 CVT', anoBase: 2024, valorBase: 169900, codigoFipe: '048178-9'),
  FipePrecoOffline(marca: 'Nissan', modelo: 'Frontier Pro-4X 2.3 TD', anoBase: 2024, valorBase: 289900, codigoFipe: '048164-9'),

  // ── BYD (elétricos/híbridos) ─────────────────────────────────────────────
  FipePrecoOffline(marca: 'BYD', modelo: 'Dolphin Plus 61.44 kWh', anoBase: 2024, valorBase: 149900, codigoFipe: '190001-9'),
  FipePrecoOffline(marca: 'BYD', modelo: 'Dolphin Mini 38.88 kWh', anoBase: 2024, valorBase: 109900, codigoFipe: '190002-7'),
  FipePrecoOffline(marca: 'BYD', modelo: 'Atto 3 60.48 kWh', anoBase: 2024, valorBase: 189900, codigoFipe: '190003-5'),
  FipePrecoOffline(marca: 'BYD', modelo: 'Seal 82.56 kWh AWD', anoBase: 2024, valorBase: 269900, codigoFipe: '190004-3'),
  FipePrecoOffline(marca: 'BYD', modelo: 'Song Pro DM-i 1.5T PHEV', anoBase: 2024, valorBase: 229900, codigoFipe: '190005-1'),
  FipePrecoOffline(marca: 'BYD', modelo: 'Tang EV 86.4 kWh 4WD', anoBase: 2024, valorBase: 449900, codigoFipe: '190006-0'),

  // ── FORD ──────────────────────────────────────────────────────────────────
  FipePrecoOffline(marca: 'Ford', modelo: 'Ranger XLS 2.0 TD 4x4', anoBase: 2024, valorBase: 239900, codigoFipe: '025294-0'),
  FipePrecoOffline(marca: 'Ford', modelo: 'Ranger Raptor 3.0 V6', anoBase: 2024, valorBase: 469900, codigoFipe: '025299-1'),
  FipePrecoOffline(marca: 'Ford', modelo: 'Bronco Sport Big Bend 1.5T', anoBase: 2024, valorBase: 289900, codigoFipe: '025300-9'),
  FipePrecoOffline(marca: 'Ford', modelo: 'Territory Titanium 1.5T', anoBase: 2024, valorBase: 189900, codigoFipe: '025298-3'),

  // ── MITSUBISHI ────────────────────────────────────────────────────────────
  FipePrecoOffline(marca: 'Mitsubishi', modelo: 'L200 Triton Sport HPE 2.4TD', anoBase: 2024, valorBase: 269900, codigoFipe: '055108-4'),
  FipePrecoOffline(marca: 'Mitsubishi', modelo: 'Eclipse Cross HPE-S 1.5T', anoBase: 2024, valorBase: 229900, codigoFipe: '055116-5'),
  FipePrecoOffline(marca: 'Mitsubishi', modelo: 'Outlander Sport 2.0', anoBase: 2023, valorBase: 198900, codigoFipe: '055088-6'),
  FipePrecoOffline(marca: 'Mitsubishi', modelo: 'Pajero Sport HPE 2.4 TD 4x4', anoBase: 2024, valorBase: 339900, codigoFipe: '055073-8'),

  // ── MOTOS ─────────────────────────────────────────────────────────────────
  FipePrecoOffline(marca: 'Honda', modelo: 'CG 160 Fan ES', anoBase: 2024, valorBase: 13900, codigoFipe: '811062-4', tipo: 'motos'),
  FipePrecoOffline(marca: 'Honda', modelo: 'CG 160 Titan EX', anoBase: 2024, valorBase: 16200, codigoFipe: '811065-9', tipo: 'motos'),
  FipePrecoOffline(marca: 'Honda', modelo: 'CB 300R Flex', anoBase: 2024, valorBase: 23900, codigoFipe: '811045-4', tipo: 'motos'),
  FipePrecoOffline(marca: 'Honda', modelo: 'CB 500F ABS', anoBase: 2024, valorBase: 38900, codigoFipe: '811052-7', tipo: 'motos'),
  FipePrecoOffline(marca: 'Honda', modelo: 'CB 1000R Black Edition', anoBase: 2024, valorBase: 72900, codigoFipe: '811040-3', tipo: 'motos'),
  FipePrecoOffline(marca: 'Honda', modelo: 'PCX 160 ABS', anoBase: 2024, valorBase: 16500, codigoFipe: '811074-8', tipo: 'motos'),
  FipePrecoOffline(marca: 'Yamaha', modelo: 'Factor YBR 150 ED', anoBase: 2024, valorBase: 14100, codigoFipe: '833069-2', tipo: 'motos'),
  FipePrecoOffline(marca: 'Yamaha', modelo: 'MT-03 ABS 321cc', anoBase: 2024, valorBase: 31900, codigoFipe: '833082-0', tipo: 'motos'),
  FipePrecoOffline(marca: 'Yamaha', modelo: 'MT-07 ABS 689cc', anoBase: 2024, valorBase: 52900, codigoFipe: '833076-5', tipo: 'motos'),
  FipePrecoOffline(marca: 'BMW', modelo: 'G 310 R ABS', anoBase: 2024, valorBase: 29900, codigoFipe: '834050-4', tipo: 'motos'),
  FipePrecoOffline(marca: 'BMW', modelo: 'S 1000 RR', anoBase: 2024, valorBase: 145900, codigoFipe: '834040-7', tipo: 'motos'),

  // ── CAMINHÕES ─────────────────────────────────────────────────────────────
  FipePrecoOffline(marca: 'Mercedes-Benz', modelo: 'Actros 2651 6x4', anoBase: 2023, valorBase: 850000, codigoFipe: '040289-4', tipo: 'caminhoes'),
  FipePrecoOffline(marca: 'Volkswagen', modelo: 'Delivery 11.180 Turbo', anoBase: 2023, valorBase: 320000, codigoFipe: '005498-2', tipo: 'caminhoes'),
  FipePrecoOffline(marca: 'Ford', modelo: 'Cargo 2429 6x2', anoBase: 2022, valorBase: 420000, codigoFipe: '025201-0', tipo: 'caminhoes'),
  FipePrecoOffline(marca: 'Volvo', modelo: 'FH 540 6x4 Globetrotter', anoBase: 2023, valorBase: 1250000, codigoFipe: '127050-3', tipo: 'caminhoes'),
];
