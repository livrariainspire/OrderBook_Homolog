<template>
  <div>
    <div class="cabecalho">
      <div>
        <h1>Omie</h1>
        <p>Estoque da livraria na Omie e ligação com o catálogo do Order Book.</p>
      </div>
      <div style="display:flex;gap:8px">
        <button class="btn btn-neutro btn-p" :disabled="ocupado" @click="corrigir">
          Corrigir descrições
        </button>
        <button class="btn btn-neutro btn-p" :disabled="ocupado" @click="importar">
          {{ importando ? 'Importando...' : 'Importar da Omie' }}
        </button>
        <button class="btn btn-principal btn-p" :disabled="ocupado" @click="carregar">
          {{ carregando ? 'Consultando...' : 'Atualizar' }}
        </button>
      </div>
    </div>
    <div v-if="msg" class="aviso" :class="erro ? 'aviso-erro' : 'aviso-ok'">{{ msg }}</div>
    <div v-if="dados?.aviso_estoque" class="aviso aviso-erro">
      A Omie respondeu o cadastro de produtos, mas recusou a consulta de saldo:
      {{ dados.aviso_estoque }}
    </div>

    <div v-if="carregando" class="carregando">Consultando a Omie...</div>

    <template v-else-if="dados">
      <div class="grade-3" style="margin-bottom:16px">
        <div class="cartao">
          <span class="rotulo">Produtos na Omie</span>
          <strong style="font-size:28px">{{ dados.total_omie }}</strong>
        </div>
        <div class="cartao">
          <span class="rotulo">Produtos no catálogo</span>
          <strong style="font-size:28px">{{ dados.total_catalogo }}</strong>
        </div>
        <div class="cartao">
          <span class="rotulo">Ainda sem ligação</span>
          <strong style="font-size:28px">{{ dados.so_no_order_book.length }}</strong>
        </div>
      </div>

      <div class="painel">
        <div class="painel-topo">
          <h2>Estoque na Omie</h2>
          <input v-model="busca" class="campo" style="max-width:260px" placeholder="Buscar produto" />
        </div>

        <TabelaVazia v-if="!linhas.length" titulo="Nada encontrado"
          texto="Nenhum produto da Omie corresponde à busca." />

        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead>
              <tr>
                <th>Código</th><th>Descrição</th><th>Saldo</th>
                <th>Valor</th><th>Catálogo</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="l in linhas" :key="l.omie_id">
                <td><strong>{{ l.codigo || '—' }}</strong></td>
                <td>{{ l.descricao }}</td>
                <td>
                  <span v-if="l.saldo === null" class="selo selo-neutro">sem dado</span>
                  <strong v-else>{{ l.saldo }}</strong>
                </td>
                <td>{{ moeda(l.valor_unitario) }}</td>
                <td>
                  <span v-if="l.ligado_a" class="selo selo-enviado">{{ l.ligado_a.codigo }}</span>
                  <span v-else class="selo selo-neutro">não ligado</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="painel" style="margin-top:16px">
        <div class="painel-topo">
          <h2>Disponível para enviar às filiais</h2>
          <span class="rotulo">saldo na Omie menos o que já está nas filiais</span>
        </div>
        <TabelaVazia v-if="!dados.quadro?.length" titulo="Nenhum produto ligado"
          texto="Ligue os produtos à Omie para acompanhar o disponível." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead>
              <tr><th>Código</th><th>Título</th><th>Na Omie</th>
                  <th>Nas filiais</th><th>Disponível</th></tr>
            </thead>
            <tbody>
              <tr v-for="q in dados.quadro" :key="q.product_id">
                <td><strong>{{ q.codigo }}</strong></td>
                <td>{{ q.titulo }}</td>
                <td>{{ q.saldo_omie }}</td>
                <td>{{ q.alocado }}</td>
                <td>
                  <span class="selo" :class="Number(q.disponivel) > 0 ? 'selo-enviado' : 'selo-neutro'">
                    {{ q.disponivel }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="painel" style="margin-top:16px">
        <div class="painel-topo">
          <h2>Fora da Omie</h2>
          <span class="rotulo">serão desativados na próxima importação</span>
        </div>

        <TabelaVazia v-if="!dados.so_no_order_book.length" titulo="Tudo ligado"
          texto="Todo o catálogo veio da Omie." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead><tr><th>Código</th><th>Título</th></tr></thead>
            <tbody>
              <tr v-for="p in dados.so_no_order_book" :key="p.id">
                <td><strong>{{ p.codigo || '—' }}</strong></td>
                <td>{{ p.title }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const carregando = ref(false)
const msg = ref('')
const erro = ref(false)
const busca = ref('')
const dados = ref<any>(null)
const importando = ref(false)

const ocupado = computed(() => carregando.value || importando.value)

async function importar () {
  if (!confirm('Isto traz o cadastro da Omie para o catálogo do Order Book. Produtos que não existirem mais na Omie ficarão inativos. Continuar?')) return
  importando.value = true
  msg.value = ''
  erro.value = false
  try {
    const r = await chamarApi('/omie/importar')
    msg.value = `${r.novos.length} produto(s) novo(s), ${r.atualizados.length} atualizado(s), ${r.desativados.length} desativado(s).`
    await carregar()
  } catch (e: any) {
    erro.value = true
    msg.value = e.message || 'Não foi possível importar.'
  } finally {
    importando.value = false
  }
}

async function corrigir () {
  importando.value = true
  msg.value = ''
  erro.value = false
  try {
    const r = await chamarApi('/omie/corrigir-descricoes')
    msg.value = `${r.ajustados.length} descrição(ões) corrigida(s) na Omie.`
      + (r.falhas.length ? ` ${r.falhas.length} falhou(aram).` : '')
    await carregar()
  } catch (e: any) {
    erro.value = true
    msg.value = e.message || 'Não foi possível corrigir.'
  } finally {
    importando.value = false
  }
}

async function carregar () {
  carregando.value = true
  msg.value = ''
  erro.value = false
  try {
    dados.value = await chamarApi('/omie/estoque')
  } catch (e: any) {
    erro.value = true
    msg.value = e.message || 'Não foi possível consultar a Omie.'
  } finally {
    carregando.value = false
  }
}

onMounted(carregar)
</script>
