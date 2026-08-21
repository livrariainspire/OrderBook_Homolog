<template>
  <div>
    <div class="cabecalho">
      <div><h1>Meu estoque</h1><p>O que sua filial recebeu e ainda não vendeu.</p></div>
      <NuxtLink to="/vendas/nova" class="btn btn-principal btn-p">Registrar venda</NuxtLink>
    </div>

    <div v-if="carregando" class="carregando">Carregando estoque...</div>

    <div v-else class="painel">
      <div class="painel-topo">
        <h2>{{ linhas.length }} produto(s) em estoque</h2>
        <input v-model="filtro" class="campo" style="max-width:260px" type="search" placeholder="Filtrar pelo nome" />
      </div>
      <TabelaVazia v-if="!filtradas.length" titulo="Estoque vazio"
        texto="Assim que um pedido for enviado pela livraria, os itens entram aqui." />
      <div v-else class="tabela-rolagem">
        <table class="lista">
          <thead><tr><th>Produto</th><th>Tipo</th><th>Quantidade</th><th>Atualizado</th></tr></thead>
          <tbody>
            <tr v-for="l in filtradas" :key="l.product_id">
              <td>
                <div class="produto-linha">
                  <FotoProduto :url="l.products.photo_url" :titulo="l.products.title" :tipo="l.products.type" />
                  <div>
                    <div class="produto-nome">{{ l.products.title }}</div>
                    <div class="produto-meta">{{ [l.products.author, l.products.edition].filter(Boolean).join(' · ') || '—' }}</div>
                  </div>
                </div>
              </td>
              <td><span class="selo selo-neutro">{{ l.products.type === 'livro' ? 'Livro' : 'Item' }}</span></td>
              <td><strong style="font-size:16px">{{ l.qty }}</strong></td>
              <td>{{ dataHora(l.updated_at) }}</td>
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
const sessao = useSessao()
const linhas = ref<any[]>([])
const carregando = ref(true)
const filtro = ref('')

const filtradas = computed(() => {
  const t = filtro.value.trim().toLowerCase()
  if (!t) return linhas.value
  return linhas.value.filter(l => (l.products.title || '').toLowerCase().includes(t))
})

onMounted(async () => {
  const { data } = await supa
    .from('stock')
    .select('qty, updated_at, product_id, products(id,title,author,edition,photo_url,type)')
    .eq('unit_id', sessao.value.perfil?.unit_id)
    .gt('qty', 0)
  linhas.value = (data ?? []).sort((a: any, b: any) => a.products.title.localeCompare(b.products.title))
  carregando.value = false
})
</script>
