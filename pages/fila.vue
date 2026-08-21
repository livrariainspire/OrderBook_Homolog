<template>
  <div>
    <div class="cabecalho">
      <div><h1>Fila de pedidos</h1><p>Pedidos aguardando um atendente. Quem puxar primeiro assume o atendimento.</p></div>
      <button class="btn btn-neutro btn-p" @click="carregar">Atualizar</button>
    </div>

    <div v-if="aviso" class="aviso aviso-atencao">{{ aviso }}</div>
    <div v-if="carregando" class="carregando">Carregando fila...</div>

    <div v-else class="painel">
      <TabelaVazia v-if="!pedidos.length" titulo="Fila vazia"
        texto="Nenhum pedido aguardando no momento." />
      <div v-else class="tabela-rolagem">
        <table class="lista">
          <thead><tr><th>Código</th><th>Filial</th><th>Solicitante</th><th>Itens</th><th>Retirada prevista</th><th>Na fila desde</th><th></th></tr></thead>
          <tbody>
            <tr v-for="p in pedidos" :key="p.id">
              <td><strong>{{ p.code }}</strong></td>
              <td>{{ p.unit_name }}</td>
              <td>{{ p.requested_by_name }}</td>
              <td>{{ p.order_items?.length ?? 0 }}</td>
              <td><strong>{{ dataCurta(p.pickup_expected) }}</strong></td>
              <td>{{ dataHora(p.created_at) }}</td>
              <td class="acoes-celula">
                <button class="btn btn-neutro btn-p" @click="ver(p)">Ver itens</button>
                <button class="btn btn-principal btn-p" @click="puxar(p)">Puxar pedido</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <JanelaModal v-if="aberto" :titulo="`Pedido ${aberto.code}`" @fechar="aberto = null">
      <p class="mini" style="margin-bottom:14px">{{ aberto.unit_name }} · {{ aberto.requested_by_name }}</p>
      <div class="entre" style="margin-bottom:14px">
        <span class="mini">Retirada prevista</span>
        <strong>{{ dataCurta(aberto.pickup_expected) }}</strong>
      </div>
      <div v-if="aberto.note" class="aviso aviso-info">{{ aberto.note }}</div>
      <table class="lista" style="font-size:13px">
        <thead><tr><th>Produto</th><th>Quantidade</th></tr></thead>
        <tbody>
          <tr v-for="i in aberto.order_items" :key="i.id">
            <td><strong>{{ i.product_title }}</strong></td><td>{{ i.qty_requested }}</td>
          </tr>
        </tbody>
      </table>
      <hr class="divisor" />
      <h4 style="font-size:14px;margin-bottom:12px">Conversa do pedido</h4>
      <ChatPedido :pedido-id="aberto.id" />
      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="aberto = null">Fechar</button>
        <button class="btn btn-principal btn-p" style="width:auto" @click="puxar(aberto)">Puxar pedido</button>
      </template>
    </JanelaModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const pedidos = ref<any[]>([])
const carregando = ref(true)
const aberto = ref<any>(null)
const aviso = ref('')

async function carregar() {
  carregando.value = true
  const { data } = await supa.from('orders')
    .select('*, order_items(*)').eq('status', 'fila').order('created_at')
  pedidos.value = data ?? []
  carregando.value = false
  await abrirDoAviso()
}
onMounted(carregar)

function ver(p: any) { aberto.value = p }

async function puxar(p: any) {
  aviso.value = ''
  const { error } = await supa.rpc('fn_claim_order', { p_order: p.id })
  if (error) { aviso.value = error.message; aberto.value = null; carregar(); return }
  await navigateTo('/atendimentos')
}

// abre sozinho o pedido indicado pelo aviso
const rota = useRoute()
async function abrirDoAviso() {
  const id = rota.query.pedido as string | undefined
  if (!id) return
  const alvo = pedidos.value.find((p: any) => p.id === id)
  if (alvo) await ver(alvo)
}
watch(() => rota.query.t, abrirDoAviso)

</script>
