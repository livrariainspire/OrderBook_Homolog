<template>
  <div>
    <div class="cabecalho">
      <div><h1>Meus pedidos</h1><p>Acompanhe cada etapa, converse com o atendente e confirme o recebimento.</p></div>
      <NuxtLink to="/pedidos/novo" class="btn btn-principal btn-p">Fazer um pedido</NuxtLink>
    </div>

    <div v-if="msg" class="aviso" :class="erro ? 'aviso-erro' : 'aviso-ok'">{{ msg }}</div>

    <div v-if="aguardando.length" class="aviso aviso-atencao">
      <strong>{{ aguardando.length }} pedido(s) aguardam sua confirmação de recebimento.</strong>
      Abra o pedido e confirme para finalizar.
    </div>

    <div v-if="carregando" class="carregando">Carregando pedidos...</div>

    <div v-else class="painel">
      <div class="painel-topo">
        <h2>{{ filtrados.length }} pedido(s)</h2>
        <select v-model="situacao" class="campo" style="max-width:220px">
          <option value="">Todas as situações</option>
          <option value="fila">Na fila</option>
          <option value="em_atendimento">Em atendimento</option>
          <option value="em_espera">Em espera</option>
          <option value="enviado">Aguardando recebimento</option>
          <option value="finalizado">Finalizado</option>
          <option value="cancelado">Cancelado</option>
        </select>
      </div>
      <TabelaVazia v-if="!filtrados.length" titulo="Nenhum pedido"
        texto="Quando sua filial fizer um pedido, ele aparece aqui." />
      <div v-else class="tabela-rolagem">
        <table class="lista">
          <thead><tr><th>Código</th><th>Situação</th><th>Retirada prevista</th><th>Atendente</th><th>Criado</th><th></th></tr></thead>
          <tbody>
            <tr v-for="p in filtrados" :key="p.id">
              <td>
                <strong>{{ p.code }}</strong>
                <div v-if="p.parent_code" class="mini">Em espera, veio de {{ p.parent_code }}</div>
              </td>
              <td><span class="selo" :class="classeSelo(p.status)">{{ rotuloSituacao(p.status) }}</span></td>
              <td>{{ dataCurta(p.pickup_expected) }}</td>
              <td>{{ p.attendant_name || '—' }}</td>
              <td>{{ dataHora(p.created_at) }}</td>
              <td class="acoes-celula">
                <button v-if="p.status === 'enviado'" class="btn btn-principal btn-p" @click="abrir(p)">Confirmar recebimento</button>
                <button v-else class="btn btn-neutro btn-p" @click="abrir(p)">Abrir</button>
                <button v-if="p.status === 'fila'" class="btn btn-perigo btn-p" @click="cancelar(p)">Cancelar</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <JanelaModal v-if="aberto" :titulo="`Pedido ${aberto.code}`" @fechar="aberto = null">
      <div class="entre" style="margin-bottom:14px">
        <span class="selo" :class="classeSelo(aberto.status)">{{ rotuloSituacao(aberto.status) }}</span>
        <span class="mini">{{ dataHora(aberto.created_at) }} · {{ aberto.requested_by_name }}</span>
      </div>
      <div class="entre" style="margin-bottom:14px">
        <span class="mini">Retirada prevista</span>
        <strong>{{ dataCurta(aberto.pickup_expected) }}</strong>
      </div>
      <div v-if="aberto.parent_code" class="aviso aviso-info">
        Este pedido guarda o que faltou em {{ aberto.parent_code }} e será atendido quando o produto chegar.
      </div>
      <div v-if="aberto.note" class="aviso aviso-info">{{ aberto.note }}</div>

      <table class="lista" style="font-size:13px">
        <thead><tr><th>Produto</th><th>Pedido</th><th>Enviado</th></tr></thead>
        <tbody>
          <tr v-for="i in itens" :key="i.id" :class="{ 'item-retirado': i.removed }">
            <td>
              <strong>{{ i.product_title }}</strong>
              <div v-if="i.removed" class="mini">Retirado por {{ i.removed_by_name }}<template v-if="i.removed_reason"> · {{ i.removed_reason }}</template></div>
            </td>
            <td>{{ i.qty_requested }}</td>
            <td>{{ i.removed ? 'Retirado' : (['enviado','finalizado'].includes(aberto.status) ? i.qty_sent : '—') }}</td>
          </tr>
        </tbody>
      </table>

      <div v-if="aberto.status === 'enviado'" style="margin-top:20px">
        <div class="aviso aviso-atencao">Confira o que chegou e confirme para finalizar o pedido.</div>
        <div class="grupo">
          <label class="rotulo">Observação (opcional)</label>
          <input v-model="obsRecebimento" class="campo" placeholder="Ex.: recebido em bom estado" />
        </div>
        <button class="btn btn-principal" :disabled="ocupado" @click="confirmar">
          {{ ocupado ? 'Confirmando...' : 'Confirmar recebimento' }}
        </button>
      </div>

      <hr class="divisor" />
      <h4 style="font-size:14px;margin-bottom:12px">Conversa do pedido</h4>
      <ChatPedido :pedido-id="aberto.id" :encerrado="['finalizado','cancelado'].includes(aberto.status)" />

      <template #acoes><button class="btn btn-neutro btn-p" @click="aberto = null">Fechar</button></template>
    </JanelaModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const pedidos = ref<any[]>([])
const carregando = ref(true)
const situacao = ref('')
const aberto = ref<any>(null)
const itens = ref<any[]>([])
const obsRecebimento = ref('')
const ocupado = ref(false)
const msg = ref(''); const erro = ref(false)

const filtrados = computed(() => situacao.value ? pedidos.value.filter(p => p.status === situacao.value) : pedidos.value)
const aguardando = computed(() => pedidos.value.filter(p => p.status === 'enviado'))

async function carregar() {
  const { data } = await supa.from('orders').select('*').order('created_at', { ascending: false })
  pedidos.value = data ?? []
  carregando.value = false
  await abrirDoAviso()
}
onMounted(carregar)

async function abrir(p: any) {
  aberto.value = p; obsRecebimento.value = ''
  const { data } = await supa.from('order_items').select('*').eq('order_id', p.id)
  itens.value = data ?? []
}

async function confirmar() {
  ocupado.value = true; msg.value = ''
  const { error } = await supa.rpc('fn_confirm_receipt', {
    p_order: aberto.value.id, p_note: obsRecebimento.value || null
  })
  ocupado.value = false
  erro.value = !!error
  msg.value = error ? error.message : `Pedido ${aberto.value.code} finalizado.`
  if (!error) { aberto.value = null; carregar() }
}

async function cancelar(p: any) {
  if (!confirm(`Cancelar o pedido ${p.code}?`)) return
  const { error } = await supa.rpc('fn_cancel_order', { p_order: p.id, p_reason: 'Cancelado pela filial' })
  if (error) { erro.value = true; msg.value = error.message; return }
  carregar()
}

// abre sozinho o pedido indicado pelo aviso
const rota = useRoute()
async function abrirDoAviso() {
  const id = rota.query.pedido as string | undefined
  if (!id) return
  const alvo = pedidos.value.find((p: any) => p.id === id)
  if (alvo) await abrir(alvo)
}
watch(() => rota.query.t, abrirDoAviso)

</script>
