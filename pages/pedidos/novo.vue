<template>
  <div>
    <div class="cabecalho">
      <div>
        <h1>Fazer um pedido</h1>
        <p>Busque no catálogo, informe as quantidades e envie para a livraria.</p>
      </div>
    </div>

    <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>
    <div v-if="ok" class="aviso aviso-ok">
      Pedido <strong>{{ ok }}</strong> enviado. Um atendente vai puxar da fila em breve.
      <NuxtLink to="/pedidos">Acompanhar meus pedidos</NuxtLink>
    </div>

    <div class="painel">
      <div class="painel-topo"><h2>1. Escolher os produtos</h2>
        <span class="mini">Tudo o que sua filial pode pedir</span></div>
      <div class="painel-corpo">
        <BuscaProdutos :escolhidos="carrinho.map((i: any) => i.id)" @escolher="adicionar" />
      </div>
    </div>

    <div class="painel">
      <div class="painel-topo">
        <h2>2. Conferir o pedido</h2>
        <span class="mini">{{ carrinho.length }} produto(s)</span>
      </div>
      <div class="painel-corpo">
        <TabelaVazia v-if="!carrinho.length" titulo="Pedido vazio"
          texto="Use a busca acima para incluir livros e itens." />
        <template v-else>
          <div v-for="(i, idx) in carrinho" :key="i.id" class="carrinho-item">
            <FotoProduto :url="i.photo_url" :titulo="i.title" :tipo="i.type" />
            <div class="cresce">
              <div class="produto-nome">{{ i.title }}</div>
              <div class="produto-meta">{{ [i.author, i.edition].filter(Boolean).join(' · ') || (i.type === 'livro' ? 'Livro' : 'Item da livraria') }}</div>
            </div>
            <div>
              <label class="rotulo" style="margin-bottom:4px">Qtd</label>
              <input v-model.number="i.qty" class="campo qtd" type="number" min="1" />
            </div>
            <button class="btn-linha" style="color:var(--vermelho)" @click="carrinho.splice(idx,1)">Remover</button>
          </div>

          <div class="grade-2" style="margin-top:22px">
            <div class="grupo">
              <label class="rotulo" for="retirada">Data prevista da retirada</label>
              <input id="retirada" v-model="retirada" class="campo" type="date" :min="hoje" required />
              <p class="mini" style="margin-top:6px">Quando sua filial pretende buscar os produtos.</p>
            </div>
            <div class="grupo">
              <label class="rotulo">Observação para o atendente (opcional)</label>
              <input v-model="observacao" class="campo" placeholder="Ex.: falar com a Ana na recepção" />
            </div>
          </div>

          <button class="btn btn-principal" :disabled="ocupado" @click="enviar">
            {{ ocupado ? 'Enviando...' : 'Enviar pedido' }}
          </button>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const carrinho = ref<any[]>([])
const observacao = ref('')
const retirada = ref('')
const hoje = new Date().toISOString().slice(0, 10)
const erro = ref(''); const ok = ref(''); const ocupado = ref(false)

function adicionar(p: any) {
  erro.value = ''; ok.value = ''
  const achou = carrinho.value.find(i => i.id === p.id)
  if (achou) { achou.qty += 1; return }
  carrinho.value.push({ ...p, qty: 1 })
}

async function enviar() {
  erro.value = ''; ok.value = ''
  if (carrinho.value.some(i => !i.qty || i.qty < 1)) { erro.value = 'Informe uma quantidade válida para cada produto.'; return }
  if (!retirada.value) { erro.value = 'Informe a data prevista da retirada.'; return }
  ocupado.value = true
  const { data, error } = await supa.rpc('fn_create_order', {
    p_items: carrinho.value.map(i => ({ product_id: i.id, qty: i.qty })),
    p_note: observacao.value || null,
    p_pickup: retirada.value
  })
  ocupado.value = false
  if (error) { erro.value = error.message; return }
  const { data: ped } = await supa.from('orders').select('code').eq('id', data).maybeSingle()
  ok.value = ped?.code ?? 'criado'
  carrinho.value = []; observacao.value = ''; retirada.value = ''
  window.scrollTo({ top: 0, behavior: 'smooth' })
}
</script>
