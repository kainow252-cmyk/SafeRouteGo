// ══════════════════════════════════════════════════════════════════════════
// SafeRouteGo — AI DATASETS SERVICE
// Carrega e indexa o catálogo de datasets HF/Kaggle/SUSEP + modelos LLM
// Fonte: assets/data/ai_datasets.json (gerado pelo ETL Python v1.0)
// ══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────
// MODELOS DE DADOS
// ─────────────────────────────────────────────────────────────────────────

class AIDataset {
  final String id;
  final String nome;
  final String fonte;
  final String repositorio;
  final String categoria;
  final String subcategoria;
  final double tamanhoMb;
  final int? registros;
  final String idioma;
  final String licenca;
  final String url;
  final String usoSadi;
  final String formato;
  final List<String> campos;
  final double qualidade;
  final int? downloadsMensais;
  final String dataCriacao;
  final List<String> tags;

  const AIDataset({
    required this.id,
    required this.nome,
    required this.fonte,
    required this.repositorio,
    required this.categoria,
    required this.subcategoria,
    required this.tamanhoMb,
    this.registros,
    required this.idioma,
    required this.licenca,
    required this.url,
    required this.usoSadi,
    required this.formato,
    required this.campos,
    required this.qualidade,
    this.downloadsMensais,
    required this.dataCriacao,
    required this.tags,
  });

  factory AIDataset.fromJson(Map<String, dynamic> j) => AIDataset(
        id: j['id'] ?? '',
        nome: j['nome'] ?? '',
        fonte: j['fonte'] ?? '',
        repositorio: j['repositorio'] ?? '',
        categoria: j['categoria'] ?? '',
        subcategoria: j['subcategoria'] ?? '',
        tamanhoMb: (j['tamanho_mb'] as num?)?.toDouble() ?? 0,
        registros: j['registros'] as int?,
        idioma: j['idioma'] ?? '',
        licenca: j['licenca'] ?? '',
        url: j['url'] ?? '',
        usoSadi: j['uso_sadi'] ?? '',
        formato: j['formato'] ?? '',
        campos: List<String>.from(j['campos'] ?? []),
        qualidade: (j['qualidade'] as num?)?.toDouble() ?? 0,
        downloadsMensais: j['downloads_mensais'] as int?,
        dataCriacao: j['data_criacao'] ?? '',
        tags: List<String>.from(j['tags'] ?? []),
      );

  String get tamanhoFormatado {
    if (tamanhoMb >= 1000) return '${(tamanhoMb / 1024).toStringAsFixed(1)} GB';
    return '${tamanhoMb.toStringAsFixed(1)} MB';
  }

  String get registrosFormatado {
    if (registros == null) return 'N/A';
    if (registros! >= 1000000) return '${(registros! / 1000000).toStringAsFixed(1)}M';
    if (registros! >= 1000) return '${(registros! / 1000).toStringAsFixed(0)}K';
    return registros.toString();
  }

  String get downloadsFormatado {
    if (downloadsMensais == null) return 'Interno';
    if (downloadsMensais! >= 1000000) return '${(downloadsMensais! / 1000000).toStringAsFixed(1)}M/mês';
    if (downloadsMensais! >= 1000) return '${(downloadsMensais! / 1000).toStringAsFixed(0)}K/mês';
    return '$downloadsMensais/mês';
  }

  bool get isHuggingFace => fonte == 'Hugging Face';
  bool get isKaggle => fonte == 'Kaggle';
  bool get isInterno => url.startsWith('internal://');
  bool get isLLMModel => categoria.contains('LLM');
}

class ModeloLLM {
  final String id;
  final String nome;
  final String provider;
  final double? parametrosB;
  final String licenca;
  final double? tamanhoGb;
  final int? contextoTokens;
  final String usoCaso;
  final double benchmark;

  const ModeloLLM({
    required this.id,
    required this.nome,
    required this.provider,
    this.parametrosB,
    required this.licenca,
    this.tamanhoGb,
    this.contextoTokens,
    required this.usoCaso,
    required this.benchmark,
  });

  factory ModeloLLM.fromJson(Map<String, dynamic> j) => ModeloLLM(
        id: j['id'] ?? '',
        nome: j['nome'] ?? '',
        provider: j['provider'] ?? '',
        parametrosB: (j['parametros_b'] as num?)?.toDouble(),
        licenca: j['licenca'] ?? '',
        tamanhoGb: (j['tamanho_gb'] as num?)?.toDouble(),
        contextoTokens: j['contexto_tokens'] as int?,
        usoCaso: j['uso_caso'] ?? '',
        benchmark: (j['benchmark'] as num?)?.toDouble() ?? 0,
      );

  String get parametrosStr {
    if (parametrosB == null) return 'API';
    return '${parametrosB}B params';
  }

  String get tamanhoStr {
    if (tamanhoGb == null) return 'Cloud';
    return '${tamanhoGb!.toStringAsFixed(1)} GB';
  }

  String get contextoStr {
    if (contextoTokens == null) return '?';
    if (contextoTokens! >= 1000) return '${(contextoTokens! / 1000).toStringAsFixed(0)}K tokens';
    return '$contextoTokens tokens';
  }
}

class AIStats {
  final int totalDatasets;
  final int totalModelos;
  final int totalSinistros;
  final int totalPremios;
  final double taxaFraude;
  final double premioMedio;
  final int tbHf;
  final int tbKaggle;
  final int tbSusep;
  final double? totalMb;

  const AIStats({
    required this.totalDatasets,
    required this.totalModelos,
    required this.totalSinistros,
    required this.totalPremios,
    required this.taxaFraude,
    required this.premioMedio,
    required this.tbHf,
    required this.tbKaggle,
    required this.tbSusep,
    this.totalMb,
  });

  factory AIStats.fromJson(Map<String, dynamic> j) => AIStats(
        totalDatasets: j['total_datasets'] as int? ?? 0,
        totalModelos: j['total_modelos'] as int? ?? 0,
        totalSinistros: j['total_sinistros'] as int? ?? 0,
        totalPremios: j['total_premios'] as int? ?? 0,
        taxaFraude: (j['taxa_fraude'] as num?)?.toDouble() ?? 0,
        premioMedio: (j['premio_medio'] as num?)?.toDouble() ?? 0,
        tbHf: j['tb_hf'] as int? ?? 0,
        tbKaggle: j['tb_kaggle'] as int? ?? 0,
        tbSusep: j['tb_susep'] as int? ?? 0,
        totalMb: (j['total_mb'] as num?)?.toDouble(),
      );

  String get totalGBStr {
    if (totalMb == null) return 'N/A';
    return '${(totalMb! / 1024).toStringAsFixed(1)} GB';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SERVICE SINGLETON
// ─────────────────────────────────────────────────────────────────────────

class AIDatasetsService {
  static AIDatasetsService? _instance;
  static AIDatasetsService get instance => _instance ??= AIDatasetsService._();
  AIDatasetsService._();

  bool _loaded = false;
  List<AIDataset> _datasets = [];
  List<ModeloLLM> _modelos = [];
  AIStats? _stats;
  Map<String, dynamic> _meta = {};
  Map<String, dynamic> _porCategoria = {};
  Map<String, dynamic> _porFonte = {};

  List<AIDataset> get datasets => _datasets;
  List<ModeloLLM> get modelos => _modelos;
  AIStats? get stats => _stats;
  Map<String, dynamic> get meta => _meta;
  bool get isLoaded => _loaded;

  Future<void> carregar() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/ai_datasets.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;

      _meta = json['meta'] as Map<String, dynamic>? ?? {};
      _stats = AIStats.fromJson(json['estatisticas'] as Map<String, dynamic>? ?? {});
      _datasets = ((json['datasets'] as List?) ?? [])
          .map((e) => AIDataset.fromJson(e as Map<String, dynamic>))
          .toList();
      _modelos = ((json['modelos_llm'] as List?) ?? [])
          .map((e) => ModeloLLM.fromJson(e as Map<String, dynamic>))
          .toList();
      _porCategoria = json['por_categoria'] as Map<String, dynamic>? ?? {};
      _porFonte = json['por_fonte'] as Map<String, dynamic>? ?? {};
      _loaded = true;
    } catch (e) {
      // Fallback silencioso
      _loaded = false;
    }
  }

  // ── Buscas ─────────────────────────────────────────────────────────────

  List<AIDataset> buscar(String query) {
    if (query.isEmpty) return _datasets;
    final q = query.toLowerCase();
    return _datasets.where((d) =>
      d.nome.toLowerCase().contains(q) ||
      d.categoria.toLowerCase().contains(q) ||
      d.fonte.toLowerCase().contains(q) ||
      d.tags.any((t) => t.contains(q)) ||
      d.usoSadi.toLowerCase().contains(q)
    ).toList();
  }

  List<AIDataset> porCategoria(String cat) =>
      _datasets.where((d) => d.categoria == cat).toList();

  List<AIDataset> porFonte(String fonte) =>
      _datasets.where((d) => d.fonte == fonte).toList();

  List<String> get categorias =>
      _datasets.map((d) => d.categoria).toSet().toList()..sort();

  List<String> get fontes =>
      _datasets.map((d) => d.fonte).toSet().toList()..sort();

  List<AIDataset> get topQualidade =>
      [..._datasets]..sort((a, b) => b.qualidade.compareTo(a.qualidade));

  List<AIDataset> get maisDownloads {
    final comDownload = _datasets.where((d) => d.downloadsMensais != null).toList();
    comDownload.sort((a, b) => (b.downloadsMensais ?? 0).compareTo(a.downloadsMensais ?? 0));
    return comDownload;
  }

  double get totalGBCatalogado {
    return _datasets.fold(0.0, (sum, d) => sum + d.tamanhoMb) / 1024;
  }

  Map<String, int> get distribuicaoPorFonte {
    final map = <String, int>{};
    for (final ds in _datasets) {
      map[ds.fonte] = (map[ds.fonte] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get distribuicaoPorCategoria {
    final map = <String, int>{};
    for (final ds in _datasets) {
      map[ds.categoria] = (map[ds.categoria] ?? 0) + 1;
    }
    return map;
  }
}
