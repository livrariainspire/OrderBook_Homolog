<template>
  <div class="pos-tela">
    <div class="pos">
      <div class="pos-topo">
        <div class="pos-marca">STONE</div>
        <div class="pos-modelo">Simulação · Order Book</div>
      </div>

      <!-- DIGITAR O CÓDIGO -->
      <template v-if="!atual && !recibo">
        <div class="pos-corpo">
          <p class="pos-titulo">Cobranças em aberto</p>

          <div v-if="fila.length" class="pos-fila">
            <button v-for="c in fila" :key="c.id" class="pos-item" @click="abrir(c.code)">
              <span>
                <strong>{{ c.code }}</strong>
                <small>{{ c.unit_name }}<template v-if="c.device_nickname"> · {{ c.device_nickname }}</template></small>
              </span>
              <span class="pos-valor">{{ moeda(c.amount) }}</span>
            </button>
          </div>
          <p v-else class="pos-vazio">Nenhuma cobrança aguardando.</p>

          <p class="pos-titulo" style="margin-top:26px">Ou digite o código</p>
          <input :value="codigo" class="pos-input" inputmode="numeric" maxlength="6"
                 placeholder="000000" @input="digitar" @keyup.enter="abrir(codigo)" />
          <p v-if="erro" class="pos-erro">{{ erro }}</p>
          <button class="pos-botao" :disabled="codigo.length < 6 || ocupado" @click="abrir(codigo)">
            Buscar cobrança
          </button>
        </div>
      </template>

      <!-- CONFIRMAR O PAGAMENTO -->
      <template v-else-if="atual">
        <div class="pos-corpo">
          <p class="pos-titulo">{{ atual.unit_name }}</p>
          <div class="pos-total">{{ moeda(atual.amount) }}</div>
          <p class="pos-meio">
            {{ rotuloMeio(atual.method) }}<template v-if="atual.method === 'credito' && atual.installments > 1"> · {{ atual.installments }}x</template>
          </p>

          <div class="pos-lista">
            <div v-for="(i, n) in atual.items" :key="n" class="pos-linha">
              <span>{{ i.qty }}x {{ i.title }}</span>
              <span>{{ moeda(i.subtotal) }}</span>
            </div>
          </div>

          <p class="pos-nota">Código {{ atual.code }} · {{ atual.created_by_name }}</p>
          <p v-if="erro" class="pos-erro">{{ erro }}</p>

          <button class="pos-botao" :disabled="ocupado" @click="pagar">
            {{ ocupado ? 'Processando...' : 'Aprovar pagamento' }}
          </button>
          <button class="pos-botao pos-botao-fraco" :disabled="ocupado" @click="recusar">
            Recusar
          </button>
          <button class="pos-voltar" @click="limpar">Voltar</button>
        </div>
      </template>

      <!-- COMPROVANTE -->
      <template v-else>
        <div class="pos-corpo centro">
          <div class="pos-ok">&#10004;</div>
          <p class="pos-aprovado">APROVADO</p>
          <div class="pos-total" style="margin:10px 0 4px">{{ moeda(recibo.amount) }}</div>
          <p class="pos-meio">{{ rotuloMeio(recibo.method) }}</p>
          <p class="pos-nota" style="margin-top:20px">
            Cobrança {{ recibo.code }}<br />
            {{ dataHora(new Date().toISOString()) }}
          </p>
          <button class="pos-botao" @click="limpar">Nova cobrança</button>
        </div>
      </template>
    </div>

    <p class="pos-rodape">
      Esta tela substitui a maquininha enquanto a integração com a Stone não está ligada.
      <NuxtLink to="/painel">Voltar ao sistema</NuxtLink>
    </p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const codigo = ref('')
const fila = ref<any[]>([])
const atual = ref<any>(null)
const recibo = ref<any>(null)
const erro = ref('')
const ocupado = ref(false)
let relogio: any = null

const rotuloMeio = (m: string) => ({
  credito: 'Crédito', debito: 'Débito', pix: 'Pix', voucher: 'Voucher', dinheiro: 'Dinheiro'
}[m] ?? m)

function digitar(e: Event) {
  codigo.value = (e.target as HTMLInputElement).value.replace(/\D/g, '').slice(0, 6)
  ;(e.target as HTMLInputElement).value = codigo.value
}

async function carregarFila() {
  if (atual.value || recibo.value) return
  const { data } = await supa.rpc('fn_charges_device', { p_device: null })
  fila.value = data ?? []
}

onMounted(() => {
  carregarFila()
  relogio = setInterval(carregarFila, 5000)
})
onUnmounted(() => clearInterval(relogio))

async function abrir(c: string) {
  erro.value = ''
  ocupado.value = true
  const { data, error } = await supa.rpc('fn_charge_by_code', { p_code: c })
  ocupado.value = false
  const achado = Array.isArray(data) ? data[0] : data
  if (error) { erro.value = error.message; return }
  if (!achado) { erro.value = 'Código não encontrado.'; return }
  if (achado.status !== 'aguardando') {
    erro.value = achado.status === 'pago' ? 'Esta cobrança já foi paga.' : 'Esta cobrança não está mais aberta.'
    return
  }
  atual.value = achado
}

async function pagar() {
  erro.value = ''
  ocupado.value = true
  const { error } = await supa.rpc('fn_confirm_charge', {
    p_code: atual.value.code,
    p_external: 'SIM-' + Date.now()
  })
  ocupado.value = false
  if (error) { erro.value = error.message; return }
  recibo.value = atual.value
  atual.value = null
  carregarFila()
}

async function recusar() {
  ocupado.value = true
  await supa.rpc('fn_cancel_charge', { p_code: atual.value.code, p_reason: 'Recusada na maquininha' })
  ocupado.value = false
  limpar()
}

function limpar() {
  atual.value = null; recibo.value = null; codigo.value = ''; erro.value = ''
  carregarFila()
}
</script>

<style scoped>
.pos-tela { display: grid; place-items: center; padding: 10px 0 40px; }
.pos {
  width: 100%; max-width: 330px; background: #1c1c1e; border-radius: 26px;
  padding: 8px; box-shadow: 0 26px 60px -24px rgba(0,0,0,.55);
}
.pos-topo {
  background: #00a868; border-radius: 20px 20px 4px 4px; padding: 14px 18px; text-align: center;
}
.pos-marca { color: #fff; font-weight: 700; letter-spacing: .22em; font-size: 15px; }
.pos-modelo { color: rgba(255,255,255,.8); font-size: 10px; letter-spacing: .1em; margin-top: 2px; }
.pos-corpo {
  background: #fff; border-radius: 4px 4px 20px 20px; padding: 22px 18px 24px; min-height: 380px;
}
.pos-titulo {
  font-size: 10.5px; letter-spacing: .14em; text-transform: uppercase;
  color: var(--rotulo); font-weight: 600; margin-bottom: 10px;
}
.pos-fila { display: flex; flex-direction: column; gap: 8px; }
.pos-item {
  display: flex; justify-content: space-between; align-items: center; gap: 10px;
  width: 100%; padding: 11px 13px; border: 1px solid var(--linha); border-radius: 10px;
  background: var(--campo); font: inherit; cursor: pointer; text-align: left;
}
.pos-item:hover { border-color: #00a868; background: #f2fbf7; }
.pos-item strong { display: block; font-size: 14px; color: var(--tinta); }
.pos-item small { font-size: 11px; color: var(--rotulo); }
.pos-valor { font-weight: 700; font-size: 14px; color: var(--tinta); white-space: nowrap; }
.pos-vazio { font-size: 13px; color: var(--rotulo); padding: 10px 0; }
.pos-input {
  width: 100%; text-align: center; font-size: 28px; font-weight: 700; letter-spacing: .3em;
  text-indent: .3em; padding: 12px; border: 1px solid var(--linha); border-radius: 10px;
  background: var(--campo); color: var(--tinta); font-family: inherit;
}
.pos-input:focus { outline: none; border-color: #00a868; background: #fff; }
.pos-botao {
  width: 100%; margin-top: 14px; padding: 13px; border: 0; border-radius: 10px;
  background: #00a868; color: #fff; font: inherit; font-size: 14.5px; font-weight: 600; cursor: pointer;
}
.pos-botao:disabled { opacity: .45; cursor: not-allowed; }
.pos-botao-fraco { background: var(--campo); color: var(--vermelho); border: 1px solid var(--linha); }
.pos-voltar {
  width: 100%; margin-top: 10px; background: none; border: 0;
  color: var(--rotulo); font: inherit; font-size: 12.5px; cursor: pointer;
}
.pos-total { font-size: 34px; font-weight: 700; color: var(--tinta); text-align: center; }
.pos-meio { text-align: center; font-size: 13px; color: var(--texto); }
.pos-lista { margin: 20px 0 8px; border-top: 1px dashed var(--linha); padding-top: 12px; }
.pos-linha { display: flex; justify-content: space-between; font-size: 12.5px; color: var(--texto); padding: 3px 0; }
.pos-nota { font-size: 11px; color: var(--rotulo); text-align: center; margin-top: 12px; line-height: 1.6; }
.pos-erro { font-size: 12.5px; color: var(--vermelho); margin-top: 10px; text-align: center; }
.pos-ok { font-size: 44px; color: #00a868; }
.pos-aprovado { font-weight: 700; letter-spacing: .18em; color: #00a868; font-size: 15px; margin-top: 6px; }
.pos-rodape { margin-top: 18px; font-size: 12.5px; color: var(--rotulo); text-align: center; max-width: 340px; line-height: 1.6; }
</style>
