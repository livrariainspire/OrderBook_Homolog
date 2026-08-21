<template>
  <div>
    <div class="cabecalho">
      <div><h1>Relatórios</h1><p>Vendas por filial e onde cada produto está guardado.</p></div>
    </div>

    <div class="painel">
      <div class="painel-topo">
        <h2>Vendas por filial</h2>
        <div class="linha-acoes">
          <input v-model="de" class="campo" type="date" style="max-width:170px" />
          <input v-model="ate" class="campo" type="date" style="max-width:170px" />
          <button class="btn btn-contorno btn-p" @click="carregarVendas">Aplicar</button>
          <button class="btn btn-neutro btn-p" @click="baixar('vendas')">Baixar CSV</button>
        </div>
      </div>
      <TabelaVazia v-if="!vendas.length" titulo="Sem vendas no periodo" texto="Ajuste as datas ou aguarde novos registros." />
      <div v-else class="tabela-rolagem">
        <table class="lista">
          <thead><tr><th>Filial</th><th>Tipo</th><th>Vendas</th><th>Itens</th><th>Total</th></tr></thead>
          <tbody>
            <tr v-for="v in vendas" :key="v.unit_id">
              <td><strong>{{ v.unit_name }}</strong></td>
              <td>{{ v.unit_type === 'igreja' ? 'Igreja da Rede' : 'Ponto de Partida' }}</td>
              <td>{{ v.vendas }}</td>
              <td>{{ v.itens }}</td>
              <td><strong>{{ moeda(v.total) }}</strong></td>
            </tr>
            <tr>
              <td colspan="2"><strong>Total geral</strong></td>
              <td><strong>{{ somaVendas }}</strong></td>
              <td><strong>{{ somaItens }}</strong></td>
              <td><strong>{{ moeda(somaTotal) }}</strong></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="painel">
      <div class="painel-topo">
        <h2>Onde está o estoque</h2>
        <div class="linha-acoes">
          <input v-model="filtroEstoque" class="campo" style="max-width:240px" type="search" placeholder="Produto ou filial" />
          <button class="btn btn-neutro btn-p" @click="baixar('estoque')">Baixar CSV</button>
        </div>
      </div>
      <TabelaVazia v-if="!estoqueFiltrado.length" titulo="Nenhum item em estoque" texto="Nada encontrado." />
      <div v-else class="tabela-rolagem">
        <table class="lista">
          <thead><tr><th>Filial</th><th>Tipo</th><th>Produto</th><th>Quantidade</th></tr></thead>
          <tbody>
            <tr v-for="(e, i) in estoqueFiltrado" :key="i">
              <td><strong>{{ e.unit_name }}</strong></td>
              <td>{{ e.unit_type === 'igreja' ? 'Igreja da Rede' : 'Ponto de Partida' }}</td>
              <td>{{ e.product_title }}</td>
              <td><strong>{{ e.qty }}</strong></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const vendas = ref<any[]>([])
const estoque = ref<any[]>([])
const de = ref(''); const ate = ref(''); const filtroEstoque = ref('')

const somaVendas = computed(() => vendas.value.reduce((s, v) => s + Number(v.vendas), 0))
const somaItens = computed(() => vendas.value.reduce((s, v) => s + Number(v.itens), 0))
const somaTotal = computed(() => vendas.value.reduce((s, v) => s + Number(v.total), 0))

const estoqueFiltrado = computed(() => {
  const t = filtroEstoque.value.trim().toLowerCase()
  if (!t) return estoque.value
  return estoque.value.filter(e => `${e.unit_name} ${e.product_title}`.toLowerCase().includes(t))
})

async function carregarVendas() {
  const { data } = await supa.rpc('fn_report_sales', { p_from: de.value || null, p_to: ate.value || null })
  vendas.value = (data ?? []).filter((v: any) => Number(v.vendas) > 0)
}

onMounted(async () => {
  await carregarVendas()
  const { data } = await supa.rpc('fn_report_stock')
  estoque.value = data ?? []
})

function baixar(qual: string) {
  const linhas = qual === 'vendas'
    ? [['Filial', 'Tipo', 'Vendas', 'Itens', 'Total'], ...vendas.value.map(v => [v.unit_name, v.unit_type, v.vendas, v.itens, v.total])]
    : [['Filial', 'Tipo', 'Produto', 'Quantidade'], ...estoqueFiltrado.value.map(e => [e.unit_name, e.unit_type, e.product_title, e.qty])]
  const csv = linhas.map(l => l.map((c: any) => `"${String(c ?? '').replace(/"/g, '""')}"`).join(';')).join('\n')
  const url = URL.createObjectURL(new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8' }))
  const a = document.createElement('a')
  a.href = url
  a.download = `inspire-${qual}-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}
</script>
