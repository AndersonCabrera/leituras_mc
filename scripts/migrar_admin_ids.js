/**
 * SCRIPT DE MIGRAÇÃO - Corrigir IDs de Administradora
 * 
 * USO:
 *   1. npm install firebase-admin
 *   2. node migrar_admin_ids.js [caminho/do/serviceAccountKey.json]
 * 
 * Se não passar o caminho, procura automaticamente em:
 *   - ../serviceAccountKey.json (raiz do projeto)
 *   - ./serviceAccountKey.json (pasta scripts)
 *   - ../../serviceAccountKey.json
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

function resolveServiceAccountPath() {
  const argPath = process.argv[2];
  if (argPath) {
    const resolved = path.resolve(argPath);
    if (fs.existsSync(resolved)) return resolved;
    console.error('❌ Arquivo não encontrado: ' + resolved);
    process.exit(1);
  }

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
  console.error('');
  console.error('Locais verificados:');
  tentativas.forEach(p => console.error('  - ' + p));
  console.error('');
  console.error('Soluções:');
  console.error('  1. Coloque na raiz: E:\\APP Leituras MC\\leituras_mc\\serviceAccountKey.json');
  console.error('  2. Ou passe o caminho: node migrar_admin_ids.js "C:\\caminho\\serviceAccountKey.json"');
  process.exit(1);
}

const serviceAccountPath = resolveServiceAccountPath();
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function migrarAdminIds() {
  console.log('');
  console.log('🔄 Iniciando migração de IDs de administradora...');
  console.log('');

  const stats = {
    totalPredios: 0,
    corrigidos: 0,
    jaCorretos: 0,
    erros: 0,
    detalhes: [],
  };

  try {
    // 1. Buscar todos os prédios
    const prediosSnapshot = await db.collection('predios').get();
    stats.totalPredios = prediosSnapshot.size;
    console.log('📊 Total de prédios encontrados: ' + stats.totalPredios);
    console.log('');

    // 2. Buscar mapeamento nome_predio -> id_administradora dos prédios já corretos
    const mapaPrediosCorretos = new Map();
    for (const doc of prediosSnapshot.docs) {
      const dados = doc.data();
      if (dados.id_administradora && dados.id_administradora !== '') {
        const nome = (dados.nome_predio || dados.nome || '').toLowerCase();
        if (nome) {
          mapaPrediosCorretos.set(nome, dados.id_administradora);
        }
      }
    }

    // 3. Processar cada prédio
    for (const doc of prediosSnapshot.docs) {
      const dados = doc.data();
      const predioId = doc.id;
      const nome = dados.nome_predio || dados.nome || 'Sem nome';
      let adminId = dados.admin_id;
      let idAdmin = dados.id_administradora;
      let alterado = false;
      let motivo = '';

      if ((!adminId || adminId === '') && (!idAdmin || idAdmin === '')) {
        const nomeLower = nome.toLowerCase();
        if (mapaPrediosCorretos.has(nomeLower)) {
          const adminCorreto = mapaPrediosCorretos.get(nomeLower);
          adminId = adminCorreto;
          idAdmin = adminCorreto;
          motivo = 'Mapeado por nome "' + nome + '" → ' + adminCorreto;
          alterado = true;
        } else {
          motivo = '⚠️ Sem admin_id nem id_administradora e sem correspondência por nome';
        }
      } else if (idAdmin === '' || idAdmin === null || idAdmin === undefined) {
        idAdmin = adminId;
        motivo = 'id_administradora vazio → copiado de admin_id (' + adminId + ')';
        alterado = true;
      } else if (adminId === '' || adminId === null || adminId === undefined) {
        adminId = idAdmin;
        motivo = 'admin_id vazio → copiado de id_administradora (' + idAdmin + ')';
        alterado = true;
      } else if (adminId !== idAdmin) {
        const adminAntigo = adminId;
        adminId = idAdmin;
        motivo = 'admin_id (' + adminAntigo + ') diferente de id_administradora (' + idAdmin + ') → unificado para ' + idAdmin;
        alterado = true;
      } else {
        stats.jaCorretos++;
        continue;
      }

      if (alterado) {
        try {
          await db.collection('predios').doc(predioId).update({
            admin_id: adminId,
            id_administradora: idAdmin,
          });

          stats.corrigidos++;
          stats.detalhes.push({
            id: predioId,
            nome: nome,
            admin_id: adminId,
            motivo: motivo,
          });

          console.log('✅ [' + stats.corrigidos + '] ' + predioId + ' - ' + nome);
          console.log('   ' + motivo);
        } catch (erro) {
          stats.erros++;
          console.error('❌ Erro ao corrigir ' + predioId + ': ' + erro.message);
        }
      }
    }

    // 4. Buscar leituras órfãs e vincular à administradora correta
    console.log('');
    console.log('🔄 Verificando leituras sem id_administradora...');
    console.log('');

    let leiturasCorrigidas = 0;

    try {
      const leiturasSnapshot = await db.collection('leituras')
        .where('id_administradora', '==', '')
        .get();

      for (const doc of leiturasSnapshot.docs) {
        const dados = doc.data();
        const condominio = (dados.condominio || '').toLowerCase();
        if (mapaPrediosCorretos.has(condominio)) {
          const adminCorreto = mapaPrediosCorretos.get(condominio);
          await doc.reference.update({ id_administradora: adminCorreto });
          leiturasCorrigidas++;
        }
      }
    } catch (e) {
      console.log('⚠️ Aviso ao buscar leituras vazias: ' + e.message);
    }

    console.log('✅ ' + leiturasCorrigidas + ' leituras corrigidas');

    // 5. Relatório final
    console.log('');
    console.log('============================================================');
    console.log('📊 RELATÓRIO DA MIGRAÇÃO');
    console.log('============================================================');
    console.log('Total de prédios:      ' + stats.totalPredios);
    console.log('Já corretos:           ' + stats.jaCorretos);
    console.log('Corrigidos:            ' + stats.corrigidos);
    console.log('Erros:                 ' + stats.erros);
    console.log('Leituras corrigidas:   ' + leiturasCorrigidas);
    console.log('============================================================');

    if (stats.detalhes.length > 0) {
      console.log('');
      console.log('📋 Detalhes das correções:');
      stats.detalhes.forEach((d, i) => {
        console.log('');
        console.log((i + 1) + '. ' + d.nome + ' (' + d.id + ')');
        console.log('   admin_id: ' + d.admin_id);
        console.log('   Motivo: ' + d.motivo);
      });
    }

    // 6. Salvar relatório em arquivo
    const relatorio = {
      data: new Date().toISOString(),
      stats: {
        totalPredios: stats.totalPredios,
        jaCorretos: stats.jaCorretos,
        corrigidos: stats.corrigidos,
        erros: stats.erros,
        leiturasCorrigidas: leiturasCorrigidas,
      },
      detalhes: stats.detalhes,
    };

    const caminhoRelatorio = path.join(__dirname, 'relatorio_migracao_' + Date.now() + '.json');
    fs.writeFileSync(caminhoRelatorio, JSON.stringify(relatorio, null, 2));
    console.log('');
    console.log('💾 Relatório salvo em: ' + caminhoRelatorio);

  } catch (erro) {
    console.error('❌ Erro fatal na migração:', erro);
  }

  process.exit(0);
}

migrarAdminIds();
