<template>
  <div>
    <div class="cabecalho">
      <div><h1>Registrar venda</h1><p>Informe o que foi vendido, o valor e anexe o comprovante. O estoque baixa automaticamente.</p></div>
    </div>

    <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>
    <div v-if="ok" class="aviso aviso-ok">
      Venda <strong>{{ ok }}</strong> registrada e estoque atualizado.
      <NuxtLink to="/vendas">Ver vendas</NuxtLink>
    </div>

    <div class="painel">
      <div class="painel-topo"><h2>1. Produtos vendidos</h2></div>
      <div class="painel-corpo">
        <BuscaProdutos somente-com-estoque :unidade-id="unidadeId" :escolhidos="carrinho.map((i: any) => i.id)" @escolher="adicionar" />
      </div>
    </div>

    <div class="painel">
      <div class="painel-topo">
        <h2>2. Quantidades e valores</h2>
        <strong style="font-size:16px">{{ moeda(total) }}</strong>
      </div>
      <div class="painel-corpo">
        <TabelaVazia v-if="!carrinho.length" titulo="Nenhum produto"
          texto="Busque acima entre os produtos disponíveis no seu estoque." />
        <template v-else>
          <div v-for="(i, idx) in carrinho" :key="i.id" class="carrinho-item">
            <FotoProduto :url="i.photo_url" :titulo="i.title" :tipo="i.type" />
            <div class="cresce">
              <div class="produto-nome">{{ i.title }}</div>
              <div class="produto-meta">Disponível: {{ i.estoque }}</div>
            </div>
            <div>
              <label class="rotulo" style="margin-bottom:4px">Qtd</label>
              <input v-model.number="i.qty" class="campo qtd" type="number" min="1" :max="i.estoque" />
            </div>
            <div>
              <label class="rotulo" style="margin-bottom:4px">Valor unitário</label>
              <input v-model.number="i.unit_price" class="campo preco" type="number" min="0" step="0.01" placeholder="0,00" />
            </div>
            <button class="btn-linha" style="color:var(--vermelho)" @click="carrinho.splice(idx,1)">Remover</button>
          </div>
        </template>
      </div>
    </div>

    <div class="painel">
      <div class="painel-topo"><h2>3. Comprovante</h2></div>
      <div class="painel-corpo">
        <EnvioFoto @arquivo="f => arquivo = f" />
        <div class="grupo" style="margin-top:18px">
          <label class="rotulo">Observação (opcional)</label>
          <textarea v-model="observacao" class="campo" placeholder="Ex.: venda no culto de domingo"></textarea>
        </div>
        <button class="btn btn-principal" :disabled="ocupado || !carrinho.length" @click="salvar">
          {{ ocupado ? 'Registrando...' : 'Registrar venda e baixar estoque' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const sessao = useSessao()
const unidadeId = computed(() => sessao.value.perfil?.unit_id ?? null)

const carrinho = ref<any[]>([])
const arquivo = ref<File | null>(null)
const observacao = ref('')
const erro = ref(''); const ok = ref(''); const ocupado = ref(false)

const total = computed(() => carrinho.value.reduce((s, i) => s + (Number(i.qty) || 0) * (Number(i.unit_price) || 0), 0))

function adicionar(p: any) {
  erro.value = ''; ok.value = ''
  if (carrinho.value.find(i => i.id === p.id)) return
  carrinho.value.push({ ...p, qty: 1, unit_price: null })
}

async function salvar() {
  erro.value = ''; ok.value = ''
  for (const i of carrinho.value) {
    if (!i.qty || i.qty < 1) { erro.value = `Informe a quantidade de "${i.title}".`; return }
    if (i.qty > i.estoque) { erro.value = `Você tem apenas ${i.estoque} de "${i.title}" em estoque.`; return }
    if (i.unit_price === null || i.unit_price === '' || Number(i.unit_price) < 0) {
      erro.value = `Informe o valor unitário de "${i.title}".`; return
    }
  }
  if (!arquivo.value) { erro.value = 'Anexe a foto do comprovante da venda.'; return }

  ocupado.value = true
  try {
    const ext = (arquivo.value.name.split('.').pop() || 'jpg').toLowerCase()
    const caminho = `${unidadeId.value}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`
    const up = await supa.storage.from('comprovantes').upload(caminho, arquivo.value, { upsert: false })
    if (up.error) throw new Error('Não foi possível enviar a foto: ' + up.error.message)

    const { data, error } = await supa.rpc('fn_create_sale', {
      p_items: carrinho.value.map(i => ({ product_id: i.id, qty: i.qty, unit_price: Number(i.unit_price) })),
      p_receipt: caminho,
      p_note: observacao.value || null
    })
    if (error) throw new Error(error.message)

    const { data: v } = await supa.from('sales').select('code').eq('id', data).maybeSingle()
    ok.value = v?.code ?? 'registrada'
    carrinho.value = []; observacao.value = ''; arquivo.value = null
    window.scrollTo({ top: 0, behavior: 'smooth' })
  } catch (e: any) {
    erro.value = e.message
  } finally {
    ocupado.value = false
  }
}
</script>
