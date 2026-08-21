<template>
  <div>
    <div class="cabecalho">
      <div>
        <h1>Omie</h1>
        <p>O catálogo vem da Omie sozinho, a cada 10 minutos. Aqui você acompanha o estoque.</p>
      </div>
      <div style="display:flex;gap:8px">
        <button class="btn btn-neutro btn-p" :disabled="ocupado" @click="corrigir">
          Corrigir descrições
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
      <div class="grade-2" style="margin-bottom:16px">
        <div class="cartao">
          <span class="rotulo">Produtos na Omie</span>
          <strong style="font-size:28px">{{ dados.total_omie }}</strong>
        </div>
        <div class="cartao">
          <span class="rotulo">Produtos no catálogo</span>
          <strong style="font-size:28px">{{ dados.total_catalogo }}</strong>
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
          <h2>Onde está cada produto</h2>
          <span class="rotulo">Matriz = saldo na Omie menos o que está nas filiais</span>
        </div>
        <TabelaVazia v-if="!estoque.length" titulo="Sem dados"
          texto="Atualize a tela para consultar o estoque da Omie." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead>
              <tr><th>Código</th><th>Produto</th><th>Na Omie</th>
                  <th>Matriz</th><th>Nas filiais</th></tr>
            </thead>
            <tbody>
              <tr v-for="p in estoque" :key="p.product_id">
                <td><strong>{{ p.codigo }}</strong></td>
                <td>{{ p.titulo }}</td>
                <td>{{ p.saldo_omie }}</td>
                <td>
                  <span class="selo" :class="Number(p.matriz) > 0 ? 'selo-enviado' : 'selo-neutro'">
                    {{ p.matriz }}
                  </span>
                </td>
                <td>
                  <span v-if="!p.filiais.length" class="rotulo">—</span>
                  <span v-for="f in p.filiais" :key="f.filial" class="selo selo-laranja"
                        style="margin-right:6px">
                    {{ f.filial }}: {{ f.qtd }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="painel" style="margin-top:16px">
        <div class="painel-topo">
          <h2>Vendas enviadas à Omie</h2>
          <span class="rotulo">sobem sozinhas assim que a venda é registrada</span>
        </div>

        <TabelaVazia v-if="!vendas.length" titulo="Nenhuma venda"
          texto="As vendas registradas pelas filiais aparecem aqui." />

        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead>
              <tr><th>Venda</th><th>Filial</th><th>Total</th>
                  <th>Situação</th><th>Observação</th></tr>
            </thead>
            <tbody>
              <tr v-for="v in vendas" :key="v.id">
                <td><strong>{{ v.code || '—' }}</strong></td>
                <td>{{ v.unit_name }}</td>
                <td>{{ moeda(v.total) }}</td>
                <td>
                  <span class="selo" :class="v.omie_status === 'faturado' ? 'selo-enviado'
                        : v.omie_status === 'erro' ? 'selo-cancelado' : 'selo-neutro'">
                    {{ v.omie_status }}
                  </span>
                </td>
                <td>{{ v.omie_erro || (v.omie_numero ? 'Pedido ' + v.omie_numero : '—') }}</td>
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
const vendas = ref<any[]>([])
const estoque = ref<any[]>([])

async function carregarEstoque () {
  const { data } = await useSupa().rpc('fn_estoque_geral')
  estoque.value = data ?? []
}

async function carregarVendas () {
  const { data } = await useSupa().rpc('fn_omie_vendas')
  vendas.value = data ?? []
}

const ocupado = computed(() => carregando.value || importando.value)

const moeda = (v: any) =>
  v === null || v === undefined || v === ''
    ? '—'
    : Number(v).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })

const linhas = computed(() => {
  const t = busca.value.trim().toLowerCase()
  const todas = dados.value?.linhas ?? []
  if (!t) return todas
  return todas.filter((l: any) =>
    String(l.descricao ?? '').toLowerCase().includes(t) ||
    String(l.codigo ?? '').toLowerCase().includes(t))
})

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
    await carregarEstoque()
    await carregarVendas()
  } catch (e: any) {
    erro.value = true
    msg.value = e.message || 'Não foi possível consultar a Omie.'
  } finally {
    carregando.value = false
  }
}

onMounted(() => { carregar(); carregarVendas(); carregarEstoque() })
</script>
