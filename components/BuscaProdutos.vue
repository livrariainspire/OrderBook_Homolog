<template>
  <div>
    <div class="busca">
      <span class="busca-icone">&#128269;</span>
      <input
        v-model="termo"
        class="campo"
        type="search"
        :placeholder="placeholder"
        @input="buscarComEspera"
      />
    </div>

    <div class="entre" style="margin-top:12px">
      <span class="mini">
        <template v-if="carregando">Carregando...</template>
        <template v-else-if="termo.trim().length >= 2">
          {{ resultados.length }} resultado(s) para "{{ termo.trim() }}"
        </template>
        <template v-else-if="somenteComEstoque">
          {{ resultados.length }} produto(s) disponíveis no seu estoque
        </template>
        <template v-else>
          {{ resultados.length }} produto(s) liberados para sua filial
        </template>
      </span>
      <button v-if="termo" class="btn-linha" @click="limpar">Limpar busca</button>
    </div>

    <div v-if="!carregando && resultados.length" style="margin-top:8px">
      <div v-for="p in resultados" :key="p.id" class="carrinho-item">
        <FotoProduto :url="p.photo_url" :titulo="p.title" :tipo="p.type" />
        <div class="cresce">
          <div class="produto-nome">{{ p.title }}</div>
          <div class="produto-meta">
            <template v-if="somenteComEstoque">Em estoque: {{ p.estoque }}</template>
            <template v-else>{{ detalhe(p) }}</template>
          </div>
          <div v-if="p.summary" class="produto-resumo">{{ resumoCurto(p.summary) }}</div>
        </div>
        <button class="btn btn-contorno btn-p" :disabled="escolhidos.includes(p.id)" @click="$emit('escolher', p)">
          {{ escolhidos.includes(p.id) ? 'Já incluído' : 'Adicionar' }}
        </button>
      </div>
    </div>

    <TabelaVazia
      v-else-if="!carregando"
      :titulo="termo.trim().length >= 2 ? 'Nada encontrado' : (somenteComEstoque ? 'Estoque vazio' : 'Nenhum produto liberado')"
      :texto="vazioTexto" />
  </div>
</template>

<script setup lang="ts">
const props = withDefaults(defineProps<{
  somenteComEstoque?: boolean
  unidadeId?: string | null
  escolhidos?: string[]
}>(), { escolhidos: () => [] })

defineEmits(['escolher'])

const supa = useSupa()
const termo = ref('')
const resultados = ref<any[]>([])
const carregando = ref(true)
let temporizador: any = null

const placeholder = computed(() => props.somenteComEstoque
  ? 'Buscar no seu estoque'
  : 'Buscar por titulo, autor, edição ou resumo')

const vazioTexto = computed(() => {
  if (termo.value.trim().length >= 2) return 'Tente outra palavra do titulo, do autor ou do resumo.'
  if (props.somenteComEstoque) return 'Você ainda não recebeu nenhum produto da livraria.'
  return 'A administração ainda não liberou produtos para o seu perfil.'
})

const detalhe = (p: any) => {
  const partes = [p.author, p.edition].filter(Boolean)
  if (partes.length) return partes.join(' · ')
  return p.type === 'livro' ? 'Livro' : 'Item da livraria'
}

const resumoCurto = (s: string) => s.length > 190 ? s.slice(0, 190).trimEnd() + '...' : s

function buscarComEspera() {
  clearTimeout(temporizador)
  temporizador = setTimeout(buscar, 280)
}

function limpar() { termo.value = ''; buscar() }

async function buscar() {
  const t = termo.value.trim().toLowerCase()
  if (t.length === 1) return
  carregando.value = true

  if (props.somenteComEstoque && props.unidadeId) {
    let q = supa
      .from('stock')
      .select('qty, products!inner(id,title,author,edition,summary,photo_url,type)')
      .eq('unit_id', props.unidadeId)
      .gt('qty', 0)
    if (t) q = q.ilike('products.search_text', `%${t}%`)
    const { data } = await q.limit(200)
    resultados.value = (data ?? [])
      .map((r: any) => ({ ...r.products, estoque: r.qty }))
      .sort((a: any, b: any) => a.title.localeCompare(b.title, 'pt-BR'))
  } else {
    let q = supa
      .from('products')
      .select('id,title,author,edition,summary,photo_url,type')
      .eq('active', true)
    if (t) q = q.ilike('search_text', `%${t}%`)
    const { data } = await q.order('title').limit(300)
    resultados.value = data ?? []
  }
  carregando.value = false
}

onMounted(buscar)
watch(() => props.unidadeId, buscar)

defineExpose({ recarregar: buscar })
</script>
