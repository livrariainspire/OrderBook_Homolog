<template>
  <div>
    <div class="cabecalho">
      <div>
        <h1>Nova venda</h1>
        <p>Monte a venda, aplique o token de desconto e envie para a maquininha.</p>
      </div>
    </div>

    <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>

    <div v-if="cobranca" class="painel">
      <div class="painel-corpo" style="text-align:center;padding:36px">
        <span class="rotulo">Código para digitar na maquininha</span>
        <div style="font-size:44px;font-weight:700;letter-spacing:6px;margin:10px 0">
          {{ cobranca.code }}
        </div>
        <div style="font-size:22px;font-weight:600;margin-bottom:6px">
          {{ moeda(cobranca.total) }}
        </div>
        <p v-if="Number(cobranca.desconto) > 0" class="rotulo">
          {{ moeda(cobranca.subtotal) }} com {{ moeda(cobranca.desconto) }} de desconto
        </p>
        <p style="margin-top:18px">Aguardando o pagamento na maquininha.</p>
        <div style="display:flex;gap:8px;justify-content:center;margin-top:18px">
          <button class="btn btn-neutro btn-p" @click="recomecar">Nova venda</button>
          <NuxtLink to="/vendas" class="btn btn-principal btn-p">Ver vendas</NuxtLink>
        </div>
      </div>
    </div>

    <template v-else>
      <div class="painel">
        <div class="painel-topo"><h2>1. Produtos vendidos</h2></div>
        <div class="painel-corpo">
          <BuscaProdutos somente-com-estoque :unidade-id="unidadeId"
            :escolhidos="carrinho.map((i) => i.id)" @escolher="adicionar" />
        </div>
      </div>

      <div class="painel">
        <div class="painel-topo">
          <h2>2. Quantidades</h2>
          <strong style="font-size:16px">{{ moeda(subtotal) }}</strong>
        </div>
        <div class="painel-corpo">
          <TabelaVazia v-if="!carrinho.length" titulo="Nenhum produto"
            texto="Busque acima entre os produtos disponíveis no seu estoque." />
          <template v-else>
            <div v-for="(i, idx) in carrinho" :key="i.id" class="carrinho-item">
              <FotoProduto :url="i.photo_url" :titulo="i.title" :tipo="i.type" />
              <div class="cresce">
                <div class="produto-nome">{{ i.title }}</div>
                <div class="produto-meta">
                  Disponível: {{ i.estoque }} · {{ moeda(i.preco_tabela) }} cada
                </div>
              </div>
              <div>
                <label class="rotulo" style="margin-bottom:4px">Qtd</label>
                <input v-model.number="i.qty" class="campo qtd" type="number"
                  min="1" :max="i.estoque" />
              </div>
              <div style="min-width:90px;text-align:right">
                <label class="rotulo" style="margin-bottom:4px">Subtotal</label>
                <strong>{{ moeda(i.qty * (i.preco_tabela || 0)) }}</strong>
              </div>
              <button class="btn-icone" title="Remover" @click="carrinho.splice(idx, 1)">✕</button>
            </div>
          </template>
        </div>
      </div>

      <div class="painel">
        <div class="painel-topo"><h2>3. Desconto</h2></div>
        <div class="painel-corpo">

          <button v-if="!mostrarToken && !tokenAplicado" class="btn btn-neutro btn-p"
            @click="mostrarToken = true">
            Adicionar desconto por token
          </button>

          <div v-if="tokenAplicado" class="aviso aviso-ok"
               style="display:flex;justify-content:space-between;align-items:center">
            <span>
              Token <strong>{{ tokenAplicado.code }}</strong> aplicado:
              {{ tokenAplicado.descricao }}, {{ tokenAplicado.percentual }}% de desconto.
            </span>
            <button class="btn btn-neutro btn-p" @click="removerToken">Remover</button>
          </div>

          <template v-if="mostrarToken && !tokenAplicado">
            <p class="rotulo" style="margin-bottom:10px">
              Digite o token do cliente. Se não tiver, é só cancelar.
            </p>
            <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">
              <input v-model="token" class="campo"
                style="max-width:220px;text-transform:uppercase"
                placeholder="Ex.: PASTOR" @keyup.enter="validarToken" />
              <button class="btn btn-principal btn-p" :disabled="!token.trim() || validando"
                @click="validarToken">
                {{ validando ? 'Conferindo...' : 'Validar' }}
              </button>
              <button class="btn btn-neutro btn-p" @click="cancelarToken">Cancelar</button>
            </div>

            <div v-if="tokenRecusado" class="aviso aviso-erro" style="margin-top:14px">
              <p style="margin-bottom:10px">
                O token <strong>{{ tokenRecusado }}</strong> não foi reconhecido.
                Deseja seguir sem desconto?
              </p>
              <div style="display:flex;gap:8px">
                <button class="btn btn-principal btn-p" @click="cancelarToken">
                  Seguir sem desconto
                </button>
                <button class="btn btn-neutro btn-p" @click="tokenRecusado = ''">
                  Tentar outro token
                </button>
              </div>
            </div>
          </template>
        </div>
      </div>

      <div class="painel">
        <div class="painel-corpo" style="display:flex;justify-content:space-between;align-items:center">
          <div>
            <span class="rotulo">Total</span>
            <div style="font-size:24px;font-weight:700">{{ moeda(totalComDesconto) }}</div>
            <span v-if="tokenAplicado" class="rotulo">
              {{ moeda(subtotal) }} menos {{ moeda(valorDesconto) }} de desconto
            </span>
          </div>
          <button class="btn btn-principal" :disabled="!carrinho.length || enviando"
            @click="enviar">
            {{ enviando ? 'Enviando...' : 'Enviar para a maquininha' }}
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

const carrinho = ref<any[]>([])
const token = ref('')
const mostrarToken = ref(false)
const tokenAplicado = ref<any>(null)
const tokenRecusado = ref('')
const validando = ref(false)
const erro = ref('')
const enviando = ref(false)
const cobranca = ref<any>(null)

const unidadeId = computed(() => sessao.value.perfil?.unit_id)
const subtotal = computed(() =>
  carrinho.value.reduce((s, i) => s + (i.qty || 0) * (i.preco_tabela || 0), 0))

const valorDesconto = computed(() =>
  tokenAplicado.value
    ? Math.round(subtotal.value * tokenAplicado.value.percentual) / 100
    : 0)
// subtotal * pct / 100, arredondado em centavos

const totalComDesconto = computed(() => subtotal.value - valorDesconto.value)

async function validarToken () {
  validando.value = true
  tokenRecusado.value = ''
  try {
    const { data, error } = await supa.rpc('fn_check_token', { p_code: token.value.trim() })
    if (error) throw error
    if (data?.valido) {
      tokenAplicado.value = { code: token.value.trim().toUpperCase(), ...data }
      mostrarToken.value = false
    } else {
      tokenRecusado.value = token.value.trim().toUpperCase()
    }
  } catch (e) {
    erro.value = e.message || 'Não foi possível conferir o token.'
  } finally {
    validando.value = false
  }
}

function cancelarToken () {
  token.value = ''
  tokenRecusado.value = ''
  mostrarToken.value = false
}

function removerToken () {
  tokenAplicado.value = null
  token.value = ''
}

function adicionar (p: any) {
  carrinho.value.push({ ...p, qty: 1 })
}

function recomecar () {
  carrinho.value = []
  token.value = ''
  tokenAplicado.value = null
  tokenRecusado.value = ''
  mostrarToken.value = false
  cobranca.value = null
  erro.value = ''
}

async function enviar () {
  enviando.value = true
  erro.value = ''
  try {
    const { data, error } = await supa.rpc('fn_create_charge', {
      p_items: carrinho.value.map(i => ({ product_id: i.id, qty: i.qty })),
      p_token: tokenAplicado.value?.code || null
    })
    if (error) throw error
    cobranca.value = data
  } catch (e) {
    erro.value = e.message || 'Não foi possível criar a cobrança.'
  } finally {
    enviando.value = false
  }
}
</script>
