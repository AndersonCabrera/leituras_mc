/**
 * SCRIPT DE LIMPEZA - Remover leituras com fotos falhadas que não existem mais
 * 
 * USO:
 *   1. npm install firebase-admin
 *   2. node scripts/limpar_fotos_falhadas.js [caminho/do/serviceAccountKey.json]
 * 
 * Este script:
 * 1. Busca TODAS as leituras com tem_foto_anexada=true mas sem url_foto
 * 2. Mostra quantas encontrou e pede confirmação
 * 3. Remove os documentos do Firestore (ou apenas limpa os campos de foto)
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const readline = require('readline');

function resolveServiceAccountPath() {
  // Verificar se o primeiro argumento é um caminho de arquivo (contém .json ou caminho absoluto)
  const argPath = process.argv[2];
  const argOpcao = process.argv[3];
  
  // Se o primeiro argumento parece ser um arquivo de credenciais
  if (argPath && (argPath.endsWith('.json') || argPath.includes(':\\') || argPath.includes('/'))) {
    const resolved = path.resolve(argPath);
    if (fs.existsSync(resolved)) return resolved;
    console.error('❌ Arquivo não encontrado: ' + resolved);
    process.exit(1);
  }
  // Senão, o primeiro argumento é a opção (1 ou 2), procurar credenciais nos locais padrão

  const baseDir = __dirname;
  const tentativas = [
    path.join(baseDir, '..', 'serviceAccountKey.json'),
    path.join(baseDir, 'serviceAccountKey.json'),
    path.join(baseDir, '..', '..', 'serviceAccountKey.json'),
  ];

  for (const p of tentativas) {
    if (fs.existsSync(p)) {
      console.log('✅ Credenciais encontradas em: ' + p);
      return p;
    }
  }

  console.error('❌ serviceAccountKey.json NÃO ENCONTRADO!');
  console.error('\nLocais verificados:');
  tentativas.forEach(p => console.error('  - ' + p));
  console.error('\nSoluções:');
  console.error('  1. Coloque na raiz: E:\\APP Leituras MC\\leituras_mc\\serviceAccountKey.json');
  console.error('  2. Ou passe o caminho: node limpar_fotos_falhadas.js "C:\\caminho\\serviceAccountKey.json"');
  process.exit(1);
}

const serviceAccountPath = resolveServiceAccountPath();
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

function perguntar(pergunta) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  return new Promise(resolve => rl.question(pergunta, resposta => {
    rl.close();
    resolve(resposta.trim().toLowerCase());
  }));
}

async function limparFotosFalhadas() {
  console.log('');
  console.log('🔍 Buscando leituras com fotos falhadas...');
  console.log('');

  // Aceitar argumentos: node script.js [serviceAccountPath] [opcao] [confirmacao]
  // Se serviceAccountPath não for .json, entende que é opcao
  const args = process.argv.slice(2);
  let serviceAccountArg = null;
  let opcaoArg = null;
  let confirmacaoArg = null;
  
  if (args.length >= 1) {
    if (args[0].endsWith('.json') || args[0].includes(':\\') || args[0].includes('/')) {
      serviceAccountArg = args[0];
      opcaoArg = args[1];
      confirmacaoArg = args[2];
    } else {
      opcaoArg = args[0];
      confirmacaoArg = args[1];
    }
  }

  try {
    // Buscar leituras com tem_foto_anexada=true mas sem url_foto
    const snapshot = await db.collection('leituras')
      .where('tem_foto_anexada', '==', true)
      .get();

    console.log('📊 Total de leituras com tem_foto_anexada=true: ' + snapshot.size);

    const docsParaLimpar = [];
    
    for (const doc of snapshot.docs) {
      const dados = doc.data();
      const temUrlFoto = dados.url_foto && dados.url_foto !== '';
      const temErro = dados.erro_sincronizacao_foto === true;
      
      // Se tem foto anexada mas NÃO tem url_foto (falhou ou nunca enviou)
      if (!temUrlFoto) {
        docsParaLimpar.push({
          id: doc.id,
          ref: doc.ref,
          condominio: dados.condominio,
          apartamento: dados.apartamento,
          medidor: dados.medidor,
          temErro: temErro,
          mensagemErro: dados.mensagem_erro || 'Sem mensagem',
          dataHora: dados.data_hora
        });
      }
    }

    console.log('');
    console.log('⚠️  Leituras com foto falhada/sem url_foto: ' + docsParaLimpar.length);
    console.log('');

    if (docsParaLimpar.length === 0) {
      console.log('✅ Nenhuma leitura para limpar!');
      process.exit(0);
    }

    // Mostrar primeiras 10
    console.log('📋 Exemplos (primeiras 10):');
    docsParaLimpar.slice(0, 10).forEach((d, i) => {
      console.log('  ' + (i+1) + '. ' + d.condominio + ' - Apto ' + d.apartamento + ' - ' + d.medidor);
      console.log('     ID: ' + d.id);
      console.log('     Erro: ' + (d.temErro ? 'SIM - ' + d.mensagemErro : 'Sem erro marcado'));
      console.log('');
    });

    if (docsParaLimpar.length > 10) {
      console.log('  ... e mais ' + (docsParaLimpar.length - 10) + ' leituras');
      console.log('');
    }

    // Usar argumentos ou modo interativo
    let opcao = opcaoArg;
    let confirmacao = confirmacaoArg;

    if (!opcao) {
      console.log('⚠️  OPÇÕES:');
      console.log('  1. DELETAR os documentos completamente (recomendado se a leitura não serve)');
      console.log('  2. LIMPAR apenas campos de foto (manter leitura, remover tem_foto_anexada, erro, etc)');
      console.log('  3. CANCELAR');
      console.log('');

      opcao = await perguntar('Escolha (1/2/3): ');

      if (opcao === '3' || opcao === 'cancelar' || opcao === 'c') {
        console.log('❌ Cancelado pelo usuário');
        process.exit(0);
      }

      confirmacao = await perguntar('Tem certeza? Digite "SIM" para confirmar: ');
    }

    if (confirmacao !== 'sim' && confirmacao !== 's' && confirmacao !== 'SIM') {
      console.log('❌ Cancelado - confirmação não recebida');
      process.exit(0);
    }

    if (opcao !== '1' && opcao !== '2') {
      console.log('❌ Opção inválida. Use 1 ou 2.');
      process.exit(1);
    }

    console.log('');
    console.log('🔄 Processando...');
    console.log('');

    let processados = 0;
    let erros = 0;
    const batchSize = 500;
    const batches = [];

    for (let i = 0; i < docsParaLimpar.length; i += batchSize) {
      batches.push(docsParaLimpar.slice(i, i + batchSize));
    }

    for (const batch of batches) {
      const writeBatch = db.batch();
      
      for (const item of batch) {
        if (opcao === '1') {
          // DELETAR documento
          writeBatch.delete(item.ref);
        } else if (opcao === '2') {
          // LIMPAR apenas campos de foto
          writeBatch.update(item.ref, {
            tem_foto_anexada: false,
            url_foto: admin.firestore.FieldValue.delete(),
            erro_sincronizacao_foto: admin.firestore.FieldValue.delete(),
            mensagem_erro: admin.firestore.FieldValue.delete(),
            caminho_foto_local: admin.firestore.FieldValue.delete(),
          });
        }
        processados++;
      }

      try {
        await writeBatch.commit();
        console.log('✅ Batch de ' + batch.length + ' processado (total: ' + processados + '/' + docsParaLimpar.length + ')');
      } catch (e) {
        console.error('❌ Erro no batch: ' + e.message);
        erros += batch.length;
      }
    }

    console.log('');
    console.log('='.repeat(50));
    console.log('📊 RELATÓRIO DE LIMPEZA');
    console.log('='.repeat(50));
    console.log('Total encontradas:    ' + docsParaLimpar.length);
    console.log('Processadas com sucesso: ' + (processados - erros));
    console.log('Erros:                ' + erros);
    console.log('Ação:                 ' + (opcao === '1' ? 'DELETAR documentos' : 'LIMPAR campos de foto'));
    console.log('='.repeat(50));

    // Salvar relatório
    const relatorio = {
      data: new Date().toISOString(),
      acao: opcao === '1' ? 'DELETE' : 'CLEAN_FIELDS',
      totalEncontradas: docsParaLimpar.length,
      processadas: processados - erros,
      erros: erros,
      detalhes: docsParaLimpar.map(d => ({
        id: d.id,
        condominio: d.condominio,
        apartamento: d.apartamento,
        medidor: d.medidor,
        temErro: d.temErro,
        mensagemErro: d.mensagemErro
      }))
    };

    const fs = require('fs');
    const caminhoRelatorio = path.join(__dirname, 'relatorio_limpeza_fotos_' + Date.now() + '.json');
    fs.writeFileSync(caminhoRelatorio, JSON.stringify(relatorio, null, 2));
    console.log('');
    console.log('💾 Relatório salvo em: ' + caminhoRelatorio);

  } catch (erro) {
    console.error('❌ Erro fatal:', erro);
  }

  process.exit(0);
}

limparFotosFalhadas();