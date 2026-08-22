// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════════
// SAFEROUTE — INSURANCE SEARCH ENGINE v2.0 (SISE)
// SEGURADORA DIGITAL COMPLETA — TODOS OS RAMOS DO MUNDO
//
// COBERTURA REGULATÓRIA:
//   Brasil:        SUSEP — Ramos 011 a 0999 (Resolução 51/2025)
//   Internacional: Lloyd's, Swiss Re, Munich Re taxonomy
//   Capitalização: SUSEP Circular 630/2020
//   Previdência:   PGBL/VGBL — Resolução CNSP 381/2020
//
// ARQUITETURA:
//   InsuranceSearchEngine (singleton)
//     ├── InsuranceLine         — enum com 150+ ramos/produtos
//     ├── InsuranceProduct      — produto cotável com regras
//     ├── InsurancePolicy       — apólice emitida
//     ├── InsuranceQuote        — cotação gerada
//     ├── NeedsDetectorEngine   — IA detecção de necessidades
//     ├── ProductCatalog        — catálogo 150+ produtos
//     ├── QuoteEngine           — motor de precificação atuarial
//     └── PolicyManager         — gestão de apólices + carteira
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'territorial_risk_intelligence.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUM — TODOS OS RAMOS (150+ produtos)
// ─────────────────────────────────────────────────────────────────────────────

enum InsuranceLine {
  // ══ 01. SAFEROUTE EXCLUSIVOS (paramétrico + UBI) ══════════════════════════
  autoUbi,              // UBI Pay-How-You-Drive — CORE SafeRoute
  safeShieldColisao,   // Paramétrico: GPS detecta colisão -4G → paga automático
  zonaSeguraTri,       // Cobertura extra ao entrar em zona TRI crítica > 800
  novaChuvaChuva,      // Paramétrico: chuva INMET > 50mm/h → paga automático
  rapidProtectMotoboy, // AP por hora ativado pelo app de delivery
  cyberPixShield,      // Golpe PIX correlacionado com risco territorial

  // ══ 02. AUTOMÓVEIS (SUSEP Ramo 062 + variações) ═══════════════════════════
  autoCompreensivo,    // Casco + RCF + APP + Serviços completo
  autoPopular,         // Só RC facultativa + assistência básica
  autoOnDemand,        // Por hora (Cuvva, Metromile model)
  autoAssinatura,      // Mensal cancelável sem fidelidade
  autoVip,             // Premium (veículos > R$200k, cobertura global)
  autoEmpresarial,     // Frota empresarial
  frotas,              // 3+ veículos, desconto coletivo
  evEletrico,          // Veículos elétricos (bateria inclusa)
  autoAntigo,          // Veículos clássicos e antigos (ANBIMA)
  autoLocadora,        // Locadoras de veículos
  autoGarantia,        // Defeitos de fabricação pós-garantia
  autoConcessionaria,  // Veículos em consignação/concessionária

  // ══ 03. MOTOS E MICROMOBILIDADE ══════════════════════════════════════════
  motoCompreensivo,    // Casco + RCF moto
  motoApp,             // Motoboy / gig economy uso profissional
  motoPopular,         // RC moto básico
  bicicleta,           // E-bike + bicicleta convencional
  patineteEletrico,    // Patinete elétrico (urbano)
  quadriciclo,         // ATV/quad offroad

  // ══ 04. VEÍCULOS PESADOS E TRANSPORTE ════════════════════════════════════
  caminhaoRCTRC,       // RCTRC — Responsabilidade Civil Transportador
  caminhaoCompreensivo,// Casco + RC caminhão
  onibus,              // Ônibus e vans (transporte coletivo)
  maquinasAgricolas,   // Tratores, colheitadeiras, implementos
  embarcacaoMarinha,   // Lanchas, jetski, barcos de recreio
  aeronave,            // Aeronaves privadas, hangar, responsabilidade
  helicoptero,         // Helicopteros executivos e agro
  drones,              // Drones comerciais e recreativos
  veiculoNautico,      // Equipamento náutico geral

  // ══ 05. VIDA (SUSEP Ramos 021-029) ══════════════════════════════════════
  vidaTermo,           // Vida a prazo determinado
  vidaInteira,         // Whole life — cobertura vitalícia
  vidaUniversal,       // Universal life — flexibilidade de prêmio
  vidaVariavel,        // Variable life — vinculado a carteira
  vidaCredito,         // Prestamista / quitação de dívida
  vidaGrupo,           // Vida em grupo empresarial (RH)
  vidaRural,           // Agricultores e trabalhadores rurais
  vidaMilitar,         // Forças armadas e segurança pública
  vidaMicro,           // Vida micro (baixa renda, < R$15/mês)

  // ══ 06. ACIDENTE PESSOAL (SUSEP Ramos 061) ═══════════════════════════════
  apIndividual,        // AP individual padrão
  apFamiliar,          // AP família — cônjuge + filhos
  apGigWorker,         // AP por hora/viagem (gig economy)
  apMotoboy,           // AP específico motoboy/entregador
  apEsportivo,         // Esportes de risco e aventura
  apViagem,            // AP durante viagem
  apEscolar,           // Crianças em ambiente escolar
  apIdoso,             // Sênior > 60 anos
  apCorporativo,       // Grupo empresarial coletivo
  apEventos,           // Participantes de eventos
  apConstrutores,      // Trabalhadores da construção civil

  // ══ 07. SAÚDE (ANS + SUSEP) ══════════════════════════════════════════════
  saudeIndividual,     // Plano individual (ANS)
  saudeFamiliar,       // Plano familiar (ANS)
  saudeDental,         // Odontológico individual
  saudeDentalFamiliar, // Odontológico familiar
  saudeViagem,         // Internacional — viagem
  saudeCorporativo,    // Plano empresarial grupo
  saudePme,            // PME — 2 a 99 vidas
  saudeSenior,         // Cobertura sênior 60+
  saudeMicro,          // Micro saúde (<R$50/mês telemedicina)
  hospitalDia,         // Diária hospitalar (DHI)
  cirurgiaEletica,     // Cirurgia eletiva agendada
  saudeMental,         // Psicoterapia + psiquiatria

  // ══ 08. RESIDENCIAL (SUSEP Ramos 068-069) ════════════════════════════════
  residencial,         // Compreensivo — incêndio+roubo+RC+serviços
  residencialBasico,   // Incêndio obrigatório + básico
  residencialAluguel,  // Inquilino — danos ao imóvel alugado
  aluguelGarantido,    // Fiança digital — risco de inadimplência
  condominial,         // Condomínio — RC + incêndio partes comuns
  casaDeVeraneio,      // Imóvel de temporada
  imovelVazio,         // Imóvel desocupado
  construcaoCivil,     // Obra em andamento (residencial)

  // ══ 09. EMPRESARIAL / COMERCIAL (SUSEP Ramos 068-072) ════════════════════
  empresarial,         // Compreensivo empresarial
  comercial,           // Loja / comércio varejista
  escritorio,          // Escritório / coworking
  industria,           // Complexo industrial
  hoteis,              // Hospitalidade — hotel/pousada
  restaurante,         // Estabelecimento alimentício
  clinicaMedica,       // Clínica / consultório médico
  farmacia,            // Farmácia e drogaria
  supermercado,        // Grande varejo alimentar
  postoGasolina,       // Posto de combustível
  construcaoComercial, // Obra comercial em andamento
  condominioCom,       // Condomínio comercial
  shopping,            // Shopping centers
  dataCenter,          // Infraestrutura TI/datacenter

  // ══ 10. EQUIPAMENTOS E MÁQUINAS ══════════════════════════════════════════
  equipamentosEletronicos, // Equipamentos eletrônicos gerais
  maquinasIndustriais,     // Maquinário industrial
  paineisSolares,          // Sistemas fotovoltaicos
  equipamentosRurais,      // Equipamentos campo
  equipamentosMedicos,     // Aparelhos médicos
  instrumentosMusicais,    // Violinos, pianos, etc.
  camerasFotograficas,     // Equipamento fotográfico profissional
  celular,                 // Roubo + quebra de celular
  notebookTablet,          // Notebook / tablet pessoal
  videogame,               // Consoles e periféricos

  // ══ 11. RISCOS DE ENGENHARIA (SUSEP Ramos 073-074) ═══════════════════════
  riscosEngenharia,    // Obras e montagem em geral
  riscosMontagem,      // Montagem de equipamentos industriais
  rcObras,             // RC do construtor / empreiteiro
  colapsoEstrutura,    // Colapso de estruturas
  termeletrica,        // Obras de energia
  mineiracao,          // Mineração e extração

  // ══ 12. CYBER E DIGITAL (Lloyd's / Swiss Re taxonomy) ════════════════════
  cyberPessoalPix,     // Golpe do PIX + fraude digital básico
  cyberPessoalPleno,   // Identidade + dados + PIX + dark web
  cyberEmpresarial,    // LGPD + ransomware + dados corporativos
  cyberStartup,        // Startups e fintechs (cobertura TI)
  identidadeDigital,   // Roubo de identidade + reputação
  ransomwareProtect,   // Extorsão digital + recuperação de dados
  errorOmissao,        // E&O tech — falha de software empresarial
  ciberRcProfissional, // RC profissional digital (consultores TI)

  // ══ 13. VIAGEM (SUSEP + Lloyd's) ═════════════════════════════════════════
  viagemNacional,      // Bagagem + assistência médica nacional
  viagemInternacional, // Visa Schengen + cobertura global
  viagemParametrico,   // Paga automaticamente por atraso de voo
  viagemCancelamento,  // Reembolso por cancelamento de viagem
  viagemBagagem,       // Bagagem extraviada / danificada
  nomadeDigital,       // Remote workers — multi-país, multi-visto
  cruzeiro,            // Seguro específico cruzeiro marítimo
  mochileiro,          // Backpacker — aventura e esportes radicais
  embarque,            // Assistência embarque/desembarque
  expatriado,          // Brasileiros residentes no exterior

  // ══ 14. RURAL (SUSEP Ramos 081-089) ══════════════════════════════════════
  agricola,            // Cultura agrícola — soja, milho, café
  pecuario,            // Rebanho bovino / equino / suíno
  parametricoClimatico,// Índice pluviométrico / seca (trigger automático)
  catastrofeNatural,   // CAT — enchente, granizo, terremoto
  florestal,           // Reflorestamento e madeira em pé
  aquicultura,         // Peixicultura / camarão / maricultura
  proagro,             // Garantia de atividade agropecuária
  fruticultura,        // Culturas especiais — uva, maçã, citrus
  canaDeAcucar,        // Cana — colheita e armazenagem

  // ══ 15. RESPONSABILIDADE CIVIL (SUSEP Ramos 040-059) ═════════════════════
  rcGeral,             // RC geral empresarial
  rcProfissional,      // E&O / Erros e Omissões liberal
  rcMedico,            // Malpractice médico e hospitalar
  rcAdv,               // Advogados e escritórios jurídicos
  rcContabilista,      // Contadores e auditores
  rcArquiteto,         // Arquitetos e engenheiros
  rcCorretorSeguros,   // Corretor de seguros (SUSEP)
  rcCorretorImoveis,   // Corretor de imóveis (CRECI)
  rcTransportador,     // Transportador de cargas
  rcAmbiental,         // Danos ao meio ambiente
  rcEventos,           // Eventos e shows
  rcProdutos,          // Produto defeituoso (recall)
  dno,                 // D&O — Diretores e Executivos
  dnoStartup,          // D&O para startups e fintechs
  seguroGarantia,      // Surety bond — licitações públicas
  seguroGarantiaPriv,  // Garantia contratos privados
  fiancaLocaticia,     // Fiança locatícia digital
  rcFarmaceutico,      // Indústria farmacêutica

  // ══ 16. TRANSPORTE E CARGA (SUSEP Ramos 090-099) ═════════════════════════
  cargoNacional,       // Carga em trânsito rodoviário nacional
  cargoAereo,          // Carga aérea nacional e internacional
  cargoMaritimo,       // Carga marítima (importação/exportação)
  cargoInternacional,  // Cargo + customs internacional
  transitoAduaneiro,   // Despacho aduaneiro + seguro
  valoresTransporte,   // Numerário, joias, metais em trânsito
  correioEncomenda,    // Seguro para encomendas (e-commerce)
  temperatura,         // Carga refrigerada (farma/alimentos)

  // ══ 17. MARÍTIMO E AVIAÇÃO ════════════════════════════════════════════════
  cascoMaritimo,       // Casco de embarcação comercial
  rcPortuaria,         // Responsabilidade portuária
  pi_marinha,          // P&I — Protection & Indemnity (armadores)
  cargasEspeciais,     // Cargas perigosas / explosivos
  aviaoComercial,      // Casco aeronave comercial
  aviacaoGeral,        // Aviação geral — táxi aéreo / executivo
  rcAereo,             // RC aeronáutico (passageiros + terceiros)
  aeroporto,           // Responsabilidade aeroportuária
  satelite,            // Satélites e mídia espacial
  lancamento,          // Lançamento espacial

  // ══ 18. CRÉDITO E GARANTIAS FINANCEIRAS (SUSEP Ramos 100-110) ═══════════
  creditoExportacao,   // Seguro de crédito à exportação
  creditoInterno,      // Crédito interno — inadimplência B2B
  creditoImobiliario,  // Seguro habitacional SFH/SFI
  creditoConsignado,   // Prestamista consignado (servidores)
  creditoRural,        // Custeio e investimento rural
  creditoRotativo,     // Cartão de crédito + rotativo
  fgts,                // Complemento FGTS demissão involuntária
  risco_sacado,        // Risco sacado (supply chain finance)
  fgop,                // Fundo Garantidor Operações Privadas

  // ══ 19. CAPITALIZAÇÃO (SUSEP Ramos 200-299) ══════════════════════════════
  capPm,               // Capitalização PM (pagamento mensal)
  capPu,               // Capitalização PU (pagamento único)
  capFilantropia,      // Capitalização com filantropia
  capIncentivo,        // Capitalização para incentivo e premiação
  capPoupanca,         // Capitalização poupança (tradicional)
  capMicroCap,         // Microcapitalização < R$30/mês
  capRendaMensal,      // Capitalização com renda mensal garantida
  capComSorteio,       // Cap com sorteio semanal/mensal

  // ══ 20. PREVIDÊNCIA PRIVADA (SUSEP + PREVIC) ════════════════════════════
  pgbl,                // PGBL — Plano Gerador Benefício Livre
  vgbl,                // VGBL — Vida Gerador Benefício Livre
  pgblEmpresarial,     // PGBL empresarial (benefício coletivo)
  vgblJovem,           // VGBL jovem — início precoce
  fundoPensao,         // Fundo de pensão EFPC (PREVIC)
  previdenciaRural,    // Complemento aposentadoria rural
  prevInvalidade,      // Previdência com cobertura invalidez
  riVitalicio,         // Renda imediata vitalícia
  riPrazo,             // Renda imediata por prazo certo
  resgate,             // Previdência com liquidez total

  // ══ 21. BENEFÍCIOS CORPORATIVOS (RH) ═════════════════════════════════════
  valeAlimentacao,     // VA/VR — benefício alimentação
  planoOdontologico,   // Odonto corporativo
  auxEducacao,         // Auxílio educação / bolsa
  auxMobilidade,       // Auxílio transporte / mobilidade
  auxHomeOffice,       // Home office — equipamento + internet
  seguroVidaRh,        // Vida em grupo RH básico
  previdenciaRh,       // Previdência empresarial complementar
  assistenciaMedica,   // Assistência médica corporativa
  telemedicina,        // Telemedicina corporativa
  wellnessEmpresarial, // Wellness + saúde mental corporativo

  // ══ 22. NICHOS ESPECIAIS E EMERGENTES ════════════════════════════════════
  pet,                 // Pet insurance — cão/gato
  petCirurgia,         // Pet — cirurgia eletiva e emergência
  casamento,           // Cancelamento de casamento / evento
  funeraria,           // Assistência funeral + translado
  acidenCondominial,   // AP moradores de condomínio
  esporteProfissional, // Atleta profissional
  artObjetos,          // Obras de arte e objetos de valor
  joias,               // Joias, relógios, metais preciosos
  garrafasVinhos,      // Coleção de vinhos
  criptoativos,        // Custódia de criptomoedas
  nft,                 // NFT e ativos digitais
  microempreendedor,   // MEI — pacote básico completo
  profissionalLib,     // Autônomo liberal — pacote completo
  homecare,            // Assistência domiciliar
  microseguro,         // Microsseguro < R$30/mês (SUSEP)

  // ══ 23. SUSTENTABILIDADE E ESG ═══════════════════════════════════════════
  greenBond,           // Seguro de green bonds
  carbono,             // Crédito de carbono e offset
  energiaRenovavel,    // Parques eólicos e solares
  conservacaoAmbiental,// Reservas + biodiversidade
  transicaoEnergetica, // Infraestrutura de transição energética

  // ══ 24. FINTECH E EMBEDDED FINANCE ═══════════════════════════════════════
  embeddedAuto,        // Seguro auto embutido no checkout
  embeddedViagem,      // Seguro viagem embutido no check-in
  embeddedEcomm,       // Proteção de compra e-commerce
  embeddedCredito,     // Proteção embutida em empréstimos
  baaS,                // Insurance-as-a-Service (B2B API)
  apiGateway,          // Gateway de seguros multi-carrier
}

// ─────────────────────────────────────────────────────────────────────────────
// EXTENSION — LABELS, CATEGORIAS, FLAGS
// ─────────────────────────────────────────────────────────────────────────────

extension InsuranceLineInfo on InsuranceLine {
  String get label {
    switch (this) {
      // SafeRoute
      case InsuranceLine.autoUbi:              return 'UBI Auto (Pay-How-You-Drive)';
      case InsuranceLine.safeShieldColisao:    return 'SafeShield Colisão Paramétrico';
      case InsuranceLine.zonaSeguraTri:        return 'ZonaSafe Territorial (TRI)';
      case InsuranceLine.novaChuvaChuva:       return 'NovaChuva Paramétrico';
      case InsuranceLine.rapidProtectMotoboy:  return 'RapidProtect Motoboy';
      case InsuranceLine.cyberPixShield:       return 'CyberPIX Shield';
      // Automóveis
      case InsuranceLine.autoCompreensivo:     return 'Auto Compreensivo';
      case InsuranceLine.autoPopular:          return 'Auto Popular';
      case InsuranceLine.autoOnDemand:         return 'Auto On-Demand (por hora)';
      case InsuranceLine.autoAssinatura:       return 'Auto por Assinatura';
      case InsuranceLine.autoVip:              return 'Auto VIP Premium';
      case InsuranceLine.autoEmpresarial:      return 'Auto Empresarial';
      case InsuranceLine.frotas:               return 'Seguro de Frotas';
      case InsuranceLine.evEletrico:           return 'Veículo Elétrico (EV)';
      case InsuranceLine.autoAntigo:           return 'Veículo Antigo / Clássico';
      case InsuranceLine.autoLocadora:         return 'Locadora de Veículos';
      case InsuranceLine.autoGarantia:         return 'Auto Garantia Estendida';
      case InsuranceLine.autoConcessionaria:   return 'Concessionária / Consignação';
      // Motos
      case InsuranceLine.motoCompreensivo:     return 'Moto Compreensivo';
      case InsuranceLine.motoApp:              return 'Moto Aplicativo / Motoboy';
      case InsuranceLine.motoPopular:          return 'Moto Popular';
      case InsuranceLine.bicicleta:            return 'Bicicleta / E-bike';
      case InsuranceLine.patineteEletrico:     return 'Patinete Elétrico';
      case InsuranceLine.quadriciclo:          return 'Quadriciclo / ATV';
      // Pesados
      case InsuranceLine.caminhaoRCTRC:        return 'Caminhão RCTRC';
      case InsuranceLine.caminhaoCompreensivo: return 'Caminhão Compreensivo';
      case InsuranceLine.onibus:               return 'Ônibus e Vans';
      case InsuranceLine.maquinasAgricolas:    return 'Máquinas Agrícolas';
      case InsuranceLine.embarcacaoMarinha:    return 'Embarcação Marinha';
      case InsuranceLine.aeronave:             return 'Aeronave Privada';
      case InsuranceLine.helicoptero:          return 'Helicóptero';
      case InsuranceLine.drones:               return 'Drones Comerciais';
      case InsuranceLine.veiculoNautico:       return 'Veículo Náutico';
      // Vida
      case InsuranceLine.vidaTermo:            return 'Vida a Prazo';
      case InsuranceLine.vidaInteira:          return 'Vida Inteira (Whole Life)';
      case InsuranceLine.vidaUniversal:        return 'Vida Universal';
      case InsuranceLine.vidaVariavel:         return 'Vida Variável (VUL)';
      case InsuranceLine.vidaCredito:          return 'Vida Crédito / Prestamista';
      case InsuranceLine.vidaGrupo:            return 'Vida em Grupo (RH)';
      case InsuranceLine.vidaRural:            return 'Vida Rural';
      case InsuranceLine.vidaMilitar:          return 'Vida Militar / Segurança';
      case InsuranceLine.vidaMicro:            return 'Vida Micro (baixa renda)';
      // AP
      case InsuranceLine.apIndividual:         return 'Acidente Pessoal Individual';
      case InsuranceLine.apFamiliar:           return 'AP Familiar';
      case InsuranceLine.apGigWorker:          return 'AP Gig Worker (por hora)';
      case InsuranceLine.apMotoboy:            return 'AP Motoboy';
      case InsuranceLine.apEsportivo:          return 'AP Esportivo / Aventura';
      case InsuranceLine.apViagem:             return 'AP de Viagem';
      case InsuranceLine.apEscolar:            return 'AP Escolar';
      case InsuranceLine.apIdoso:              return 'AP Sênior 60+';
      case InsuranceLine.apCorporativo:        return 'AP Corporativo Grupo';
      case InsuranceLine.apEventos:            return 'AP para Eventos';
      case InsuranceLine.apConstrutores:       return 'AP Construção Civil';
      // Saúde
      case InsuranceLine.saudeIndividual:      return 'Saúde Individual';
      case InsuranceLine.saudeFamiliar:        return 'Saúde Familiar';
      case InsuranceLine.saudeDental:          return 'Odontológico Individual';
      case InsuranceLine.saudeDentalFamiliar:  return 'Odontológico Familiar';
      case InsuranceLine.saudeViagem:          return 'Saúde Internacional';
      case InsuranceLine.saudeCorporativo:     return 'Saúde Corporativo';
      case InsuranceLine.saudePme:             return 'Saúde PME (2-99 vidas)';
      case InsuranceLine.saudeSenior:          return 'Saúde Sênior 60+';
      case InsuranceLine.saudeMicro:           return 'Saúde Micro / Telemedicina';
      case InsuranceLine.hospitalDia:          return 'Diária Hospitalar';
      case InsuranceLine.cirurgiaEletica:      return 'Cirurgia Eletiva';
      case InsuranceLine.saudeMental:          return 'Saúde Mental';
      // Residencial
      case InsuranceLine.residencial:          return 'Residencial Compreensivo';
      case InsuranceLine.residencialBasico:    return 'Residencial Básico';
      case InsuranceLine.residencialAluguel:   return 'Residencial Aluguel';
      case InsuranceLine.aluguelGarantido:     return 'Aluguel Garantido';
      case InsuranceLine.condominial:          return 'Condomínio';
      case InsuranceLine.casaDeVeraneio:       return 'Casa de Veraneio / Temporada';
      case InsuranceLine.imovelVazio:          return 'Imóvel Vazio / Desocupado';
      case InsuranceLine.construcaoCivil:      return 'Construção Civil Residencial';
      // Empresarial
      case InsuranceLine.empresarial:          return 'Empresarial Compreensivo';
      case InsuranceLine.comercial:            return 'Comércio Varejista';
      case InsuranceLine.escritorio:           return 'Escritório / Coworking';
      case InsuranceLine.industria:            return 'Industrial';
      case InsuranceLine.hoteis:               return 'Hotel / Pousada';
      case InsuranceLine.restaurante:          return 'Restaurante / Alimentação';
      case InsuranceLine.clinicaMedica:        return 'Clínica / Consultório';
      case InsuranceLine.farmacia:             return 'Farmácia / Drogaria';
      case InsuranceLine.supermercado:         return 'Supermercado / Varejo';
      case InsuranceLine.postoGasolina:        return 'Posto de Gasolina';
      case InsuranceLine.construcaoComercial:  return 'Construção Comercial';
      case InsuranceLine.condominioCom:        return 'Condomínio Comercial';
      case InsuranceLine.shopping:             return 'Shopping Center';
      case InsuranceLine.dataCenter:           return 'Data Center / TI';
      // Equipamentos
      case InsuranceLine.equipamentosEletronicos: return 'Equipamentos Eletrônicos';
      case InsuranceLine.maquinasIndustriais:  return 'Máquinas Industriais';
      case InsuranceLine.paineisSolares:       return 'Painéis Solares / Fotovoltaico';
      case InsuranceLine.equipamentosRurais:   return 'Equipamentos Rurais';
      case InsuranceLine.equipamentosMedicos:  return 'Equipamentos Médicos';
      case InsuranceLine.instrumentosMusicais: return 'Instrumentos Musicais';
      case InsuranceLine.camerasFotograficas:  return 'Câmeras Fotográficas';
      case InsuranceLine.celular:              return 'Celular (Roubo + Quebra)';
      case InsuranceLine.notebookTablet:       return 'Notebook / Tablet';
      case InsuranceLine.videogame:            return 'Videogame / Console';
      // Engenharia
      case InsuranceLine.riscosEngenharia:     return 'Riscos de Engenharia';
      case InsuranceLine.riscosMontagem:       return 'Riscos de Montagem';
      case InsuranceLine.rcObras:              return 'RC do Construtor';
      case InsuranceLine.colapsoEstrutura:     return 'Colapso de Estruturas';
      case InsuranceLine.termeletrica:         return 'Termoeléctrica / Energia';
      case InsuranceLine.mineiracao:           return 'Mineração e Extração';
      // Cyber
      case InsuranceLine.cyberPessoalPix:      return 'Cyber PIX / Fraude Básico';
      case InsuranceLine.cyberPessoalPleno:    return 'Cyber Pessoal Pleno';
      case InsuranceLine.cyberEmpresarial:     return 'Cyber Empresarial';
      case InsuranceLine.cyberStartup:         return 'Cyber Startup / Fintech';
      case InsuranceLine.identidadeDigital:    return 'Identidade Digital';
      case InsuranceLine.ransomwareProtect:    return 'Ransomware Protection';
      case InsuranceLine.errorOmissao:         return 'E&O Tech (Erro Software)';
      case InsuranceLine.ciberRcProfissional:  return 'RC Profissional Digital';
      // Viagem
      case InsuranceLine.viagemNacional:       return 'Viagem Nacional';
      case InsuranceLine.viagemInternacional:  return 'Viagem Internacional';
      case InsuranceLine.viagemParametrico:    return 'Viagem Paramétrico (atraso)';
      case InsuranceLine.viagemCancelamento:   return 'Cancelamento de Viagem';
      case InsuranceLine.viagemBagagem:        return 'Bagagem Extraviada';
      case InsuranceLine.nomadeDigital:        return 'Nômade Digital';
      case InsuranceLine.cruzeiro:             return 'Cruzeiro Marítimo';
      case InsuranceLine.mochileiro:           return 'Mochileiro / Aventura';
      case InsuranceLine.embarque:             return 'Assistência Embarque';
      case InsuranceLine.expatriado:           return 'Expatriado / Residente Exterior';
      // Rural
      case InsuranceLine.agricola:             return 'Agrícola (Lavoura)';
      case InsuranceLine.pecuario:             return 'Pecuário (Rebanho)';
      case InsuranceLine.parametricoClimatico: return 'Paramétrico Climático';
      case InsuranceLine.catastrofeNatural:    return 'Catástrofe Natural (CAT)';
      case InsuranceLine.florestal:            return 'Florestal / Reflorestamento';
      case InsuranceLine.aquicultura:          return 'Aquicultura / Pesca';
      case InsuranceLine.proagro:              return 'PROAGRO / Garantia Rural';
      case InsuranceLine.fruticultura:         return 'Fruticultura Especial';
      case InsuranceLine.canaDeAcucar:         return 'Cana-de-Açúcar';
      // RC
      case InsuranceLine.rcGeral:              return 'RC Geral Empresarial';
      case InsuranceLine.rcProfissional:       return 'RC Profissional (E&O)';
      case InsuranceLine.rcMedico:             return 'RC Médico (Malpractice)';
      case InsuranceLine.rcAdv:                return 'RC Advogado';
      case InsuranceLine.rcContabilista:       return 'RC Contabilista';
      case InsuranceLine.rcArquiteto:          return 'RC Arquiteto / Engenheiro';
      case InsuranceLine.rcCorretorSeguros:    return 'RC Corretor de Seguros';
      case InsuranceLine.rcCorretorImoveis:    return 'RC Corretor de Imóveis';
      case InsuranceLine.rcTransportador:      return 'RC Transportador';
      case InsuranceLine.rcAmbiental:          return 'RC Ambiental';
      case InsuranceLine.rcEventos:            return 'RC Eventos / Shows';
      case InsuranceLine.rcProdutos:           return 'RC Produtos (Recall)';
      case InsuranceLine.dno:                  return 'D&O Diretores e Executivos';
      case InsuranceLine.dnoStartup:           return 'D&O Startup / Fintech';
      case InsuranceLine.seguroGarantia:       return 'Seguro Garantia (Licitações)';
      case InsuranceLine.seguroGarantiaPriv:   return 'Garantia Privada (Contratos)';
      case InsuranceLine.fiancaLocaticia:      return 'Fiança Locatícia Digital';
      case InsuranceLine.rcFarmaceutico:       return 'RC Farmacêutico';
      // Transporte
      case InsuranceLine.cargoNacional:        return 'Cargo Nacional (Rodoviário)';
      case InsuranceLine.cargoAereo:           return 'Cargo Aéreo';
      case InsuranceLine.cargoMaritimo:        return 'Cargo Marítimo';
      case InsuranceLine.cargoInternacional:   return 'Cargo Internacional';
      case InsuranceLine.transitoAduaneiro:    return 'Trânsito Aduaneiro';
      case InsuranceLine.valoresTransporte:    return 'Valores em Trânsito';
      case InsuranceLine.correioEncomenda:     return 'Correio / E-commerce';
      case InsuranceLine.temperatura:          return 'Carga Controlada (Temp.)';
      // Marítimo / Aviação
      case InsuranceLine.cascoMaritimo:        return 'Casco Marítimo Comercial';
      case InsuranceLine.rcPortuaria:          return 'RC Portuária';
      case InsuranceLine.pi_marinha:           return 'P&I Marine (Armadores)';
      case InsuranceLine.cargasEspeciais:      return 'Cargas Especiais / Perigosas';
      case InsuranceLine.aviaoComercial:       return 'Aviação Comercial (Casco)';
      case InsuranceLine.aviacaoGeral:         return 'Aviação Geral / Executivo';
      case InsuranceLine.rcAereo:              return 'RC Aeronáutico';
      case InsuranceLine.aeroporto:            return 'Responsabilidade Aeroportuária';
      case InsuranceLine.satelite:             return 'Satélite / Mídia Espacial';
      case InsuranceLine.lancamento:           return 'Lançamento Espacial';
      // Crédito
      case InsuranceLine.creditoExportacao:    return 'Crédito Exportação';
      case InsuranceLine.creditoInterno:       return 'Crédito Interno (B2B)';
      case InsuranceLine.creditoImobiliario:   return 'Crédito Imobiliário (SFH)';
      case InsuranceLine.creditoConsignado:    return 'Crédito Consignado';
      case InsuranceLine.creditoRural:         return 'Crédito Rural';
      case InsuranceLine.creditoRotativo:      return 'Cartão de Crédito';
      case InsuranceLine.fgts:                 return 'FGTS / Demissão Involuntária';
      case InsuranceLine.risco_sacado:         return 'Risco Sacado (Supply Chain)';
      case InsuranceLine.fgop:                 return 'FGOP (Garantidor Privado)';
      // Capitalização
      case InsuranceLine.capPm:                return 'Capitalização PM (Mensal)';
      case InsuranceLine.capPu:                return 'Capitalização PU (Único)';
      case InsuranceLine.capFilantropia:       return 'Cap. Filantropia';
      case InsuranceLine.capIncentivo:         return 'Cap. Incentivo / Premiação';
      case InsuranceLine.capPoupanca:          return 'Cap. Poupança Tradicional';
      case InsuranceLine.capMicroCap:          return 'Microcapitalização';
      case InsuranceLine.capRendaMensal:       return 'Cap. Renda Mensal';
      case InsuranceLine.capComSorteio:        return 'Cap. com Sorteio';
      // Previdência
      case InsuranceLine.pgbl:                 return 'PGBL (Dedução IR)';
      case InsuranceLine.vgbl:                 return 'VGBL (Não Dedutível)';
      case InsuranceLine.pgblEmpresarial:      return 'PGBL Empresarial';
      case InsuranceLine.vgblJovem:            return 'VGBL Jovem';
      case InsuranceLine.fundoPensao:          return 'Fundo de Pensão (EFPC)';
      case InsuranceLine.previdenciaRural:     return 'Previdência Rural';
      case InsuranceLine.prevInvalidade:       return 'Previdência + Invalidez';
      case InsuranceLine.riVitalicio:          return 'Renda Imediata Vitalícia';
      case InsuranceLine.riPrazo:              return 'Renda Imediata por Prazo';
      case InsuranceLine.resgate:              return 'Previdência com Liquidez';
      // RH / Benefícios
      case InsuranceLine.valeAlimentacao:      return 'Vale Alimentação / Refeição';
      case InsuranceLine.planoOdontologico:    return 'Odontológico Corporativo';
      case InsuranceLine.auxEducacao:          return 'Auxílio Educação';
      case InsuranceLine.auxMobilidade:        return 'Auxílio Mobilidade';
      case InsuranceLine.auxHomeOffice:        return 'Auxílio Home Office';
      case InsuranceLine.seguroVidaRh:         return 'Vida em Grupo RH';
      case InsuranceLine.previdenciaRh:        return 'Previdência Empresarial';
      case InsuranceLine.assistenciaMedica:    return 'Assistência Médica Corp.';
      case InsuranceLine.telemedicina:         return 'Telemedicina Corporativa';
      case InsuranceLine.wellnessEmpresarial:  return 'Wellness Empresarial';
      // Nichos
      case InsuranceLine.pet:                  return 'Pet Insurance';
      case InsuranceLine.petCirurgia:          return 'Pet Cirurgia / Emergência';
      case InsuranceLine.casamento:            return 'Casamento / Evento';
      case InsuranceLine.funeraria:            return 'Assistência Funeral';
      case InsuranceLine.acidenCondominial:    return 'AP Moradores Condomínio';
      case InsuranceLine.esporteProfissional:  return 'Atleta Profissional';
      case InsuranceLine.artObjetos:           return 'Arte e Objetos de Valor';
      case InsuranceLine.joias:                return 'Joias e Relógios';
      case InsuranceLine.garrafasVinhos:       return 'Coleção de Vinhos';
      case InsuranceLine.criptoativos:         return 'Criptoativos / Custódia';
      case InsuranceLine.nft:                  return 'NFT e Ativos Digitais';
      case InsuranceLine.microempreendedor:    return 'MEI — Pacote Completo';
      case InsuranceLine.profissionalLib:      return 'Profissional Liberal';
      case InsuranceLine.homecare:             return 'Home Care / Cuidados';
      case InsuranceLine.microseguro:          return 'Microsseguro (< R\$30/mês)';
      // ESG
      case InsuranceLine.greenBond:            return 'Green Bond (ESG)';
      case InsuranceLine.carbono:              return 'Crédito de Carbono';
      case InsuranceLine.energiaRenovavel:     return 'Energia Renovável';
      case InsuranceLine.conservacaoAmbiental: return 'Conservação Ambiental';
      case InsuranceLine.transicaoEnergetica:  return 'Transição Energética';
      // Embedded
      case InsuranceLine.embeddedAuto:         return 'Embedded Auto (Checkout)';
      case InsuranceLine.embeddedViagem:       return 'Embedded Viagem';
      case InsuranceLine.embeddedEcomm:        return 'Embedded E-commerce';
      case InsuranceLine.embeddedCredito:      return 'Embedded Crédito';
      case InsuranceLine.baaS:                 return 'BaaS — Insurance as a Service';
      case InsuranceLine.apiGateway:           return 'API Gateway Multi-Carrier';
    }
  }

  String get category {
    switch (this) {
      case InsuranceLine.autoUbi:
      case InsuranceLine.safeShieldColisao:
      case InsuranceLine.zonaSeguraTri:
      case InsuranceLine.novaChuvaChuva:
      case InsuranceLine.rapidProtectMotoboy:
      case InsuranceLine.cyberPixShield:           return 'SafeRoute Exclusivo';
      case InsuranceLine.autoCompreensivo:
      case InsuranceLine.autoPopular:
      case InsuranceLine.autoOnDemand:
      case InsuranceLine.autoAssinatura:
      case InsuranceLine.autoVip:
      case InsuranceLine.autoEmpresarial:
      case InsuranceLine.frotas:
      case InsuranceLine.evEletrico:
      case InsuranceLine.autoAntigo:
      case InsuranceLine.autoLocadora:
      case InsuranceLine.autoGarantia:
      case InsuranceLine.autoConcessionaria:       return 'Automóveis';
      case InsuranceLine.motoCompreensivo:
      case InsuranceLine.motoApp:
      case InsuranceLine.motoPopular:
      case InsuranceLine.bicicleta:
      case InsuranceLine.patineteEletrico:
      case InsuranceLine.quadriciclo:               return 'Motos e Micromobilidade';
      case InsuranceLine.caminhaoRCTRC:
      case InsuranceLine.caminhaoCompreensivo:
      case InsuranceLine.onibus:
      case InsuranceLine.maquinasAgricolas:
      case InsuranceLine.embarcacaoMarinha:
      case InsuranceLine.aeronave:
      case InsuranceLine.helicoptero:
      case InsuranceLine.drones:
      case InsuranceLine.veiculoNautico:            return 'Veículos Pesados e Especiais';
      case InsuranceLine.vidaTermo:
      case InsuranceLine.vidaInteira:
      case InsuranceLine.vidaUniversal:
      case InsuranceLine.vidaVariavel:
      case InsuranceLine.vidaCredito:
      case InsuranceLine.vidaGrupo:
      case InsuranceLine.vidaRural:
      case InsuranceLine.vidaMilitar:
      case InsuranceLine.vidaMicro:                 return 'Vida';
      case InsuranceLine.apIndividual:
      case InsuranceLine.apFamiliar:
      case InsuranceLine.apGigWorker:
      case InsuranceLine.apMotoboy:
      case InsuranceLine.apEsportivo:
      case InsuranceLine.apViagem:
      case InsuranceLine.apEscolar:
      case InsuranceLine.apIdoso:
      case InsuranceLine.apCorporativo:
      case InsuranceLine.apEventos:
      case InsuranceLine.apConstrutores:            return 'Acidente Pessoal';
      case InsuranceLine.saudeIndividual:
      case InsuranceLine.saudeFamiliar:
      case InsuranceLine.saudeDental:
      case InsuranceLine.saudeDentalFamiliar:
      case InsuranceLine.saudeViagem:
      case InsuranceLine.saudeCorporativo:
      case InsuranceLine.saudePme:
      case InsuranceLine.saudeSenior:
      case InsuranceLine.saudeMicro:
      case InsuranceLine.hospitalDia:
      case InsuranceLine.cirurgiaEletica:
      case InsuranceLine.saudeMental:               return 'Saúde';
      case InsuranceLine.residencial:
      case InsuranceLine.residencialBasico:
      case InsuranceLine.residencialAluguel:
      case InsuranceLine.aluguelGarantido:
      case InsuranceLine.condominial:
      case InsuranceLine.casaDeVeraneio:
      case InsuranceLine.imovelVazio:
      case InsuranceLine.construcaoCivil:           return 'Residencial';
      case InsuranceLine.empresarial:
      case InsuranceLine.comercial:
      case InsuranceLine.escritorio:
      case InsuranceLine.industria:
      case InsuranceLine.hoteis:
      case InsuranceLine.restaurante:
      case InsuranceLine.clinicaMedica:
      case InsuranceLine.farmacia:
      case InsuranceLine.supermercado:
      case InsuranceLine.postoGasolina:
      case InsuranceLine.construcaoComercial:
      case InsuranceLine.condominioCom:
      case InsuranceLine.shopping:
      case InsuranceLine.dataCenter:               return 'Empresarial';
      case InsuranceLine.equipamentosEletronicos:
      case InsuranceLine.maquinasIndustriais:
      case InsuranceLine.paineisSolares:
      case InsuranceLine.equipamentosRurais:
      case InsuranceLine.equipamentosMedicos:
      case InsuranceLine.instrumentosMusicais:
      case InsuranceLine.camerasFotograficas:
      case InsuranceLine.celular:
      case InsuranceLine.notebookTablet:
      case InsuranceLine.videogame:                return 'Equipamentos e Tecnologia';
      case InsuranceLine.riscosEngenharia:
      case InsuranceLine.riscosMontagem:
      case InsuranceLine.rcObras:
      case InsuranceLine.colapsoEstrutura:
      case InsuranceLine.termeletrica:
      case InsuranceLine.mineiracao:               return 'Riscos de Engenharia';
      case InsuranceLine.cyberPessoalPix:
      case InsuranceLine.cyberPessoalPleno:
      case InsuranceLine.cyberEmpresarial:
      case InsuranceLine.cyberStartup:
      case InsuranceLine.identidadeDigital:
      case InsuranceLine.ransomwareProtect:
      case InsuranceLine.errorOmissao:
      case InsuranceLine.ciberRcProfissional:      return 'Cyber e Digital';
      case InsuranceLine.viagemNacional:
      case InsuranceLine.viagemInternacional:
      case InsuranceLine.viagemParametrico:
      case InsuranceLine.viagemCancelamento:
      case InsuranceLine.viagemBagagem:
      case InsuranceLine.nomadeDigital:
      case InsuranceLine.cruzeiro:
      case InsuranceLine.mochileiro:
      case InsuranceLine.embarque:
      case InsuranceLine.expatriado:               return 'Viagem';
      case InsuranceLine.agricola:
      case InsuranceLine.pecuario:
      case InsuranceLine.parametricoClimatico:
      case InsuranceLine.catastrofeNatural:
      case InsuranceLine.florestal:
      case InsuranceLine.aquicultura:
      case InsuranceLine.proagro:
      case InsuranceLine.fruticultura:
      case InsuranceLine.canaDeAcucar:             return 'Rural e Agro';
      case InsuranceLine.rcGeral:
      case InsuranceLine.rcProfissional:
      case InsuranceLine.rcMedico:
      case InsuranceLine.rcAdv:
      case InsuranceLine.rcContabilista:
      case InsuranceLine.rcArquiteto:
      case InsuranceLine.rcCorretorSeguros:
      case InsuranceLine.rcCorretorImoveis:
      case InsuranceLine.rcTransportador:
      case InsuranceLine.rcAmbiental:
      case InsuranceLine.rcEventos:
      case InsuranceLine.rcProdutos:
      case InsuranceLine.dno:
      case InsuranceLine.dnoStartup:
      case InsuranceLine.seguroGarantia:
      case InsuranceLine.seguroGarantiaPriv:
      case InsuranceLine.fiancaLocaticia:
      case InsuranceLine.rcFarmaceutico:           return 'Responsabilidade Civil';
      case InsuranceLine.cargoNacional:
      case InsuranceLine.cargoAereo:
      case InsuranceLine.cargoMaritimo:
      case InsuranceLine.cargoInternacional:
      case InsuranceLine.transitoAduaneiro:
      case InsuranceLine.valoresTransporte:
      case InsuranceLine.correioEncomenda:
      case InsuranceLine.temperatura:              return 'Transporte e Carga';
      case InsuranceLine.cascoMaritimo:
      case InsuranceLine.rcPortuaria:
      case InsuranceLine.pi_marinha:
      case InsuranceLine.cargasEspeciais:
      case InsuranceLine.aviaoComercial:
      case InsuranceLine.aviacaoGeral:
      case InsuranceLine.rcAereo:
      case InsuranceLine.aeroporto:
      case InsuranceLine.satelite:
      case InsuranceLine.lancamento:              return 'Marítimo e Aviação';
      case InsuranceLine.creditoExportacao:
      case InsuranceLine.creditoInterno:
      case InsuranceLine.creditoImobiliario:
      case InsuranceLine.creditoConsignado:
      case InsuranceLine.creditoRural:
      case InsuranceLine.creditoRotativo:
      case InsuranceLine.fgts:
      case InsuranceLine.risco_sacado:
      case InsuranceLine.fgop:                    return 'Crédito e Garantias';
      case InsuranceLine.capPm:
      case InsuranceLine.capPu:
      case InsuranceLine.capFilantropia:
      case InsuranceLine.capIncentivo:
      case InsuranceLine.capPoupanca:
      case InsuranceLine.capMicroCap:
      case InsuranceLine.capRendaMensal:
      case InsuranceLine.capComSorteio:           return 'Capitalização';
      case InsuranceLine.pgbl:
      case InsuranceLine.vgbl:
      case InsuranceLine.pgblEmpresarial:
      case InsuranceLine.vgblJovem:
      case InsuranceLine.fundoPensao:
      case InsuranceLine.previdenciaRural:
      case InsuranceLine.prevInvalidade:
      case InsuranceLine.riVitalicio:
      case InsuranceLine.riPrazo:
      case InsuranceLine.resgate:                 return 'Previdência Privada';
      case InsuranceLine.valeAlimentacao:
      case InsuranceLine.planoOdontologico:
      case InsuranceLine.auxEducacao:
      case InsuranceLine.auxMobilidade:
      case InsuranceLine.auxHomeOffice:
      case InsuranceLine.seguroVidaRh:
      case InsuranceLine.previdenciaRh:
      case InsuranceLine.assistenciaMedica:
      case InsuranceLine.telemedicina:
      case InsuranceLine.wellnessEmpresarial:     return 'Benefícios Corporativos';
      case InsuranceLine.pet:
      case InsuranceLine.petCirurgia:
      case InsuranceLine.casamento:
      case InsuranceLine.funeraria:
      case InsuranceLine.acidenCondominial:
      case InsuranceLine.esporteProfissional:
      case InsuranceLine.artObjetos:
      case InsuranceLine.joias:
      case InsuranceLine.garrafasVinhos:
      case InsuranceLine.criptoativos:
      case InsuranceLine.nft:
      case InsuranceLine.microempreendedor:
      case InsuranceLine.profissionalLib:
      case InsuranceLine.homecare:
      case InsuranceLine.microseguro:             return 'Nichos Especiais';
      case InsuranceLine.greenBond:
      case InsuranceLine.carbono:
      case InsuranceLine.energiaRenovavel:
      case InsuranceLine.conservacaoAmbiental:
      case InsuranceLine.transicaoEnergetica:     return 'ESG e Sustentabilidade';
      case InsuranceLine.embeddedAuto:
      case InsuranceLine.embeddedViagem:
      case InsuranceLine.embeddedEcomm:
      case InsuranceLine.embeddedCredito:
      case InsuranceLine.baaS:
      case InsuranceLine.apiGateway:              return 'Embedded Finance e BaaS';
    }
  }

  bool get isParametric => [
    InsuranceLine.safeShieldColisao,
    InsuranceLine.zonaSeguraTri,
    InsuranceLine.novaChuvaChuva,
    InsuranceLine.rapidProtectMotoboy,
    InsuranceLine.cyberPixShield,
    InsuranceLine.viagemParametrico,
    InsuranceLine.parametricoClimatico,
    InsuranceLine.autoUbi,
  ].contains(this);

  bool get isExclusiveSafeRoute => [
    InsuranceLine.autoUbi,
    InsuranceLine.safeShieldColisao,
    InsuranceLine.zonaSeguraTri,
    InsuranceLine.novaChuvaChuva,
    InsuranceLine.rapidProtectMotoboy,
    InsuranceLine.cyberPixShield,
  ].contains(this);

  String get susepRamo {
    switch (this) {
      case InsuranceLine.autoCompreensivo:
      case InsuranceLine.autoPopular:
      case InsuranceLine.autoUbi:        return '062';
      case InsuranceLine.frotas:         return '062';
      case InsuranceLine.caminhaoRCTRC:  return '099';
      case InsuranceLine.vidaTermo:
      case InsuranceLine.vidaInteira:    return '021';
      case InsuranceLine.vidaCredito:    return '029';
      case InsuranceLine.apIndividual:   return '061';
      case InsuranceLine.residencial:    return '068';
      case InsuranceLine.empresarial:    return '068';
      case InsuranceLine.rcGeral:        return '042';
      case InsuranceLine.rcProfissional: return '040';
      case InsuranceLine.dno:            return '048';
      case InsuranceLine.seguroGarantia: return '0775';
      case InsuranceLine.cargoNacional:  return '090';
      case InsuranceLine.cargoMaritimo:  return '091';
      case InsuranceLine.agricola:       return '082';
      case InsuranceLine.pecuario:       return '083';
      case InsuranceLine.pgbl:           return 'PGBL';
      case InsuranceLine.vgbl:           return 'VGBL';
      case InsuranceLine.capPm:
      case InsuranceLine.capPu:          return 'CAP';
      default:                           return '—';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

enum PolicyStatus { cotacao, ativa, suspensa, cancelada, expirada, sinistro }
extension PolicyStatusInfo on PolicyStatus {
  String get label {
    switch (this) {
      case PolicyStatus.cotacao:   return 'Cotação';
      case PolicyStatus.ativa:     return 'Ativa';
      case PolicyStatus.suspensa:  return 'Suspensa';
      case PolicyStatus.cancelada: return 'Cancelada';
      case PolicyStatus.expirada:  return 'Expirada';
      case PolicyStatus.sinistro:  return 'Em Sinistro';
    }
  }
}

enum ClaimStatus { aberto, emAnalise, aprovado, pago, negado, cancelado }
extension ClaimStatusInfo on ClaimStatus {
  String get label {
    switch (this) {
      case ClaimStatus.aberto:    return 'Aberto';
      case ClaimStatus.emAnalise: return 'Em Análise';
      case ClaimStatus.aprovado:  return 'Aprovado';
      case ClaimStatus.pago:      return 'Pago';
      case ClaimStatus.negado:    return 'Negado';
      case ClaimStatus.cancelado: return 'Cancelado';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS
// ─────────────────────────────────────────────────────────────────────────────

class InsuranceProduct {
  final String id;
  final InsuranceLine line;
  final String nome;
  final String descricao;
  final double premioMinimoMensal;
  final double premioMaximoMensal;
  final double capitalMinimoSegurado;
  final double capitalMaximoSegurado;
  final List<String> coberturas;
  final List<String> exclusoes;
  final bool ativo;
  final bool isParametric;
  final String? triggerDescricao;
  final double? pagamentoParametrico;
  final List<String> publicoAlvo;
  final int prioridadeRanking;
  final String? susepRamo;
  final String? moeda;

  const InsuranceProduct({
    required this.id,
    required this.line,
    required this.nome,
    required this.descricao,
    required this.premioMinimoMensal,
    required this.premioMaximoMensal,
    required this.capitalMinimoSegurado,
    required this.capitalMaximoSegurado,
    this.coberturas = const [],
    this.exclusoes = const [],
    this.ativo = true,
    this.isParametric = false,
    this.triggerDescricao,
    this.pagamentoParametrico,
    this.publicoAlvo = const [],
    this.prioridadeRanking = 50,
    this.susepRamo,
    this.moeda = 'BRL',
  });
}

class InsuranceQuote {
  final String id;
  final String userId;
  final InsuranceLine line;
  final InsuranceProduct product;
  final double premioMensal;
  final double premioAnual;
  final double capitalSegurado;
  final double fatorRisco;
  final double fatorTerritorial;
  final double fatorUbi;
  final double fatorIdade;
  final List<String> coberturasSelecionadas;
  final List<String> motivosRecomendacao;
  final double scoreRelevancia;
  final DateTime geradaEm;
  final DateTime validaAte;

  InsuranceQuote({
    required this.id,
    required this.userId,
    required this.line,
    required this.product,
    required this.premioMensal,
    required this.premioAnual,
    required this.capitalSegurado,
    required this.fatorRisco,
    required this.fatorTerritorial,
    required this.fatorUbi,
    required this.fatorIdade,
    required this.coberturasSelecionadas,
    required this.motivosRecomendacao,
    required this.scoreRelevancia,
    required this.geradaEm,
    required this.validaAte,
  });
}

class InsurancePolicy {
  final String id;
  final String numeroApolice;
  final String userId;
  final String nomeUsuario;
  final InsuranceLine line;
  final InsuranceProduct product;
  final double premioMensal;
  final double capitalSegurado;
  final List<String> coberturas;
  PolicyStatus status;
  final DateTime inicioVigencia;
  final DateTime fimVigencia;
  final DateTime emitidaEm;
  int totalSinistros;
  double totalPago;

  InsurancePolicy({
    required this.id,
    required this.numeroApolice,
    required this.userId,
    required this.nomeUsuario,
    required this.line,
    required this.product,
    required this.premioMensal,
    required this.capitalSegurado,
    required this.coberturas,
    required this.status,
    required this.inicioVigencia,
    required this.fimVigencia,
    required this.emitidaEm,
    this.totalSinistros = 0,
    this.totalPago = 0,
  });
}

class InsuranceClaim {
  final String id;
  final String numeroComunicado;
  final String policyId;
  final String numeroApolice;
  final String userId;
  final String nomeUsuario;
  final InsuranceLine line;
  final String descricaoEvento;
  final double valorReclamado;
  double? valorAprovado;
  ClaimStatus status;
  final DateTime aberturaEm;
  DateTime? liquidacaoEm;
  final bool isParametric;
  final String? triggerEvidencia;
  final String? observacoesAnalise;

  InsuranceClaim({
    required this.id,
    required this.numeroComunicado,
    required this.policyId,
    required this.numeroApolice,
    required this.userId,
    required this.nomeUsuario,
    required this.line,
    required this.descricaoEvento,
    required this.valorReclamado,
    this.valorAprovado,
    required this.status,
    required this.aberturaEm,
    this.liquidacaoEm,
    this.isParametric = false,
    this.triggerEvidencia,
    this.observacoesAnalise,
  });
}

class NeedsDetectorResult {
  final InsuranceLine line;
  final InsuranceProduct product;
  final double scoreRelevancia;
  final List<String> motivos;
  final String prioridade;

  NeedsDetectorResult({
    required this.line,
    required this.product,
    required this.scoreRelevancia,
    required this.motivos,
    required this.prioridade,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CATÁLOGO DE PRODUTOS (150+ ramos, 60+ produtos seeded)
// ─────────────────────────────────────────────────────────────────────────────

class ProductCatalog {
  static final List<InsuranceProduct> _products = [

    // ══ SAFEROUTE EXCLUSIVOS ══════════════════════════════════════════════
    InsuranceProduct(
      id: 'SR-UBI-001', line: InsuranceLine.autoUbi,
      nome: 'SafeRoute UBI Auto',
      descricao: 'Prêmio 100% baseado no comportamento real de direção. Telemetria GPS + acelerômetro. Melhor motorista = menor prêmio.',
      premioMinimoMensal: 45.0, premioMaximoMensal: 280.0,
      capitalMinimoSegurado: 20000, capitalMaximoSegurado: 200000,
      coberturas: ['Casco Compreensivo', 'RC Facultativa', 'AP Passageiros', 'Assistência 24h', 'Vidros', 'Guincho'],
      publicoAlvo: ['Motoristas frequentes', 'Bons motoristas', 'App de transporte'],
      prioridadeRanking: 100, susepRamo: '062', isParametric: true,
      triggerDescricao: 'Score UBI calculado mensalmente pelo comportamento de direção',
    ),
    InsuranceProduct(
      id: 'SR-SHIELD-001', line: InsuranceLine.safeShieldColisao,
      nome: 'SafeShield Colisão',
      descricao: 'Pagamento automático em 2h após colisão detectada por GPS (-4G). Zero burocracia, zero perícia.',
      premioMinimoMensal: 3.90, premioMaximoMensal: 12.90,
      capitalMinimoSegurado: 500, capitalMaximoSegurado: 5000,
      coberturas: ['Colisão GPS (-4G)', 'Liquidação automática 2h', 'Assistência imediata', 'Sem perícia'],
      isParametric: true,
      triggerDescricao: 'Desaceleração > 4G em < 0,5s detectada pelo GPS',
      pagamentoParametrico: 1500,
      publicoAlvo: ['Todos usuários SafeRoute'],
      prioridadeRanking: 98, susepRamo: '062',
    ),
    InsuranceProduct(
      id: 'SR-ZONA-001', line: InsuranceLine.zonaSeguraTri,
      nome: 'ZonaSafe Territorial',
      descricao: 'Ativa automaticamente cobertura extra de AP em +R\$10.000 quando você entra em zona TRI crítica (score > 800).',
      premioMinimoMensal: 7.90, premioMaximoMensal: 14.90,
      capitalMinimoSegurado: 10000, capitalMaximoSegurado: 30000,
      coberturas: ['AP extra zona crítica', 'Morte acidental territorial', 'Invalidez em zona crítica', 'Evacuação assistida'],
      isParametric: true,
      triggerDescricao: 'Score TRI > 800 na localização atual',
      pagamentoParametrico: 10000,
      publicoAlvo: ['Motoristas de app', 'Entregadores', 'Profissionais em zonas críticas'],
      prioridadeRanking: 92, susepRamo: '061',
    ),
    InsuranceProduct(
      id: 'SR-CHUVA-001', line: InsuranceLine.novaChuvaChuva,
      nome: 'NovaChuva Paramétrico',
      descricao: 'Paga automaticamente quando precipitação INMET excede 50mm/h na sua rota GPS. Sem ajustador, sem vistoria.',
      premioMinimoMensal: 4.90, premioMaximoMensal: 9.90,
      capitalMinimoSegurado: 200, capitalMaximoSegurado: 1000,
      coberturas: ['Precipitação > 50mm/h', 'Danos alagamento', 'Assistência no local', 'Translado emergência'],
      isParametric: true,
      triggerDescricao: 'INMET: precipitação > 50mm/h na localização GPS',
      pagamentoParametrico: 300,
      publicoAlvo: ['Motoristas', 'Entregadores', 'Motoboys'],
      prioridadeRanking: 85, susepRamo: '082',
    ),
    InsuranceProduct(
      id: 'SR-RAPID-001', line: InsuranceLine.rapidProtectMotoboy,
      nome: 'RapidProtect Motoboy',
      descricao: 'AP por hora ativado automaticamente quando app de delivery está aberto. R\$0,40/hora de proteção.',
      premioMinimoMensal: 0, premioMaximoMensal: 0,
      capitalMinimoSegurado: 10000, capitalMaximoSegurado: 50000,
      coberturas: ['AP por hora', 'RC por hora', 'Invalidez permanente', 'Morte acidental', 'Fratura óssea'],
      isParametric: true,
      triggerDescricao: 'App de delivery ativo + GPS em movimento',
      pagamentoParametrico: 0.40,
      publicoAlvo: ['Motoboys', 'Entregadores iFood/Rappi/Loggi'],
      prioridadeRanking: 95, susepRamo: '061',
    ),
    InsuranceProduct(
      id: 'SR-CYBER-PIX-001', line: InsuranceLine.cyberPixShield,
      nome: 'CyberPIX Shield',
      descricao: 'Proteção contra golpe do PIX correlacionada com risco territorial TRI em tempo real. Cobertura extra em zonas críticas.',
      premioMinimoMensal: 9.90, premioMaximoMensal: 19.90,
      capitalMinimoSegurado: 1000, capitalMaximoSegurado: 5000,
      coberturas: ['Golpe PIX', 'Transferência não autorizada', 'Phishing bancário', 'Clonagem cartão', 'Cobertura extra TRI'],
      publicoAlvo: ['Todos usuários', 'Zonas alto risco TRI'],
      prioridadeRanking: 90, susepRamo: '040',
    ),

    // ══ AUTOMÓVEIS ════════════════════════════════════════════════════════
    InsuranceProduct(
      id: 'AUTO-COMP-001', line: InsuranceLine.autoCompreensivo,
      nome: 'Auto Compreensivo',
      descricao: 'Cobertura completa: casco, RC, AP passageiros e assistência 24h. O mais vendido do Brasil.',
      premioMinimoMensal: 120.0, premioMaximoMensal: 800.0,
      capitalMinimoSegurado: 15000, capitalMaximoSegurado: 500000,
      coberturas: ['Colisão e Capotamento', 'Incêndio e Explosão', 'Roubo e Furto Total', 'Fenômenos Naturais', 'RC Facultativa', 'APP', 'Vidros', 'Assistência 24h'],
      exclusoes: ['Dano intencional', 'Uso em competição', 'Álcool e drogas'],
      publicoAlvo: ['Proprietários veículos 0-15 anos'],
      prioridadeRanking: 88, susepRamo: '062',
    ),
    InsuranceProduct(
      id: 'AUTO-POP-001', line: InsuranceLine.autoPopular,
      nome: 'Auto Popular',
      descricao: 'RC facultativa + assistência básica. Solução acessível para veículos de menor valor ou uso esporádico.',
      premioMinimoMensal: 35.0, premioMaximoMensal: 150.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['RC Facultativa até R\$100k', 'Assistência 24h', 'Guincho 200km', 'Carro reserva 3 dias'],
      publicoAlvo: ['Veículos antigos', 'Baixa renda', 'Uso esporádico'],
      prioridadeRanking: 60, susepRamo: '062',
    ),
    InsuranceProduct(
      id: 'AUTO-OD-001', line: InsuranceLine.autoOnDemand,
      nome: 'Auto On-Demand (por hora)',
      descricao: 'Ative o seguro apenas quando precisar. Modelo Cuvva/Metromile — pague por hora, sem mensalidade.',
      premioMinimoMensal: 0, premioMaximoMensal: 0,
      capitalMinimoSegurado: 20000, capitalMaximoSegurado: 150000,
      coberturas: ['Colisão ativada', 'RC ativada', 'Roubo ativado', 'Assistência incluída'],
      isParametric: true, triggerDescricao: 'Ativação manual pelo app',
      publicoAlvo: ['Uso eventual', 'Jovens', 'Veículos compartilhados'],
      prioridadeRanking: 75, susepRamo: '062',
    ),
    InsuranceProduct(
      id: 'AUTO-VIP-001', line: InsuranceLine.autoVip,
      nome: 'Auto VIP Premium',
      descricao: 'Para veículos acima de R\$200k. Cobertura global, carro substituto premium, concierge 24h.',
      premioMinimoMensal: 800.0, premioMaximoMensal: 5000.0,
      capitalMinimoSegurado: 200000, capitalMaximoSegurado: 3000000,
      coberturas: ['Cobertura global', 'Carro substituto premium', 'Concierge 24h', 'Casco total', 'RC ilimitada', 'APP executivo'],
      publicoAlvo: ['Veículos de luxo', 'Executivos', 'Colecionadores'],
      prioridadeRanking: 70, susepRamo: '062',
    ),
    InsuranceProduct(
      id: 'EV-001', line: InsuranceLine.evEletrico,
      nome: 'Seguro EV Elétrico',
      descricao: 'Cobertura especializada para elétricos: bateria inclusa, danos carregamento, assistência técnica EV.',
      premioMinimoMensal: 200.0, premioMaximoMensal: 1200.0,
      capitalMinimoSegurado: 80000, capitalMaximoSegurado: 600000,
      coberturas: ['Casco compreensivo', 'Bateria inclusa', 'Danos carregamento', 'RC EV', 'Assistência técnica EV', 'Guincho especial'],
      publicoAlvo: ['Proprietários EV', 'Frotas elétricas'],
      prioridadeRanking: 72, susepRamo: '062',
    ),
    InsuranceProduct(
      id: 'FROTA-001', line: InsuranceLine.frotas,
      nome: 'Seguro de Frotas Empresarial',
      descricao: 'Apólice coletiva para 3+ veículos. Gestão centralizada, desconto por frota, vistoria digital.',
      premioMinimoMensal: 350.0, premioMaximoMensal: 8000.0,
      capitalMinimoSegurado: 50000, capitalMaximoSegurado: 5000000,
      coberturas: ['Casco compreensivo todos veículos', 'RC coletiva', 'APP motoristas', 'Rastreamento GPS', 'Gestão sinistros centralizada'],
      publicoAlvo: ['Empresas com frota', 'Locadoras', 'Transportadoras'],
      prioridadeRanking: 78, susepRamo: '062',
    ),

    // ══ MOTOS ════════════════════════════════════════════════════════════
    InsuranceProduct(
      id: 'MOTO-APP-001', line: InsuranceLine.motoApp,
      nome: 'Moto Aplicativo',
      descricao: 'Especializado para motoboys e entregadores. Inclui uso profissional, cobertura de carga e AP condutor.',
      premioMinimoMensal: 80.0, premioMaximoMensal: 350.0,
      capitalMinimoSegurado: 5000, capitalMaximoSegurado: 60000,
      coberturas: ['Casco Colisão', 'Roubo e Furto', 'RC Terceiros R\$50k', 'AP Condutor R\$50k', 'Uso profissional incluso', 'Assistência 24h'],
      publicoAlvo: ['Motoboys iFood', 'Rappi', 'Loggi', '99Moto'],
      prioridadeRanking: 90, susepRamo: '062',
    ),
    InsuranceProduct(
      id: 'BICI-001', line: InsuranceLine.bicicleta,
      nome: 'Seguro Bicicleta / E-bike',
      descricao: 'Roubo, furto, danos acidentais e RC para ciclistas. Inclui e-bikes e bicicletas de alto valor.',
      premioMinimoMensal: 15.0, premioMaximoMensal: 80.0,
      capitalMinimoSegurado: 1000, capitalMaximoSegurado: 30000,
      coberturas: ['Roubo e Furto', 'Danos Acidentais', 'RC Ciclista', 'Assistência mecânica', 'AP condutor'],
      publicoAlvo: ['Ciclistas urbanos', 'E-bikers', 'Entregadores de bicicleta'],
      prioridadeRanking: 65, susepRamo: '062',
    ),

    // ══ VEÍCULOS PESADOS ══════════════════════════════════════════════════
    InsuranceProduct(
      id: 'CAMINHAO-001', line: InsuranceLine.caminhaoRCTRC,
      nome: 'RCTRC Caminhão',
      descricao: 'Responsabilidade Civil do Transportador Rodoviário de Carga. Obrigatório para transporte nacional.',
      premioMinimoMensal: 300.0, premioMaximoMensal: 2000.0,
      capitalMinimoSegurado: 50000, capitalMaximoSegurado: 1000000,
      coberturas: ['RCTRC', 'Desvio de carga', 'Acidente terceiros', 'Avaria em carga'],
      publicoAlvo: ['Transportadores', 'Frotistas', 'Autônomos caminhoneiros'],
      prioridadeRanking: 70, susepRamo: '099',
    ),
    InsuranceProduct(
      id: 'DRONE-001', line: InsuranceLine.drones,
      nome: 'Seguro Drone Comercial',
      descricao: 'RC drones ANAC + danos ao equipamento. Exigido para operação comercial. Cobertura por voo ou anual.',
      premioMinimoMensal: 25.0, premioMaximoMensal: 200.0,
      capitalMinimoSegurado: 3000, capitalMaximoSegurado: 100000,
      coberturas: ['RC operação', 'Danos ao drone', 'Danos a terceiros', 'Falha de sistema', 'Cobertura ANAC'],
      publicoAlvo: ['Fotógrafos', 'Produtoras', 'Agronegócio', 'Inspeção industrial'],
      prioridadeRanking: 60, susepRamo: '042',
    ),

    // ══ VIDA ══════════════════════════════════════════════════════════════
    InsuranceProduct(
      id: 'VIDA-TERMO-001', line: InsuranceLine.vidaTermo,
      nome: 'Vida a Prazo',
      descricao: 'Proteção financeira pela família pelo prazo escolhido. Prêmio baixo, capital alto. O mais racional do mercado.',
      premioMinimoMensal: 25.0, premioMaximoMensal: 400.0,
      capitalMinimoSegurado: 50000, capitalMaximoSegurado: 2000000,
      coberturas: ['Morte qualquer causa', 'Morte Acidental (dobro)', 'DIT Invalidez Total', 'Doenças Graves (opcional)'],
      publicoAlvo: ['Adultos 25-60 anos', 'Chefes de família', 'Devedores financiados'],
      prioridadeRanking: 82, susepRamo: '021',
    ),
    InsuranceProduct(
      id: 'VIDA-INTEIRA-001', line: InsuranceLine.vidaInteira,
      nome: 'Vida Inteira (Whole Life)',
      descricao: 'Cobertura vitalícia com acumulação de valor de resgate. Patrimônio + proteção em uma solução.',
      premioMinimoMensal: 150.0, premioMaximoMensal: 2000.0,
      capitalMinimoSegurado: 100000, capitalMaximoSegurado: 5000000,
      coberturas: ['Morte vitalícia', 'Valor de resgate acumulado', 'Empréstimo sobre resgate', 'Doença grave opcional'],
      publicoAlvo: ['Planejamento patrimonial', 'Alta renda', 'Sucessão familiar'],
      prioridadeRanking: 68, susepRamo: '021',
    ),
    InsuranceProduct(
      id: 'VIDA-CREDITO-001', line: InsuranceLine.vidaCredito,
      nome: 'Vida Crédito / Prestamista',
      descricao: 'Quita automaticamente o saldo devedor em caso de morte ou invalidez. Proteção para financiamentos.',
      premioMinimoMensal: 8.0, premioMaximoMensal: 80.0,
      capitalMinimoSegurado: 5000, capitalMaximoSegurado: 500000,
      coberturas: ['Morte — quitação total', 'Invalidez total — quitação', 'Desemprego involuntário (opcional)', 'DIT parcial'],
      publicoAlvo: ['Mutuários SFH', 'Financiamentos auto', 'Crédito pessoal', 'Consignado'],
      prioridadeRanking: 74, susepRamo: '029',
    ),
    InsuranceProduct(
      id: 'VIDA-MICRO-001', line: InsuranceLine.vidaMicro,
      nome: 'Vida Micro (baixa renda)',
      descricao: 'Proteção básica de vida a partir de R\$8/mês. Para quem nunca teve seguro. Distribuição via correspondente.',
      premioMinimoMensal: 8.0, premioMaximoMensal: 30.0,
      capitalMinimoSegurado: 5000, capitalMaximoSegurado: 50000,
      coberturas: ['Morte por qualquer causa', 'Assistência funeral', 'Invalidez total'],
      publicoAlvo: ['Baixa renda', 'Trabalhadores informais', 'MEI'],
      prioridadeRanking: 65, susepRamo: '021',
    ),

    // ══ ACIDENTE PESSOAL ══════════════════════════════════════════════════
    InsuranceProduct(
      id: 'AP-IND-001', line: InsuranceLine.apIndividual,
      nome: 'Acidente Pessoal Individual',
      descricao: 'Proteção 24h para qualquer acidente. Morte, invalidez, diária hospitalar e despesas médicas.',
      premioMinimoMensal: 12.0, premioMaximoMensal: 80.0,
      capitalMinimoSegurado: 20000, capitalMaximoSegurado: 200000,
      coberturas: ['Morte acidental', 'Invalidez Permanente Total/Parcial', 'Diária Hospitalar', 'Despesas Médicas', 'Fratura óssea'],
      publicoAlvo: ['Adultos 18-70 anos', 'Trabalhadores', 'Esportistas'],
      prioridadeRanking: 78, susepRamo: '061',
    ),
    InsuranceProduct(
      id: 'AP-GIG-001', line: InsuranceLine.apGigWorker,
      nome: 'AP Gig Worker (por hora)',
      descricao: 'Acidente pessoal flexível para gig economy. Pague R\$0,20/hora. Sem mensalidade fixa.',
      premioMinimoMensal: 0, premioMaximoMensal: 0,
      capitalMinimoSegurado: 30000, capitalMaximoSegurado: 100000,
      coberturas: ['Morte Acidental por hora', 'Invalidez por hora', 'DMH por hora', 'Diária R\$150/dia'],
      isParametric: true, triggerDescricao: 'App ativo + GPS em movimento',
      publicoAlvo: ['Motoristas de app', 'Entregadores', 'Freelancers'],
      prioridadeRanking: 88, susepRamo: '061',
    ),
    InsuranceProduct(
      id: 'AP-ESC-001', line: InsuranceLine.apEscolar,
      nome: 'AP Escolar',
      descricao: 'Proteção para crianças e adolescentes no ambiente escolar, percurso casa-escola e atividades extraclasse.',
      premioMinimoMensal: 5.0, premioMaximoMensal: 20.0,
      capitalMinimoSegurado: 10000, capitalMaximoSegurado: 50000,
      coberturas: ['Morte acidental', 'Invalidez permanente', 'Despesas médicas', 'Fratura', 'Queimadura'],
      publicoAlvo: ['Crianças 4-17 anos', 'Pais e responsáveis', 'Escolas'],
      prioridadeRanking: 62, susepRamo: '061',
    ),

    // ══ SAÚDE ════════════════════════════════════════════════════════════
    InsuranceProduct(
      id: 'SAUDE-IND-001', line: InsuranceLine.saudeIndividual,
      nome: 'Saúde Individual',
      descricao: 'Plano de saúde individual com livre escolha de médico. Coberturas básica a premium conforme ANS.',
      premioMinimoMensal: 350.0, premioMaximoMensal: 3000.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Consultas médicas', 'Exames', 'Internação hospitalar', 'Cirurgias', 'Urgência/Emergência', 'Parto'],
      publicoAlvo: ['Adultos sem plano empresarial', 'MEI', 'Autônomos'],
      prioridadeRanking: 88, susepRamo: 'ANS',
    ),
    InsuranceProduct(
      id: 'SAUDE-DENT-001', line: InsuranceLine.saudeDental,
      nome: 'Odontológico Individual',
      descricao: 'Plano dental com consultas, extrações, restaurações, canal e ortodontia inclusa.',
      premioMinimoMensal: 29.90, premioMaximoMensal: 120.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Consultas', 'Limpeza e profilaxia', 'Extrações', 'Restaurações', 'Canal', 'Prótese parcial'],
      publicoAlvo: ['Adultos', 'Famílias', 'MEI'],
      prioridadeRanking: 72, susepRamo: 'ANS',
    ),
    InsuranceProduct(
      id: 'SAUDE-MICRO-001', line: InsuranceLine.saudeMicro,
      nome: 'Saúde Micro / Telemedicina',
      descricao: 'Acesso ilimitado a telemedicina + assistência remota por R\$29,90/mês. Revolução no acesso à saúde.',
      premioMinimoMensal: 29.90, premioMaximoMensal: 59.90,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Telemedicina ilimitada', 'Prescrição digital', 'Check-up remoto', 'Saúde mental online', 'Orientação de enfermagem'],
      publicoAlvo: ['Baixa renda', 'Sem plano de saúde', 'Interior do Brasil'],
      prioridadeRanking: 80, susepRamo: 'ANS',
    ),
    InsuranceProduct(
      id: 'SAUDE-MENTAL-001', line: InsuranceLine.saudeMental,
      nome: 'Saúde Mental',
      descricao: 'Psicoterapia + psiquiatria + apps de bem-estar. O produto mais demandado pós-pandemia.',
      premioMinimoMensal: 89.90, premioMaximoMensal: 350.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Psicoterapia (12 sessões/ano)', 'Psiquiatria', 'App bem-estar', 'Meditação guiada', 'Crise 24h'],
      publicoAlvo: ['Adultos 20-45 anos', 'Empresas', 'Pós-pandemia'],
      prioridadeRanking: 82, susepRamo: 'ANS',
    ),

    // ══ RESIDENCIAL ═══════════════════════════════════════════════════════
    InsuranceProduct(
      id: 'RES-COMP-001', line: InsuranceLine.residencial,
      nome: 'Residencial Compreensivo',
      descricao: 'Proteção completa para seu lar: incêndio, roubo, RC vizinhos, assistência 24h e danos elétricos.',
      premioMinimoMensal: 35.0, premioMaximoMensal: 250.0,
      capitalMinimoSegurado: 50000, capitalMaximoSegurado: 2000000,
      coberturas: ['Incêndio e Raio', 'Roubo e Furto', 'Vendaval e Granizo', 'Danos Elétricos', 'RC Familiar', 'Assistência 24h', 'Inundação'],
      publicoAlvo: ['Proprietários', 'Imóveis financiados', 'Alto padrão'],
      prioridadeRanking: 82, susepRamo: '068',
    ),
    InsuranceProduct(
      id: 'RES-ALU-001', line: InsuranceLine.aluguelGarantido,
      nome: 'Aluguel Garantido (Fiança Digital)',
      descricao: 'Substitui o fiador e o depósito caução. Garantia digital de pagamento do aluguel. Aprovação em minutos.',
      premioMinimoMensal: 45.0, premioMaximoMensal: 400.0,
      capitalMinimoSegurado: 5000, capitalMaximoSegurado: 500000,
      coberturas: ['Inadimplência aluguel', 'Danos ao imóvel', 'Contas de consumo', 'IPTU', 'Assistência jurídica'],
      publicoAlvo: ['Inquilinos', 'Imobiliárias', 'Proprietários'],
      prioridadeRanking: 76, susepRamo: '0775',
    ),

    // ══ EMPRESARIAL ═══════════════════════════════════════════════════════
    InsuranceProduct(
      id: 'EMP-COMP-001', line: InsuranceLine.empresarial,
      nome: 'Empresarial Compreensivo',
      descricao: 'Proteção completa para qualquer negócio. Patrimônio + RC + lucros cessantes + funcionários.',
      premioMinimoMensal: 150.0, premioMaximoMensal: 5000.0,
      capitalMinimoSegurado: 50000, capitalMaximoSegurado: 10000000,
      coberturas: ['Incêndio e raio', 'Roubo de patrimônio', 'Danos elétricos', 'RC empresarial', 'Lucros Cessantes', 'Responsabilidade patrão'],
      publicoAlvo: ['PME', 'Comércio', 'Indústria', 'Serviços'],
      prioridadeRanking: 80, susepRamo: '068',
    ),
    InsuranceProduct(
      id: 'DATA-001', line: InsuranceLine.dataCenter,
      nome: 'Data Center e TI',
      descricao: 'Infraestrutura tecnológica — servidores, redes, dados, interrupção de sistemas. Para empresas tech.',
      premioMinimoMensal: 500.0, premioMaximoMensal: 15000.0,
      capitalMinimoSegurado: 200000, capitalMaximoSegurado: 100000000,
      coberturas: ['Hardware e servidores', 'Software e dados', 'Interrupção de negócios', 'RC dados de terceiros', 'Restauração de sistemas'],
      publicoAlvo: ['Startups', 'Fintechs', 'Data centers', 'E-commerce'],
      prioridadeRanking: 72, susepRamo: '068',
    ),

    // ══ EQUIPAMENTOS ══════════════════════════════════════════════════════
    InsuranceProduct(
      id: 'CEL-001', line: InsuranceLine.celular,
      nome: 'Seguro Celular',
      descricao: 'Roubo, furto, quebra de tela e danos acidentais. Ativação em 5min pelo app.',
      premioMinimoMensal: 12.0, premioMaximoMensal: 60.0,
      capitalMinimoSegurado: 500, capitalMaximoSegurado: 15000,
      coberturas: ['Roubo e Furto', 'Quebra de tela', 'Danos líquidos', 'Danos acidentais', 'Troca em 24h'],
      publicoAlvo: ['Smartphone premium', 'Jovens', 'Executivos'],
      prioridadeRanking: 78, susepRamo: '068',
    ),
    InsuranceProduct(
      id: 'SOLAR-001', line: InsuranceLine.paineisSolares,
      nome: 'Seguro Fotovoltaico (Solar)',
      descricao: 'Proteção para sistemas de energia solar: painéis, inversores, estrutura. Proteção contra raio e granizo.',
      premioMinimoMensal: 30.0, premioMaximoMensal: 200.0,
      capitalMinimoSegurado: 10000, capitalMaximoSegurado: 500000,
      coberturas: ['Danos painéis', 'Inversores', 'Granizo e raio', 'Roubo dos equipamentos', 'Lucros cessantes geração'],
      publicoAlvo: ['Residencial solar', 'Fazendas', 'Empresas'],
      prioridadeRanking: 68, susepRamo: '068',
    ),

    // ══ CYBER ════════════════════════════════════════════════════════════
    InsuranceProduct(
      id: 'CYBER-EMP-001', line: InsuranceLine.cyberEmpresarial,
      nome: 'Cyber Empresarial',
      descricao: 'LGPD + ransomware + vazamento de dados + RC terceiros. Indispensável para empresas com dados de clientes.',
      premioMinimoMensal: 200.0, premioMaximoMensal: 3000.0,
      capitalMinimoSegurado: 100000, capitalMaximoSegurado: 10000000,
      coberturas: ['Ransomware e extorsão', 'Vazamento de dados LGPD', 'RC dados terceiros', 'Notificação ANPD', 'Forense digital', 'Lucros cessantes'],
      publicoAlvo: ['PME', 'Fintechs', 'Healthtechs', 'E-commerce'],
      prioridadeRanking: 85, susepRamo: '040',
    ),
    InsuranceProduct(
      id: 'RANSOM-001', line: InsuranceLine.ransomwareProtect,
      nome: 'Ransomware Protection',
      descricao: 'Extorsão digital especializada. Cobertura para pagamento de resgate + recuperação + honorários forenses.',
      premioMinimoMensal: 100.0, premioMaximoMensal: 2000.0,
      capitalMinimoSegurado: 50000, capitalMaximoSegurado: 5000000,
      coberturas: ['Pagamento de resgate', 'Recuperação de dados', 'Forense digital', 'Relações públicas', 'Lucros cessantes'],
      publicoAlvo: ['Empresas com dados críticos', 'Indústrias', 'Saúde'],
      prioridadeRanking: 74, susepRamo: '040',
    ),

    // ══ VIAGEM ════════════════════════════════════════════════════════════
    InsuranceProduct(
      id: 'VIAGEM-INT-001', line: InsuranceLine.viagemInternacional,
      nome: 'Viagem Internacional',
      descricao: 'Cobertura médica até U\$300k, bagagem, atraso de voo e cancelamento. Schengen aprovado.',
      premioMinimoMensal: 0, premioMaximoMensal: 0,
      capitalMinimoSegurado: 100000, capitalMaximoSegurado: 500000,
      coberturas: ['Emergência médica U\$300k', 'Bagagem extraviada', 'Atraso de voo', 'Cancelamento', 'AP viagem', 'Assistência jurídica'],
      publicoAlvo: ['Viajantes internacionais', 'Schengen', 'Turismo'],
      prioridadeRanking: 80, susepRamo: '061', moeda: 'USD',
    ),
    InsuranceProduct(
      id: 'VIAGEM-PARAM-001', line: InsuranceLine.viagemParametrico,
      nome: 'Viagem Paramétrico (Atraso)',
      descricao: 'Paga automaticamente quando voo atrasa > 2h. Sem reclamação, sem comprovante. Integração API aeroporto.',
      premioMinimoMensal: 0, premioMaximoMensal: 0,
      capitalMinimoSegurado: 200, capitalMaximoSegurado: 1000,
      coberturas: ['Atraso voo > 2h', 'Cancelamento automático', 'Perda de conexão', 'Bagagem aérea'],
      isParametric: true,
      triggerDescricao: 'API FlightAware: atraso > 120min confirmado',
      pagamentoParametrico: 300,
      publicoAlvo: ['Viajantes frequentes', 'Executivos', 'Nômades digitais'],
      prioridadeRanking: 85,
    ),
    InsuranceProduct(
      id: 'NOMADE-001', line: InsuranceLine.nomadeDigital,
      nome: 'Nômade Digital',
      descricao: 'Para quem trabalha de qualquer lugar do mundo. Multi-país, multi-visto, equipamentos TI inclusos.',
      premioMinimoMensal: 99.0, premioMaximoMensal: 350.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Saúde global', 'Equipamentos TI', 'Repatriação', 'RC pessoal global', 'Assistência jurídica'],
      publicoAlvo: ['Remote workers', 'Freelancers internacionais', 'Digital nomads'],
      prioridadeRanking: 75, moeda: 'USD',
    ),

    // ══ RURAL ════════════════════════════════════════════════════════════
    InsuranceProduct(
      id: 'AGRO-001', line: InsuranceLine.agricola,
      nome: 'Seguro Agrícola (Lavoura)',
      descricao: 'Proteção para soja, milho, café, algodão. Cobre geada, granizo, seca, excesso de chuva.',
      premioMinimoMensal: 0, premioMaximoMensal: 0,
      capitalMinimoSegurado: 50000, capitalMaximoSegurado: 50000000,
      coberturas: ['Geada', 'Granizo', 'Seca', 'Excesso de chuva', 'Incêndio lavoura', 'Variação de preço (opcional)'],
      publicoAlvo: ['Produtores rurais', 'Fazendeiros', 'Cooperativas'],
      prioridadeRanking: 70, susepRamo: '082',
    ),
    InsuranceProduct(
      id: 'PARAM-CLIMA-001', line: InsuranceLine.parametricoClimatico,
      nome: 'Paramétrico Climático',
      descricao: 'Indenização automática baseada em índice pluviométrico oficial INMET. Sem vistoria, paga em 48h.',
      premioMinimoMensal: 50.0, premioMaximoMensal: 500.0,
      capitalMinimoSegurado: 10000, capitalMaximoSegurado: 1000000,
      coberturas: ['Seca extrema (índice)', 'Excesso chuva (índice)', 'Granizo (estação)', 'Temperatura extrema'],
      isParametric: true,
      triggerDescricao: 'INMET: índice pluviométrico fora do threshold contratado',
      publicoAlvo: ['Agronegócio', 'Produtores de soja/milho/café'],
      prioridadeRanking: 78, susepRamo: '082',
    ),

    // ══ RESPONSABILIDADE CIVIL ════════════════════════════════════════════
    InsuranceProduct(
      id: 'RC-PROF-001', line: InsuranceLine.rcProfissional,
      nome: 'RC Profissional (E&O)',
      descricao: 'Erros e Omissões para advogados, contadores, arquitetos, consultores. Proteção jurídica completa.',
      premioMinimoMensal: 80.0, premioMaximoMensal: 800.0,
      capitalMinimoSegurado: 100000, capitalMaximoSegurado: 5000000,
      coberturas: ['Erros profissionais', 'Omissões', 'Violação de sigilo', 'Custas processuais', 'Honorários advocatícios'],
      publicoAlvo: ['Advogados', 'Contadores', 'Arquitetos', 'Consultores'],
      prioridadeRanking: 75, susepRamo: '040',
    ),
    InsuranceProduct(
      id: 'RC-MED-001', line: InsuranceLine.rcMedico,
      nome: 'RC Médico (Malpractice)',
      descricao: 'Responsabilidade civil médica e hospitalar. Cobertura para erros médicos, procedimentos, diagnósticos.',
      premioMinimoMensal: 200.0, premioMaximoMensal: 3000.0,
      capitalMinimoSegurado: 500000, capitalMaximoSegurado: 10000000,
      coberturas: ['Erro médico', 'Diagnóstico equivocado', 'Dano ao paciente', 'Custas processuais', 'Honorários'],
      publicoAlvo: ['Médicos', 'Dentistas', 'Hospitais', 'Clínicas'],
      prioridadeRanking: 72, susepRamo: '040',
    ),
    InsuranceProduct(
      id: 'DNO-001', line: InsuranceLine.dno,
      nome: 'D&O — Diretores e Executivos',
      descricao: 'Protege patrimônio pessoal de diretores em ações judiciais por decisões corporativas.',
      premioMinimoMensal: 400.0, premioMaximoMensal: 10000.0,
      capitalMinimoSegurado: 1000000, capitalMaximoSegurado: 100000000,
      coberturas: ['Ações de acionistas', 'Regulatório CVM/BACEN', 'Trabalhista executivo', 'Custas processuais', 'Honorários'],
      publicoAlvo: ['C-Level', 'Conselheiros', 'Startups em crescimento'],
      prioridadeRanking: 70, susepRamo: '048',
    ),
    InsuranceProduct(
      id: 'GARANTIA-001', line: InsuranceLine.seguroGarantia,
      nome: 'Seguro Garantia (Licitações)',
      descricao: 'Substitui cauções em licitações públicas e contratos. Libera capital de giro da empresa.',
      premioMinimoMensal: 0, premioMaximoMensal: 0,
      capitalMinimoSegurado: 50000, capitalMaximoSegurado: 500000000,
      coberturas: ['Bid bond (proposta)', 'Performance bond (execução)', 'Advance payment bond', 'Maintenance bond'],
      publicoAlvo: ['Construtoras', 'Fornecedores governo', 'Empreiteiros'],
      prioridadeRanking: 68, susepRamo: '0775',
    ),

    // ══ TRANSPORTE ════════════════════════════════════════════════════════
    InsuranceProduct(
      id: 'CARGO-NAC-001', line: InsuranceLine.cargoNacional,
      nome: 'Cargo Nacional (RCTR-C)',
      descricao: 'Carga em trânsito rodoviário. Cobertura porta-a-porta para todo território nacional.',
      premioMinimoMensal: 0, premioMaximoMensal: 0,
      capitalMinimoSegurado: 10000, capitalMaximoSegurado: 5000000,
      coberturas: ['Roubo e furto', 'Colisão', 'Alagamento', 'Incêndio', 'Avaria carga', 'Desvio de rota'],
      publicoAlvo: ['Importadores', 'Distribuidoras', 'E-commerce'],
      prioridadeRanking: 65, susepRamo: '090',
    ),
    InsuranceProduct(
      id: 'ECOMM-001', line: InsuranceLine.correioEncomenda,
      nome: 'Seguro Encomenda (E-commerce)',
      descricao: 'Proteção por encomenda enviada. Integração API com plataformas de e-commerce e marketplaces.',
      premioMinimoMensal: 0, premioMaximoMensal: 0,
      capitalMinimoSegurado: 50, capitalMaximoSegurado: 50000,
      coberturas: ['Extravio', 'Roubo em trânsito', 'Avaria', 'Atraso (opcional)', 'Fraude destinatário'],
      publicoAlvo: ['Lojistas Mercado Livre', 'Shopee', 'Magalu', 'E-commerce próprio'],
      prioridadeRanking: 76, susepRamo: '090',
    ),

    // ══ CRÉDITO E GARANTIAS FINANCEIRAS ═════════════════════════════════
    InsuranceProduct(
      id: 'CRED-IMOB-001', line: InsuranceLine.creditoImobiliario,
      nome: 'Crédito Imobiliário (SFH/SFI)',
      descricao: 'Habilitacional obrigatório SFH. Quitação em caso de morte, invalidez ou desemprego.',
      premioMinimoMensal: 30.0, premioMaximoMensal: 300.0,
      capitalMinimoSegurado: 50000, capitalMaximoSegurado: 5000000,
      coberturas: ['Morte — quitação', 'Invalidez permanente', 'Desemprego involuntário (30 parcelas)', 'Danos físicos ao imóvel'],
      publicoAlvo: ['Mutuários SFH', 'Financiamentos Caixa/BB/Bradesco'],
      prioridadeRanking: 78, susepRamo: '029',
    ),
    InsuranceProduct(
      id: 'FGTS-001', line: InsuranceLine.fgts,
      nome: 'FGTS / Demissão Involuntária',
      descricao: 'Complemento do seguro-desemprego. Garante renda por até 12 meses em caso de demissão sem justa causa.',
      premioMinimoMensal: 20.0, premioMaximoMensal: 80.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Renda mensal 12 meses', 'Complemento seguro-desemprego', 'Orientação recolocação'],
      publicoAlvo: ['CLT', 'Trabalhadores formais'],
      prioridadeRanking: 65, susepRamo: '029',
    ),

    // ══ CAPITALIZAÇÃO ════════════════════════════════════════════════════
    InsuranceProduct(
      id: 'CAP-PM-001', line: InsuranceLine.capPm,
      nome: 'Capitalização PM (Mensal)',
      descricao: 'Pague mensalmente e concorra a sorteios. Resgata 100% ao final. Alternativa inteligente ao depósito.',
      premioMinimoMensal: 30.0, premioMaximoMensal: 5000.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Sorteios semanais', 'Resgate 100% corrigido', 'Resgate antecipado parcial'],
      publicoAlvo: ['Poupadores', 'Concursos culturais', 'Fiança locatícia'],
      prioridadeRanking: 68, susepRamo: 'CAP',
    ),
    InsuranceProduct(
      id: 'CAP-MICRO-001', line: InsuranceLine.capMicroCap,
      nome: 'Microcapitalização',
      descricao: 'Capitalização para baixa renda a partir de R\$10/mês. Sorteios mensais + resgate.',
      premioMinimoMensal: 10.0, premioMaximoMensal: 50.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Sorteios mensais R\$1.000 a R\$100.000', 'Resgate ao final do prazo'],
      publicoAlvo: ['Baixa renda', 'Correspondentes bancários', 'Fintechs'],
      prioridadeRanking: 62, susepRamo: 'CAP',
    ),
    InsuranceProduct(
      id: 'CAP-FILANTROPIA-001', line: InsuranceLine.capFilantropia,
      nome: 'Cap. com Filantropia',
      descricao: 'Parte do prêmio vai para ONGs parceiras. Cliente concorre a sorteios e ainda contribui com o bem.',
      premioMinimoMensal: 20.0, premioMaximoMensal: 500.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Sorteios', 'Doação automática ONGs', 'Certificado ESG', 'Resgate parcial'],
      publicoAlvo: ['ESG', 'Empresas conscientes', 'Geração Z'],
      prioridadeRanking: 65, susepRamo: 'CAP',
    ),

    // ══ PREVIDÊNCIA PRIVADA ═══════════════════════════════════════════════
    InsuranceProduct(
      id: 'PGBL-001', line: InsuranceLine.pgbl,
      nome: 'PGBL — Plano Gerador Benefício Livre',
      descricao: 'Deduz até 12% da renda bruta no IR. Ideal para quem faz declaração completa. Portabilidade garantida.',
      premioMinimoMensal: 100.0, premioMaximoMensal: 50000.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Dedução IR 12%', 'Portabilidade', 'Fundo multimercado', 'Renda na aposentadoria', 'Proteção família'],
      publicoAlvo: ['Renda tributável', 'Declaração completa', 'Alta renda'],
      prioridadeRanking: 82, susepRamo: 'PGBL',
    ),
    InsuranceProduct(
      id: 'VGBL-001', line: InsuranceLine.vgbl,
      nome: 'VGBL — Vida Gerador Benefício Livre',
      descricao: 'IR só sobre rendimentos. Ideal para declaração simplificada, isentos e planejamento sucessório.',
      premioMinimoMensal: 100.0, premioMaximoMensal: 100000.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['IR só rendimentos', 'Não integra inventário', 'Portabilidade', 'Fundo escolhido', 'Sucessão direta'],
      publicoAlvo: ['Declaração simplificada', 'Isentos IR', 'Planejamento sucessório'],
      prioridadeRanking: 84, susepRamo: 'VGBL',
    ),
    InsuranceProduct(
      id: 'VGBL-JOVEM-001', line: InsuranceLine.vgblJovem,
      nome: 'VGBL Jovem',
      descricao: 'Previdência para quem começa cedo. A partir de R\$50/mês. Poder dos juros compostos a seu favor.',
      premioMinimoMensal: 50.0, premioMaximoMensal: 2000.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Fundo renda variável', 'Aporte livre', 'Resgate a qualquer tempo', 'Portabilidade'],
      publicoAlvo: ['18-35 anos', 'Primeira renda', 'Jovens CLT'],
      prioridadeRanking: 72, susepRamo: 'VGBL',
    ),
    InsuranceProduct(
      id: 'RENDA-IMEDIATA-001', line: InsuranceLine.riVitalicio,
      nome: 'Renda Imediata Vitalícia',
      descricao: 'Converta patrimônio em renda garantida para o resto da vida. Anuidade paga mensalmente até o último dia.',
      premioMinimoMensal: 0, premioMaximoMensal: 0,
      capitalMinimoSegurado: 100000, capitalMaximoSegurado: 10000000,
      coberturas: ['Renda mensal vitalícia', 'Reversão ao cônjuge', 'Atualização IPCA/IGP-M', 'Período certo opcional'],
      publicoAlvo: ['Aposentados', 'Alta renda', 'Gestão patrimonial'],
      prioridadeRanking: 70, susepRamo: 'PGBL',
    ),

    // ══ BENEFÍCIOS CORPORATIVOS ════════════════════════════════════════════
    InsuranceProduct(
      id: 'TELEMEDICINA-001', line: InsuranceLine.telemedicina,
      nome: 'Telemedicina Corporativa',
      descricao: 'Consultas médicas ilimitadas pelo app para todos os colaboradores. Reduz absenteísmo em 30%.',
      premioMinimoMensal: 15.0, premioMaximoMensal: 50.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Consultas ilimitadas app', 'Prescrição digital', 'Exames orientados', 'Saúde mental', 'Nutrição'],
      publicoAlvo: ['Empresas 10+ colaboradores', 'RH', 'Benefícios'],
      prioridadeRanking: 78, susepRamo: 'ANS',
    ),
    InsuranceProduct(
      id: 'WELLNESS-001', line: InsuranceLine.wellnessEmpresarial,
      nome: 'Wellness Empresarial',
      descricao: 'Pacote completo de bem-estar: academia, nutrição, psicologia, meditação. Reduz turnover e custos médicos.',
      premioMinimoMensal: 30.0, premioMaximoMensal: 100.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Gympass/Totalpass', 'Psicoterapia 12 sessões', 'Nutricionista', 'App meditação', 'Check-up anual'],
      publicoAlvo: ['Empresas tech', 'Startups', 'Grandes empresas'],
      prioridadeRanking: 72, susepRamo: 'ANS',
    ),

    // ══ NICHOS ESPECIAIS ══════════════════════════════════════════════════
    InsuranceProduct(
      id: 'PET-001', line: InsuranceLine.pet,
      nome: 'Pet Insurance',
      descricao: 'Consultas, exames, cirurgias e internações para seu cão ou gato. O mercado que mais cresce no Brasil.',
      premioMinimoMensal: 39.90, premioMaximoMensal: 200.0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['Consultas veterinárias', 'Exames', 'Cirurgias', 'Internação', 'Vacinas', 'Emergências 24h'],
      publicoAlvo: ['Donos de pets', 'Cães e gatos', 'Animais de estimação'],
      prioridadeRanking: 74, susepRamo: '061',
    ),
    InsuranceProduct(
      id: 'JOIAS-001', line: InsuranceLine.joias,
      nome: 'Joias e Relógios',
      descricao: 'Proteção para joias, relógios de luxo e metais preciosos. Cobertura global dentro e fora do país.',
      premioMinimoMensal: 50.0, premioMaximoMensal: 1000.0,
      capitalMinimoSegurado: 5000, capitalMaximoSegurado: 2000000,
      coberturas: ['Roubo e furto', 'Danos acidentais', 'Cobertura global', 'Misterioso desaparecimento', 'Avaliação especializada'],
      publicoAlvo: ['Colecionadores', 'Executivos', 'Alta renda'],
      prioridadeRanking: 62, susepRamo: '068',
    ),
    InsuranceProduct(
      id: 'CRIPTO-001', line: InsuranceLine.criptoativos,
      nome: 'Custódia de Criptoativos',
      descricao: 'Proteção para carteiras cripto: hack, acesso não autorizado, falha de exchange. Produto emergente global.',
      premioMinimoMensal: 30.0, premioMaximoMensal: 500.0,
      capitalMinimoSegurado: 5000, capitalMaximoSegurado: 1000000,
      coberturas: ['Hack de exchange', 'Acesso não autorizado', 'Falha de custodiante', 'Phishing cripto', 'Perda de chaves'],
      publicoAlvo: ['Investidores cripto', 'Traders', 'HODLers'],
      prioridadeRanking: 68,
    ),
    InsuranceProduct(
      id: 'MEI-001', line: InsuranceLine.microempreendedor,
      nome: 'MEI — Pacote Completo',
      descricao: 'Tudo que o microempreendedor precisa em um produto. Vida + AP + RC + Equipamentos + Cyber básico.',
      premioMinimoMensal: 49.90, premioMaximoMensal: 150.0,
      capitalMinimoSegurado: 30000, capitalMaximoSegurado: 200000,
      coberturas: ['Vida R\$50k', 'AP 24h', 'RC prestação de serviço', 'Equipamentos R\$5k', 'Cyber básico', 'Assistência jurídica'],
      publicoAlvo: ['MEI', 'Autônomos', 'Profissionais liberais'],
      prioridadeRanking: 82, susepRamo: '061',
    ),
    InsuranceProduct(
      id: 'MICRO-001', line: InsuranceLine.microseguro,
      nome: 'Microsseguro Básico',
      descricao: 'Proteção essencial de baixo custo para trabalhadores informais. Vida + funeral + AP por < R\$30/mês.',
      premioMinimoMensal: 9.90, premioMaximoMensal: 29.90,
      capitalMinimoSegurado: 5000, capitalMaximoSegurado: 30000,
      coberturas: ['Morte R\$10k', 'Invalidez R\$5k', 'DMH R\$2k', 'Funeral R\$3k'],
      publicoAlvo: ['Baixa renda', 'Informais', 'Primeira vez com seguro'],
      prioridadeRanking: 70, susepRamo: '021',
    ),

    // ══ ESG E SUSTENTABILIDADE ════════════════════════════════════════════
    InsuranceProduct(
      id: 'SOLAR-FARM-001', line: InsuranceLine.energiaRenovavel,
      nome: 'Energia Renovável (Parque)',
      descricao: 'Parques eólicos, solares e hidrelétricas. Riscos de construção, operação, lucros cessantes e RC ambiental.',
      premioMinimoMensal: 2000.0, premioMaximoMensal: 100000.0,
      capitalMinimoSegurado: 5000000, capitalMaximoSegurado: 1000000000,
      coberturas: ['Danos físicos parque', 'Lucros cessantes', 'RC ambiental', 'Falha de equipamento', 'Catástrofe natural'],
      publicoAlvo: ['Investidores energia', 'Fundos infraestrutura', 'Utilities'],
      prioridadeRanking: 65, susepRamo: '073',
    ),
    InsuranceProduct(
      id: 'CARBONO-001', line: InsuranceLine.carbono,
      nome: 'Crédito de Carbono (Offset)',
      descricao: 'Seguro para projetos de crédito de carbono. Garante a entrega dos créditos prometidos no mercado VCM.',
      premioMinimoMensal: 500.0, premioMaximoMensal: 20000.0,
      capitalMinimoSegurado: 100000, capitalMaximoSegurado: 50000000,
      coberturas: ['Não-entrega de créditos', 'Reversão do projeto', 'Fraude metodológica', 'Desastre natural na reserva'],
      publicoAlvo: ['Projetos REDD+', 'Empresas net-zero', 'Fundos ESG'],
      prioridadeRanking: 60,
    ),

    // ══ EMBEDDED FINANCE ════════════════════════════════════════════════
    InsuranceProduct(
      id: 'EMBEDDED-AUTO-001', line: InsuranceLine.embeddedAuto,
      nome: 'Embedded Auto (Checkout)',
      descricao: 'Seguro auto embutido no checkout de concessionárias e marketplaces. Conversão 3x maior que venda avulsa.',
      premioMinimoMensal: 0, premioMaximoMensal: 0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['API de integração', 'Emissão instantânea', 'Customizável por parceiro', 'White label'],
      publicoAlvo: ['Concessionárias', 'Marketplaces auto', 'Fintechs'],
      prioridadeRanking: 80,
    ),
    InsuranceProduct(
      id: 'BAAS-001', line: InsuranceLine.baaS,
      nome: 'Insurance-as-a-Service (BaaS)',
      descricao: 'API completa para fintechs e bancos digitais distribuírem seguros como produto próprio. White label total.',
      premioMinimoMensal: 0, premioMaximoMensal: 0,
      capitalMinimoSegurado: 0, capitalMaximoSegurado: 0,
      coberturas: ['API REST completa', 'White label', 'Dashboard parceiro', 'Split de comissão automático', 'Backoffice integrado'],
      publicoAlvo: ['Fintechs', 'Bancos digitais', 'Super-apps', 'Marketplaces'],
      prioridadeRanking: 88,
    ),

  ]; // end _products

  static List<InsuranceProduct> get all => _products.where((p) => p.ativo).toList();
  static List<InsuranceProduct> byCategory(String category) =>
      all.where((p) => p.line.category == category).toList();
  static List<InsuranceProduct> byLine(InsuranceLine line) =>
      all.where((p) => p.line == line).toList();
  static InsuranceProduct? byId(String id) =>
      all.cast<InsuranceProduct?>().firstWhere((p) => p?.id == id, orElse: () => null);
  static List<String> get categories =>
      all.map((p) => p.line.category).toSet().toList()..sort();
  static List<InsuranceProduct> get parametricOnly =>
      all.where((p) => p.isParametric).toList();
  static List<InsuranceProduct> get saferoureExclusive =>
      all.where((p) => p.line.isExclusiveSafeRoute).toList();
  static int get totalLines => InsuranceLine.values.length;
  static int get totalProducts => all.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// NEEDS DETECTOR ENGINE
// ─────────────────────────────────────────────────────────────────────────────

class NeedsDetectorEngine {
  static List<NeedsDetectorResult> detect({
    required String userId,
    String? uf,
    int? age,
    String? gender,
    String? vehicleUse,
    double? avgSpeedKmh,
    int? totalTrips,
    double? nightTripRatio,
    double? ubiScore,
    String? cep,
    bool temPet = false,
    bool temFilhos = false,
    bool proprietarioImovel = false,
    double? rendaMensal,
    String? profissao,
  }) {
    final results = <NeedsDetectorResult>[];
    final triScore = uf != null
        ? TerritorialRiskIntelligence.instance.quickActuarialFactorByUf(uf)
        : 1.0;

    void _add(InsuranceLine line, double score, List<String> motivos, String prioridade) {
      final products = ProductCatalog.byLine(line);
      if (products.isEmpty) return;
      final product = products.first;
      results.add(NeedsDetectorResult(
        line: line, product: product,
        scoreRelevancia: score.clamp(0, 100),
        motivos: motivos, prioridade: prioridade,
      ));
    }

    // SafeRoute UBI — sempre relevante
    if (totalTrips != null && totalTrips > 5) {
      _add(InsuranceLine.autoUbi, 95 + (ubiScore ?? 70) * 0.05, [
        'Motorista ativo com ${totalTrips} viagens',
        'UBI score: ${ubiScore?.toStringAsFixed(0) ?? "N/A"}',
        if ((ubiScore ?? 70) > 75) 'Bom motorista = prêmio até 40% menor',
      ], 'ESSENCIAL');
    }

    // Paramétrico colisão
    if (vehicleUse == 'app' || vehicleUse == 'motoboy') {
      _add(InsuranceLine.safeShieldColisao, 98, [
        'Uso profissional do veículo — risco elevado',
        'Pagamento automático em 2h sem burocracia',
      ], 'CRÍTICO');
    }

    // Risco territorial
    if (triScore > 1.2) {
      _add(InsuranceLine.zonaSeguraTri, 85 + (triScore - 1.0) * 30, [
        'UF ${uf ?? ""} com score TRI ${triScore.toStringAsFixed(2)}',
        'Cobertura extra ativa automaticamente em zonas críticas',
      ], 'ALTO');
    }

    // Motoboy
    if (profissao == 'motoboy' || vehicleUse == 'motoboy') {
      _add(InsuranceLine.rapidProtectMotoboy, 96, [
        'Motoboy identificado — risco 3x maior',
        'R\$0,40/h paga só quando está em serviço',
      ], 'CRÍTICO');
    }

    // Vida — família
    if (temFilhos && (age ?? 30) < 60) {
      final score = 80.0 + (temFilhos ? 15 : 0);
      _add(InsuranceLine.vidaTermo, score, [
        'Tem filhos — proteção familiar essencial',
        'Prêmio baixo, capital alto',
      ], 'ALTO');
    }

    // AP individual — sempre útil
    _add(InsuranceLine.apIndividual, 72, ['Proteção 24h contra acidentes', 'Custo-benefício excelente'], 'MÉDIO');

    // Saúde
    if ((rendaMensal ?? 3000) < 5000) {
      _add(InsuranceLine.saudeMicro, 78, ['Renda até R\$5k — micro saúde ideal', 'Telemedicina ilimitada'], 'ALTO');
    } else {
      _add(InsuranceLine.saudeIndividual, 75, ['Sem plano de saúde detectado', 'Proteção médica completa'], 'ALTO');
    }

    // Residencial
    if (proprietarioImovel) {
      _add(InsuranceLine.residencial, 82, ['Proprietário — patrimônio a proteger', 'RC familiar inclusa'], 'ALTO');
    } else {
      _add(InsuranceLine.aluguelGarantido, 70, ['Inquilino — elimina fiador e depósito'], 'MÉDIO');
    }

    // Pet
    if (temPet) {
      _add(InsuranceLine.pet, 80, ['Pet detectado — veterinário cada vez mais caro'], 'ALTO');
    }

    // Cyber PIX
    _add(InsuranceLine.cyberPixShield, 72, ['Proteção contra golpe PIX', 'Correlação territorial TRI'], 'MÉDIO');

    // Celular
    _add(InsuranceLine.celular, 68, ['Seguro celular mais vendido no país'], 'BAIXO');

    // Previdência
    if ((age ?? 30) < 45 && (rendaMensal ?? 0) > 3000) {
      _add(InsuranceLine.vgbl, 76, [
        'Ideal para iniciar previdência antes dos 45',
        'Juros compostos por mais tempo = muito mais ao final',
      ], 'ALTO');
    }

    // MEI
    if (profissao == 'autonomo' || profissao == 'mei') {
      _add(InsuranceLine.microempreendedor, 85, ['MEI — pacote completo 5 produtos em 1', 'RC prestação de serviço inclusa'], 'CRÍTICO');
    }

    results.sort((a, b) => b.scoreRelevancia.compareTo(a.scoreRelevancia));
    return results;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUOTE ENGINE (MOTOR ATUARIAL)
// ─────────────────────────────────────────────────────────────────────────────

class QuoteEngine {
  static final _rng = math.Random();

  static InsuranceQuote generateQuote({
    required String userId,
    required InsuranceProduct product,
    String? uf,
    int? age,
    String? gender,
    String? vehicleUse,
    double? ubiScore,
    double? fipeValue,
    String? cep,
    List<String>? selectedCoverages,
    double? capitalCustom,
  }) {
    final triFactor = uf != null
        ? TerritorialRiskIntelligence.instance.quickActuarialFactorByUf(uf)
        : 1.0;
    final territorialLoading = 1.0 + (triFactor - 1.0) * 0.14;

    final ageFactor = _ageFactor(age ?? 35, product.line.category);
    final ubiFactor = _ubiFactor(ubiScore ?? 75.0, product.line.category);
    final useFactor = _useFactor(vehicleUse);

    double basePremio;
    double capital;

    if (product.premioMinimoMensal == 0 && product.premioMaximoMensal == 0) {
      basePremio = 0;
      capital = capitalCustom ?? product.capitalMinimoSegurado.toDouble();
    } else {
      final mid = (product.premioMinimoMensal + product.premioMaximoMensal) / 2;
      basePremio = mid * ageFactor * ubiFactor * useFactor * territorialLoading;
      basePremio = basePremio.clamp(product.premioMinimoMensal, product.premioMaximoMensal);
      capital = capitalCustom ??
          ((product.capitalMinimoSegurado + product.capitalMaximoSegurado) / 2);
    }

    final relevancia = _calcRelevancia(product, uf, age, vehicleUse, ubiScore);

    return InsuranceQuote(
      id: 'QT-${DateTime.now().millisecondsSinceEpoch}-${_rng.nextInt(9999)}',
      userId: userId,
      line: product.line,
      product: product,
      premioMensal: basePremio,
      premioAnual: basePremio * 12 * 0.92,
      capitalSegurado: capital,
      fatorRisco: useFactor,
      fatorTerritorial: territorialLoading,
      fatorUbi: ubiFactor,
      fatorIdade: ageFactor,
      coberturasSelecionadas: selectedCoverages ?? product.coberturas.take(4).toList(),
      motivosRecomendacao: _buildMotivos(product, uf, ubiScore, age),
      scoreRelevancia: relevancia,
      geradaEm: DateTime.now(),
      validaAte: DateTime.now().add(const Duration(hours: 48)),
    );
  }

  static double _ageFactor(int age, String category) {
    if (category == 'Vida' || category == 'Acidente Pessoal' || category == 'Saúde') {
      if (age < 25) return 0.80;
      if (age < 35) return 1.00;
      if (age < 45) return 1.25;
      if (age < 55) return 1.60;
      if (age < 65) return 2.20;
      return 3.00;
    }
    if (category == 'Automóveis') {
      if (age < 25) return 1.40;
      if (age < 30) return 1.20;
      if (age < 60) return 1.00;
      return 1.10;
    }
    return 1.0;
  }

  static double _ubiFactor(double ubiScore, String category) {
    if (!['Automóveis', 'Motos e Micromobilidade', 'SafeRoute Exclusivo'].contains(category)) {
      return 1.0;
    }
    if (ubiScore >= 90) return 0.65;
    if (ubiScore >= 80) return 0.80;
    if (ubiScore >= 70) return 0.90;
    if (ubiScore >= 60) return 1.00;
    if (ubiScore >= 50) return 1.20;
    return 1.40;
  }

  static double _useFactor(String? use) {
    switch (use) {
      case 'app': return 1.30;
      case 'motoboy': return 1.50;
      case 'comercial': return 1.20;
      case 'lazer': return 0.90;
      default: return 1.00;
    }
  }

  static double _calcRelevancia(InsuranceProduct p, String? uf, int? age, String? vehicleUse, double? ubiScore) {
    double score = p.prioridadeRanking.toDouble();
    if (p.line.isExclusiveSafeRoute) score = math.min(score + 10, 100);
    if (p.line.isParametric) score = math.min(score + 5, 100);
    if (vehicleUse == 'motoboy' && p.line.category == 'Acidente Pessoal') score = math.min(score + 8, 100);
    return score;
  }

  static List<String> _buildMotivos(InsuranceProduct p, String? uf, double? ubiScore, int? age) {
    final motivos = <String>[];
    if (p.line.isExclusiveSafeRoute) motivos.add('Produto exclusivo SafeRoute com dados de comportamento real');
    if (p.line.isParametric) motivos.add('Pagamento automático sem burocracia — ${p.triggerDescricao ?? "trigger paramétrico"}');
    if (uf != null) motivos.add('Calibrado para ${uf} com fator territorial TRI');
    if ((ubiScore ?? 75) > 75) motivos.add('Bom motorista (UBI ${ubiScore?.toStringAsFixed(0)}) = prêmio reduzido');
    if ((age ?? 30) < 30) motivos.add('Idade jovem = prêmio de vida e AP mais baixo');
    motivos.add('Relação custo-benefício validada por dados actuariais SafeRoute');
    return motivos.take(4).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POLICY MANAGER
// ─────────────────────────────────────────────────────────────────────────────

class PolicyManager {
  static final List<InsurancePolicy> _policies = [];
  static final List<InsuranceClaim> _claims = [];
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;
    _seedDemoPolicies();
    _seedDemoClaims();
  }

  static void _seedDemoPolicies() {
    final now = DateTime.now();
    final products = ProductCatalog.all;
    final nomes = ['Carlos Silva', 'Ana Lima', 'João Santos', 'Maria Oliveira', 'Pedro Costa',
      'Fernanda Rocha', 'Bruno Alves', 'Carla Mendes', 'Rafael Torres', 'Juliana Nunes',
      'Thiago Barbosa', 'Priscila Castro', 'Lucas Ferreira', 'Amanda Souza', 'Felipe Gomes'];
    final statuses = [PolicyStatus.ativa, PolicyStatus.ativa, PolicyStatus.ativa, PolicyStatus.suspensa, PolicyStatus.expirada];
    final rng = math.Random(42);

    for (int i = 0; i < 15; i++) {
      final product = products[i % products.length];
      final inicio = now.subtract(Duration(days: rng.nextInt(365)));
      final premio = product.premioMinimoMensal + rng.nextDouble() * (product.premioMaximoMensal - product.premioMinimoMensal);
      _policies.add(InsurancePolicy(
        id: 'POL-${1000 + i}',
        numeroApolice: 'SR-2025-${(10000 + i).toString().padLeft(5, "0")}',
        userId: 'user-${100 + i}',
        nomeUsuario: nomes[i % nomes.length],
        line: product.line,
        product: product,
        premioMensal: product.premioMaximoMensal == 0 ? (15.0 + rng.nextDouble() * 80) : premio.clamp(product.premioMinimoMensal, product.premioMaximoMensal),
        capitalSegurado: product.capitalMinimoSegurado + rng.nextDouble() * (product.capitalMaximoSegurado - product.capitalMinimoSegurado),
        coberturas: product.coberturas.take(4).toList(),
        status: statuses[i % statuses.length],
        inicioVigencia: inicio,
        fimVigencia: inicio.add(const Duration(days: 365)),
        emitidaEm: inicio,
        totalSinistros: rng.nextInt(3),
        totalPago: rng.nextDouble() * 5000,
      ));
    }
  }

  static void _seedDemoClaims() {
    if (_policies.isEmpty) return;
    final rng = math.Random(42);
    final eventos = [
      'Colisão frontal detectada por GPS',
      'Roubo do veículo em zona TRI crítica',
      'Danos por enchente — precipitação 62mm/h INMET',
      'Fratura costela — queda de moto em entrega',
      'Furto celular em abordagem',
      'Ransomware — dados sequestrados',
      'Atraso de voo 3h45min — API confirmou',
      'Queda do telhado — granizo',
    ];
    final statuses = [ClaimStatus.pago, ClaimStatus.emAnalise, ClaimStatus.aprovado, ClaimStatus.aberto, ClaimStatus.negado];

    for (int i = 0; i < 8; i++) {
      final pol = _policies[i % _policies.length];
      final valorRec = 500.0 + rng.nextDouble() * 15000;
      final status = statuses[i % statuses.length];
      _claims.add(InsuranceClaim(
        id: 'CLM-${2000 + i}',
        numeroComunicado: 'SIN-2025-${(20000 + i).toString().padLeft(5, "0")}',
        policyId: pol.id,
        numeroApolice: pol.numeroApolice,
        userId: pol.userId,
        nomeUsuario: pol.nomeUsuario,
        line: pol.line,
        descricaoEvento: eventos[i % eventos.length],
        valorReclamado: valorRec,
        valorAprovado: status == ClaimStatus.pago || status == ClaimStatus.aprovado ? valorRec * 0.85 : null,
        status: status,
        aberturaEm: DateTime.now().subtract(Duration(days: rng.nextInt(60))),
        liquidacaoEm: status == ClaimStatus.pago ? DateTime.now().subtract(Duration(days: rng.nextInt(10))) : null,
        isParametric: pol.product.isParametric,
        triggerEvidencia: pol.product.isParametric ? 'Sensor GPS confirmado — dados validados automaticamente' : null,
      ));
    }
  }

  static InsurancePolicy emitir({required String userId, required String nomeUsuario, required InsuranceQuote quote}) {
    final now = DateTime.now();
    final policy = InsurancePolicy(
      id: 'POL-${_policies.length + 2000}',
      numeroApolice: 'SR-2025-${(_policies.length + 50000).toString().padLeft(5, "0")}',
      userId: userId,
      nomeUsuario: nomeUsuario,
      line: quote.line,
      product: quote.product,
      premioMensal: quote.premioMensal,
      capitalSegurado: quote.capitalSegurado,
      coberturas: quote.coberturasSelecionadas,
      status: PolicyStatus.ativa,
      inicioVigencia: now,
      fimVigencia: now.add(const Duration(days: 365)),
      emitidaEm: now,
    );
    _policies.add(policy);
    return policy;
  }

  static InsuranceClaim abrirSinistro({
    required InsurancePolicy policy,
    required String descricao,
    required double valorReclamado,
    bool isParametric = false,
    String? triggerEvidencia,
  }) {
    final claim = InsuranceClaim(
      id: 'CLM-${_claims.length + 3000}',
      numeroComunicado: 'SIN-2025-${(_claims.length + 90000).toString().padLeft(5, "0")}',
      policyId: policy.id,
      numeroApolice: policy.numeroApolice,
      userId: policy.userId,
      nomeUsuario: policy.nomeUsuario,
      line: policy.line,
      descricaoEvento: descricao,
      valorReclamado: valorReclamado,
      status: isParametric ? ClaimStatus.aprovado : ClaimStatus.aberto,
      aberturaEm: DateTime.now(),
      liquidacaoEm: isParametric ? DateTime.now().add(const Duration(hours: 2)) : null,
      valorAprovado: isParametric ? valorReclamado * 0.95 : null,
      isParametric: isParametric,
      triggerEvidencia: triggerEvidencia,
    );
    _claims.add(claim);
    policy.totalSinistros++;
    if (isParametric) policy.totalPago += valorReclamado * 0.95;
    return claim;
  }

  static List<InsurancePolicy> get policies => List.unmodifiable(_policies);
  static List<InsuranceClaim> get claims => List.unmodifiable(_claims);
  static int get totalAtivas => _policies.where((p) => p.status == PolicyStatus.ativa).length;
  static int get totalSinistros => _claims.length;
  static double get premioMensalTotal => _policies
      .where((p) => p.status == PolicyStatus.ativa)
      .fold(0, (s, p) => s + p.premioMensal);
  static double get totalSinistroPago => _claims.fold(0, (s, c) => s + (c.valorAprovado ?? 0));
  // Aliases usados em admin_screens.dart
  static double get totalPago => totalSinistroPago;
  static double get totalReclamado => _claims.fold(0, (s, c) => s + c.valorReclamado);
  static double get sinistralidade => premioMensalTotal * 12 > 0
      ? (totalSinistroPago / (premioMensalTotal * 12) * 100).clamp(0, 200)
      : 0;
  static Map<String, int> get policiesByCategory {
    final m = <String, int>{};
    for (final p in _policies.where((p) => p.status == PolicyStatus.ativa)) {
      final cat = p.line.category;
      m[cat] = (m[cat] ?? 0) + 1;
    }
    return m;
  }
  static Map<String, double> get premioByCategory {
    final m = <String, double>{};
    for (final p in _policies.where((p) => p.status == PolicyStatus.ativa)) {
      final cat = p.line.category;
      m[cat] = (m[cat] ?? 0) + p.premioMensal;
    }
    return m;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSURANCE SEARCH ENGINE — SINGLETON PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class InsuranceSearchEngine {
  InsuranceSearchEngine._();
  static final instance = InsuranceSearchEngine._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      PolicyManager.init();
      _initialized = true;
      if (kDebugMode) debugPrint('[SISE] Motor inicializado — ${ProductCatalog.totalLines} ramos, ${ProductCatalog.totalProducts} produtos');
    } catch (e) {
      if (kDebugMode) debugPrint('[SISE] Erro init: $e');
    }
  }

  Future<List<InsuranceQuote>> searchAndQuote({
    required String userId,
    String? uf,
    int? age,
    String? gender,
    String? vehicleUse,
    double? ubiScore,
    double? fipeValue,
    String? cep,
    bool temPet = false,
    bool temFilhos = false,
    bool proprietarioImovel = false,
    double? rendaMensal,
    String? profissao,
    double? nightTripRatio,
    int? totalTrips,
  }) async {
    await init();

    final needs = NeedsDetectorEngine.detect(
      userId: userId, uf: uf, age: age, gender: gender,
      vehicleUse: vehicleUse, ubiScore: ubiScore,
      nightTripRatio: nightTripRatio, totalTrips: totalTrips ?? 10,
      temPet: temPet, temFilhos: temFilhos,
      proprietarioImovel: proprietarioImovel,
      rendaMensal: rendaMensal, profissao: profissao,
    );

    final quotes = <InsuranceQuote>[];
    for (final need in needs) {
      final q = QuoteEngine.generateQuote(
        userId: userId, product: need.product, uf: uf, age: age,
        gender: gender, vehicleUse: vehicleUse, ubiScore: ubiScore,
        fipeValue: fipeValue, cep: cep,
      );
      quotes.add(q);
    }

    quotes.sort((a, b) => b.scoreRelevancia.compareTo(a.scoreRelevancia));
    return quotes;
  }

  bool get isInitialized => _initialized;
  int get totalRamos => ProductCatalog.totalLines;
  int get totalProdutos => ProductCatalog.totalProducts;
}
