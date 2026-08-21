<template>
  <div>
    <div class="cabecalho">
      <div>
        <h1>Maquininha</h1>
        <p>Simulação do terminal de pagamento. Digite o código da venda e confirme.</p>
      </div>
    </div>

    <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>
    <div v-if="pago" class="aviso aviso-ok">
      Pagamento aprovado. Venda registrada, estoque baixado e enviada à Omie.
    </div>

    <div class="painel">
      <div class="painel-corpo" style="max-width:420px;margin:0 auto;text-align:center;padding:32px">
        <span class="rotulo">Código da venda</span>
        <input v-model="codigo" class="campo" inputmode="numeric" maxlength="6"
          placeholder="000000"
          style="font-size:34px;text-align:center;letter-spacing:8px;margin:12px 0" />

        <div v-if="escolhida" style="margin:14px 0">
          <div class="rotulo">{{ escolhida.unit_name }}</div>
          <div style="font-size:26px;font-weight:700">{{ moeda(escolhida.total) }}</div>
        </div>

        <span class="rotulo">Forma de pagamento</span>
        <div style="display:flex;gap:8px;justify-content:center;margin:10px 0 18px">
          <button v-for="f in formas" :key="f" class="btn btn-p"
            :class="forma === f ? 'btn-principal' : 'btn-neutro'" @click="forma = f">
            {{ f }}
          </button>
        </div>

        <button class="btn btn-principal" style="width:100%"
          :disabled="codigo.length !== 6 || pagando" @click="pagar">
          {{ pagando ? 'Processando...' : 'Confirmar pagamento' }}
        </button>
      </div>
    </div>

    <div class="painel" style="margin-top:16px">
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
              <td><strong style="font-size:16px;letter-spacing:2px">{{ c.code }}</strong></td>
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

const formas = ['Pix', 'Débito', 'Crédito']
const codigo = ref('')
const forma = ref('Pix')
const abertas = ref<any[]>([])
const erro = ref('')
const pago = ref(false)
const pagando = ref(false)

const escolhida = computed(() =>
  abertas.value.find((c: any) => c.code === codigo.value) || null)

async function carregar () {
  const { data } = await supa.rpc('fn_open_charges')
  abertas.value = data ?? []
}

async function pagar () {
  pagando.value = true
  erro.value = ''
  pago.value = false
  try {
    const { error } = await supa.rpc('fn_pay_charge', {
      p_code: codigo.value.trim(),
      p_forma: forma.value
    })
    if (error) throw error
    pago.value = true
    codigo.value = ''
    await carregar()
  } catch (e) {
    erro.value = e.message || 'Não foi possível confirmar o pagamento.'
  } finally {
    pagando.value = false
  }
}

onMounted(carregar)
</script>
