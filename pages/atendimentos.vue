<template>
  <div>
    <div class="cabecalho">
      <div><h1>Meus atendimentos</h1><p>Converse com a filial, retire o que estiver em falta e registre o envio.</p></div>
      <NuxtLink to="/fila" class="btn btn-neutro btn-p">Ir para a fila</NuxtLink>
    </div>

    <div v-if="msg" class="aviso" :class="erro ? 'aviso-erro' : 'aviso-ok'">{{ msg }}</div>
    <div v-if="carregando" class="carregando">Carregando atendimentos...</div>

    <template v-else>
      <div class="painel">
        <div class="painel-topo"><h2>Em atendimento ({{ abertos.length }})</h2></div>
        <TabelaVazia v-if="!abertos.length" titulo="Nada em atendimento" texto="Puxe um pedido da fila para começar." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead><tr><th>Código</th><th>Filial</th><th>Itens</th><th>Retirada prevista</th><th>Puxado em</th><th></th></tr></thead>
            <tbody>
              <tr v-for="p in abertos" :key="p.id">
                <td><strong>{{ p.code }}</strong></td>
                <td>{{ p.unit_name }}</td>
                <td>{{ p.order_items.filter((i: any) => !i.removed).length }} de {{ p.order_items.length }}</td>
                <td><strong>{{ dataCurta(p.pickup_expected) }}</strong></td>
                <td>{{ dataHora(p.claimed_at) }}</td>
                <td class="acoes-celula">
                  <button class="btn btn-principal btn-p" @click="abrir(p)">Abrir atendimento</button>
                  <button class="btn btn-neutro btn-p" @click="devolver(p)">Devolver a fila</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="painel">
        <div class="painel-topo"><h2>Em espera ({{ espera.length }})</h2></div>
        <TabelaVazia v-if="!espera.length" titulo="Nada em espera"
          texto="Pedidos aguardando a chegada de produto aparecem aqui." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead><tr><th>Código</th><th>Filial</th><th>Veio de</th><th>Itens</th><th>Retirada prevista</th><th>Desde</th><th></th></tr></thead>
            <tbody>
              <tr v-for="p in espera" :key="p.id">
                <td><strong>{{ p.code }}</strong></td>
                <td>{{ p.unit_name }}</td>
                <td>{{ p.parent_code || '—' }}</td>
                <td>{{ p.order_items.length }}</td>
                <td><strong>{{ dataCurta(p.pickup_expected) }}</strong></td>
                <td>{{ dataHora(p.created_at) }}</td>
                <td class="acoes-celula">
                  <button class="btn btn-principal btn-p" @click="retomar(p)">O produto chegou</button>
                  <button class="btn btn-neutro btn-p" @click="abrir(p)">Abrir</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="painel">
        <div class="painel-topo"><h2>Concluidos por mim</h2></div>
        <TabelaVazia v-if="!concluidos.length" titulo="Nenhum pedido concluido" texto="Seus envios aparecem aqui." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead><tr><th>Código</th><th>Filial</th><th>Situação</th><th>Enviado em</th><th></th></tr></thead>
            <tbody>
              <tr v-for="p in concluidos" :key="p.id">
                <td><strong>{{ p.code }}</strong></td>
                <td>{{ p.unit_name }}</td>
                <td><span class="selo" :class="classeSelo(p.status)">{{ rotuloSituacao(p.status) }}</span></td>
                <td>{{ dataHora(p.completed_at) }}</td>
                <td><button class="btn btn-neutro btn-p" @click="abrir(p)">Abrir</button></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <JanelaModal v-if="atual" :titulo="`Pedido ${atual.code}`" @fechar="fechar">
      <div class="entre" style="margin-bottom:14px">
        <span class="selo" :class="classeSelo(atual.status)">{{ rotuloSituacao(atual.status) }}</span>
        <span class="mini">{{ atual.unit_name }} · {{ atual.requested_by_name }}</span>
      </div>
      <div class="entre" style="margin-bottom:14px">
        <span class="mini">Retirada prevista</span>
        <strong>{{ dataCurta(atual.pickup_expected) }}</strong>
      </div>
      <div v-if="atual.parent_code" class="aviso aviso-info">
        Pedido em espera criado a partir de {{ atual.parent_code }}.
      </div>
      <div v-if="atual.note" class="aviso aviso-info">{{ atual.note }}</div>
      <div v-if="erroJanela" class="aviso aviso-erro">{{ erroJanela }}</div>

      <h4 style="font-size:14px;margin-bottom:10px">Itens do pedido</h4>
      <div v-for="i in atual.order_items" :key="i.id" class="carrinho-item" :class="{ 'item-retirado': i.removed }">
        <div class="cresce">
          <div class="produto-nome">{{ i.product_title }}</div>
          <div class="produto-meta">
            Pedido: {{ i.qty_requested }}
            <template v-if="i.removed"> · retirado por {{ i.removed_by_name }}</template>
          </div>
          <div v-if="i.removed_reason" class="mini">{{ i.removed_reason }}</div>
        </div>
        <template v-if="podeEditar">
          <div v-if="!i.removed">
            <label class="rotulo" style="margin-bottom:4px">Enviado</label>
            <input v-model.number="i.qty_sent" class="campo qtd" type="number" min="0" :max="i.qty_requested" />
          </div>
          <button v-if="!i.removed" class="btn-linha" style="color:var(--vermelho)" @click="retirar(i)">Retirar</button>
          <button v-else class="btn-linha" @click="devolverItem(i)">Devolver</button>
        </template>
        <div v-else class="mini">{{ i.removed ? 'Retirado' : `Enviado: ${i.qty_sent}` }}</div>
      </div>

      <template v-if="podeEditar">
        <div class="grupo" style="margin-top:20px">
          <label class="linha-acoes" style="gap:8px;cursor:pointer">
            <input v-model="criarEspera" type="checkbox" />
            <span style="font-size:14px">Criar pedido em espera com o que faltar</span>
          </label>
          <p class="mini" style="margin-top:6px">
            O que foi retirado ou enviado a menos vira um pedido novo em espera, que fica com você até o produto chegar.
          </p>
        </div>
        <div v-if="criarEspera" class="grupo">
          <label class="rotulo">Observação do pedido em espera</label>
          <input v-model="notaEspera" class="campo" placeholder="Ex.: previsão de chegada na próxima semana" />
        </div>
        <button class="btn btn-principal" :disabled="ocupado" @click="concluir">
          {{ ocupado ? 'Registrando...' : 'Registrar envio' }}
        </button>
      </template>

      <hr class="divisor" />
      <h4 style="font-size:14px;margin-bottom:12px">Conversa do pedido</h4>
      <ChatPedido :pedido-id="atual.id" :encerrado="['finalizado','cancelado'].includes(atual.status)" />

      <template #acoes><button class="btn btn-neutro btn-p" @click="fechar">Fechar</button></template>
    </JanelaModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const sessao = useSessao()
const abertos = ref<any[]>([])
const espera = ref<any[]>([])
const concluidos = ref<any[]>([])
const carregando = ref(true)
const atual = ref<any>(null)
const criarEspera = ref(true)
const notaEspera = ref('')
const ocupado = ref(false)
const msg = ref(''); const erro = ref(false); const erroJanela = ref('')

const podeEditar = computed(() => atual.value?.status === 'em_atendimento')

async function carregar() {
  const id = sessao.value.perfil!.id
  const [a, e, c] = await Promise.all([
    supa.from('orders').select('*, order_items(*)').eq('attendant_id', id).eq('status', 'em_atendimento').order('claimed_at'),
    supa.from('orders').select('*, order_items(*)').eq('attendant_id', id).eq('status', 'em_espera').order('created_at'),
    supa.from('orders').select('*, order_items(*)').eq('attendant_id', id).in('status', ['enviado', 'finalizado']).order('completed_at', { ascending: false }).limit(30)
  ])
  abertos.value = a.data ?? []
  espera.value = e.data ?? []
  concluidos.value = c.data ?? []
  carregando.value = false
  await abrirDoAviso()
}
onMounted(carregar)

async function recarregarAtual() {
  const { data } = await supa.from('orders').select('*, order_items(*)').eq('id', atual.value.id).single()
  if (data) atual.value = { ...data, order_items: prepararItens(data) }
}

const prepararItens = (p: any) => p.order_items
  .map((i: any) => ({ ...i, qty_sent: i.removed ? 0 : (i.qty_sent || i.qty_requested) }))
  .sort((a: any, b: any) => Number(a.removed) - Number(b.removed))

function abrir(p: any) {
  erroJanela.value = ''; criarEspera.value = true; notaEspera.value = ''
  atual.value = { ...p, order_items: prepararItens(p) }
}
function fechar() { atual.value = null; carregar() }

async function retirar(i: any) {
  const motivo = prompt(`Retirar "${i.product_title}" do pedido. Qual o motivo?`, 'Produto em falta no estoque')
  if (motivo === null) return
  const { error } = await supa.rpc('fn_remove_order_item', { p_item: i.id, p_reason: motivo || null })
  if (error) { erroJanela.value = error.message; return }
  await recarregarAtual()
}

async function devolverItem(i: any) {
  const { error } = await supa.rpc('fn_restore_order_item', { p_item: i.id })
  if (error) { erroJanela.value = error.message; return }
  await recarregarAtual()
}

async function concluir() {
  ocupado.value = true; erroJanela.value = ''
  const { error } = await supa.rpc('fn_fulfill_order', {
    p_order: atual.value.id,
    p_items: atual.value.order_items.filter((i: any) => !i.removed)
      .map((i: any) => ({ item_id: i.id, qty_sent: Number(i.qty_sent) || 0 })),
    p_criar_espera: criarEspera.value,
    p_espera_note: notaEspera.value || null
  })
  ocupado.value = false
  if (error) { erroJanela.value = error.message; return }
  erro.value = false
  msg.value = `Envio de ${atual.value.code} registrado. A filial precisa confirmar o recebimento.`
  atual.value = null
  carregar()
}

async function devolver(p: any) {
  if (!confirm(`Devolver o pedido ${p.code} para a fila?`)) return
  const { error } = await supa.rpc('fn_release_order', { p_order: p.id })
  if (error) { erro.value = true; msg.value = error.message; return }
  carregar()
}

async function retomar(p: any) {
  if (!confirm(`Retomar o pedido ${p.code}? Ele volta para o seu atendimento.`)) return
  const { error } = await supa.rpc('fn_resume_order', { p_order: p.id })
  if (error) { erro.value = true; msg.value = error.message; return }
  erro.value = false; msg.value = `${p.code} voltou para o atendimento.`
  carregar()
}

// abre sozinho o pedido indicado pelo aviso
const rota = useRoute()
async function abrirDoAviso() {
  const id = rota.query.pedido as string | undefined
  if (!id) return
  const alvo = [...abertos.value, ...espera.value, ...concluidos.value].find((p: any) => p.id === id)
  if (alvo) abrir(alvo)
}
watch(() => rota.query.t, abrirDoAviso)

</script>
