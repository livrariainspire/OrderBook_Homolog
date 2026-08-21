<template>
  <div>
    <div class="cabecalho">
      <div>
        <h1>Nova venda</h1>
        <p>Monte a venda, escolha o meio de pagamento e mande cobrar na maquininha.</p>
      </div>
      <NuxtLink to="/vendas" class="btn btn-neutro btn-p">Ver vendas</NuxtLink>
    </div>

    <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>
    <div v-if="simulacao" class="aviso aviso-atencao">
      <strong>Modo simulação.</strong>
      A cobrança não vai para a maquininha de verdade. Use a tela
      <NuxtLink to="/maquininha">Maquininha</NuxtLink> para confirmar o pagamento com o código gerado.
    </div>

    <!-- COBRANÇA EM ANDAMENTO -->
    <div v-if="cobranca" class="painel">
      <div class="painel-topo">
        <h2>Aguardando pagamento</h2>
        <span class="selo selo-fila">{{ cobranca.code }}</span>
      </div>
      <div class="painel-corpo centro">
        <div class="codigo-grande">{{ cobranca.code }}</div>
        <p class="mini" style="margin-bottom:6px">Código da cobrança</p>
        <div style="font-size:30px;font-weight:700;margin:14px 0 6px">{{ moeda(cobranca.amount) }}</div>
        <p class="mini">
          {{ rotuloMeio(meio) }}<template v-if="meio === 'credito' && parcelas > 1"> em {{ parcelas }}x</template>
          <template v-if="cobranca.device"> · {{ cobranca.device }}</template>
        </p>

        <div class="aviso aviso-info" style="margin-top:22px;text-align:left">
          <template v-if="simulacao">
            Abra a tela <strong>Maquininha</strong> em outro dispositivo, digite o código acima
            e confirme o pagamento. Esta tela avisa sozinha quando isso acontecer.
          </template>
          <template v-else>
            A cobrança foi enviada para a maquininha. Peça ao cliente para concluir o pagamento.
          </template>
        </div>

        <div class="linha-acoes" style="justify-content:center;margin-top:20px">
          <NuxtLink v-if="simulacao" to="/maquininha" class="btn btn-principal btn-p" style="width:auto">
            Abrir a maquininha
          </NuxtLink>
          <button class="btn btn-perigo btn-p" :disabled="ocupado" @click="cancelar">
            Cancelar cobrança
          </button>
        </div>
        <p class="mini" style="margin-top:16px">Conferindo o pagamento...</p>
      </div>
    </div>

    <!-- VENDA CONCLUÍDA -->
    <div v-else-if="concluida" class="painel">
      <div class="painel-corpo centro">
        <div style="font-size:44px;line-height:1">&#9989;</div>
        <h2 style="font-size:22px;margin-top:14px">Pagamento confirmado</h2>
        <p style="color:var(--texto);font-size:14px;margin-top:10px;line-height:1.6">
          A venda foi registrada, o estoque baixou e os dados entraram na fila da Omie.
        </p>
        <div class="linha-acoes" style="justify-content:center;margin-top:22px">
          <button class="btn btn-principal btn-p" style="width:auto" @click="recomecar">Nova venda</button>
          <NuxtLink to="/vendas" class="btn btn-neutro btn-p">Ver vendas</NuxtLink>
        </div>
      </div>
    </div>

    <!-- MONTAGEM DA VENDA -->
    <template v-else>
      <div class="painel">
        <div class="painel-topo"><h2>1. Produtos vendidos</h2></div>
        <div class="painel-corpo">
          <BuscaProdutos somente-com-estoque :unidade-id="unidadeId"
                         :escolhidos="carrinho.map((i: any) => i.id)" @escolher="adicionar" />
        </div>
      </div>

      <div class="painel">
        <div class="painel-topo">
          <h2>2. Quantidades e valores</h2>
          <strong style="font-size:18px">{{ moeda(total) }}</strong>
        </div>
        <div class="painel-corpo">
          <TabelaVazia v-if="!carrinho.length" titulo="Nenhum produto"
            texto="Busque acima entre os produtos disponíveis no seu estoque." />
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
        </div>
      </div>

      <div class="painel">
        <div class="painel-topo"><h2>3. Pagamento</h2></div>
        <div class="painel-corpo">
          <div class="grade-2">
            <div class="grupo">
              <label class="rotulo">Meio de pagamento</label>
              <select v-model="meio" class="campo">
                <option value="credito">Crédito</option>
                <option value="debito">Débito</option>
                <option value="pix">Pix</option>
                <option value="voucher">Voucher</option>
              </select>
            </div>
            <div v-if="meio === 'credito'" class="grupo">
              <label class="rotulo">Parcelas</label>
              <select v-model.number="parcelas" class="campo">
                <option v-for="n in 12" :key="n" :value="n">{{ n }}x</option>
              </select>
            </div>
          </div>

          <div class="grupo">
            <label class="rotulo">Maquininha</label>
            <select v-model="maquina" class="campo">
              <option value="">Selecione a maquininha</option>
              <option v-for="m in maquinas" :key="m.id" :value="m.serial">
                {{ m.serial }}<template v-if="m.nickname"> · {{ m.nickname }}</template>
              </option>
            </select>
            <p v-if="!maquinas.length" class="mini" style="margin-top:8px">
              Nenhuma maquininha cadastrada para a sua filial. Fale com a administração.
            </p>
          </div>

          <div class="grupo">
            <label class="rotulo">Observação (opcional)</label>
            <input v-model="observacao" class="campo" placeholder="Ex.: venda no culto de domingo" />
          </div>

          <button class="btn btn-principal" :disabled="ocupado || !carrinho.length" @click="cobrar">
            {{ ocupado ? 'Enviando...' : `Cobrar ${moeda(total)} na maquininha` }}
          </button>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const sessao = useSessao()
const unidadeId = computed(() => sessao.value.perfil?.unit_id ?? null)

const carrinho = ref<any[]>([])
const maquinas = ref<any[]>([])
const maquina = ref('')
const meio = ref('credito')
const parcelas = ref(1)
const observacao = ref('')
const simulacao = ref(true)

const cobranca = ref<any>(null)
const concluida = ref(false)
const erro = ref('')
const ocupado = ref(false)
let relogio: any = null

const total = computed(() => carrinho.value.reduce(
  (s, i) => s + (Number(i.qty) || 0) * (Number(i.unit_price) || 0), 0))

const rotuloMeio = (m: string) => ({
  credito: 'Crédito', debito: 'Débito', pix: 'Pix', voucher: 'Voucher', dinheiro: 'Dinheiro'
}[m] ?? m)

onMounted(async () => {
  const [d, s] = await Promise.all([
    supa.from('unit_devices').select('*').eq('unit_id', unidadeId.value).eq('active', true).order('serial'),
    supa.from('settings').select('value').eq('key', 'modo_simulacao').maybeSingle()
  ])
  maquinas.value = d.data ?? []
  if (maquinas.value.length === 1) maquina.value = maquinas.value[0].serial
  simulacao.value = (s.data?.value ?? 'true') === 'true'
})
onUnmounted(() => clearInterval(relogio))

function adicionar(p: any) {
  erro.value = ''
  if (carrinho.value.find(i => i.id === p.id)) return
  carrinho.value.push({ ...p, qty: 1, unit_price: null })
}

async function cobrar() {
  erro.value = ''
  for (const i of carrinho.value) {
    if (!i.qty || i.qty < 1) { erro.value = `Informe a quantidade de "${i.title}".`; return }
    if (i.qty > i.estoque) { erro.value = `Você tem apenas ${i.estoque} de "${i.title}".`; return }
    if (!i.unit_price || Number(i.unit_price) <= 0) { erro.value = `Informe o valor de "${i.title}".`; return }
  }
  if (!maquina.value) { erro.value = 'Selecione a maquininha.'; return }

  ocupado.value = true
  const { data, error } = await supa.rpc('fn_create_charge', {
    p_items: carrinho.value.map(i => ({ product_id: i.id, qty: i.qty, unit_price: Number(i.unit_price) })),
    p_method: meio.value,
    p_installments: meio.value === 'credito' ? parcelas.value : 1,
    p_device: maquina.value,
    p_note: observacao.value || null
  })
  ocupado.value = false
  if (error) { erro.value = error.message; return }

  const c = Array.isArray(data) ? data[0] : data
  cobranca.value = { ...c, device: maquina.value }
  acompanhar()
}

function acompanhar() {
  clearInterval(relogio)
  relogio = setInterval(async () => {
    if (!cobranca.value) return
    const { data } = await supa.from('charges').select('status').eq('id', cobranca.value.id).maybeSingle()
    if (data?.status === 'pago') {
      clearInterval(relogio)
      cobranca.value = null
      concluida.value = true
    } else if (data?.status === 'cancelado') {
      clearInterval(relogio)
      cobranca.value = null
      erro.value = 'A cobrança foi cancelada.'
    }
  }, 3000)
}

async function cancelar() {
  ocupado.value = true
  await supa.rpc('fn_cancel_charge', { p_code: cobranca.value.code, p_reason: 'Cancelada pela filial' })
  ocupado.value = false
  clearInterval(relogio)
  cobranca.value = null
}

function recomecar() {
  concluida.value = false
  carrinho.value = []
  observacao.value = ''
  parcelas.value = 1
}
</script>

<style scoped>
.codigo-grande {
  font-size: 46px; font-weight: 700; letter-spacing: .18em; color: var(--laranja);
  font-variant-numeric: tabular-nums;
}
</style>
