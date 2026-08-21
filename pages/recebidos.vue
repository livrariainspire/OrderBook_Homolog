<template>
  <div>
    <div class="cabecalho">
      <div>
        <h1>Material recebido</h1>
        <p>Tudo o que a livraria já entregou para a sua filial.</p>
      </div>
      <NuxtLink to="/pedidos/novo" class="btn btn-principal btn-p">Fazer um pedido</NuxtLink>
    </div>

    <div v-if="carregando" class="carregando">Carregando entregas...</div>

    <template v-else>
      <div class="resumos">
        <div class="resumo">
          <div class="resumo-rotulo">Itens recebidos</div>
          <div class="resumo-valor">{{ totalItens }}</div>
          <div class="resumo-nota">Somando todas as entregas</div>
        </div>
        <div class="resumo">
          <div class="resumo-rotulo">Títulos diferentes</div>
          <div class="resumo-valor">{{ linhas.length }}</div>
          <div class="resumo-nota">Livros e demais itens</div>
        </div>
      </div>

      <div class="painel">
        <div class="painel-topo">
          <h2>Histórico de entregas</h2>
          <input v-model="filtro" class="campo" style="max-width:260px" type="search"
                 placeholder="Filtrar pelo nome" />
        </div>
        <TabelaVazia v-if="!filtradas.length" titulo="Nada recebido ainda"
          texto="Assim que a livraria enviar um pedido e você confirmar o recebimento, aparece aqui." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead>
              <tr><th>Produto</th><th>Tipo</th><th>Quantidade</th><th>Última entrega</th></tr>
            </thead>
            <tbody>
              <tr v-for="l in filtradas" :key="l.product_id">
                <td>
                  <div class="produto-linha">
                    <FotoProduto :url="l.photo_url" :titulo="l.product_title" :tipo="l.product_type" />
                    <div>
                      <div class="produto-nome">{{ l.product_title }}</div>
                      <div class="produto-meta">
                        {{ [l.author, l.edition].filter(Boolean).join(' · ') || '—' }}
                      </div>
                    </div>
                  </div>
                </td>
                <td><span class="selo selo-neutro">{{ l.product_type === 'livro' ? 'Livro' : 'Item' }}</span></td>
                <td><strong style="font-size:16px">{{ l.total_recebido }}</strong></td>
                <td>{{ dataCurta(l.ultima_entrega) }}</td>
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

const supa = useSupa()
const linhas = ref<any[]>([])
const carregando = ref(true)
const filtro = ref('')

const totalItens = computed(() => linhas.value.reduce((s, l) => s + Number(l.total_recebido), 0))

const filtradas = computed(() => {
  const t = filtro.value.trim().toLowerCase()
  if (!t) return linhas.value
  return linhas.value.filter(l => (l.product_title || '').toLowerCase().includes(t))
})

onMounted(async () => {
  const { data } = await supa.rpc('fn_entregas_filial', { p_unit: null })
  linhas.value = data ?? []
  carregando.value = false
})
</script>
