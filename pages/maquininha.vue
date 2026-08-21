<template>
  <div>
    <div class="cabecalho">
      <div>
        <h1>Maquininha</h1>
        <p>Simulação do terminal de pagamento. Não é o equipamento real.</p>
      </div>
      <NuxtLink to="/vendas" class="btn btn-neutro btn-p">Voltar</NuxtLink>
    </div>

    <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>

    <!-- ---------- Terminal ---------- -->
    <div class="pos">
      <div class="pos-topo">
        <span class="pos-marca">terminal de pagamento</span>
        <span class="pos-sinal">simulação</span>
      </div>

      <div class="pos-tela">
        <!-- Pagamento concluído -->
        <template v-if="pago">
          <div class="pos-check">✓</div>
          <div class="pos-aprovado">APROVADO</div>
          <div class="pos-valor">{{ moeda(pago.total) }}</div>
          <div class="pos-nota">
            {{ pago.forma }}<template v-if="pago.parcelas > 1"> · {{ pago.parcelas }}x</template>
          </div>
          <button class="btn btn-principal" style="width:100%;margin-top:22px" @click="reiniciar">
            Nova cobrança
          </button>
        </template>

        <!-- Aguardando código -->
        <template v-else-if="!escolhida">
          <div class="pos-rotulo">Código da venda</div>
          <input v-model="codigo" class="pos-input" inputmode="numeric" maxlength="6"
            placeholder="000000" />
          <div class="pos-nota" style="margin-top:14px">
            Digite o código que apareceu na tela da filial.
          </div>
        </template>

        <!-- Cobrança encontrada -->
        <template v-else>
          <div class="pos-rotulo">{{ escolhida.unit_name }}</div>
          <div class="pos-valor">{{ moeda(escolhida.total) }}</div>
          <div v-if="Number(escolhida.desconto) > 0" class="pos-nota">
            desconto de {{ moeda(escolhida.desconto) }}
          </div>

          <!-- Escolha da forma -->
          <template v-if="!forma">
            <div class="pos-rotulo" style="margin-top:20px">Forma de pagamento</div>
            <div class="pos-formas">
              <button v-for="f in formas" :key="f" class="pos-btn" @click="escolherForma(f)">
                {{ f }}
              </button>
            </div>
          </template>

          <!-- Crédito: parcelas -->
          <template v-else-if="forma === 'Crédito' && !confirmando">
            <div class="pos-rotulo" style="margin-top:18px">Parcelas</div>
            <div class="pos-parcelas">
              <button v-for="n in 12" :key="n" class="pos-parcela"
                :class="{ ativa: parcelas === n }" @click="parcelas = n">
                {{ n }}x
              </button>
            </div>
            <div class="pos-nota" style="margin-top:10px">
              {{ parcelas }}x de {{ moeda(escolhida.total / parcelas) }}
            </div>
            <button class="btn btn-principal" style="width:100%;margin-top:18px"
              :disabled="pagando" @click="pagar">
              {{ pagando ? 'Processando...' : 'Passar cartão' }}
            </button>
            <button class="pos-voltar" @click="forma = ''">Trocar forma</button>
          </template>

          <!-- Pix: QR Code -->
          <template v-else-if="forma === 'Pix'">
            <div class="pos-rotulo" style="margin-top:16px">Aponte a câmera</div>
            <div class="pos-qr" v-html="qrSvg"></div>
            <button class="btn btn-principal" style="width:100%;margin-top:6px"
              :disabled="pagando" @click="pagar">
              {{ pagando ? 'Processando...' : 'Ler QR Code' }}
            </button>
            <button class="pos-voltar" @click="forma = ''">Trocar forma</button>
          </template>

          <!-- Débito -->
          <template v-else>
            <div class="pos-nota" style="margin-top:20px">Insira ou aproxime o cartão</div>
            <button class="btn btn-principal" style="width:100%;margin-top:16px"
              :disabled="pagando" @click="pagar">
              {{ pagando ? 'Processando...' : 'Passar cartão' }}
            </button>
            <button class="pos-voltar" @click="forma = ''">Trocar forma</button>
          </template>
        </template>
      </div>
    </div>

    <!-- ---------- Fila ---------- -->
    <div class="painel" style="margin-top:20px">
      <div class="painel-topo">
        <h2>Aguardando pagamento</h2>
        <button class="btn btn-neutro btn-p" @click="carregar">Atualizar</button>
      </div>
      <TabelaVazia v-if="!abertas.length" titulo="Nenhuma cobrança"
        texto="As vendas enviadas pelas filiais aparecem aqui." />
      <div v-else class="tabela-rolagem">
        <table class="lista">
          <thead><tr><th>Código</th><th>Filial</th><th>Valor</th><th></th></tr></thead>
          <tbody>
            <tr v-for="c in abertas" :key="c.id">
              <td><strong style="letter-spacing:2px">{{ c.code }}</strong></td>
              <td>{{ c.unit_name }}</td>
              <td>{{ moeda(c.total) }}</td>
              <td><button class="btn btn-neutro btn-p" @click="codigo = c.code">Usar</button></td>
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
const rota = useRoute()

const formas = ['Pix', 'Débito', 'Crédito']
const codigo = ref(String(rota.query.codigo || ''))
const forma = ref('')
const parcelas = ref(1)
const abertas = ref<any[]>([])
const erro = ref('')
const pago = ref<any>(null)
const pagando = ref(false)
const confirmando = ref(false)

const escolhida = computed(() =>
  abertas.value.find((c: any) => c.code === codigo.value) || null)

function escolherForma (f: string) {
  forma.value = f
  parcelas.value = 1
}

function reiniciar () {
  pago.value = null
  forma.value = ''
  parcelas.value = 1
  codigo.value = ''
  erro.value = ''
}

// QR fictício: um desenho estável, gerado a partir do código da venda.
// Não é um Pix de verdade e não leva a lugar nenhum.
const qrSvg = computed(() => {
  const semente = (codigo.value || '000000').split('')
    .reduce((a, c) => a * 31 + c.charCodeAt(0), 7)
  let x = semente || 1
  const rnd = () => { x = (x * 1103515245 + 12345) % 2147483648; return x / 2147483648 }

  const n = 21
  const cheio: boolean[][] = []
  for (let i = 0; i < n; i++) {
    cheio[i] = []
    for (let j = 0; j < n; j++) cheio[i][j] = rnd() > 0.52
  }
  // marcas de canto, como num QR de verdade
  const marca = (li: number, lj: number) => {
    for (let i = 0; i < 7; i++) for (let j = 0; j < 7; j++) {
      const borda = i === 0 || i === 6 || j === 0 || j === 6
      const miolo = i >= 2 && i <= 4 && j >= 2 && j <= 4
      cheio[li + i][lj + j] = borda || miolo
    }
  }
  marca(0, 0); marca(0, n - 7); marca(n - 7, 0)

  let q = ''
  for (let i = 0; i < n; i++)
    for (let j = 0; j < n; j++)
      if (cheio[i][j]) q += `<rect x="${j}" y="${i}" width="1" height="1"/>`

  return `<svg viewBox="0 0 ${n} ${n}" width="170" height="170"
    xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
    <rect width="${n}" height="${n}" fill="#fff"/>
    <g fill="#0a0a0a">${q}</g></svg>`
})

async function carregar () {
  const { data } = await supa.rpc('fn_open_charges')
  abertas.value = data ?? []
}

async function pagar () {
  pagando.value = true
  erro.value = ''
  try {
    const alvo = escolhida.value
    const { error } = await supa.rpc('fn_pay_charge', {
      p_code: codigo.value.trim(),
      p_forma: forma.value,
      p_parcelas: parcelas.value
    })
    if (error) throw error
    pago.value = { total: alvo?.total, forma: forma.value, parcelas: parcelas.value }
    await carregar()
  } catch (e) {
    erro.value = e.message || 'Não foi possível confirmar o pagamento.'
  } finally {
    pagando.value = false
  }
}

onMounted(carregar)
</script>

<style scoped>
/* Terminal simulado. Cores inspiradas em maquininhas de cartão. */
.pos {
  max-width: 340px; margin: 0 auto;
  background: #101314; border-radius: 26px; padding: 16px;
  box-shadow: 0 18px 40px rgba(0,0,0,.28);
}
.pos-topo {
  display: flex; justify-content: space-between; align-items: center;
  padding: 2px 6px 12px;
}
.pos-marca { color: #00d264; font-size: 11px; font-weight: 700; letter-spacing: 1.4px; text-transform: uppercase; }
.pos-sinal { color: #5d6b66; font-size: 10px; letter-spacing: 1px; text-transform: uppercase; }
.pos-tela {
  background: #f7f9f8; border-radius: 16px; padding: 24px 20px; text-align: center;
  min-height: 240px; display: flex; flex-direction: column; justify-content: center;
}
.pos-rotulo { color: #7b8b85; font-size: 11px; letter-spacing: 1.4px; text-transform: uppercase; }
.pos-input {
  width: 100%; border: 0; background: transparent; text-align: center;
  font-size: 34px; font-weight: 700; letter-spacing: 8px; color: #101314;
  margin-top: 10px; outline: none;
}
.pos-valor { font-size: 30px; font-weight: 700; color: #101314; margin: 6px 0; }
.pos-nota { color: #7b8b85; font-size: 12.5px; }
.pos-formas { display: flex; gap: 8px; margin-top: 10px; }
.pos-btn {
  flex: 1; border: 0; border-radius: 12px; padding: 13px 0; cursor: pointer;
  background: #00a859; color: #fff; font-weight: 600; font-size: 13.5px;
}
.pos-btn:hover { background: #00d264; }
.pos-parcelas { display: grid; grid-template-columns: repeat(6, 1fr); gap: 5px; margin-top: 10px; }
.pos-parcela {
  border: 1px solid #dfe6e3; background: #fff; border-radius: 9px;
  padding: 8px 0; cursor: pointer; font-size: 12px; font-weight: 600; color: #101314;
}
.pos-parcela.ativa { background: #00a859; border-color: #00a859; color: #fff; }
.pos-qr { margin: 12px auto; line-height: 0; }
.pos-voltar {
  border: 0; background: transparent; color: #7b8b85; font-size: 12px;
  margin-top: 10px; cursor: pointer; text-decoration: underline;
}
.pos-check {
  width: 62px; height: 62px; border-radius: 50%; background: #00a859; color: #fff;
  font-size: 32px; line-height: 62px; margin: 0 auto 12px;
}
.pos-aprovado { color: #00a859; font-weight: 700; letter-spacing: 2px; font-size: 15px; }
</style>
